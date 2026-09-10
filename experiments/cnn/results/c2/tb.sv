`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,iv=0,ready=0; wire ir,ov; reg [15:0] din=0; wire [15:0] dout;
reg [15:0] stim[0:127],gold[0:127];
integer sent=0,got=0,cycles=0,stalls=0,done_at=0; reg blocked=0,taken=0; reg [15:0] held;
int8_dw3x1 #(.WIDTH(8),.HEIGHT(8),.CHANNELS(2),.QSHIFT(7),.RELU(0)) dut
(clk,rst_n,iv,ir,din,48'h9f0080ff7f80,64'hffffe13dfffff702,ov,ready,dout);
initial begin
stim[0]=16'h1bc; gold[0]=16'hedab;
stim[1]=16'hd3a7; gold[1]=16'hf896;
stim[2]=16'h303b; gold[2]=16'h9b29;
stim[3]=16'h8702; gold[3]=16'hd2ef;
stim[4]=16'hd9ae; gold[4]=16'h809c;
stim[5]=16'hc2df; gold[5]=16'h80ce;
stim[6]=16'h3a4b; gold[6]=16'ha638;
stim[7]=16'h79af; gold[7]=16'hc9f;
stim[8]=16'hc800; gold[8]=16'hbe32;
stim[9]=16'hba0c; gold[9]=16'hfc52;
stim[10]=16'h34f1; gold[10]=16'h80a5;
stim[11]=16'hec5f; gold[11]=16'h1b4b;
stim[12]=16'h767c; gold[12]=16'h927f;
stim[13]=16'h63d6; gold[13]=16'hfde5;
stim[14]=16'h250f; gold[14]=16'h80b3;
stim[15]=16'h9f84; gold[15]=16'h80c3;
stim[16]=16'h441; gold[16]=16'he12f;
stim[17]=16'hef5c; gold[17]=16'hbc3e;
stim[18]=16'h6bce; gold[18]=16'h80cc;
stim[19]=16'h2ba1; gold[19]=16'he080;
stim[20]=16'h73fb; gold[20]=16'h8080;
stim[21]=16'h5f0; gold[21]=16'h8009;
stim[22]=16'h458f; gold[22]=16'hcc80;
stim[23]=16'hf65c; gold[23]=16'h187f;
stim[24]=16'h21fa; gold[24]=16'hc5a7;
stim[25]=16'h65bd; gold[25]=16'h1b80;
stim[26]=16'h27f2; gold[26]=16'h8011;
stim[27]=16'hf313; gold[27]=16'h8060;
stim[28]=16'hc5df; gold[28]=16'h80d3;
stim[29]=16'hec6; gold[29]=16'hf6c5;
stim[30]=16'hc210; gold[30]=16'h8070;
stim[31]=16'hf93; gold[31]=16'h9e80;
stim[32]=16'hf8fe; gold[32]=16'hadf2;
stim[33]=16'ha22a; gold[33]=16'h805a;
stim[34]=16'h6c79; gold[34]=16'hd374;
stim[35]=16'h2620; gold[35]=16'hd2fa;
stim[36]=16'h79d3; gold[36]=16'h9e2;
stim[37]=16'hb69e; gold[37]=16'he2c7;
stim[38]=16'h3d8f; gold[38]=16'hdb80;
stim[39]=16'h3d98; gold[39]=16'hdbf3;
stim[40]=16'hf1e8; gold[40]=16'hb4d8;
stim[41]=16'h7727; gold[41]=16'hceb;
stim[42]=16'hb7e5; gold[42]=16'hb480;
stim[43]=16'hfd72; gold[43]=16'h803f;
stim[44]=16'hf134; gold[44]=16'h894f;
stim[45]=16'hc4fa; gold[45]=16'hfa49;
stim[46]=16'h3136; gold[46]=16'ha87f;
stim[47]=16'hcc54; gold[47]=16'h907f;
stim[48]=16'h1d43; gold[48]=16'hf448;
stim[49]=16'h1bde; gold[49]=16'h84a5;
stim[50]=16'h8597; gold[50]=16'hf7a1;
stim[51]=16'h5921; gold[51]=16'hbc9c;
stim[52]=16'hac94; gold[52]=16'h1480;
stim[53]=16'h1973; gold[53]=16'hec66;
stim[54]=16'hd3a0; gold[54]=16'hf280;
stim[55]=16'hf22e; gold[55]=16'hddc8;
stim[56]=16'hd366; gold[56]=16'ha510;
stim[57]=16'hb60f; gold[57]=16'ha71f;
stim[58]=16'h1b0e; gold[58]=16'h3d65;
stim[59]=16'hd3c; gold[59]=16'h8009;
stim[60]=16'ha81b; gold[60]=16'h1675;
stim[61]=16'h191a; gold[61]=16'ha995;
stim[62]=16'h81bd; gold[62]=16'hef0c;
stim[63]=16'h22f7; gold[63]=16'hd0b7;
stim[64]=16'h1bc; gold[64]=16'hedab;
stim[65]=16'hd3a7; gold[65]=16'hf896;
stim[66]=16'h303b; gold[66]=16'h9b29;
stim[67]=16'h8702; gold[67]=16'hd2ef;
stim[68]=16'hd9ae; gold[68]=16'h809c;
stim[69]=16'hc2df; gold[69]=16'h80ce;
stim[70]=16'h3a4b; gold[70]=16'ha638;
stim[71]=16'h79af; gold[71]=16'hc9f;
stim[72]=16'hc800; gold[72]=16'hbe32;
stim[73]=16'hba0c; gold[73]=16'hfc52;
stim[74]=16'h34f1; gold[74]=16'h80a5;
stim[75]=16'hec5f; gold[75]=16'h1b4b;
stim[76]=16'h767c; gold[76]=16'h927f;
stim[77]=16'h63d6; gold[77]=16'hfde5;
stim[78]=16'h250f; gold[78]=16'h80b3;
stim[79]=16'h9f84; gold[79]=16'h80c3;
stim[80]=16'h441; gold[80]=16'he12f;
stim[81]=16'hef5c; gold[81]=16'hbc3e;
stim[82]=16'h6bce; gold[82]=16'h80cc;
stim[83]=16'h2ba1; gold[83]=16'he080;
stim[84]=16'h73fb; gold[84]=16'h8080;
stim[85]=16'h5f0; gold[85]=16'h8009;
stim[86]=16'h458f; gold[86]=16'hcc80;
stim[87]=16'hf65c; gold[87]=16'h187f;
stim[88]=16'h21fa; gold[88]=16'hc5a7;
stim[89]=16'h65bd; gold[89]=16'h1b80;
stim[90]=16'h27f2; gold[90]=16'h8011;
stim[91]=16'hf313; gold[91]=16'h8060;
stim[92]=16'hc5df; gold[92]=16'h80d3;
stim[93]=16'hec6; gold[93]=16'hf6c5;
stim[94]=16'hc210; gold[94]=16'h8070;
stim[95]=16'hf93; gold[95]=16'h9e80;
stim[96]=16'hf8fe; gold[96]=16'hadf2;
stim[97]=16'ha22a; gold[97]=16'h805a;
stim[98]=16'h6c79; gold[98]=16'hd374;
stim[99]=16'h2620; gold[99]=16'hd2fa;
stim[100]=16'h79d3; gold[100]=16'h9e2;
stim[101]=16'hb69e; gold[101]=16'he2c7;
stim[102]=16'h3d8f; gold[102]=16'hdb80;
stim[103]=16'h3d98; gold[103]=16'hdbf3;
stim[104]=16'hf1e8; gold[104]=16'hb4d8;
stim[105]=16'h7727; gold[105]=16'hceb;
stim[106]=16'hb7e5; gold[106]=16'hb480;
stim[107]=16'hfd72; gold[107]=16'h803f;
stim[108]=16'hf134; gold[108]=16'h894f;
stim[109]=16'hc4fa; gold[109]=16'hfa49;
stim[110]=16'h3136; gold[110]=16'ha87f;
stim[111]=16'hcc54; gold[111]=16'h907f;
stim[112]=16'h1d43; gold[112]=16'hf448;
stim[113]=16'h1bde; gold[113]=16'h84a5;
stim[114]=16'h8597; gold[114]=16'hf7a1;
stim[115]=16'h5921; gold[115]=16'hbc9c;
stim[116]=16'hac94; gold[116]=16'h1480;
stim[117]=16'h1973; gold[117]=16'hec66;
stim[118]=16'hd3a0; gold[118]=16'hf280;
stim[119]=16'hf22e; gold[119]=16'hddc8;
stim[120]=16'hd366; gold[120]=16'ha510;
stim[121]=16'hb60f; gold[121]=16'ha71f;
stim[122]=16'h1b0e; gold[122]=16'h3d65;
stim[123]=16'hd3c; gold[123]=16'h8009;
stim[124]=16'ha81b; gold[124]=16'h1675;
stim[125]=16'h191a; gold[125]=16'ha995;
stim[126]=16'h81bd; gold[126]=16'hef0c;
stim[127]=16'h22f7; gold[127]=16'hd0b7;
repeat(3) @(negedge clk); rst_n=1;
end
always @(negedge clk) if(rst_n) begin
ready=(cycles%7!=2 && cycles%7!=3);
if(ov && got==0 && stalls<2) ready=0;
if(!iv || taken) begin iv=(sent<128 && cycles%5!=1); if(sent<128) din=stim[sent]; end
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
$display("CNN PASS beats=%0d cycles=%0d stalled=%0d",got,cycles,stalls); $finish;
end
end
if(cycles>10000) $fatal(1,"timeout");
end
endmodule
