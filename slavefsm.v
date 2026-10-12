`timescale 1ns/1ps

// Ideal I2C slave model (write-only target), simulation model.
//
// Drop-in replacement: same module name and ports as before, and the same
// hierarchical names the testbench uses (received_address, received_rw,
// received_data).
//
// Behaviour
//   - Open-drain SDA: the slave only ever pulls LOW or releases (z).
//   - START / STOP detected when SDA changes while SCL is HIGH
//     (also handles a repeated START).
//   - Address byte {addr[6:0], R/W}: ACK only if addr == address_dev AND R/W = 0.
//     A read request (R/W = 1) or a wrong address is NACKed, and the slave
//     ignores the bus until the next START.
//   - Data bytes: every byte is received MSB first and ACKed; any number of
//     bytes can follow one address (byte_count counts them).
//   - Bits are sampled on SCL rising edge; ACK is driven after SCL falls and
//     released on the SCL fall that ends the 9th clock.
//   - T_VD models the slave's SCL-low -> ACK-valid delay (spec allows up to
//     3450 ns in standard mode). It also keeps a push-pull master from
//     briefly fighting the ACK at the handover.
module i2c_slave #(
    parameter T_VD = 50                 // ns
)(
    input  [6:0] address_dev,
    input        scl,
    inout        sda
);

    localparam [2:0] IDLE          = 3'd0;  // not addressed / waiting for START
    localparam [2:0] RX_ADDR       = 3'd1;  // receiving address + R/W
    localparam [2:0] ADDR_ACK      = 3'd2;  // 8 bits in, ACK goes out on next SCL fall
    localparam [2:0] ADDR_ACK_HOLD = 3'd3;  // ACK being driven, release on next SCL fall
    localparam [2:0] RX_DATA       = 3'd4;  // receiving a data byte
    localparam [2:0] DATA_ACK      = 3'd5;
    localparam [2:0] DATA_ACK_HOLD = 3'd6;

    reg [2:0] state = IDLE;
    reg [3:0] bit_count = 4'd0;
    reg [7:0] shift = 8'h00;

    reg [6:0] received_address = 7'd0;
    reg       received_rw      = 1'b0;
    reg [7:0] received_data    = 8'h00;
    reg [7:0] byte_count       = 8'd0;      // data bytes ACKed since last START
    reg       address_match    = 1'b0;

    reg sda_low = 1'b0;
    reg scl_q   = 1'b1;
    reg sda_q   = 1'b1;

    // Open-drain: pull low or release. Pulling low is delayed by T_VD,
    // releasing is immediate.   #(rise, fall(->0), turn-off(->z))
    assign #(0, T_VD, 0) sda = sda_low ? 1'b0 : 1'bz;

    // One block owns all state, so there are no races between edges.
    // Only clean 0->1 / 1->0 transitions count as edges (x/z are ignored).
    always @(scl or sda) begin : bus_monitor

        if (scl === 1'b1 && scl_q === 1'b1) begin
            // SCL stayed high: SDA edge here is a START or STOP
            if (sda_q === 1'b1 && sda === 1'b0) begin          // START
                state     = RX_ADDR;
                bit_count = 4'd0;
                shift     = 8'h00;
                byte_count = 8'd0;
                sda_low   = 1'b0;
            end
            else if (sda_q === 1'b0 && sda === 1'b1) begin     // STOP
                state     = IDLE;
                bit_count = 4'd0;
                sda_low   = 1'b0;
            end
        end

        else if (scl_q === 1'b0 && scl === 1'b1) begin
            // ---- SCL rising edge: sample SDA ----
            case (state)
                RX_ADDR: begin
                    shift     = {shift[6:0], sda};
                    bit_count = bit_count + 1'b1;
                    if (bit_count == 4'd8) begin
                        received_address = shift[7:1];
                        received_rw      = shift[0];
                        address_match    = (shift[7:1] == address_dev) &&
                                           (shift[0]   == 1'b0);
                        state = ADDR_ACK;
                    end
                end

                RX_DATA: begin
                    shift     = {shift[6:0], sda};
                    bit_count = bit_count + 1'b1;
                    if (bit_count == 4'd8) begin
                        received_data = shift;
                        byte_count    = byte_count + 1'b1;
                        state = DATA_ACK;
                    end
                end

                default: ;
            endcase
        end

        else if (scl_q === 1'b1 && scl === 1'b0) begin
            // ---- SCL falling edge: drive / release ACK ----
            case (state)
                ADDR_ACK: begin
                    if (address_match) begin
                        sda_low = 1'b1;                 // ACK
                        state   = ADDR_ACK_HOLD;
                    end
                    else begin
                        state = IDLE;                   // NACK: ignore until next START
                    end
                end

                ADDR_ACK_HOLD: begin
                    sda_low   = 1'b0;                   // release after 9th clock
                    bit_count = 4'd0;
                    state     = RX_DATA;
                end

                DATA_ACK: begin
                    sda_low = 1'b1;                     // ACK
                    state   = DATA_ACK_HOLD;
                end

                DATA_ACK_HOLD: begin
                    sda_low   = 1'b0;
                    bit_count = 4'd0;
                    state     = RX_DATA;
                end

                default: ;
            endcase
        end

        scl_q = scl;
        sda_q = sda;
    end

endmodule