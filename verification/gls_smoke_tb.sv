`timescale 1ns/1ps

// Public-interface-only smoke for a zero-delay synthesized netlist.  blk_v=1
// deliberately avoids dependence on an SRAM timing model while still testing
// reset, frame capture, elastic input/output handshakes and beat ordering.
module gls_smoke_tb;
    localparam BEATS = 24 * 6;
    reg clk = 0;
    reg rst_n = 0;
    reg in_pix_rdy = 0;
    wire in_pix_need;
    reg [159:0] in_pix_data = 0;
    wire out_pix_rdy;
    reg out_pix_need = 1;
    wire [159:0] out_pix_data;
    reg frm_start = 0;
    wire [48:0] mem_ce, mem_we;
    wire [538:0] mem_addr;
    wire [7839:0] mem_wdata;
    reg [159:0] stimulus [0:BEATS-1];
    integer sent = 0, received = 0, errors = 0, seed, i, word;

    always #0.5 clk = ~clk;

    IMG_FILTER dut (
        .clk(clk), .rst_n(rst_n), .in_pix_rdy(in_pix_rdy),
        .in_pix_need(in_pix_need), .in_pix_data(in_pix_data),
        .out_pix_rdy(out_pix_rdy), .out_pix_need(out_pix_need),
        .out_pix_data(out_pix_data), .frm_start(frm_start),
        .img_width(11'd23), .img_height(12'd23), .blk_v(6'd1),
        .coef(200'd128), .mem_ce(mem_ce), .mem_we(mem_we),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_rdata(7840'd0)
    );

    always @(posedge clk) begin
        if (rst_n && out_pix_rdy && out_pix_need) begin
            if (received >= BEATS) begin
                errors = errors + 1;
                $display("GLS EXTRA OUTPUT beat=%0d got=%h", received, out_pix_data);
            end else if (out_pix_data !== stimulus[received]) begin
                errors = errors + 1;
                $display("GLS DATA ERROR beat=%0d exp=%h got=%h",
                         received, stimulus[received], out_pix_data);
            end
            received = received + 1;
        end
    end

    initial begin
        seed = 32'h6c53_2026;
        for (i = 0; i < BEATS; i = i + 1)
            for (word = 0; word < 5; word = word + 1)
                stimulus[i][word*32 +: 32] = $random(seed);

        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (3) @(negedge clk);
        frm_start = 1;
        @(negedge clk);
        frm_start = 0;

        while (sent < BEATS) begin
            @(negedge clk);
            in_pix_rdy = 1;
            in_pix_data = stimulus[sent];
            #0.4;
            if (in_pix_need) sent = sent + 1;
        end
        @(negedge clk);
        in_pix_rdy = 0;

        wait (received == BEATS);
        repeat (5) @(negedge clk);
        if (out_pix_rdy !== 1'b0) errors = errors + 1;
        $display("GLS SMOKE beats=%0d errors=%0d", received, errors);
        if (errors == 0) begin
            $display("GLS TEST PASSED");
            $finish;
        end
        $fatal(1, "GLS TEST FAILED");
    end

    initial begin
        #2_000_000;
        $fatal(1, "GLS TEST TIMEOUT");
    end
endmodule
