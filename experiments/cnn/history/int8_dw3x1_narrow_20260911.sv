// Signed INT8 vertical depthwise convolution. Three weights per channel.
// Two rolling line buffers, zero top/bottom padding, stride 1, one pixel/beat.
// All channels parallel; bias INT32; symmetric quantization zero_point=0.
// QSHIFT rounding: nearest, ties away from zero; optional ReLU after scaling.
// Three valid-aligned stages: products -> bias/accumulate -> requantize.
// A blocked output freezes every stage and the line buffers together.
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
    // Do not synthesize 32-bit signed counters/comparators for a tiny image.
    // y must represent HEIGHT during the virtual-row flush.
    localparam integer XW = WIDTH <= 1 ? 1 : $clog2(WIDTH);
    localparam integer YW = HEIGHT <= 1 ? 1 : $clog2(HEIGHT+1);
    reg [XW-1:0] x;
    reg [YW-1:0] y;
    integer c;
    reg flushing;
    reg product_valid, sum_valid;
    reg signed [15:0] product0[0:CHANNELS-1],product1[0:CHANNELS-1],product2[0:CHANNELS-1];
    reg signed [31:0] bias_q[0:CHANNELS-1];
    reg signed [32:0] sum_q[0:CHANNELS-1];
    wire advance=!out_valid || out_ready;
    assign in_ready=rst_n && !flushing && advance;
    // INT32 bias plus three signed 8x8 products needs 33 signed bits.
    // Rounding offset (QSHIFT <= 31) also fits in the same width.
    reg signed [32:0] rounded, shifted;
    reg signed [17:0] product_sum;
    localparam signed [32:0] HALF = (QSHIFT>0) ? (33'sd1 << (QSHIFT-1)) : 33'sd0;
    reg signed [7:0] top,center,bottom,w0,w1,w2;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x<=0; y<=0; flushing<=0; out_valid<=0; out_data<=0;
            product_valid<=0; sum_valid<=0;
        end else if(advance) begin
            out_valid<=sum_valid;
            sum_valid<=product_valid;
            product_valid<=0;
            for(c=0;c<CHANNELS;c=c+1) begin
                if(sum_valid) begin
                    // floor((a + half - (a<0))/2^Q) rounds ties away
                    // from zero without a 64-bit abs/negate/add/negate cone.
                    if(QSHIFT>0) begin
                        rounded=sum_q[c]+HALF-(sum_q[c][32] ? 33'sd1 : 33'sd0);
                        shifted=rounded>>>QSHIFT;
                    end else shifted=sum_q[c];
                    if(RELU && shifted<0) shifted=0;
                    if(shifted>127) shifted=127;
                    if(shifted< -128) shifted=-128;
                    out_data[c*8+:8]<=shifted[7:0];
                end
                if(product_valid) begin
                    product_sum={{2{product0[c][15]}},product0[c]}+
                                {{2{product1[c][15]}},product1[c]}+
                                {{2{product2[c][15]}},product2[c]};
                    sum_q[c]<=$signed({bias_q[c][31],bias_q[c]})+
                              $signed({{15{product_sum[17]}},product_sum});
                end
            end
            if(flushing || in_valid) begin
                if(y>=1) begin
                    for(c=0;c<CHANNELS;c=c+1) begin
                        top=(y>=2)?$signed(row2[x][c*8+:8]):8'sd0;
                        center=$signed(row1[x][c*8+:8]);
                        bottom=flushing?8'sd0:$signed(in_data[c*8+:8]);
                        w0=$signed(weights[c*24+:8]); w1=$signed(weights[c*24+8+:8]); w2=$signed(weights[c*24+16+:8]);
                        product0[c]<=top*w0;
                        product1[c]<=center*w1;
                        product2[c]<=bottom*w2;
                        bias_q[c]<=biases[c*32+:32];
                    end
                    product_valid<=1;
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
