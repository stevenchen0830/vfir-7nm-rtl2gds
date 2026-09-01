// Included inside IMG_FILTER only when FORMAL_PROPERTIES is defined.
reg f_past_valid = 1'b0;
initial assume(!rst_n);

always @(posedge clk) begin
    f_past_valid <= 1'b1;

    // The block-level contract is asynchronous assertion followed by a
    // clean, synchronous release supplied by integration logic.
    if (!$initstate)
        assume(rst_n);

    if (rst_n && frm_start) begin
        assume(img_width >= 11'd23);   // W >= 24
        assume(img_height >= 12'd23); // H >= 24
        assume(blk_v >= 6'd1 && blk_v <= 6'd49 && blk_v[0]);
    end

    if (rst_n) begin
        assert(state <= S_DRAIN);
        assert(wbank <= 6'd48);
        assert(icnt <= 2'd2);
        assert(!(oskid_v && !out_v_q));
        assert((mem_we & ~mem_ce) == {NBK{1'b0}});
        assert((mem_we & (mem_we - {{(NBK-1){1'b0}}, 1'b1})) == {NBK{1'b0}});
        assert((m_ce & m_1h) == {NBK{1'b0}});
        if (state == S_IDLE)
            assert(!in_pix_need);
    end

    if (f_past_valid && $past(!rst_n)) begin
        assert(state == S_IDLE);
        assert(!out_pix_rdy);
        assert(mem_ce == {NBK{1'b0}});
        assert(mem_we == {NBK{1'b0}});
    end

    if (f_past_valid && $past(rst_n && out_pix_rdy && !out_pix_need))
        assert(out_pix_rdy);

    // v4 split-rotator/tag alignment.  These assertions pin every registered
    // stage to the value and metadata presented in the preceding cycle, then
    // pin the row-boundary transfer to the prepared vector.  They catch a
    // PREP count change or unequal data/enable/control pipeline depth.
    if (f_past_valid && rst_n && $past(rst_n)) begin
        assert(cvlo1_q == $past(cvlo1));
        assert(cvlo2_q == $past(cvlo2));
        assert(cvlo3_q == $past(cvlo3));
        assert(shi1_q  == $past(s1_c[5:3]));
        assert(shi2_q  == $past(s2_c[5:3]));
        assert(shi3_q  == $past(s3_c[5:3]));
        assert(cbp_mid_q == $past(cbp_nxt));
        assert(c_fut  == $past(c_nxt));
        assert(ce_fut == $past(ce_nxt));
        assert(cbp_fut == $past(cbp_mid_q));
        if ($past(c_load)) begin
            assert(c_cur  == $past(c_fut));
            assert(ce_cur == $past(ce_fut));
            assert(cbp_cur == $past(cbp_fut));
        end
    end
end
