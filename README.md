# I²C Master Controller in Verilog

A Verilog RTL implementation of an I²C master with single-byte read/write support, ACK/NACK handling, and a behavioral slave for simulation.

## Features

- I²C master FSM with START and STOP generation
- 7-bit slave addressing and MSB-first transmission
- Single-byte read and write transactions
- ACK/NACK handling and error-case testing
- Open-drain SDA and SCL output modelling
- Reset recovery and back-to-back transactions
- Testbench verification with Icarus Verilog and GTKWave

## Configuration

| Parameter | Value |
|---|---|
| System clock | 100 MHz |
| Target SCL frequency | 100 kHz |
| Address width | 7 bits |
| Data width | 8 bits |
| Data order | MSB first |
| Simulation tools | Icarus Verilog, GTKWave |

## Architecture

The design consists of four modules:

| File | Description |
|---|---|
| `scl.v` | SCL clock generation |
| `sda.v` | I²C master FSM and SDA control |
| `slavefsm.v` | Behavioral I²C slave |
| `TB_I2C.v` | Testbench and regression checks |

A typical write transaction follows:

```text
START → Address + Write → ACK
      → Data Byte → ACK → STOP
```

For reads, the master receives a byte and sends a NACK after the final byte.

## Simulation

Compile and run from the project directory:

```bash
iverilog -g2012 -o i2c_sim scl.v sda.v TB_I2C.v slavefsm.v
vvp i2c_sim
gtkwave i2c_regression.vcd
```

## Verification Results

The latest regression reports **10 passed checks and 0 failures**.

Tested scenarios include:

- Single-byte read returning `0x68`
- Writes of `0xA5` and `0x3C`
- Back-to-back transactions without reset
- Wrong-address and missing-slave NACK handling
- Reset while idle and during a transaction
- Successful transaction after reset
- START and STOP transition monitoring

Verification has been performed in simulation; physical hardware testing has not yet been completed.

## Current Limitations

- Repeated START and register-addressed reads
- Multi-byte transfers
- Clock stretching and multi-master arbitration
- Full protocol timing verification
- Physical sensor and FPGA validation

## Future Improvements

1. Implement register-addressed reads and repeated START.
2. Support multi-byte sensor data transfers.
3. Strengthen timeout and error-recovery handling.
4. Validate the controller with an MPU6050 on hardware.

## Tools

Verilog HDL · Icarus Verilog · GTKWave · Git · GitHub

## Author

Aarav Singh
