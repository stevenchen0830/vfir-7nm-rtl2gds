`timescale 1ns/1ps
// Experimental v5 MAC. Legal unsigned FIR coefficients must sum to 128.
// All stages freeze together. Payload is unreset; valid masks it after reset.
module fir_mac_pipeline (
    input wire clk, rst_n, advance, in_valid,
    input wire [7999:0] tap_data,
    input wire [399:0] tap_coef,
    output wire out_valid,
    output wire [159:0] result
);
    reg [7:0] valid;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) valid <= 8'b0;
        else if (advance) valid <= {valid[6:0], in_valid};
    assign out_valid = valid[7];

    // Stage 0: split each 10x8 multiply into two independent 10x4 cones.
    // Stage 1: recombine, before any cross-tap addition.
    // Stages 2..7: one binary addition per stage (50->25->13->7->4->2->1).
    // max valid partial sum = 1023*128 = 130944 < 2^17.
    // The output register in IMG_FILTER performs round/saturate, separately.
    genvar lane, tap, level, node;
    generate for (lane=0; lane<16; lane=lane+1) begin : G_LANE
        wire [16:0] sums [0:6][0:49];
        for (tap=0; tap<50; tap=tap+1) begin : G_MULT
            reg [13:0] lo_q, hi_q;
            reg [16:0] product_q;
            wire [9:0] pixel = tap_data[tap*160+lane*10 +: 10];
            wire [7:0] weight = tap_coef[tap*8 +: 8];
            wire [17:0] full_product = {4'b0,lo_q} + {hi_q,4'b0};
            always @(posedge clk) if (advance) begin
                if (in_valid) begin
                    lo_q <= pixel * weight[3:0];
                    hi_q <= pixel * weight[7:4];
                end
                if (valid[0]) product_q <= full_product[16:0];
            end
            assign sums[0][tap] = product_q;
        end
        for (level=1; level<=6; level=level+1) begin : G_REDUCE
            localparam PREV = (50 + (1<<(level-1)) - 1) >> (level-1);
            localparam COUNT = (PREV+1)/2;
            for (node=0; node<50; node=node+1) begin : G_NODE
                if (node<COUNT) begin : G_USED
                    reg [16:0] sum_q;
                    wire [16:0] rhs;
                    if (2*node+1<PREV) begin : G_PAIR
                        assign rhs = sums[level-1][2*node+1];
                    end else begin : G_ODD
                        assign rhs = 17'b0;
                    end
                    always @(posedge clk)
                        if (advance && valid[level])
                            sum_q <= sums[level-1][2*node] + rhs;
                    assign sums[level][node] = sum_q;
                end else begin : G_UNUSED
                    assign sums[level][node] = 17'b0;
                end
            end
        end
        wire [17:0] rounded = {1'b0,sums[6][0]} + 18'd64;
        assign result[lane*10 +: 10] = rounded[17] ? 10'd1023 : rounded[16:7];
    end endgenerate
endmodule
