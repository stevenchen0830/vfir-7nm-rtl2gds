`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [7:0] din=0; wire [7:0] dout;
reg [7:0] stim[0:1],gold[0:1];
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [7:0] held;
int8_dw3x1 #(.WIDTH(1),.HEIGHT(1),.CHANNELS(1),.QSHIFT(0),.RELU(0)) dut
(clk,rst_n,iv,ir,din,24'hff7f80,32'hffffe3b6,ov,ready,dout);
initial begin
stim[0]=8'h2; gold[0]=8'h80;
stim[1]=8'h2; gold[1]=8'h80;
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) if(rst_n) begin
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<2 && cycles%5!=1); if(sent<2) din=stim[sent]; end
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
$display("CNN PASS beats=%0d cycles=%0d stalled=%0d",got,cycles,stalls); $finish;
end
end
if(cycles>10000) $fatal(1,"timeout");
end
endmodule
