module muf_top #(
    parameter MEM_SIZE = 32'h00008000
) (
    input  clk_i,
    input  rst_i
);
    `include "wb_intercon.vh"
endmodule
