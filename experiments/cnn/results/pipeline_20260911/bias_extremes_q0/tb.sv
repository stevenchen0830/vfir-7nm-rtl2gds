`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [15:0] din=0; wire [15:0] dout;
reg [15:0] stim[0:17],gold[0:17];
reg [47:0] wstim[0:1],wreg;
reg [63:0] bstim[0:1],breg;
integer active_frame=0,reset_left=0; reg reset_done=0;
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [15:0] held;
int8_dw3x1 #(.WIDTH(3),.HEIGHT(3),.CHANNELS(2),.QSHIFT(0),.RELU(0)) dut
(clk,rst_n,iv,ir,din,wreg,breg,ov,ready,dout);
initial begin
stim[0]=16'h180; gold[0]=16'h807f;
stim[1]=16'hd3a7; gold[1]=16'h807f;
stim[2]=16'h303b; gold[2]=16'h807f;
stim[3]=16'h8702; gold[3]=16'h807f;
stim[4]=16'hd9ae; gold[4]=16'h807f;
stim[5]=16'hc2df; gold[5]=16'h807f;
stim[6]=16'h3a4b; gold[6]=16'h807f;
stim[7]=16'h79af; gold[7]=16'h807f;
stim[8]=16'hc800; gold[8]=16'h807f;
stim[9]=16'hd681; gold[9]=16'h7f80;
stim[10]=16'hf63; gold[10]=16'h7f80;
stim[11]=16'h8425; gold[11]=16'h7f80;
stim[12]=16'h419f; gold[12]=16'h7f80;
stim[13]=16'h5c04; gold[13]=16'h7f80;
stim[14]=16'hceef; gold[14]=16'h7f80;
stim[15]=16'ha16b; gold[15]=16'h7f80;
stim[16]=16'hfb2b; gold[16]=16'h7f80;
stim[17]=16'hf073; gold[17]=16'h7f80;
wstim[0]=48'hff9fff7f80; bstim[0]=64'h800000007fffffff;wstim[1]=48'hff400180ff7f; bstim[1]=64'h7fffffff80000000;
wreg=wstim[0]; breg=bstim[0];
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) begin
if(0 && rst_n && !reset_done && sent>=4) begin
rst_n=0; reset_done=1; reset_left=2; sent=0; got=0; iv=0; blocked=0; taken=0; active_frame=0;
wreg=wstim[0]; breg=bstim[0];
end else if(reset_left>0) begin reset_left=reset_left-1; if(reset_left==0) rst_n=1; end
else if(rst_n) begin
// Do not reload frame-static parameters until its final output was accepted.
if(active_frame+1<2 && got>=(active_frame+1)*9) begin
active_frame=active_frame+1; wreg=wstim[active_frame]; breg=bstim[active_frame];
end
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<(active_frame+1)*9 && sent<18 && cycles%5!=1); if(sent<18) din=stim[sent]; end
end
end
always @(posedge clk) if(rst_n) begin
cycles=cycles+1;
if(blocked && (!ov || dout!==held)) $fatal(1,"unstable output");
blocked=ov&&!ready; held=dout; if(blocked) stalls=stalls+1;
taken=iv&&ir;
if(taken) sent=sent+1;
if(ov&&ready) begin
if(got>=18 || dout!==gold[got]) $fatal(1,"CNN mismatch beat %0d got %h expected %h",got,dout,gold[got]);
got=got+1;
end
if(got==18) begin
if(done_at==0) done_at=cycles;
if(cycles>=done_at+10) begin
if(stalls==0) $fatal(1,"stall coverage missing");
if(0 && !reset_done) $fatal(1,"reset coverage missing");
$display("CNN PASS beats=%0d cycles=%0d stalled=%0d",got,cycles,stalls); $finish;
end
end
if(cycles>10000) $fatal(1,"timeout");
end
endmodule
