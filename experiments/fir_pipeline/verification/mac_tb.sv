`timescale 1ns/1ps
module mac_tb;
    reg clk=0; always #0.5 clk=~clk;
    reg rst_n=0, advance=0, in_valid=0;
    reg [7999:0] tap_data=0;
    reg [399:0] tap_coef=0;
    wire out_valid;
    wire [159:0] result;
    fir_mac_pipeline dut(.*);
    reg [159:0] expected[0:8191];
    reg [159:0] golden;
    integer head=0, tail=0, checks=0, cycles=0, resets=0, stalls=0;
    integer l,t,k,left,idx,acc,seed=32'h513a724b;
    integer random_value;
    reg draining=0;

    always @(posedge clk) begin
        if (!rst_n) begin head=0; tail=0; end
        else if (advance) begin
            if (out_valid) begin
                if (head>=tail) $fatal(1,"unexpected output");
                if ((result ^ ($test$plusargs("FAULT") ? 160'd1 : 160'd0)) !== expected[head])
                    $fatal(1,"MAC MISMATCH beat=%0d",head);
                head=head+1; checks=checks+16;
            end
            if (in_valid) begin
                golden=0;
                for (l=0;l<16;l=l+1) begin
                    acc=0;
                    for(t=0;t<50;t=t+1)
                        acc=acc+tap_data[t*160+l*10+:10]*tap_coef[t*8+:8];
                    acc=(acc+64)>>7;
                    golden[l*10+:10]=(acc>1023)?10'd1023:10'(acc);
                end
                expected[tail]=golden; tail=tail+1;
            end
        end else stalls=stalls+1;
    end

    initial begin
        repeat(3) @(negedge clk);
        rst_n=1;
        for(cycles=0;cycles<2400;cycles=cycles+1) begin
            @(negedge clk);
            advance=({$random(seed)}%5)!=0;
            in_valid=({$random(seed)}%7)!=0;
            tap_coef=0;
            // Every possible single nonzero tap, extremes, then random
            // legal nonnegative weights (including 128) summing to 128.
            if(cycles<50) tap_coef[cycles*8+:8]=8'd128;
            else for(k=0;k<128;k=k+1) begin
                idx={$random(seed)}%50;
                tap_coef[idx*8+:8]=tap_coef[idx*8+:8]+8'd1;
            end
            for(t=0;t<50;t=t+1) for(l=0;l<16;l=l+1) begin
                random_value=$random(seed);
                tap_data[t*160+l*10+:10]=(cycles<25)?10'd1023:
                                         (cycles<50)?10'd0:random_value[9:0];
            end
            if(cycles==631 || cycles==1577) begin
                rst_n=0; in_valid=0; resets=resets+1;
                repeat(2) @(negedge clk);
                rst_n=1;
            end
        end
        @(negedge clk); in_valid=0; advance=1;
        repeat(12) @(negedge clk);
        if(head!=tail || out_valid) $fatal(1,"undrained pipeline");
        $display("MAC PASS checks=%0d resets=%0d stall_cycles=%0d",checks,resets,stalls);
        $finish;
    end
    initial begin #10000; $fatal(1,"MAC timeout"); end
endmodule
