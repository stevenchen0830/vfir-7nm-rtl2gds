`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import img_filter_uvm_pkg::*;

    logic clk = 1'b0;
    always #0.5 clk = ~clk;

    img_filter_if vif(clk);

    IMG_FILTER dut (
        .clk          (clk),
        .rst_n        (vif.rst_n),
        .in_pix_rdy   (vif.in_pix_rdy),
        .in_pix_need  (vif.in_pix_need),
        .in_pix_data  (vif.in_pix_data),
        .out_pix_rdy  (vif.out_pix_rdy),
        .out_pix_need (vif.out_pix_need),
        .out_pix_data (vif.out_pix_data),
        .frm_start    (vif.frm_start),
        .img_width    (vif.img_width),
        .img_height   (vif.img_height),
        .blk_v        (vif.blk_v),
        .coef         (vif.coef),
        .mem_ce       (vif.mem_ce),
        .mem_we       (vif.mem_we),
        .mem_addr     (vif.mem_addr),
        .mem_wdata    (vif.mem_wdata),
        .mem_rdata    (vif.mem_rdata)
    );

    img_sram_model sram(vif);
    final begin
        uvm_report_server server;
        server=uvm_report_server::get_server();
        $display("SRAM COVERAGE reads=%0d writes=%0d banks_written=%0d", sram.reads, sram.writes, $countones(sram.banks_written));
        if(server.get_severity_count(UVM_ERROR)!=0 || server.get_severity_count(UVM_FATAL)!=0)
            $fatal(1,"UVM failure propagated to simulator exit status");
        if(int'(vif.blk_v)>1 && (sram.reads==0 || sram.writes==0))
            $fatal(1,"Nontrivial filter did not access SRAM");
    end

    initial begin
        vif.rst_n = 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        vif.rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual img_filter_if)::set(null, "*", "vif", vif);
        run_test("img_filter_smoke_test");
    end

    initial begin
        #200000;
        $fatal(1, "UVM smoke timeout");
    end
endmodule
