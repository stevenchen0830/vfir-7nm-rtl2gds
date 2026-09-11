`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [31:0] din=0; wire [31:0] dout;
reg [31:0] stim[0:127],gold[0:127];
reg [95:0] wstim[0:1],wreg;
reg [127:0] bstim[0:1],breg;
integer active_frame=0,reset_left=0; reg reset_done=0;
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [31:0] held;
int8_dw3x1 #(.WIDTH(8),.HEIGHT(8),.CHANNELS(4),.QSHIFT(7),.RELU(1)) dut
(clk,rst_n,iv,ir,din,wreg,breg,ov,ready,dout);
initial begin
stim[0]=32'hfd0c8c80; gold[0]=32'h52097f00;
stim[1]=32'hacb4c7f2; gold[1]=32'h41085700;
stim[2]=32'haf8f9058; gold[2]=32'h46087f56;
stim[3]=32'he58df7ef; gold[3]=32'h41082800;
stim[4]=32'he65f056; gold[4]=32'h92e54;
stim[5]=32'h2e58d183; gold[5]=32'ha4e00;
stim[6]=32'h2ceecf0e; gold[6]=32'h44094f0c;
stim[7]=32'hb142afb4; gold[7]=32'ha7000;
stim[8]=32'h96073037; gold[8]=32'h637f;
stim[9]=32'ha841bf6b; gold[9]=32'h8447f77;
stim[10]=32'ha3e23916; gold[10]=32'h3a5f5600;
stim[11]=32'ha814f497; gold[11]=32'h5f3300;
stim[12]=32'he42b3f7; gold[12]=32'h17007b00;
stim[13]=32'h3dd33a68; gold[13]=32'h147f;
stim[14]=32'ha408eb35; gold[14]=32'h176425;
stim[15]=32'h6cd3fdd7; gold[15]=32'h55007222;
stim[16]=32'h26f00a42; gold[16]=32'h40009;
stim[17]=32'h2190f59c; gold[17]=32'h7f006b00;
stim[18]=32'heca1094d; gold[18]=32'h761f0035;
stim[19]=32'h4a7fec21; gold[19]=32'h3f7f;
stim[20]=32'hc707c96a; gold[20]=32'h28007f72;
stim[21]=32'h4c5b06fe; gold[21]=32'h2c0000;
stim[22]=32'h7cc6f039; gold[22]=32'h24302;
stim[23]=32'hceb898ae; gold[23]=32'h2a7f00;
stim[24]=32'h45a058d1; gold[24]=32'h23140000;
stim[25]=32'h85006f43; gold[25]=32'h105f007f;
stim[26]=32'hb92e08ba; gold[26]=32'h520e00;
stim[27]=32'h68d05e16; gold[27]=32'h0;
stim[28]=32'hb6db0681; gold[28]=32'h35000;
stim[29]=32'h3fcee518; gold[29]=32'he003419;
stim[30]=32'h7a2580d2; gold[30]=32'h357f00;
stim[31]=32'h1d39b989; gold[31]=32'h19417f00;
stim[32]=32'ha8fb9dfa; gold[32]=32'h11512928;
stim[33]=32'hc0a378ab; gold[33]=32'h59070000;
stim[34]=32'h7d473c1; gold[34]=32'h7;
stim[35]=32'h1fe6ec58; gold[35]=32'h2e003f;
stim[36]=32'h67603f4c; gold[36]=32'h25007f;
stim[37]=32'ha0f3febd; gold[37]=32'h1a2f3b00;
stim[38]=32'hf0f58a2d; gold[38]=32'h7f59;
stim[39]=32'hf59ea483; gold[39]=32'hb007f00;
stim[40]=32'ha42990a2; gold[40]=32'hd7f00;
stim[41]=32'hed780ef9; gold[41]=32'h6750004d;
stim[42]=32'h72fc72c3; gold[42]=32'h2b0002;
stim[43]=32'hb1b0e150; gold[43]=32'h1b5200;
stim[44]=32'h5258355c; gold[44]=32'he;
stim[45]=32'h9fb29b6f; gold[45]=32'h2b127f7f;
stim[46]=32'hffb72d4e; gold[46]=32'h10681e;
stim[47]=32'hc765e1e2; gold[47]=32'h2547f5e;
stim[48]=32'h6c0edd58; gold[48]=32'h7f007f7f;
stim[49]=32'hb262a6ff; gold[49]=32'h5a006c05;
stim[50]=32'hf9af8799; gold[50]=32'hc2500;
stim[51]=32'h767850d5; gold[51]=32'h25470000;
stim[52]=32'hd49e4ded; gold[52]=32'h0;
stim[53]=32'h7478142; gold[53]=32'h38447f00;
stim[54]=32'h79581268; gold[54]=32'h410018;
stim[55]=32'hef17e1cf; gold[55]=32'h7f005d00;
stim[56]=32'h9d209f9d; gold[56]=32'h7f00;
stim[57]=32'h9dd07499; gold[57]=32'h24000500;
stim[58]=32'ha2a3dfa9; gold[58]=32'h467f0f;
stim[59]=32'hfebd4ef8; gold[59]=32'h22;
stim[60]=32'h2156a994; gold[60]=32'h9542900;
stim[61]=32'hfa20e805; gold[61]=32'h7f00;
stim[62]=32'h19c34a07; gold[62]=32'h0;
stim[63]=32'h84a5216a; gold[63]=32'h1d7f;
stim[64]=32'h19841a81; gold[64]=32'h300079;
stim[65]=32'hbb07c4b5; gold[65]=32'hd1954;
stim[66]=32'h100bcfb6; gold[66]=32'h2f0802;
stim[67]=32'h7e82feb; gold[67]=32'h170034;
stim[68]=32'haf9a007a; gold[68]=32'h0;
stim[69]=32'h81960d58; gold[69]=32'h341444;
stim[70]=32'hd206c22a; gold[70]=32'h1400;
stim[71]=32'hb9845a62; gold[71]=32'h4d;
stim[72]=32'h3d92cca6; gold[72]=32'h86c0000;
stim[73]=32'h95c15ccb; gold[73]=32'h2600;
stim[74]=32'h37943a1d; gold[74]=32'h5000149;
stim[75]=32'h35b4ffeb; gold[75]=32'h4000000;
stim[76]=32'hd3f9cf50; gold[76]=32'h7f004b;
stim[77]=32'hdb8c53da; gold[77]=32'h410071;
stim[78]=32'h8ff522a; gold[78]=32'h497f;
stim[79]=32'h9343b7d1; gold[79]=32'h260021;
stim[80]=32'h6be6f170; gold[80]=32'h20030000;
stim[81]=32'hf2f41c33; gold[81]=32'h5;
stim[82]=32'h284ce28c; gold[82]=32'h7b0013;
stim[83]=32'h330ea30e; gold[83]=32'h30c1400;
stim[84]=32'hbb8e294c; gold[84]=32'h56;
stim[85]=32'h9307db05; gold[85]=32'h3e0000;
stim[86]=32'h20305eb7; gold[86]=32'h7f;
stim[87]=32'he145bb5f; gold[87]=32'h3400;
stim[88]=32'h805f9602; gold[88]=32'h2c;
stim[89]=32'ha35c3ae4; gold[89]=32'h7f;
stim[90]=32'h19bf2029; gold[90]=32'h1100;
stim[91]=32'h4e27511e; gold[91]=32'h111f0061;
stim[92]=32'h57e2c117; gold[92]=32'h15000000;
stim[93]=32'h4f1ad942; gold[93]=32'h11002940;
stim[94]=32'heb121b80; gold[94]=32'hd0000;
stim[95]=32'h626e245c; gold[95]=32'h1a001723;
stim[96]=32'hd672ed62; gold[96]=32'h3b7f;
stim[97]=32'haf2b11ab; gold[97]=32'h3f;
stim[98]=32'he5f31ef8; gold[98]=32'h420500;
stim[99]=32'hfd978ccb; gold[99]=32'h0;
stim[100]=32'h5469a573; gold[100]=32'h13001800;
stim[101]=32'h4c7d44e3; gold[101]=32'h1000127f;
stim[102]=32'hb682cbfc; gold[102]=32'hc0000;
stim[103]=32'h6ddaf059; gold[103]=32'h2100007f;
stim[104]=32'h69beff99; gold[104]=32'h1e00007f;
stim[105]=32'h62226dc4; gold[105]=32'h1c001500;
stim[106]=32'h73d1645a; gold[106]=32'h2400002d;
stim[107]=32'hdfe0466; gold[107]=32'h7f7d00;
stim[108]=32'h610cfa78; gold[108]=32'h1b005378;
stim[109]=32'hbf812a7; gold[109]=32'h0;
stim[110]=32'hc6a9232b; gold[110]=32'h250000;
stim[111]=32'hce44f6cd; gold[111]=32'h28;
stim[112]=32'h5054a0ed; gold[112]=32'h1377102b;
stim[113]=32'h9f546e29; gold[113]=32'h0;
stim[114]=32'h8a4757e9; gold[114]=32'h7f;
stim[115]=32'h34837442; gold[115]=32'h4001c7f;
stim[116]=32'hf0564718; gold[116]=32'h53;
stim[117]=32'h5f0bf079; gold[117]=32'h1a40151c;
stim[118]=32'h2c478e78; gold[118]=32'h17b0015;
stim[119]=32'hc16fd44f; gold[119]=32'h5c;
stim[120]=32'haa8d498d; gold[120]=32'h340c;
stim[121]=32'hdd6cc55b; gold[121]=32'h46;
stim[122]=32'h27420599; gold[122]=32'h8;
stim[123]=32'h2c2768ec; gold[123]=32'h5b0060;
stim[124]=32'h1570e42; gold[124]=32'h36;
stim[125]=32'h9a8970a9; gold[125]=32'h7f;
stim[126]=32'h94a3f233; gold[126]=32'h417f;
stim[127]=32'h8ae6fe8f; gold[127]=32'hc6e;
wstim[0]=96'h80ff9fff019f018080ff7f80; bstim[0]=128'hfffff4310000047a00000f4cffffff44;wstim[1]=96'hff40009f018040009f80ff7f; bstim[1]=128'hfffff4f6ffffeea9fffff57a00000f37;
wreg=wstim[0]; breg=bstim[0];
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) begin
if(0 && rst_n && !reset_done && sent>=32) begin
rst_n=0; reset_done=1; reset_left=2; sent=0; got=0; iv=0; blocked=0; taken=0; active_frame=0;
wreg=wstim[0]; breg=bstim[0];
end else if(reset_left>0) begin reset_left=reset_left-1; if(reset_left==0) rst_n=1; end
else if(rst_n) begin
// Do not reload frame-static parameters until its final output was accepted.
if(active_frame+1<2 && got>=(active_frame+1)*64) begin
active_frame=active_frame+1; wreg=wstim[active_frame]; breg=bstim[active_frame];
end
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<(active_frame+1)*64 && sent<128 && cycles%5!=1); if(sent<128) din=stim[sent]; end
end
end
always @(posedge clk) if(rst_n) begin
cycles=cycles+1;
if(blocked && (!ov || dout!==held)) $fatal(1,"unstable output");
blocked=ov&&!ready; held=dout; if(blocked) stalls=stalls+1;
taken=iv&&ir;
if(taken) sent=sent+1;
if(ov&&ready) begin
if(got>=128 || dout!==gold[got]) $fatal(1,"CNN mismatch beat %0d got %h expected %h",got,dout,gold[got]);
got=got+1;
end
if(got==128) begin
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
