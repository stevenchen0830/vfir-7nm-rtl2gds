#!/usr/bin/env python3
"""Generate a self-checking SV test from an independent integer convolution."""
import argparse
import json
import random
import subprocess
import time
from pathlib import Path


def quant(acc,shift,relu):
    value=((abs(acc)+(1<<(shift-1)))>>shift) if shift else abs(acc)
    if acc<0: value=-value
    return max(0 if relu else -128,min(127,value))


def run(out,seed,channels=2,width=8,height=8,relu=0,frames=2,shift=7):
    if min(channels,width,height,frames)<1 or not 0<=shift<=31: raise ValueError('positive dimensions; QSHIFT 0..31')
    out.mkdir(parents=True,exist_ok=True); rng=random.Random(seed)
    image=[[[rng.randint(-128,127) for _ in range(channels)] for _ in range(width)] for _ in range(height)]
    # Extreme weights plus mixed signs, bias, saturation and negative outputs.
    weights=[[rng.choice([-128,-97,-1,0,1,64,127]) for _ in range(3)] for _ in range(channels)]
    biases=[rng.randint(-8192,8192) for _ in range(channels)]
    weights[0]=[-128,127,-1]
    expected=[]; inputs=[]
    for y in range(height):
        for x in range(width):
            values=[]
            for c in range(channels):
                acc=biases[c]
                for k in range(3):
                    yy=y+k-1
                    if 0<=yy<height: acc+=image[yy][x][c]*weights[c][k]
                values.append(quant(acc,shift,relu))
            expected.append(sum((v&255)<<(8*c) for c,v in enumerate(values)))
            inputs.append(sum((v&255)<<(8*c) for c,v in enumerate(image[y][x])))
    # Back-to-back frames stress the virtual-row flush -> new-frame transition.
    # Repeating the exact frame isolates framing correctness from coefficient reload.
    inputs*=frames; expected*=frames
    wp=sum((weights[c][k]&255)<<(24*c+8*k) for c in range(channels) for k in range(3))
    bp=sum((v&0xffffffff)<<(32*c) for c,v in enumerate(biases))
    init='\n'.join(f"stim[{i}]={8*channels}'h{v:x}; gold[{i}]={8*channels}'h{expected[i]:x};" for i,v in enumerate(inputs))
    tb=f'''`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [{8*channels-1}:0] din=0; wire [{8*channels-1}:0] dout;
reg [{8*channels-1}:0] stim[0:{len(inputs)-1}],gold[0:{len(inputs)-1}];
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [{8*channels-1}:0] held;
int8_dw3x1 #(.WIDTH({width}),.HEIGHT({height}),.CHANNELS({channels}),.QSHIFT({shift}),.RELU({relu})) dut
(clk,rst_n,iv,ir,din,{24*channels}'h{wp:x},{32*channels}'h{bp:x},ov,ready,dout);
initial begin
{init}
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) if(rst_n) begin
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<{len(inputs)} && cycles%5!=1); if(sent<{len(inputs)}) din=stim[sent]; end
end
always @(posedge clk) if(rst_n) begin
cycles=cycles+1;
if(blocked && (!ov || dout!==held)) $fatal(1,"unstable output");
blocked=ov&&!ready; held=dout; if(blocked) stalls=stalls+1;
taken=iv&&ir;
if(taken) sent=sent+1;
if(ov&&ready) begin
if(got>={len(inputs)} || dout!==gold[got]) $fatal(1,"CNN mismatch beat %0d got %h expected %h",got,dout,gold[got]);
got=got+1;
end
if(got=={len(inputs)}) begin
if(done_at==0) done_at=cycles;
if(cycles>=done_at+10) begin
if(stalls==0) $fatal(1,"stall coverage missing");
$display("CNN PASS beats=%0d cycles=%0d stalled=%0d",got,cycles,stalls); $finish;
end
end
if(cycles>10000) $fatal(1,"timeout");
end
endmodule
'''
    (out/'tb.sv').write_text(tb)
    rtl=Path(__file__).parent/'rtl/int8_dw3x1.sv'
    start=time.perf_counter()
    subprocess.run(['iverilog','-g2012','-s','tb','-o',str(out/'tb.vvp'),str(rtl),str(out/'tb.sv')],check=True)
    r=subprocess.run(['vvp',str(out/'tb.vvp')],capture_output=True,text=True)
    (out/'simulation.log').write_text(r.stdout)
    if r.returncode or 'CNN PASS' not in r.stdout:
        raise RuntimeError(r.stdout+r.stderr)
    result={'scope':'signed INT8 3x1 depthwise CNN operator; not a complete trained classifier',
            'seed':seed,'channels':channels,'width':width,'height':height,'relu':relu,'frames':frames,'qshift':shift,
            'pixel_beats':len(inputs),'component_checks':len(inputs)*channels,'weights':weights,
            'biases':biases,'line_buffer_bits':2*width*channels*8,'macs_per_output_pixel':3*channels,
            'wall_seconds':time.perf_counter()-start,'simulation':r.stdout.strip(),
            'accuracy':'bit-exact integer operator test; task accuracy not measured',
            'physical_area_power':'separate placement pilot only; see results/placement; no SRAM macro or energy measurement'}
    (out/'results.json').write_text(json.dumps(result,indent=2)+'\n'); print(json.dumps(result))


if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--output',type=Path,default=Path('work/cnn'))
    p.add_argument('--seed',type=int,default=20260910); p.add_argument('--channels',type=int,default=2)
    p.add_argument('--relu',type=int,choices=[0,1],default=0)
    p.add_argument('--width',type=int,default=8); p.add_argument('--height',type=int,default=8)
    p.add_argument('--frames',type=int,default=2); p.add_argument('--qshift',type=int,default=7)
    a=p.parse_args(); run(a.output,a.seed,a.channels,a.width,a.height,a.relu,a.frames,a.qshift)
