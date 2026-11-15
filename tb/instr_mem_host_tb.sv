`timescale 1ns/1ps
`default_nettype none

module instr_mem_host_tb;
    localparam logic [31:0] BOOT_ADDR = 32'h0000_0000;
    localparam int TIMEOUT_CYCLES = 500;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst = 1'b1;
    wishbone_pkg::wb_d2h_t wb_in;
    wishbone_pkg::wb_h2d_t wb_out;
    logic [31:0] write_data;
    logic write_valid, write_halfword, write_ready = 1'b1;
    logic [31:0] redirect_addr = '0;
    logic redirect_valid = 1'b0;

    instr_mem_host #(.BOOT_ADDR(BOOT_ADDR)) dut (
        .wb_clk_i(clk), .wb_rst_i(rst),
        .wb_instr_i(wb_in), .wb_instr_o(wb_out),
        .write_data_o(write_data), .write_valid_o(write_valid),
        .write_halfword_o(write_halfword), .write_ready_i(write_ready),
        .redirect_addr_i(redirect_addr), .redirect_valid_i(redirect_valid)
    );

    // Reference memory: deterministic contents for any aligned address.
    function automatic logic [31:0] memory_word(input logic [31:0] addr);
        memory_word = 32'hA500_1234 ^ (addr * 32'h0101_0101);
    endfunction

    // Simple classic Wishbone slave. Samples requests at the rising edge;
    // presents registered ACK/data for a later rising edge.
    // wb_delay=0: earliest registered response; larger values add wait cycles.
    int wb_delay = 2;
    logic inject_error = 1'b0;
    logic [31:0] error_addr = '0;
    logic bus_active = 1'b0;
    logic [31:0] latched_addr = '0;
    logic [3:0] latched_sel = '0;
    int delay_left = 0;
    int bus_requests = 0;

    always @(posedge clk) begin
        if (rst) begin
            wb_in <= '0;
            bus_active <= 1'b0;
            latched_addr <= '0;
            latched_sel <= '0;
            delay_left <= 0;
            bus_requests <= 0;
        end else begin
            // Deassert any one-cycle response unless a new one is generated.
            wb_in.ack <= 1'b0;
            wb_in.err <= 1'b0;
            wb_in.dat <= '0;

            if (!bus_active) begin
                if (wb_out.cyc && wb_out.stb) begin
                    if ((^wb_out.adr === 1'bx) || (wb_out.adr[1:0] !== 2'b00))
                        $fatal(1, "Wishbone requested invalid/unaligned address %h", wb_out.adr);
                    if (wb_out.sel !== 4'b1111 || wb_out.we !== 1'b0)
                        $fatal(1, "Unexpected Wishbone SEL/WE: sel=%b we=%b", wb_out.sel, wb_out.we);
                    latched_addr <= wb_out.adr;
                    latched_sel <= wb_out.sel;
                    bus_active <= 1'b1;
                    delay_left <= wb_delay;
                    bus_requests <= bus_requests + 1;
                end
            end else begin
                if (!wb_out.cyc || !wb_out.stb)
                    $fatal(1, "Wishbone CYC/STB dropped before ACK/ERR at %h", latched_addr);
                if (wb_out.adr !== latched_addr || wb_out.sel !== latched_sel)
                    $fatal(1, "Wishbone request changed while pending: %h -> %h", latched_addr, wb_out.adr);

                if (wb_in.ack || wb_in.err) begin
                    bus_active <= 1'b0;
                end else if (delay_left > 0) begin
                    delay_left <= delay_left - 1;
                end else begin
                    wb_in.dat <= memory_word(latched_addr);
                    if (inject_error && latched_addr == error_addr)
                        wb_in.err <= 1'b1;
                    else
                        wb_in.ack <= 1'b1;
                end
            end
        end
    end

    // Expected FIFO handshakes (scoreboard).
    logic [31:0] expected_data [0:63];
    logic        expected_half [0:63];
    int expected_count = 0;
    int received_count = 0;
    string test_name = "startup";

    task automatic expect_word(input logic [31:0] addr,
                               input logic halfword);
        if (expected_count >= 64) $fatal(1, "Scoreboard overflow");
        expected_data[expected_count] = memory_word(addr & 32'hFFFF_FFFC);
        expected_half[expected_count] = halfword;
        expected_count = expected_count + 1;
    endtask

    always @(posedge clk) begin
        if (!rst && write_valid && write_ready) begin
            if (received_count >= expected_count)
                $fatal(1, "[%s] Unexpected FIFO write: %h, half=%b",
                       test_name, write_data, write_halfword);
            if (write_data !== expected_data[received_count] ||
                write_halfword !== expected_half[received_count])
                $fatal(1, "[%s] FIFO[%0d]: got %h half=%b; expected %h half=%b",
                       test_name, received_count, write_data, write_halfword,
                       expected_data[received_count], expected_half[received_count]);
            $display("[%s] FIFO[%0d] data=%h half=%b @ %0t",
                     test_name, received_count, write_data, write_halfword, $time);
            received_count = received_count + 1;
        end
    end

    task automatic prepare_test(input string name, input int latency,
                                input logic ready_initial);
        @(negedge clk);
        rst = 1'b1;
        redirect_valid = 1'b0;
        redirect_addr = '0;
        write_ready = ready_initial;
        wb_delay = latency;
        inject_error = 1'b0;
        expected_count = 0;
        received_count = 0;
        test_name = name;
        repeat (3) @(negedge clk);
    endtask

    task automatic start_test();
        rst = 1'b0; // Called at a falling edge, before next rising edge.
        $display("RUN %s", test_name);
    endtask

    task automatic wait_received(input int n);
        int cycles;
        cycles = 0;
        while (received_count < n && cycles < TIMEOUT_CYCLES) begin
            @(negedge clk);
            cycles = cycles + 1;
        end
        if (received_count != n)
            $fatal(1, "[%s] Timeout: got %0d/%0d words", test_name, received_count, n);
    endtask

    task automatic redirect_to(input logic [31:0] addr);
        @(negedge clk);
        redirect_addr = addr;
        redirect_valid = 1'b1;
        @(negedge clk);
        redirect_valid = 1'b0;
    endtask

    task automatic test_sequential();
        prepare_test("sequential", 2, 1'b1);
        expect_word(32'h00, 1'b0);
        expect_word(32'h04, 1'b0);
        expect_word(32'h08, 1'b0);
        start_test();
        wait_received(3);
        $display("PASS sequential");
    endtask

    task automatic test_backpressure();
        logic [31:0] held_data;
        logic held_half;
        prepare_test("backpressure", 2, 1'b0);
        expect_word(32'h00, 1'b0);
        expect_word(32'h04, 1'b0);
        start_test();
        wait (write_valid === 1'b1);
        @(negedge clk);
        held_data = write_data;
        held_half = write_halfword;
        repeat (5) begin
            if (write_valid !== 1'b1 || write_data !== held_data ||
                write_halfword !== held_half)
                $fatal(1, "Backpressure: VALID or payload changed");
            @(negedge clk);
        end
        write_ready = 1'b1;
        wait_received(2);
        $display("PASS backpressure");
    endtask

    task automatic test_halfword_redirect();
        prepare_test("halfword_redirect", 2, 1'b0);
        start_test();
        // Park an old fetch result in FIFO_TX, then discard it.
        wait (write_valid === 1'b1);
        redirect_to(32'h0000_0002);
        expect_word(32'h00, 1'b1); // only low halfword is appended
        expect_word(32'h04, 1'b0);
        write_ready = 1'b1;
        wait_received(2);
        $display("PASS halfword_redirect");
    endtask

    task automatic test_inflight_redirect();
        prepare_test("inflight_redirect", 6, 1'b1);
        expect_word(32'h20, 1'b0);
        expect_word(32'h24, 1'b0);
        start_test();
        wait (bus_active === 1'b1);
        redirect_to(32'h20);
        wait_received(2);
        $display("PASS inflight_redirect");
    endtask

    task automatic test_bus_error_retry();
        prepare_test("bus_error_retry", 1, 1'b1);
        inject_error = 1'b1;
        error_addr = 32'h00;
        expect_word(32'h00, 1'b0);
        start_test();
        // Current DUT policy is to retry a failed fetch (fault reporting TODO).
        wait (bus_requests >= 2);
        @(negedge clk);
        if (received_count != 0)
            $fatal(1, "Bus error incorrectly entered FIFO");
        inject_error = 1'b0;
        wait_received(1);
        $display("PASS bus_error_retry");
    endtask

    initial begin
        $dumpfile("instr_mem_host_tb.vcd");
        $dumpvars(0, instr_mem_host_tb);
        test_sequential();
        test_backpressure();
        test_halfword_redirect();
        test_inflight_redirect();
        test_bus_error_retry();
        $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin
        repeat (3000) @(posedge clk);
        $fatal(1, "Global simulation watchdog expired in %s", test_name);
    end
endmodule

`default_nettype wire
