`timescale 1ns/1ps

package img_filter_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int SMOKE_WIDTH  = 24;
    localparam int SMOKE_HEIGHT = 24;
    localparam int SMOKE_BEATS  = (SMOKE_WIDTH / 4) * SMOKE_HEIGHT;
    localparam bit [10:0] SMOKE_WIDTH_M1  = 11'd23;
    localparam bit [11:0] SMOKE_HEIGHT_M1 = 12'd23;

    class img_item extends uvm_sequence_item;
        bit         frame_start;
        bit [10:0]  width_m1;
        bit [11:0]  height_m1;
        bit [5:0]   blk_v;
        bit [199:0] coef;
        bit [159:0] data;
        int unsigned input_gap;

        `uvm_object_utils(img_item)

        function new(string name = "img_item");
            super.new(name);
        endfunction
    endclass

    class img_smoke_sequence extends uvm_sequence #(img_item);
        `uvm_object_utils(img_smoke_sequence)

        function new(string name = "img_smoke_sequence");
            super.new(name);
        endfunction

        task body();
            img_item req;
            bit [159:0] beat;
            int unsigned pixel_value;

            req = img_item::type_id::create("frame_config");
            start_item(req);
            req.frame_start = 1'b1;
            req.width_m1    = SMOKE_WIDTH_M1;
            req.height_m1   = SMOKE_HEIGHT_M1;
            req.blk_v       = 6'd1;
            req.coef        = '0;
            req.coef[7:0]   = 8'd128;
            req.data        = '0;
            req.input_gap   = 0;
            finish_item(req);

            for (int beat_idx = 0; beat_idx < SMOKE_BEATS; beat_idx++) begin
                beat = '0;
                for (int lane = 0; lane < 16; lane++) begin
                    pixel_value = beat_idx * 17 + lane * 3;
                    beat[lane*10 +: 10] = pixel_value[9:0];
                end

                req = img_item::type_id::create($sformatf("beat_%0d", beat_idx));
                start_item(req);
                req.frame_start = 1'b0;
                req.data        = beat;
                // Deterministic gaps exercise input starvation while keeping
                // the test reproducible on commercial and open simulators.
                req.input_gap   = ((beat_idx % 11) == 3) ? 2 :
                                  ((beat_idx % 7)  == 2) ? 1 : 0;
                finish_item(req);
            end
        endtask
    endclass

    class img_driver extends uvm_driver #(img_item);
        `uvm_component_utils(img_driver)
        virtual img_filter_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual img_filter_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "img_filter_if was not placed in config_db")
        endfunction

        task drive_output_ready();
            int unsigned cycle;
            vif.out_pix_need <= 1'b0;
            cycle = 0;
            forever begin
                @(negedge vif.clk);
                if (!vif.rst_n)
                    vif.out_pix_need <= 1'b0;
                else begin
                    // Repeatable output backpressure: two blocked cycles out
                    // of every thirteen once the frame is running.
                    vif.out_pix_need <= !((cycle % 13) inside {5, 6});
                    cycle++;
                end
            end
        endtask

        task drive_items();
            img_item req;
            vif.frm_start  <= 1'b0;
            vif.in_pix_rdy <= 1'b0;
            vif.in_pix_data <= '0;
            vif.img_width  <= '0;
            vif.img_height <= '0;
            vif.blk_v      <= 6'd1;
            vif.coef       <= '0;

            wait (vif.rst_n === 1'b1);
            forever begin
                seq_item_port.get_next_item(req);
                if (req.frame_start) begin
                    @(negedge vif.clk);
                    vif.img_width  <= req.width_m1;
                    vif.img_height <= req.height_m1;
                    vif.blk_v      <= req.blk_v;
                    vif.coef       <= req.coef;
                    vif.frm_start  <= 1'b1;
                    @(negedge vif.clk);
                    vif.frm_start  <= 1'b0;
                end else begin
                    repeat (req.input_gap) @(negedge vif.clk);
                    vif.in_pix_data <= req.data;
                    vif.in_pix_rdy  <= 1'b1;
                    do @(posedge vif.clk); while (!vif.in_pix_need);
                    @(negedge vif.clk);
                    vif.in_pix_rdy <= 1'b0;
                end
                seq_item_port.item_done();
            end
        endtask

        task run_phase(uvm_phase phase);
            fork
                drive_output_ready();
                drive_items();
            join
        endtask
    endclass

    class img_input_monitor extends uvm_monitor;
        `uvm_component_utils(img_input_monitor)
        virtual img_filter_if vif;
        uvm_analysis_port #(img_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual img_filter_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "input monitor has no virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            img_item item;
            forever begin
                @(posedge vif.clk);
                if (vif.rst_n && vif.in_pix_rdy && vif.in_pix_need) begin
                    item = img_item::type_id::create("accepted_input");
                    item.data = vif.in_pix_data;
                    ap.write(item);
                end
            end
        endtask
    endclass

    class img_output_monitor extends uvm_monitor;
        `uvm_component_utils(img_output_monitor)
        virtual img_filter_if vif;
        uvm_analysis_port #(img_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual img_filter_if)::get(this, "", "vif", vif))
                `uvm_fatal("NOVIF", "output monitor has no virtual interface")
        endfunction

        task run_phase(uvm_phase phase);
            img_item item;
            forever begin
                @(posedge vif.clk);
                if (vif.rst_n && vif.out_pix_rdy && vif.out_pix_need) begin
                    item = img_item::type_id::create("accepted_output");
                    item.data = vif.out_pix_data;
                    ap.write(item);
                end
            end
        endtask
    endclass

    class img_scoreboard extends uvm_component;
        `uvm_component_utils(img_scoreboard)
        uvm_tlm_analysis_fifo #(img_item) expected_fifo;
        uvm_tlm_analysis_fifo #(img_item) actual_fifo;
        int unsigned checked;
        int unsigned errors;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            expected_fifo = new("expected_fifo", this);
            actual_fifo   = new("actual_fifo", this);
            checked = 0;
            errors  = 0;
        endfunction

        task run_phase(uvm_phase phase);
            img_item expected;
            img_item actual;
            forever begin
                expected_fifo.get(expected);
                actual_fifo.get(actual);
                checked++;
                if (actual.data !== expected.data) begin
                    errors++;
                    `uvm_error("MISMATCH", $sformatf(
                        "beat %0d expected=%040h actual=%040h",
                        checked-1, expected.data, actual.data))
                end
            end
        endtask
    endclass

    class img_env extends uvm_env;
        `uvm_component_utils(img_env)
        uvm_sequencer #(img_item) sequencer;
        img_driver        driver;
        img_input_monitor input_monitor;
        img_output_monitor output_monitor;
        img_scoreboard    scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer      = uvm_sequencer#(img_item)::type_id::create("sequencer", this);
            driver         = img_driver::type_id::create("driver", this);
            input_monitor  = img_input_monitor::type_id::create("input_monitor", this);
            output_monitor = img_output_monitor::type_id::create("output_monitor", this);
            scoreboard     = img_scoreboard::type_id::create("scoreboard", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            input_monitor.ap.connect(scoreboard.expected_fifo.analysis_export);
            output_monitor.ap.connect(scoreboard.actual_fifo.analysis_export);
        endfunction
    endclass

    class img_filter_smoke_test extends uvm_test;
        `uvm_component_utils(img_filter_smoke_test)
        img_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = img_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            img_smoke_sequence seq;
            phase.raise_objection(this);
            seq = img_smoke_sequence::type_id::create("seq");
            seq.start(env.sequencer);
            wait (env.scoreboard.checked == SMOKE_BEATS);
            repeat (5) @(posedge env.driver.vif.clk);
            if (env.scoreboard.errors != 0)
                `uvm_fatal("FAILED", $sformatf(
                    "UVM smoke saw %0d mismatches", env.scoreboard.errors))
            `uvm_info("PASSED", $sformatf(
                "UVM SMOKE PASSED: %0d beats checked with deterministic input/output stalls",
                env.scoreboard.checked), UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
endpackage
