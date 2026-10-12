module i2c_sda(
    input clk,
    input reset,
    input start,
    input r_w,
    input [6:0] address,
    input scl,
    input [7:0] data,
    input tick, 
    inout sda
);

    localparam IDLE = 5'd0;
    localparam START = 5'd1;
    localparam ADDR = 5'd2;
    localparam R_W = 5'd3;
    localparam ACK1_FIRST = 5'd4;
    localparam ACK1_RELEASE = 5'd5;
    localparam ACK1_SAMPLE = 5'd6;
    localparam DATA_WRITE = 5'd7;
    localparam DATA_READ = 5'd8;
    localparam ACK2_FIRST = 5'd9;
    localparam ACK2_RELEASE = 5'd10;
    localparam ACK2_SAMPLE = 5'd11;
    localparam STOP_PREP = 5'd12;
    localparam STOP_FINISH = 5'd13;
    localparam MASTER_ACK_DRIVE = 5'd14;
    localparam MASTER_ACK_FINISH = 5'd15;

    reg [4:0] state;
    reg [2:0] addr_count;
    reg [7:0] data_read;
    reg ack1;
    reg ack2;
    reg [2:0] count_data;
    reg sda_out;
    reg sda_oe;
    reg start_req;

assign sda = (sda_oe && !sda_out) ? 1'b0 : 1'bz;

    always @(posedge clk) begin

        if (reset) begin
            state <= IDLE;
            addr_count <= 0;
            count_data <= 0;
            data_read <= 8'd0;
            ack1 <= 1'b1;
            ack2 <= 1'b1;
            sda_out <= 1'b1;
            sda_oe <= 1'b1;
            start_req <= 1'b0;
        end

        else begin

            if (start)
                start_req <= 1'b1;

            case (state)

                IDLE: begin
                    sda_oe <= 1'b1;
                    sda_out <= 1'b1;
                    if (start_req) begin
                        state <= START;
                    end
                end

                START: begin
                    if (scl && tick) begin
                        sda_out <= 1'b0;
                        start_req <= 1'b0;
                        addr_count <= 3'd6;
                        state <= ADDR;
                    end
                end

                ADDR: begin
                    if (!scl && tick) begin
                        sda_out <= address[addr_count];
                        if (addr_count == 0) begin
                            state <= R_W;
                        end
                        else begin
                            addr_count <= addr_count - 1'b1;
                        end
                    end
                end

                R_W: begin 
                    if (!scl && tick) begin
                        sda_out <= r_w;
                        state <= ACK1_FIRST;
                    end
                end

                ACK1_FIRST: begin
                    if (scl && tick) begin
                        state <= ACK1_RELEASE;
                    end
                end

                ACK1_RELEASE: begin 
                    if (!scl && tick) begin
                        sda_oe <= 1'b0;
                        state <= ACK1_SAMPLE;
                    end
                end

                ACK1_SAMPLE: begin
                    if (scl && tick) begin
                        ack1 <= sda;
                        if (sda == 1'b0) begin
                            count_data <= 3'd7;
                            if (r_w == 1'b0) begin
                                state <= DATA_WRITE;
                            end
                            else begin
                                state <= DATA_READ;
                            end
                        end
                        else begin
                            state <= STOP_PREP;
                        end
                    end
                end

                DATA_WRITE: begin
                    if (!scl && tick) begin
                        sda_oe <= 1'b1;
                        sda_out <= data[count_data];
                        if (count_data == 0) begin
                            state <= ACK2_FIRST;
                        end
                        else begin
                            count_data <= count_data - 1'b1;
                        end
                    end
                end

                DATA_READ: begin
                    if (scl && tick) begin
                        sda_oe <= 1'b0;
                        data_read[count_data] <= sda;
                        if (count_data == 0) begin
                            state <= MASTER_ACK_DRIVE;
                        end
                        else begin
                            count_data <= count_data - 1'b1;
                        end
                    end
                end

                ACK2_FIRST: begin
                    if (scl && tick) begin
                        state <= ACK2_RELEASE;
                    end
                end

                ACK2_RELEASE: begin
                    if (!scl && tick) begin
                        sda_oe <= 1'b0;
                        state <= ACK2_SAMPLE;
                    end
                end

                ACK2_SAMPLE: begin
                    if (scl && tick) begin
                        ack2 <= sda;
                        state <= STOP_PREP;
                    end
                end

                MASTER_ACK_DRIVE: begin
                    if (!scl && tick) begin
                        sda_oe <= 1'b0;
                        state <= MASTER_ACK_FINISH;
                    end
                end

                MASTER_ACK_FINISH: begin
                    if (scl && tick) begin
                        state <= STOP_PREP;
                    end
                end

                STOP_PREP: begin
                    if (!scl && tick) begin
                        sda_oe <= 1'b1;
                        sda_out <= 1'b0;
                        state <= STOP_FINISH;
                    end
                end

                STOP_FINISH: begin
                    if (scl && tick) begin
                        sda_out <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end

            endcase

        end
    end

endmodule