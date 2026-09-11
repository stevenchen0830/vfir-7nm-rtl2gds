// Signed INT8 vertical depthwise convolution. Three weights per channel.
// Two rolling line buffers, zero top/bottom padding, stride 1, one pixel/beat.
// All channels parallel; bias INT32; symmetric quantization zero_point=0.
// QSHIFT rounding: nearest, ties away from zero; optional ReLU after scaling.
module int8_dw3x1 #(
    parameter integer WIDTH=8, HEIGHT=8, CHANNELS=2, QSHIFT=7, RELU=0
)(
    input wire clk,rst_n,
    input wire in_valid,
    output wire in_ready,
    input wire [CHANNELS*8-1:0] in_data,
    input wire [CHANNELS*24-1:0] weights,
    input wire [CHANNELS*32-1:0] biases,
    output reg out_valid,
    input wire out_ready,
    output reg [CHANNELS*8-1:0] out_data
);
    reg [CHANNELS*8-1:0] row1[0:WIDTH-1], row2[0:WIDTH-1];
    integer x,y,c;
    reg flushing;
    wire advance=!out_valid || out_ready;
    assign in_ready=rst_n && !flushing && advance;
    reg signed [63:0] acc,rounded;
    reg signed [7:0] top,center,bottom,w0,w1,w2;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x<=0; y<=0; flushing<=0; out_valid<=0; out_data<=0;
        end else if(advance) begin
            out_valid<=0;
            if(flushing || in_valid) begin
                if(y>=1) begin
                    for(c=0;c<CHANNELS;c=c+1) begin
                        top=(y>=2)?$signed(row2[x][c*8+:8]):8'sd0;
                        center=$signed(row1[x][c*8+:8]);
                        bottom=flushing?8'sd0:$signed(in_data[c*8+:8]);
                        w0=$signed(weights[c*24+:8]); w1=$signed(weights[c*24+8+:8]); w2=$signed(weights[c*24+16+:8]);
                        acc=$signed(biases[c*32+:32]);
                        acc=acc+top*w0+center*w1+bottom*w2;
                        if(QSHIFT>0) begin
                            if(acc<0) rounded=-(((-acc)+(64'sd1<<(QSHIFT-1)))>>>QSHIFT);
                            else rounded=(acc+(64'sd1<<(QSHIFT-1)))>>>QSHIFT;
                        end else rounded=acc;
                        if(RELU && rounded<0) rounded=0;
                        if(rounded>127) rounded=127;
                        if(rounded< -128) rounded=-128;
                        out_data[c*8+:8]<=rounded[7:0];
                    end
                    out_valid<=1;
                end
                if(!flushing) begin
                    if(y>=1) row2[x]<=row1[x];
                    row1[x]<=in_data;
                end
                if(x==WIDTH-1) begin
                    x<=0;
                    if(flushing) begin flushing<=0; y<=0; end
                    else if(y==HEIGHT-1) begin flushing<=1; y<=HEIGHT; end
                    else y<=y+1;
                end else x<=x+1;
            end
        end
    end
endmodule
