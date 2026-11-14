module muf_tb;
    // Clock and reset generation
    reg syst_clk = 1;
    reg syst_rst = 1;

    always #5 syst_clk <= ~syst_clk;
    initial #100 syst_rst <= 0;

    // DUT instantiation
    muf_top dut(
        .clk_i(syst_clk),
        .rst_i(syst_rst)
    );

    initial begin
        $dumpfile("muf_tb.vcd");
        $dumpvars(0, muf_tb);
        #1000;
        $finish;
    end
endmodule
