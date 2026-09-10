`timescale 1ns/1ps
package img_filter_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    class img_item extends uvm_sequence_item;
        bit frame_start;
        bit [10:0] width_m1;
        bit [11:0] height_m1;
        bit [5:0] blk_v;
        bit [199:0] coef;
        logic [159:0] data;
        bit [159:0] mask='1;
        int unsigned input_gap;
        `uvm_object_utils(img_item)
        function new(string name="img_item"); super.new(name); endfunction
    endclass
    class img_vectors extends uvm_object;
        int width,height,kernel,beats;
        bit [199:0] coef;
        logic [159:0] inputs[$],golden[$];
        `uvm_object_utils(img_vectors)
        function new(string name="img_vectors"); super.new(name); endfunction
        function void load();
            string filename;
            int fd,rc;
            logic [159:0] word;
            if(!$value$plusargs("VECTORS=%s",filename)) `uvm_fatal("VECTORS","Supply +VECTORS=<file>")
            fd=$fopen(filename,"r");
            if(fd==0) `uvm_fatal("VECTORS","Cannot open vector file")
            rc=$fscanf(fd,"%d %d %d %h",width,height,kernel,coef);
            if(rc!=4 || width<24 || width>1440 || height<24 || height>4096 || kernel<1 || kernel>49 || kernel%2==0)
                `uvm_fatal("VECTORS","Invalid frame configuration")
            beats=((width+3)/4)*height;
            for(int i=0;i<2*beats;i++) begin
                if($fscanf(fd,"%h",word)!=1) `uvm_fatal("VECTORS","Truncated vectors")
                if(i<beats) inputs.push_back(word); else golden.push_back(word);
            end
            $fclose(fd);
        endfunction
    endclass
    class img_filter_sequence extends uvm_sequence #(img_item);
        img_vectors vectors;
        `uvm_object_utils(img_filter_sequence)
        function new(string name="img_filter_sequence"); super.new(name); endfunction
        task body();
            img_item req;
            req=img_item::type_id::create("config"); start_item(req);
            req.frame_start=1; req.width_m1=11'(vectors.width-1); req.height_m1=12'(vectors.height-1);
            req.blk_v=6'(vectors.kernel); req.coef=vectors.coef; finish_item(req);
            foreach(vectors.inputs[i]) begin
                req=img_item::type_id::create($sformatf("input_%0d",i)); start_item(req);
                req.data=vectors.inputs[i]; req.input_gap=(i%11==3)?2:((i%7==2)?1:0); finish_item(req);
            end
        endtask
    endclass
    class img_driver extends uvm_driver #(img_item);
        virtual img_filter_if vif;
        `uvm_component_utils(img_driver)
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db#(virtual img_filter_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","driver")
        endfunction
        task drive_output_ready();
            int cycle=0; vif.out_pix_need=0;
            forever begin @(negedge vif.clk);
                vif.out_pix_need=vif.rst_n && !(cycle%13 inside {5,6}); cycle++;
            end
        endtask
        task drive_items();
            img_item req;
            vif.frm_start=0; vif.in_pix_rdy=0; vif.in_pix_data='0;
            vif.img_width=0; vif.img_height=0; vif.blk_v=1; vif.coef=0;
            wait(vif.rst_n===1);
            forever begin
                seq_item_port.get_next_item(req); @(negedge vif.clk);
                if(req.frame_start) begin
                    vif.img_width=req.width_m1; vif.img_height=req.height_m1;
                    vif.blk_v=req.blk_v; vif.coef=req.coef; vif.frm_start=1;
                    @(negedge vif.clk); vif.frm_start=0;
                end else begin
                    repeat(req.input_gap) @(negedge vif.clk);
                    vif.in_pix_data=req.data; vif.in_pix_rdy=1;
                    do @(posedge vif.clk); while(!vif.in_pix_need);
                    @(negedge vif.clk); vif.in_pix_rdy=0;
                end
                seq_item_port.item_done();
            end
        endtask
        task run_phase(uvm_phase phase); fork drive_items(); drive_output_ready(); join endtask
    endclass
    class img_input_monitor extends uvm_monitor;
        virtual img_filter_if vif;
        uvm_analysis_port #(img_item) ap;
        int starved=0,blocked=0;
        `uvm_component_utils(img_input_monitor)
        function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db#(virtual img_filter_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","input")
        endfunction
        task run_phase(uvm_phase phase);
            img_item item;
            forever begin @(posedge vif.clk); if(vif.rst_n) begin
                if(vif.frm_start) begin
                    item=img_item::type_id::create("config"); item.frame_start=1;
                    item.width_m1=vif.img_width; item.height_m1=vif.img_height;
                    item.blk_v=vif.blk_v; item.coef=vif.coef; ap.write(item);
                end
                if(vif.in_pix_need && !vif.in_pix_rdy) starved++;
                if(vif.in_pix_rdy && !vif.in_pix_need) blocked++;
                if(vif.in_pix_rdy && vif.in_pix_need) begin
                    item=img_item::type_id::create("input"); item.data=vif.in_pix_data; ap.write(item);
                end
            end end
        endtask
    endclass
    class img_output_monitor extends uvm_monitor;
        virtual img_filter_if vif;
        uvm_analysis_port #(img_item) ap;
        int accepted=0,stalled=0;
        `uvm_component_utils(img_output_monitor)
        function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if(!uvm_config_db#(virtual img_filter_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","output")
        endfunction
        task run_phase(uvm_phase phase);
            img_item item;
            logic [159:0] held;
            bit was_stalled=0;
            forever begin @(posedge vif.clk);
                if(!vif.rst_n) was_stalled=0;
                else begin
                    if(was_stalled && (!vif.out_pix_rdy || vif.out_pix_data!==held)) `uvm_error("PROTOCOL","Output changed while blocked")
                    was_stalled=vif.out_pix_rdy && !vif.out_pix_need; held=vif.out_pix_data;
                    if(was_stalled) stalled++;
                    if(vif.out_pix_rdy && vif.out_pix_need) begin
                        item=img_item::type_id::create("output"); item.data=vif.out_pix_data;
                        if($test$plusargs("FAULT_DATA") && accepted==0) item.data[0]=~item.data[0];
                        ap.write(item); accepted++;
                    end
                end
            end
        endtask
    endclass
    // Direct per-tap convolution of OBSERVED inputs, independent of bank/rotator implementation.
    class img_predictor extends uvm_component;
        uvm_tlm_analysis_fifo #(img_item) input_fifo;
        uvm_analysis_port #(img_item) ap;
        img_vectors vectors;
        logic [159:0] samples[$];
        int top_beats=0,bottom_beats=0,interior_beats=0,partial_beats=0;
        `uvm_component_utils(img_predictor)
        function new(string name,uvm_component parent);
            super.new(name,parent); input_fifo=new("input_fifo",this); ap=new("ap",this);
        endfunction
        task run_phase(uvm_phase phase);
            img_item item,expected;
            int bpr,h,source_y,idx,lane,weight,acc,hv;
            input_fifo.get(item);
            if(!item.frame_start || int'(item.width_m1)+1!=vectors.width || int'(item.height_m1)+1!=vectors.height ||
                int'(item.blk_v)!=vectors.kernel || item.coef!=vectors.coef) `uvm_fatal("CONFIG","Observed config mismatch")
            bpr=(vectors.width+3)/4; h=vectors.height; hv=(vectors.kernel-1)/2;
            for(int b=0;b<vectors.beats;b++) begin
                input_fifo.get(item); if(item.frame_start) `uvm_fatal("CONFIG","Overlapping frame")
                samples.push_back(item.data);
            end
            for(int y=0;y<h;y++) for(int bx=0;bx<bpr;bx++) begin
                expected=img_item::type_id::create("predicted"); expected.data='0; expected.mask='0;
                for(int p=0;p<4;p++) if(4*bx+p<vectors.width) for(int c=0;c<4;c++) begin
                    acc=0; lane=p*4+c;
                    for(int k=-hv;k<=hv;k++) begin
                        source_y=y+k;
                        if(source_y<0) source_y=-source_y-1;
                        if(source_y>=h) source_y=2*h-source_y-1;
                        idx=hv-((k<0)?-k:k); weight=int'(vectors.coef[idx*8+:8]);
                        acc+=int'(samples[source_y*bpr+bx][lane*10+:10])*weight;
                    end
                    acc=(acc+64)>>7; if(acc>1023) acc=1023;
                    expected.data[lane*10+:10]=10'(acc); expected.mask[lane*10+:10]='1;
                end
                if((expected.data & expected.mask)!==(vectors.golden[y*bpr+bx] & expected.mask))
                    `uvm_fatal("PREDICTOR","SV predictor disagrees with Python golden")
                if(y<hv) top_beats++; else if(y>=h-hv) bottom_beats++; else interior_beats++;
                if(bx==bpr-1 && vectors.width%4!=0) partial_beats++;
                ap.write(expected);
            end
        endtask
    endclass
    class img_scoreboard extends uvm_component;
        uvm_tlm_analysis_fifo #(img_item) expected_fifo,actual_fifo;
        int checked=0,errors=0;
        `uvm_component_utils(img_scoreboard)
        function new(string name,uvm_component parent);
            super.new(name,parent); expected_fifo=new("expected_fifo",this); actual_fifo=new("actual_fifo",this);
        endfunction
        task run_phase(uvm_phase phase);
            img_item expected,actual;
            forever begin
                expected_fifo.get(expected); actual_fifo.get(actual);
                if((actual.data & expected.mask)!==(expected.data & expected.mask)) begin
                    errors++; `uvm_error("MISMATCH",$sformatf("beat %0d expected=%040h actual=%040h",checked,expected.data,actual.data))
                end
                checked++;
            end
        endtask
    endclass
    class img_env extends uvm_env;
        img_vectors vectors;
        uvm_sequencer #(img_item) sequencer;
        img_driver driver; img_input_monitor input_monitor; img_output_monitor output_monitor;
        img_predictor predictor; img_scoreboard scoreboard;
        `uvm_component_utils(img_env)
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase); vectors=img_vectors::type_id::create("vectors"); vectors.load();
            sequencer=uvm_sequencer#(img_item)::type_id::create("sequencer",this);
            driver=img_driver::type_id::create("driver",this);
            input_monitor=img_input_monitor::type_id::create("input_monitor",this);
            output_monitor=img_output_monitor::type_id::create("output_monitor",this);
            predictor=img_predictor::type_id::create("predictor",this); predictor.vectors=vectors;
            scoreboard=img_scoreboard::type_id::create("scoreboard",this);
        endfunction
        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
            input_monitor.ap.connect(predictor.input_fifo.analysis_export);
            predictor.ap.connect(scoreboard.expected_fifo.analysis_export);
            output_monitor.ap.connect(scoreboard.actual_fifo.analysis_export);
        endfunction
    endclass
    class img_filter_smoke_test extends uvm_test;
        img_env env;
        `uvm_component_utils(img_filter_smoke_test)
        function new(string name,uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); env=img_env::type_id::create("env",this); endfunction
        task run_phase(uvm_phase phase);
            img_filter_sequence seq;
            uvm_report_server server;
            phase.raise_objection(this); seq=img_filter_sequence::type_id::create("seq"); seq.vectors=env.vectors;
            seq.start(env.sequencer); wait(env.scoreboard.checked==env.vectors.beats);
            repeat(20) @(posedge env.driver.vif.clk); server=uvm_report_server::get_server();
            if(env.scoreboard.errors!=0 || server.get_severity_count(UVM_ERROR)!=0 ||
                env.output_monitor.accepted!=env.vectors.beats || env.scoreboard.actual_fifo.used()!=0) begin
                `uvm_fatal("FAILED","Mismatch, protocol error, or extra output")
                return;
            end
            `uvm_info("COVERAGE",$sformatf("kernel=%0d width_mod4=%0d top=%0d bottom=%0d interior=%0d partial=%0d input_starved=%0d output_stalled=%0d",env.vectors.kernel,env.vectors.width%4,env.predictor.top_beats,env.predictor.bottom_beats,env.predictor.interior_beats,env.predictor.partial_beats,env.input_monitor.starved,env.output_monitor.stalled),UVM_NONE)
            if(env.vectors.kernel>1 && (env.predictor.top_beats==0 || env.predictor.bottom_beats==0 || env.output_monitor.stalled==0))
                `uvm_fatal("COVERAGE","Required boundary/backpressure bins not hit")
            `uvm_info("PASSED",$sformatf("UVM FILTER PASSED: kernel=%0d %0d beats checked",env.vectors.kernel,env.scoreboard.checked),UVM_NONE)
            phase.drop_objection(this);
        endtask
    endclass
endpackage
