`timescale 1ns/1ps
`default_nettype none

module instr_fifo_tb;
    reg clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    reg rst_i = 1'b0;
    reg [31:0] write_data_i = 32'b0;
    reg write_halfword_i = 1'b0;
    reg write_valid_i = 1'b0;
    wire write_ready_o;
    wire [47:0] instruction_o;
    wire instruction_valid_o;
    reg instruction_ready_i = 1'b0;

    instr_fifo dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .write_data_i(write_data_i),
        .write_halfword_i(write_halfword_i),
        .write_valid_i(write_valid_i),
        .write_ready_o(write_ready_o),
        .instruction_o(instruction_o),
        .instruction_valid_o(instruction_valid_o),
        .instruction_ready_i(instruction_ready_i)
    );

    // Reference model: halfwords in arrival order, oldest at index zero.
    // Fixed-size array rather than SV queues for Icarus compatibility.
    reg [15:0] expected [0:4];
    integer count = 0;
    integer cycle = 0;
    integer reads = 0;
    integer writes = 0;
    integer simultaneous = 0;
    integer blocked_writes = 0;
    integer stalled_reads = 0;
    integer full_cycles = 0;
    integer read_len1 = 0;
    integer read_len2 = 0;
    integer read_len3 = 0;
    integer halfword_writes = 0;
    integer seed = 32'h00123456;

    // Chosen by the test currently running; included in failures.
    reg [8*64-1:0] test_name = "startup";

    function integer length_of(input reg [15:0] hw);
        begin
            case (hw[15:14])
                2'b00: length_of = 1;
                2'b01, 2'b10: length_of = 2;
                2'b11: length_of = 3;
                default: length_of = 3;
            endcase
        end
    endfunction

    function [31:0] random_word;
        begin
            random_word = $random(seed);
        end
    endfunction

    task check_outputs;
        integer len;
        integer j;
        reg should_valid;
        reg should_ready;
        begin
            should_ready = (count <= 3);
            should_valid = 1'b0;
            len = 0;
            if (count != 0) begin
                len = length_of(expected[0]);
                should_valid = (count >= len);
            end

            if (write_ready_o !== should_ready)
                $fatal(1, "[%0s, cycle %0d] write_ready: got %b expected %b, occupancy=%0d",
                       test_name, cycle, write_ready_o, should_ready, count);
            if (instruction_valid_o !== should_valid)
                $fatal(1, "[%0s, cycle %0d] instruction_valid: got %b expected %b, occupancy=%0d, required=%0d",
                       test_name, cycle, instruction_valid_o, should_valid, count, len);

            // The unused portion of instruction_o may legitimately be stale.
            // Check only the halfwords belonging to a COMPLETE instruction.
            if (should_valid) begin
                for (j = 0; j < len; j = j + 1) begin
                    if (instruction_o[47 - 16*j -: 16] !== expected[j])
                        $fatal(1, "[%0s, cycle %0d] instruction halfword %0d: got %04h expected %04h (occupancy=%0d, length=%0d)",
                               test_name, cycle, j,
                               instruction_o[47 - 16*j -: 16], expected[j], count, len);
                end
            end
        end
    endtask

    // Drive inputs away from the sampling edge. Model transfers at the
    // rising edge using the PRE-edge ready/valid signals; check both before
    // and after the DUT's nonblocking assignments settle.
    task step(
        input reg reset_now,
        input reg wr_valid,
        input reg wr_half,
        input reg [31:0] wr_data,
        input reg rd_ready
    );
        integer len;
        integer i;
        reg accepted_write;
        reg accepted_read;
        begin
            @(negedge clk_i);
            rst_i = reset_now;
            write_valid_i = wr_valid;
            write_halfword_i = wr_half;
            write_data_i = wr_data;
            instruction_ready_i = rd_ready;
            #1;
            if (!reset_now)
                check_outputs();

            accepted_write = (!reset_now && wr_valid && write_ready_o);
            accepted_read = (!reset_now && instruction_valid_o && rd_ready);
            len = 0;
            if (accepted_read)
                len = length_of(expected[0]);

            @(posedge clk_i);
            if (reset_now) begin
                count = 0;
            end else begin
                if (count == 5) full_cycles = full_cycles + 1;
                if (wr_valid && !accepted_write) blocked_writes = blocked_writes + 1;
                if (instruction_valid_o && !rd_ready) stalled_reads = stalled_reads + 1;

                // Consume FIRST, then append: this models both handshakes
                // occurring on the same edge without losing either transfer.
                if (accepted_read) begin
                    reads = reads + 1;
                    case (len)
                        1: read_len1 = read_len1 + 1;
                        2: read_len2 = read_len2 + 1;
                        3: read_len3 = read_len3 + 1;
                        default: $fatal(1, "Invalid expected instruction length");
                    endcase
                    for (i = 0; i < count-len; i = i + 1)
                        expected[i] = expected[i+len];
                    count = count - len;
                end
                if (accepted_write) begin
                    writes = writes + 1;
                    if (wr_half) begin
                        halfword_writes = halfword_writes + 1;
                        if (count + 1 > 5)
                            $fatal(1, "Reference overflow on halfword append");
                        expected[count] = wr_data[15:0];
                        count = count + 1;
                    end else begin
                        if (count + 2 > 5)
                            $fatal(1, "Reference overflow on word append");
                        expected[count] = wr_data[31:16];
                        expected[count+1] = wr_data[15:0];
                        count = count + 2;
                    end
                end
                if (accepted_write && accepted_read)
                    simultaneous = simultaneous + 1;
            end
            cycle = cycle + 1;
            #1; // wait for DUT NBAs to settle
            check_outputs();
        end
    endtask

    task reset_test(input reg [8*64-1:0] name);
        begin
            test_name = name;
            $display("TEST: %0s", test_name);
            step(1, 0, 0, 32'b0, 0);
        end
    endtask

    integer k;
    reg [31:0] rnd;
    initial begin
        $dumpfile("instr_fifo_tb.vcd");
        $dumpvars(0, instr_fifo_tb);

        // 16-bit, 32-bit, and 48-bit instructions in a single stream.
        reset_test("mixed lengths");
        step(0, 1, 0, 32'h0123_4123, 0); // 16-bit + 32-bit prefix
        step(0, 1, 0, 32'hABCD_C123, 0); // 32-bit suffix + 48-bit prefix
        step(0, 0, 0, 0, 1);             // consume 16-bit
        step(0, 1, 0, 32'h4567_89AB, 1); // consume 32-bit, append 48-bit tail
        step(0, 0, 0, 0, 1);             // consume 48-bit
        step(0, 0, 0, 0, 1);

        // Fetch redirected to address +2: the host sends the low 16 bits.
        reset_test("halfword alignment and split 48-bit instruction");
        step(0, 1, 1, 32'hDEAD_C001, 0);
        step(0, 1, 0, 32'hBEEF_CAFE, 0);
        step(0, 0, 0, 0, 1);             // 48-bit complete
        step(0, 0, 0, 0, 1);

        // Capacity is five halfwords; current DUT intentionally uses a
        // conservative ready rule of count <= 3 even for 16-bit writes.
        reset_test("full and backpressure");
        step(0, 1, 0, 32'h0001_0002, 0);
        step(0, 1, 0, 32'h0003_0004, 0);
        step(0, 1, 1, 32'hDEAD_0005, 0); // count=5
        step(0, 1, 1, 32'hDEAD_0006, 0); // blocked at count=5
        step(0, 1, 0, 32'h0007_0008, 1); // read, but write still blocked
        step(0, 1, 0, 32'h0007_0008, 1); // read + write concurrently
        step(0, 0, 0, 0, 1);
        step(0, 0, 0, 0, 1);
        step(0, 0, 0, 0, 1);
        step(0, 0, 0, 0, 1);

        // Simultaneously consume 48 bits and append 32 bits.
        reset_test("48-bit read plus 32-bit write");
        step(0, 1, 0, 32'hC001_ABCD, 0);
        step(0, 1, 0, 32'hEF01_0002, 0);
        step(0, 1, 0, 32'h0003_0004, 1); // count 4 -> write blocked
        step(0, 1, 0, 32'h0003_0004, 0); // count 1 -> append word
        step(0, 1, 0, 32'h0005_0006, 1); // concurrent 16-bit read + word write
        step(0, 0, 0, 0, 1);
        step(0, 0, 0, 0, 1);
        step(0, 0, 0, 0, 1);
        step(0, 0, 0, 0, 1);

        // Reset clears occupancy even with valid transfers pending.
        reset_test("reset while occupied");
        step(0, 1, 0, 32'hC000_1234, 0);
        step(0, 1, 0, 32'h5678_0001, 0);
        step(1, 1, 0, 32'hFFFF_FFFF, 1);
        step(0, 1, 0, 32'h0001_4002, 1);
        step(0, 0, 0, 0, 1);
        step(0, 0, 0, 0, 1);

        // Repeatable random write modes and decoder stalls. The reference
        // model decodes length from whatever halfword reaches its head.
        reset_test("random stress");
        for (k = 0; k < 2000; k = k + 1) begin
            rnd = random_word();
            step(0, (rnd[2:0] != 3'b000), rnd[3],
                 random_word(), rnd[5:4] != 2'b00);
        end
        // Drain remaining instructions where possible. A trailing incomplete
        // instruction is allowed: it must remain invalid until more input.
        for (k = 0; k < 8; k = k + 1)
            step(0, 0, 0, 0, 1);

        if (simultaneous == 0 || halfword_writes == 0 ||
            read_len1 == 0 || read_len2 == 0 || read_len3 == 0 ||
            blocked_writes == 0 || stalled_reads == 0 || full_cycles == 0)
            $fatal(1, "Insufficient test coverage");

        $display("PASS: %0d cycles, %0d writes (%0d halfword), %0d reads, %0d simultaneous, %0d blocked writes, %0d stalled reads, %0d full cycles",
                 cycle, writes, halfword_writes, reads, simultaneous,
                 blocked_writes, stalled_reads, full_cycles);
        $display("Read lengths: 16-bit=%0d 32-bit=%0d 48-bit=%0d",
                 read_len1, read_len2, read_len3);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Global testbench timeout");
    end
endmodule

`default_nettype wire
