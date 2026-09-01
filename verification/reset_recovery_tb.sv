`timescale 1ns/1ps

module reset_recovery_tb;
    localparam [159:0] PATTERN = {4{40'h155_2aa_3c3}};
    localparam S_IDLE = 0, S_PREP = 1, S_FILL = 2, S_MAIN = 3;

    reg clk = 0;
    reg rst_n = 0;
    reg in_pix_rdy = 0;
    wire in_pix_need;
    reg [159:0] in_pix_data = PATTERN;
    wire out_pix_rdy;
    reg out_pix_need = 0;
    wire [159:0] out_pix_data;
    reg frm_start = 0;
    reg [10:0] img_width = 23;
    reg [11:0] img_height = 23;
    reg [5:0] blk_v = 1;
    reg [199:0] coef = 128;
    wire [48:0] mem_ce, mem_we;
    wire [538:0] mem_addr;
    wire [7839:0] mem_wdata;
    integer errors = 0;
    integer reset_checks = 0;

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

    task pulse_frame(input integer bv);
        begin
            @(negedge clk);
            img_width = 23;
            img_height = 23;
            blk_v = bv;
            coef = 200'd0;
            coef[7:0] = 8'd128;
            frm_start = 1;
            @(negedge clk);
            frm_start = 0;
        end
    endtask

    task assert_runtime_reset(input integer site);
        begin
            pulse_frame(7);
            in_pix_rdy = 1;
            out_pix_need = 1;
            case (site)
                0: wait (dut.state == S_PREP && dut.prep_cnt == 4'd3);
                1: wait (dut.state == S_PREP && dut.prep_cnt == 4'd9);
                2: wait (dut.state == S_PREP && dut.prep_cnt == 4'd10);
                3: wait (dut.state == S_FILL);
                4: begin
                    wait (dut.state == S_MAIN);
                    @(negedge clk);
                    out_pix_need = 0;
                    wait (out_pix_rdy);
                end
            endcase

            @(negedge clk);
            rst_n = 0;
            in_pix_rdy = 0;
            out_pix_need = 0;
            #0.1;
            reset_checks = reset_checks + 1;
            if (dut.state !== S_IDLE || out_pix_rdy !== 1'b0 ||
                mem_ce !== 49'd0 || mem_we !== 49'd0 || in_pix_need !== 1'b0) begin
                errors = errors + 1;
                $display("RESET ERROR site=%0d state=%0d out=%b ce=%h we=%h need=%b",
                         site, dut.state, out_pix_rdy, mem_ce, mem_we, in_pix_need);
            end
            repeat (3) @(negedge clk);
            rst_n = 1;
            repeat (2) @(negedge clk);
        end
    endtask

    task recover_pass_through;
        integer sent, received, beats;
        begin
            beats = 24 * 6;
            sent = 0;
            received = 0;
            pulse_frame(1);
            in_pix_data = PATTERN;
            out_pix_need = 1;
            fork
                begin
                    in_pix_rdy = 1;
                    while (sent < beats) begin
                        @(posedge clk);
                        if (in_pix_need) sent = sent + 1;
                    end
                    @(negedge clk);
                    in_pix_rdy = 0;
                end
                begin
                    while (received < beats) begin
                        @(posedge clk);
                        if (out_pix_rdy && out_pix_need) begin
                            if (out_pix_data !== PATTERN) begin
                                errors = errors + 1;
                                $display("RECOVERY DATA ERROR beat=%0d got=%h", received, out_pix_data);
                            end
                            received = received + 1;
                        end
                    end
                    @(negedge clk);
                    out_pix_need = 0;
                end
            join
            repeat (5) @(negedge clk);
            if (dut.state !== S_IDLE || out_pix_rdy !== 1'b0) begin
                errors = errors + 1;
                $display("RECOVERY COMPLETION ERROR state=%0d out=%b", dut.state, out_pix_rdy);
            end
        end
    endtask

    integer site;
    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (3) @(negedge clk);

        for (site = 0; site < 5; site = site + 1) begin
            assert_runtime_reset(site);
            recover_pass_through;
        end

        $display("RESET COVERAGE PREP=1 ROT_A=1 ROT_B=1 FILL=1 MAIN_BACKPRESSURE=1");
        $display("RESET RECOVERY checks=%0d errors=%0d", reset_checks, errors);
        if (errors == 0) begin
            $display("RESET TEST PASSED");
            $finish;
        end
        $fatal(1, "RESET TEST FAILED");
    end

    initial begin
        #2_000_000;
        $fatal(1, "RESET TEST TIMEOUT");
    end
endmodule
