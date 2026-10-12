module TB_I2C;

    reg clk;
    reg reset;
    reg start;
    reg r_w;
    reg [6:0] address;
    reg [7:0] data;

    wire scl;
    wire tick;
    tri sda;

    pullup(sda);

    i2c_scl clock_gen (
        .clk(clk),
        .scl(scl),
        .tick(tick)
    );

    i2c_sda master (
        .clk(clk),
        .reset(reset),
        .start(start),
        .r_w(r_w),
        .address(address),
        .scl(scl),
        .data(data),
        .tick(tick),
        .sda(sda)
    );

    i2c_slave slave (
        .address_dev(7'b1010011),
        .scl(scl),
        .sda(sda)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task start_transaction;
        begin
            @(negedge clk);
            start = 1'b1;

            repeat (3) @(negedge clk);
            start = 1'b0;
        end
    endtask

    task wait_for_idle;
        integer timeout_count;
        begin
            timeout_count = 0;

            while (master.state == 5'd0 &&
                   timeout_count < 100000) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            while (master.state != 5'd0 &&
                   timeout_count < 100000) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 100000)
                $display("ERROR: Transaction timeout");
        end
    endtask

    initial begin
        $dumpfile("i2c_slave_test.vcd");
        $dumpvars(0, TB_I2C);

        reset   = 1'b1;
        start   = 1'b0;
        r_w     = 1'b0;
        address = 7'b1010011;
        data    = 8'hA5;

        repeat (5) @(negedge clk);
        reset = 1'b0;

        repeat (10) @(negedge clk);

        $display("\nTEST 1: Write data A5");

        start_transaction();
        wait_for_idle();

        $display("Master ACK1 = %b", master.ack1);
        $display("Master ACK2 = %b", master.ack2);
        $display("Slave address = %b", slave.received_address);
        $display("Slave data = %h", slave.received_data);

        if (slave.received_address == address &&
            slave.received_data == data &&
            master.ack1 == 1'b0 &&
            master.ack2 == 1'b0)
            $display("PASS: Address and data verified");
        else
            $display("FAIL: Check bus timing and slave FSM");

        $display("\nTEST 2: Write data 3C");

        data = 8'h3C;
        start_transaction();
        wait_for_idle();

        $display("Expected data = %h", data);
        $display("Received data = %h", slave.received_data);

        if (slave.received_data == data)
            $display("PASS: Data byte matches");
        else
            $display("FAIL: Data byte mismatch");

        $display("\nSimulation completed.");
        #1000;
        $finish;
    end

    initial begin
        #5000000;
        $display("ERROR: Global timeout");
        $finish;
    end

endmodule
