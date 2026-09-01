`timescale 1ns/1ps

// Consecutive-frame PREP test: finish a pass-through frame, then configure
// the maximum legal height without resetting.  This catches stale look-ahead
// state that reset-before-every-frame boundary tests cannot observe.
module prep_transition_tb;
    localparam FIRST_BEATS = 24 * 360;
    reg clk = 0, rst_n = 0, frm_start = 0;
    reg in_pix_rdy = 0, out_pix_need = 1;
    reg [159:0] in_pix_data = 0;
    reg [11:0] img_height = 0;
    reg [10:0] img_width = 0;
    reg [5:0] blk_v = 1;
    reg [199:0] coef = 0;
    wire in_pix_need, out_pix_rdy;
    wire [159:0] out_pix_data;
    wire [48:0] mem_ce, mem_we;
    wire [538:0] mem_addr;
    wire [7839:0] mem_wdata;
    integer sent = 0, received = 0, errors = 0, bank;
    reg [391:0] expected;

    always #0.5 clk = ~clk;

    IMG_FILTER dut (
        .clk(clk), .rst_n(rst_n), .in_pix_rdy(in_pix_rdy),
        .in_pix_need(in_pix_need), .in_pix_data(in_pix_data),
        .out_pix_rdy(out_pix_rdy), .out_pix_need(out_pix_need),
        .out_pix_data(out_pix_data), .frm_start(frm_start),
        .img_width(img_width), .img_height(img_height), .blk_v(blk_v),
        .coef(coef), .mem_ce(mem_ce), .mem_we(mem_we),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_rdata(7840'd0)
    );

    always @(posedge clk)
        if (rst_n && out_pix_rdy && out_pix_need)
            received <= received + 1;

    task start_frame;
        begin
            @(negedge clk);
            frm_start = 1;
            @(negedge clk);
            frm_start = 0;
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;

        // Frame 1 reaches IDLE normally; no reset is applied afterwards.
        img_width = 11'd1438;
        img_height = 12'd23;
        blk_v = 6'd1;
        coef = 200'd128;
        start_frame();
        while (sent < FIRST_BEATS) begin
            @(negedge clk);
            in_pix_rdy = 1;
            if (in_pix_need) sent = sent + 1;
        end
        @(negedge clk);
        in_pix_rdy = 0;
        wait (received == FIRST_BEATS);
        wait (dut.state == 3'd0);

        // Frame 2 checks PREP only; there is no need to simulate 4096 rows.
        img_width = 11'd23;
        img_height = 12'd4095;
        blk_v = 6'd3;
        coef = 200'd0;
        coef[7:0] = 8'd41;
        coef[15:8] = 8'd46;
        start_frame();
        wait (dut.c_load === 1'b1);
        @(posedge clk);
        #0.1;
        expected = 392'd0;
        expected[7:0] = 8'd87;
        if (dut.c_cur !== expected || dut.ce_cur !== 49'd1 ||
            dut.cbp_cur !== 8'd41) begin
            errors = errors + 1;
            $display("PREP TRANSITION ERROR mod_x=%0d cbp=%0d", dut.mod_x,
                     dut.cbp_cur);
            for (bank = 0; bank < 49; bank = bank + 1)
                if (dut.c_cur[bank*8 +: 8] !== expected[bank*8 +: 8])
                    $display("  bank=%0d exp=%0d got=%0d ce=%b", bank,
                             expected[bank*8 +: 8],
                             dut.c_cur[bank*8 +: 8], dut.ce_cur[bank]);
        end

        $display("PREP TRANSITION checks=1 errors=%0d", errors);
        if (errors == 0) begin
            $display("PREP TRANSITION TEST PASSED");
            $finish;
        end
        $fatal(1, "PREP TRANSITION TEST FAILED");
    end

    initial begin
        #1_000_000;
        $fatal(1, "PREP TRANSITION TEST TIMEOUT");
    end
endmodule
