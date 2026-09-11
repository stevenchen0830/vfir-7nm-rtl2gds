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


def run(out,seed,channels=2,width=8,height=8,relu=0,frames=2,shift=7,reset_midframe=False,bias_extremes=False):
    if min(channels,width,height,frames)<1 or not 0<=shift<=31: raise ValueError('positive dimensions; QSHIFT 0..31')
    out.mkdir(parents=True,exist_ok=True); rng=random.Random(seed)
    expected=[]; inputs=[]; frame_weights=[]; frame_biases=[]; params=[]
    for frame in range(frames):
        image=[[[rng.randint(-128,127) for _ in range(channels)] for _ in range(width)] for _ in range(height)]
        # Distinct adjacent frames expose stale line-buffer content. Even the
        # 1x1 edge case differs deterministically, not merely probabilistically.
        image[0][0][0] = -128 + frame % 256
        weights=[[rng.choice([-128,-97,-1,0,1,64,127]) for _ in range(3)] for _ in range(channels)]
        biases=[rng.randint(-8192,8192) for _ in range(channels)]
        if bias_extremes:
            biases=[(2**31-1 if (frame+c)%2==0 else -2**31) for c in range(channels)]
        weights[0]=[-128,127,-1] if frame%2==0 else [127,-1,-128]
        frame_weights.append(weights); frame_biases.append(biases)
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
        wp=sum((weights[c][k]&255)<<(24*c+8*k) for c in range(channels) for k in range(3))
        bp=sum((v&0xffffffff)<<(32*c) for c,v in enumerate(biases))
        params.append(f"wstim[{frame}]={24*channels}'h{wp:x}; bstim[{frame}]={32*channels}'h{bp:x};")
    init='\n'.join(f"stim[{i}]={8*channels}'h{v:x}; gold[{i}]={8*channels}'h{expected[i]:x};" for i,v in enumerate(inputs))
    tb=f'''`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [{8*channels-1}:0] din=0; wire [{8*channels-1}:0] dout;
reg [{8*channels-1}:0] stim[0:{len(inputs)-1}],gold[0:{len(inputs)-1}];
reg [{24*channels-1}:0] wstim[0:{frames-1}],wreg;
reg [{32*channels-1}:0] bstim[0:{frames-1}],breg;
integer active_frame=0,reset_left=0; reg reset_done=0;
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [{8*channels-1}:0] held;
int8_dw3x1 #(.WIDTH({width}),.HEIGHT({height}),.CHANNELS({channels}),.QSHIFT({shift}),.RELU({relu})) dut
(clk,rst_n,iv,ir,din,wreg,breg,ov,ready,dout);
initial begin
{init}
{''.join(params)}
wreg=wstim[0]; breg=bstim[0];
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) begin
if({1 if reset_midframe else 0} && rst_n && !reset_done && sent>={max(1,width*height//2)}) begin
rst_n=0; reset_done=1; reset_left=2; sent=0; got=0; iv=0; blocked=0; taken=0; active_frame=0;
wreg=wstim[0]; breg=bstim[0];
end else if(reset_left>0) begin reset_left=reset_left-1; if(reset_left==0) rst_n=1; end
else if(rst_n) begin
// Do not reload frame-static parameters until its final output was accepted.
if(active_frame+1<{frames} && got>=(active_frame+1)*{width*height}) begin
active_frame=active_frame+1; wreg=wstim[active_frame]; breg=bstim[active_frame];
end
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<(active_frame+1)*{width*height} && sent<{len(inputs)} && cycles%5!=1); if(sent<{len(inputs)}) din=stim[sent]; end
end
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
if({1 if reset_midframe else 0} && !reset_done) $fatal(1,"reset coverage missing");
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
            'pixel_beats':len(inputs),'component_checks':len(inputs)*channels,'frame_weights':frame_weights,
            'frame_biases':frame_biases,'distinct_frames':True,'parameter_reload_each_frame':True,
            'midframe_reset_restart':reset_midframe,'bias_extremes':bias_extremes,
            'line_buffer_bits':2*width*channels*8,'macs_per_output_pixel':3*channels,
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
    p.add_argument('--reset-midframe',action='store_true')
    p.add_argument('--bias-extremes',action='store_true')
    a=p.parse_args(); run(a.output,a.seed,a.channels,a.width,a.height,a.relu,a.frames,a.qshift,a.reset_midframe,a.bias_extremes)
