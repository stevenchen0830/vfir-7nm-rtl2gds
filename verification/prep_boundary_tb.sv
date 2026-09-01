`timescale 1ns/1ps

// Focused PREP boundary test.  For blk_v=3 at output row zero, the mirrored
// top tap and centre tap must both map to bank 0; the bottom tap is bypassed.
module prep_boundary_tb;
    reg clk = 0, rst_n = 0, frm_start = 0;
    reg [11:0] img_height = 0;
    reg [199:0] coef = 0;
    wire in_pix_need, out_pix_rdy;
    wire [159:0] out_pix_data;
    wire [48:0] mem_ce, mem_we;
    wire [538:0] mem_addr;
    wire [7839:0] mem_wdata;
    reg [391:0] expected;
    integer errors = 0, checks = 0;

    always #0.5 clk = ~clk;

    IMG_FILTER dut (
        .clk(clk), .rst_n(rst_n), .in_pix_rdy(1'b0),
        .in_pix_need(in_pix_need), .in_pix_data(160'd0),
        .out_pix_rdy(out_pix_rdy), .out_pix_need(1'b0),
        .out_pix_data(out_pix_data), .frm_start(frm_start),
        .img_width(11'd23), .img_height(img_height), .blk_v(6'd3),
        .coef(coef), .mem_ce(mem_ce), .mem_we(mem_we),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_rdata(7840'd0)
    );

    task check_height(input integer height);
        integer bank;
        begin
            rst_n = 0;
            repeat (3) @(negedge clk);
            rst_n = 1;
            coef = 200'd0;
            coef[7:0] = 8'd40;
            coef[15:8] = 8'd48;
            img_height = height - 1;
            @(negedge clk);
            frm_start = 1;
            @(negedge clk);
            frm_start = 0;
            wait (dut.c_load === 1'b1);
            @(posedge clk);
            #0.1;
            expected = 392'd0;
            expected[7:0] = 8'd88;
            checks = checks + 1;
            if (dut.c_cur !== expected || dut.cbp_cur !== 8'd40) begin
                errors = errors + 1;
                $display("PREP BOUNDARY ERROR H=%0d mod_x=%0d cbp=%0d", height,
                         dut.mod_x, dut.cbp_cur);
                for (bank = 0; bank < 49; bank = bank + 1)
                    if (dut.c_cur[bank*8 +: 8] !== expected[bank*8 +: 8])
                        $display("  bank=%0d exp=%0d got=%0d", bank,
                                 expected[bank*8 +: 8], dut.c_cur[bank*8 +: 8]);
            end
        end
    endtask

    initial begin
        check_height(24);
        check_height(49);
        check_height(4095);
        check_height(4096);
        $display("PREP BOUNDARY checks=%0d errors=%0d", checks, errors);
        if (errors == 0) begin
            $display("PREP BOUNDARY TEST PASSED");
            $finish;
        end
        $fatal(1, "PREP BOUNDARY TEST FAILED");
    end
endmodule
