`timescale 1ns/1ps
// Protocol model, not a characterized physical macro.
module img_sram_model(img_filter_if vif);
    logic [159:0] mem [0:48][0:1439];
    bit written [0:48][0:1439];
    int unsigned reads=0, writes=0;
    bit [48:0] banks_written='0;
    bit inject_fault;
    initial begin inject_fault=$test$plusargs("FAULT_SRAM"); vif.mem_rdata='0; end
    always @(posedge vif.clk) if(vif.rst_n) begin
        for(int b=0;b<49;b++) if(vif.mem_ce[b]) begin
            if(int'(vif.mem_addr[b*11+:11])>=1440) $fatal(1,"SRAM address out of range");
            if(vif.mem_we[b]) begin
                mem[b][vif.mem_addr[b*11+:11]] <= vif.mem_wdata[b*160+:160];
                written[b][vif.mem_addr[b*11+:11]] <= 1;
                writes++; banks_written[b]=1;
            end else begin
                if(!written[b][vif.mem_addr[b*11+:11]]) $fatal(1,"SRAM read before write");
                vif.mem_rdata[b*160+:160] <= mem[b][vif.mem_addr[b*11+:11]] ^
                    (inject_fault ? 160'h3ffffffffff : 160'b0);
                reads++;
            end
        end
    end
endmodule
