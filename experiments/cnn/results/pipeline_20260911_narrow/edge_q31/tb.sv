`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [23:0] din=0; wire [23:0] dout;
reg [23:0] stim[0:11],gold[0:11];
reg [71:0] wstim[0:1],wreg;
reg [95:0] bstim[0:1],breg;
integer active_frame=0,reset_left=0; reg reset_done=0;
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [23:0] held;
int8_dw3x1 #(.WIDTH(3),.HEIGHT(2),.CHANNELS(3),.QSHIFT(31),.RELU(0)) dut
(clk,rst_n,iv,ir,din,wreg,breg,ov,ready,dout);
initial begin
stim[0]=24'h686b80; gold[0]=24'h0;
stim[1]=24'h3349d9; gold[1]=24'h0;
stim[2]=24'hbeb85d; gold[2]=24'h0;
stim[3]=24'h669a9; gold[3]=24'h0;
stim[4]=24'h2be898; gold[4]=24'h0;
stim[5]=24'he81ef5; gold[5]=24'h0;
stim[6]=24'hbfd281; gold[6]=24'h0;
stim[7]=24'h4a82dc; gold[7]=24'h0;
stim[8]=24'he2d3cb; gold[8]=24'h0;
stim[9]=24'hf98dd5; gold[9]=24'h0;
stim[10]=24'hc04665; gold[10]=24'h0;
stim[11]=24'h14fe9a; gold[11]=24'h0;
wstim[0]=72'h9f7f0040ffffff7f80; bstim[0]=96'h34c00001b0500001397;wstim[1]=72'hff7f01ff400180ff7f; bstim[1]=96'hffffe7ed0000136c00001de5;
wreg=wstim[0]; breg=bstim[0];
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) begin
if(0 && rst_n && !reset_done && sent>=3) begin
rst_n=0; reset_done=1; reset_left=2; sent=0; got=0; iv=0; blocked=0; taken=0; active_frame=0;
wreg=wstim[0]; breg=bstim[0];
end else if(reset_left>0) begin reset_left=reset_left-1; if(reset_left==0) rst_n=1; end
else if(rst_n) begin
// Do not reload frame-static parameters until its final output was accepted.
if(active_frame+1<2 && got>=(active_frame+1)*6) begin
active_frame=active_frame+1; wreg=wstim[active_frame]; breg=bstim[active_frame];
end
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<(active_frame+1)*6 && sent<12 && cycles%5!=1); if(sent<12) din=stim[sent]; end
end
end
always @(posedge clk) if(rst_n) begin
cycles=cycles+1;
if(blocked && (!ov || dout!==held)) $fatal(1,"unstable output");
blocked=ov&&!ready; held=dout; if(blocked) stalls=stalls+1;
taken=iv&&ir;
if(taken) sent=sent+1;
if(ov&&ready) begin
if(got>=12 || dout!==gold[got]) $fatal(1,"CNN mismatch beat %0d got %h expected %h",got,dout,gold[got]);
got=got+1;
end
if(got==12) begin
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
