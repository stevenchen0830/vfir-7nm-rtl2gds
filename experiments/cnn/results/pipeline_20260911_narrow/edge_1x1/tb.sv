`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [7:0] din=0; wire [7:0] dout;
reg [7:0] stim[0:1],gold[0:1];
reg [23:0] wstim[0:1],wreg;
reg [31:0] bstim[0:1],breg;
integer active_frame=0,reset_left=0; reg reset_done=0;
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [7:0] held;
int8_dw3x1 #(.WIDTH(1),.HEIGHT(1),.CHANNELS(1),.QSHIFT(0),.RELU(0)) dut
(clk,rst_n,iv,ir,din,wreg,breg,ov,ready,dout);
initial begin
stim[0]=8'h80; gold[0]=8'h80;
stim[1]=8'h81; gold[1]=8'h80;
wstim[0]=24'hff7f80; bstim[0]=32'hffffe3b6;wstim[1]=24'h80ff7f; bstim[1]=32'hffffe6a3;
wreg=wstim[0]; breg=bstim[0];
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) begin
if(0 && rst_n && !reset_done && sent>=1) begin
rst_n=0; reset_done=1; reset_left=2; sent=0; got=0; iv=0; blocked=0; taken=0; active_frame=0;
wreg=wstim[0]; breg=bstim[0];
end else if(reset_left>0) begin reset_left=reset_left-1; if(reset_left==0) rst_n=1; end
else if(rst_n) begin
// Do not reload frame-static parameters until its final output was accepted.
if(active_frame+1<2 && got>=(active_frame+1)*1) begin
active_frame=active_frame+1; wreg=wstim[active_frame]; breg=bstim[active_frame];
end
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<(active_frame+1)*1 && sent<2 && cycles%5!=1); if(sent<2) din=stim[sent]; end
end
end
always @(posedge clk) if(rst_n) begin
cycles=cycles+1;
if(blocked && (!ov || dout!==held)) $fatal(1,"unstable output");
blocked=ov&&!ready; held=dout; if(blocked) stalls=stalls+1;
taken=iv&&ir;
if(taken) sent=sent+1;
if(ov&&ready) begin
if(got>=2 || dout!==gold[got]) $fatal(1,"CNN mismatch beat %0d got %h expected %h",got,dout,gold[got]);
got=got+1;
end
if(got==2) begin
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
