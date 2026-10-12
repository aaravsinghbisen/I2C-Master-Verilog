# I2C Master Verilog RTL

A basic I2C master implemented in Verilog RTL and verified through simulation using Icarus Verilog and GTKWave.

## Overview

This project implements an I2C master finite-state machine (FSM) and a simulated I2C slave for testing basic write transactions.

The master transmits a 7-bit slave address, the read/write direction bit, and an 8-bit data byte. The fake slave detects the address, receives the data, and acknowledges the transaction.

The design includes:

- I2C master FSM
- SCL clock generator
- START and STOP condition generation
- 7-bit slave addressing
- Read/write direction-bit transmission
- Open-drain SDA handling
- Slave ACK/NACK sampling
- MSB-first address and data transmission
- Fake I2C slave for simulation
- Verilog testbench
- VCD waveform generation
- GTKWave waveform verification

The design uses a 100 MHz system clock and generates an SCL signal intended for approximately 100 kHz communication.

## I2C Configuration

| Parameter | Value |
|---|---|
| System Clock | 100 MHz |
| Target SCL Frequency | 100 kHz |
| Slave Address | `7'b1010011` |
| Address Width | 7 bits |
| Data Width | 8 bits |
| Data Order | MSB First |
| SDA Signaling | Open-drain |
| SCL Signaling | Push-pull |
| Simulation Tool | Icarus Verilog |
| Waveform Viewer | GTKWave |

## What is I2C?

I2C (Inter-Integrated Circuit) is a synchronous serial communication protocol that uses two signal lines:

- **SCL** — Serial Clock Line
- **SDA** — Serial Data Line

The master initiates communication and controls the clock. The addressed slave responds to the address and participates in the data transfer.

Each transmitted byte consists of eight data bits followed by a ninth clock for acknowledgement.

- **ACK (`0`)** — The receiver acknowledges the byte.
- **NACK (`1`)** — The receiver does not acknowledge the byte.

## System Architecture

The project consists of an SCL generator, an I2C master, a fake I2C slave, and a testbench.

```text
                     +-------------------+
                     |   SCL Generator   |
                     +---------+---------+
                               | SCL, tick
                               v
                     +-------------------+
                     |    I2C Master     |
                     |                   |
                     | START / STOP      |
                     | Address FSM       |
                     | Data Transmission|
                     | ACK Detection     |
                     +---------+---------+
                               |
                          SDA / SCL
                               |
                     +---------v---------+
                     |   Fake I2C Slave  |
                     |                   |
                     | Address Detection |
                     | Data Reception    |
                     | ACK Generation    |
                     +-------------------+

                     +-------------------+
                     |    Testbench      |
                     | Input Stimulus    |
                     | Result Checking   |
                     | VCD Generation    |
                     +-------------------+
```

The master and fake slave communicate through shared SDA and SCL signals. The testbench generates transactions and checks the received address, data, and acknowledgement signals.

## I2C Transaction Format

A basic write transaction follows this sequence:

```text
START -> 7-bit Address -> R/W = 0 -> ACK1
      -> 8-bit Data -> ACK2 -> STOP
```

The master generates START and transmits the address and write direction bit.

The slave acknowledges the address if it matches the configured address. The master then transmits the data byte, and the slave acknowledges the received data before the master generates STOP.

## START and STOP Conditions

### START Condition

A START condition occurs when SDA transitions from HIGH to LOW while SCL is HIGH.

### STOP Condition

A STOP condition occurs when SDA transitions from LOW to HIGH while SCL is HIGH.

These conditions mark the beginning and end of an I2C transaction.

## SCL Clock Generation

The SCL generator uses the 100 MHz system clock to generate timing for approximately 100 kHz I2C communication.

For a target frequency of 100 kHz:

```text
SCL Period = 1 / 100,000
           = 10 us

SCL Half Period = 5 us

System Clock Period = 10 ns

Clock Cycles per Half Period = 5 us / 10 ns
                             = 500 cycles
```

The counter toggles SCL when it reaches 499, producing a half-period of 500 system-clock cycles.

The clock generator also produces a timing enable signal (`tick`) for the master FSM.

The current SCL output is push-pull: it actively drives both HIGH and LOW. Open-drain SCL behavior has not yet been implemented.

## I2C Master FSM

The master is implemented as a finite-state machine.

### Main States

| State | Function |
|---|---|
| `IDLE` | Wait for a transaction request |
| `START` | Generate START condition |
| `ADDR` | Transmit the seven-bit slave address |
| `R_W` | Transmit the read/write direction bit |
| `ACK1_FIRST` | Wait for the address acknowledgement clock |
| `ACK1_RELEASE` | Release SDA for the slave response |
| `ACK1_SAMPLE` | Sample the slave's address ACK/NACK |
| `DATA_WRITE` | Transmit an eight-bit data byte |
| `DATA_READ` | Read-data state, not yet verified |
| `ACK2_FIRST` | Wait for the data acknowledgement clock |
| `ACK2_RELEASE` | Release SDA for the slave response |
| `ACK2_SAMPLE` | Sample the slave's data ACK/NACK |
| `MASTER_ACK_DRIVE` | Master read-response state |
| `MASTER_ACK_FINISH` | Complete the master response phase |
| `STOP_PREP` | Prepare the STOP condition |
| `STOP_FINISH` | Complete the STOP condition |

The write path is the currently verified operating path. The read-related states are present in the master RTL but have not been verified with a read-capable slave.

### Address Transmission

The master transmits the seven-bit address MSB first.

The configured address is:

```text
1010011
```

The address bits are transmitted in this order:

```text
A6 -> A5 -> A4 -> A3 -> A2 -> A1 -> A0
```

The read/write direction bit follows the address:

```text
R/W = 0 -> Write
R/W = 1 -> Read
```

## ACK/NACK Handling

### Address Acknowledgement — ACK1

After transmitting the address and direction bit, the master releases SDA and samples the slave's response.

```text
Master -> Address + R/W
Slave  -> ACK1 / NACK
```

A LOW level indicates that the slave acknowledged the address.

### Data Acknowledgement — ACK2

During a write transaction, the slave acknowledges the received data byte.

```text
Master -> 8-bit Data
Slave  -> ACK2 / NACK
```

The master samples SDA during the ninth clock.

The internal `ack1` and `ack2` registers record the sampled responses:

```text
ack1 = 0 -> Address acknowledged
ack1 = 1 -> Address not acknowledged

ack2 = 0 -> Data acknowledged
ack2 = 1 -> Data not acknowledged
```

These registers are initialized to `1` during reset. A value of `1` before a sample is also the initial reset value, so the testbench should check that the transaction actually completed before interpreting it as NACK.

## Fake I2C Slave

The fake slave is a simulation model used to test the master without physical I2C hardware.

Its current functionality includes:

- Detecting START and STOP conditions
- Monitoring SCL and SDA transitions
- Receiving the seven-bit address and R/W bit
- Matching the configured slave address
- Acknowledging matching write addresses
- Rejecting read requests and incorrect addresses
- Receiving eight-bit data bytes
- Acknowledging received data bytes
- Recording the received address and data for verification

The slave uses open-drain SDA behavior. It pulls the line LOW or releases it, while a pull-up in the testbench establishes the HIGH level.

The fake slave is currently write-only. It does not yet transmit data to the master.

## Simulation

The design is simulated using Icarus Verilog and GTKWave.

### Compilation

Run the following command from the project directory:

```bash
iverilog -g2012 -o i2c_sim scl.v sda.v TB_I2C.v slavefsm.v
```

### Run Simulation

```bash
vvp i2c_sim
```

### Open Waveforms

```bash
gtkwave i2c_slave_test.vcd
```

The VCD waveform can be inspected to observe SCL, SDA, START timing, address transmission, data transmission, and acknowledgement behavior.

## Verification Results

The following write transactions have passed simulation.

### Test 1 — Write `0xA5`

```text
Transmitted Data = A5
Received Data    = A5

Master ACK1 = 0
Master ACK2 = 0

Address Verification = PASS
Data Verification    = PASS
```

### Test 2 — Write `0x3C`

```text
Expected Data = 3C
Received Data = 3C

Data Verification = PASS
```

These tests verify the basic write transaction, address decoding, data reception, and acknowledgement handling in the current simulation environment.

The current tests do not establish that the master read path works or that the start-request latch handles every possible SCL phase.

## Files

| File | Description |
|---|---|
| `scl.v` | SCL clock generator |
| `sda.v` | I2C master FSM |
| `slavefsm.v` | Fake I2C slave model |
| `TB_I2C.v` | Testbench and verification checks |

## Tools

- Verilog HDL
- Icarus Verilog
- GTKWave
- Git
- GitHub

## Current Limitations

This project is currently focused on basic I2C write transactions and RTL simulation.

The following features remain to be implemented or verified:

- Complete master read transactions
- Read-capable fake slave
- Master ACK/NACK behavior after received data
- Repeated START for register reads
- MPU6050 register-read verification
- Open-drain SCL behavior
- Clock stretching
- Verification of start requests arriving during SCL-low
- Address-NACK and additional error-handling regression tests
- FPGA hardware validation

## Future Improvements

Planned improvements include:

- Complete and verify master read support
- Implement a read-capable fake slave
- Add repeated START and register addressing
- Read the MPU6050 `WHO_AM_I` register
- Evaluate open-drain SCL behavior
- Add more automated test cases
- Improve protocol timing and error handling
- Perform FPGA hardware validation

## Author

Aarav Singh
