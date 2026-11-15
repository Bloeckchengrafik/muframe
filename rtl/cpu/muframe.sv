module muframe (
    input                         wb_clk_i,
    input                         wb_rst_i,
    input  wishbone_pkg::wb_d2h_t wb_instr_i,
    output wishbone_pkg::wb_h2d_t wb_instr_o,
    input  wishbone_pkg::wb_d2h_t wb_data_i,
    output wishbone_pkg::wb_h2d_t wb_data_o
);
    /* === Stage 1: Instruction Fetch === */
    logic [31:0] fifo_write_data;
    logic        fifo_write_valid;
    logic        fifo_write_ready;
    logic [47:0] fifo_instruction;
    logic        fifo_instruction_valid;
    logic        fifo_instruction_ready;

    instr_mem_host instr_mem_host_m (
		.wb_clk_i (wb_clk_i),
		.wb_rst_i (wb_rst_i),
		.wb_instr_i (wb_instr_i),
		.wb_instr_o (wb_instr_o),
		.write_data_o (fifo_write_data),
		.write_valid_o (fifo_write_valid),
		.write_ready_i (fifo_write_ready)
    );

    instr_fifo instr_fifo_m (
		.clk_i (wb_clk_i),
		.rst_i (wb_rst_i),
		.write_data_i (fifo_write_data),
		.write_valid_i (fifo_write_valid),
		.write_ready_o (fifo_write_ready),
		.instruction_o (fifo_instruction),
		.instruction_valid_o (fifo_instruction_valid),
		.instruction_ready_i (fifo_instruction_ready)
    );
endmodule
