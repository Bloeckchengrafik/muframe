module muf_top #(
    parameter MEM_SIZE = 32'h00008000,
    parameter memfile  = ""
) (
    input  clk_i,
    input  rst_i
);
    wire wb_clk = clk_i;
    wire wb_rst = rst_i;

    `include "wb_intercon.vh"

    wb_ram #(
        .depth  (MEM_SIZE),
        .memfile(memfile)
    ) wb_ram_i (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wb_adr_i(wb_mem_adr[$clog2(MEM_SIZE)-1:0]),
        .wb_dat_i(wb_mem_dat),
        .wb_sel_i(wb_mem_sel),
        .wb_we_i (wb_mem_we),
        .wb_cyc_i(wb_mem_cyc),
        .wb_stb_i(wb_mem_stb),
        .wb_cti_i(wb_mem_cti),
        .wb_bte_i(wb_mem_bte),
        .wb_dat_o(wb_mem_dat),
        .wb_ack_o(wb_mem_ack),
        .wb_err_o(wb_mem_err)
    );
    assign wb_s2m_mem_rty = 1'b0;



endmodule
