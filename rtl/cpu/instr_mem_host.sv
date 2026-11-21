module instr_mem_host #(
    parameter BOOT_ADDR = 32'h0000_0000
) (
    input                         wb_clk_i,
    input                         wb_rst_i,
    input  wishbone_pkg::wb_d2h_t wb_instr_i,
    output wishbone_pkg::wb_h2d_t wb_instr_o,

    output logic [31:0] write_data_o,
    output logic        write_valid_o,
    output logic        write_halfword_o,
    input  logic        write_ready_i,

    input  logic [31:0] redirect_addr_i,
    input  logic        redirect_valid_i
);
    typedef enum logic [1:0] {
        WB_REQ,
        WB_WAIT,
        FIFO_TX
    } fetch_state_t;

    fetch_state_t state;

    logic [31:0] next_addr;
    logic discard_result;

    assign write_valid_o =
        (state == FIFO_TX) && !redirect_valid_i;

    logic [31:0] req_addr;
    logic        req_halfword;

    always_comb begin
        wb_instr_o = '0;

        wb_instr_o.adr = req_addr & 32'b11111111_11111111_11111111_11111100;
        wb_instr_o.sel = 4'b1111;

        wb_instr_o.cyc = state == WB_WAIT;
        wb_instr_o.stb = state == WB_WAIT;
    end

    always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            state          <= WB_REQ;
            next_addr      <= BOOT_ADDR;
            write_data_o   <= '0;
            discard_result <= 1'b0;
        end
        else begin
            if (redirect_valid_i) begin
                next_addr <= redirect_addr_i;
            end

            case (state)
                WB_REQ: begin
                    req_addr      <= next_addr;
                    req_halfword  <= next_addr[1];

                    // Requests are driven combinationally.
                    // Move to waiting state after the first cycle.
                    state <= WB_WAIT;
                end

                WB_WAIT: begin
                    if (redirect_valid_i)
                        discard_result <= 1'b1;

                    if (wb_instr_i.ack || wb_instr_i.err) begin
                        if (wb_instr_i.err) begin
                            // TODO: report a fetch fault
                            state <= WB_REQ;
                        end
                        else if (discard_result || redirect_valid_i) begin
                            // Redirect happened during this transaction
                            state <= WB_REQ;
                        end
                        else begin
                            write_data_o <= wb_instr_i.dat;
                            if (req_halfword) begin
                                write_halfword_o <= 1'b1;
                                next_addr        <= req_addr + 32'd2;
                            end
                            else begin
                                write_halfword_o <= 1'b0;
                                next_addr        <= req_addr + 32'd4;
                            end
                            state <= FIFO_TX;
                        end

                        discard_result <= 1'b0;
                    end
                end

                FIFO_TX: begin
                    if (redirect_valid_i) begin
                        state <= WB_REQ;
                    end
                    else if (write_ready_i) begin
                        state <= WB_REQ;
                    end
                end

                default: state <= WB_REQ;
            endcase
        end
    end
endmodule
