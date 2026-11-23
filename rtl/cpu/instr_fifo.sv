`default_nettype none
module instr_fifo (
    input  wire         clk_i,
    input  wire         rst_i,

    // Memory side
    input  logic [31:0] write_data_i,
    input  logic        write_halfword_i,
    input  logic        write_valid_i,
    output logic        write_ready_o,

    // Decoder side
    output logic [47:0] instruction_o,
    output logic        instruction_valid_o,
    input  logic        instruction_ready_i
);
    logic [79:0] instr_fifo_data;
    logic [2:0]  instr_halfwords_valid;

    assign write_ready_o = instr_halfwords_valid <= 3;

    logic [1:0] instruction_halfwords;

    always_comb begin
        case (instr_fifo_data[79:78])
            2'b00:        instruction_halfwords = 2'd1;
            2'b01, 2'b10: instruction_halfwords = 2'd2;
            2'b11:        instruction_halfwords = 2'd3;
            default:      instruction_halfwords = 2'd3;
        endcase
    end

    assign instruction_valid_o = instr_halfwords_valid >= {1'b0, instruction_halfwords};
    assign instruction_o = instr_fifo_data[79:32];

    wire do_write = write_valid_i && write_ready_o;
    wire do_read = instruction_valid_o && instruction_ready_i;

    logic [79:0] rw_data;
    always_comb begin
        rw_data = instr_fifo_data << {instruction_halfwords, 4'b0};

        if (do_read && do_write) begin
            if (write_halfword_i) begin
                rw_data[
                    79 - (int'(instr_halfwords_valid - {1'b0, instruction_halfwords}) << 4)
                    -: 16
                ] = write_data_i[15:0];
            end else begin
                rw_data[
                    79 - (int'(instr_halfwords_valid - {1'b0, instruction_halfwords}) << 4)
                    -: 32
                ] = write_data_i;
            end
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            instr_fifo_data <= 0;
            instr_halfwords_valid <= 0;
        end
        else begin
            if (do_write && do_read) begin
                instr_fifo_data <=rw_data;
                instr_halfwords_valid <= instr_halfwords_valid - {1'b0, instruction_halfwords} + (write_halfword_i ? 1 : 2);
            end
            else if (do_write) begin
                if (write_halfword_i) begin
                    instr_fifo_data[79 - (int'(instr_halfwords_valid) << 4) -: 16] <= write_data_i[15:0];
                    instr_halfwords_valid <= instr_halfwords_valid + 1;
                end else begin
                    instr_fifo_data[79 - (int'(instr_halfwords_valid) << 4) -: 32] <= write_data_i;
                    instr_halfwords_valid <= instr_halfwords_valid + 2;
                end
            end
            else if (do_read) begin
                instr_fifo_data <= instr_fifo_data << {instruction_halfwords, 4'b0};
                instr_halfwords_valid <= instr_halfwords_valid - {1'b0, instruction_halfwords};
            end
        end
    end
endmodule
`default_nettype wire
