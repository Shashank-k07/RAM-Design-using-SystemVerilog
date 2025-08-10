
# Design of 1 Kibibit RAM using SystemVerilog

---

## Project Overview

This project presents a synchronous **Random Access Memory (RAM)** module implemented in SystemVerilog, accompanied by a verification testbench. The RAM provides:

* **Memory Size:** 128 locations, each 8 bits wide (total 1024 bits).
* **Read and Write Operations:** Controlled by `rd_en` and `wr_en` signals respectively, synchronized with the clock.
* **Reset Functionality:** Asynchronous reset clears all memory contents and output data to zero.
* **Clock Signal:** All operations are synchronized on the rising edge of the clock, ensuring deterministic timing behavior.

The verification environment consists of:

* A SystemVerilog interface `ram_inf` that groups all input/output signals and the clock for clean connectivity.
* A `tb` class describing randomized stimulus with constraints to ensure valid scenarios, including reset behavior.
* A `common` class housing shared resources such as a mailbox and virtual interface.
* A stimulus generator class `gen` that produces random test vectors and enqueues them for consumption.
* A bus functional model class `bfm` that applies stimulus to the DUT signals via the interface.
* A top-level testbench module coordinating clock generation, instantiation of all components, and test sequencing.

This structured setup ensures modularity, scalability, and reliable verification of the RAM module.

---

## Memory Parameters and Addressing

| Parameter     | Value  | Description                                                               |
| ------------- | ------ | ------------------------------------------------------------------------- |
| Memory Width  | 8 bits | Data width for each memory location                                       |
| Memory Depth  | 128    | Number of memory locations                                                |
| Address Width | 7 bits | Number of bits required to address all memory locations (since 2^7 = 128) |

---

## Signal Description

| Signal Name | Direction | Width  | Description                                                                                          |
| ----------- | --------- | ------ | ---------------------------------------------------------------------------------------------------- |
| `reset`     | Input     | 1 bit  | Active high reset signal. When asserted, clears memory content and output data.                      |
| `clock`     | Input     | 1 bit  | Clock signal to synchronize all read/write operations.                                               |
| `wr_en`     | Input     | 1 bit  | Write enable signal. When high on rising clock edge, data on `wr_data` is written to memory.         |
| `rd_en`     | Input     | 1 bit  | Read enable signal. When high on rising clock edge, data at addressed location appears on `rd_data`. |
| `wr_data`   | Input     | 8 bits | Data input bus for write operations.                                                                 |
| `addr`      | Input     | 7 bits | Memory address bus to select read/write location.                                                    |
| `rd_data`   | Output    | 8 bits | Data output bus carrying data read from memory.                                                      |

---

## Functional Description

* On each rising clock edge:

  * If `reset` is asserted (`1`), the entire memory is cleared to zero, and output data `rd_data` is set to zero.
  * If `reset` is deasserted (`0`):

    * If `wr_en` is asserted, `wr_data` is written into the memory location specified by `addr`.
    * If `rd_en` is asserted, data stored at `addr` is output on `rd_data`.

---

## Verification Components

### 1. `common` Class

```systemverilog
class common;
  static mailbox mb = new();        // Mailbox for test vector exchange
  static virtual ram_inf vif;       // Virtual interface handle
endclass
```

* Facilitates thread-safe communication between stimulus generator and BFM.
* Provides access to DUT interface signals.

---

### 2. Interface `ram_inf`

```systemverilog
interface ram_inf(input bit clock);
  bit reset;
  bit rd_en;
  bit wr_en;
  bit [7:0] rd_data;
  bit [7:0] wr_data;
  bit [6:0] addr;
endinterface
```

* Encapsulates all control, data, and address signals along with the clock.
* Enables easy connectivity and modular testbench design.

---

### 3. RAM Module

```systemverilog
module ram(
  input reset,
  input clock,
  input wr_en,
  input rd_en,
  input [7:0] wr_data,
  input [6:0] addr,
  output reg [7:0] rd_data
);
  reg [7:0] mem [0:127];
  integer i;

  always @(posedge clock) begin
    if (reset) begin
      rd_data <= 8'd0;
      for (i = 0; i < 128; i = i + 1) begin
        mem[i] <= 8'd0;
      end
    end else begin
      if (wr_en)
        mem[addr] <= wr_data;
      if (rd_en)
        rd_data <= mem[addr];
    end
  end
endmodule
```

* Synchronous reset clears memory and output.
* Write and read operations synchronized with clock.

---

### 4. Testbench Class `tb`

```systemverilog
class tb;
  randc bit reset;
  randc bit rd_en;
  randc bit wr_en;
  randc bit [7:0] wr_data;
  randc bit [6:0] addr;

  constraint addr_fixed {
    addr == 7'd111;                  // Fix address to 111 for focused testing
  }
  
  constraint reset_behavior {
    (reset == 1) -> (wr_en == 0);   // No write when reset is active
    (reset == 1) -> (rd_en == 0);   // No read when reset is active
  }
endclass
```

* Generates randomized test vectors.
* Ensures that when reset is asserted, no reads or writes happen.

---

### 5. Generator Class `gen`

```systemverilog
class gen;
  tb p;

  task t1();
    p = new();
    p.randomize();
    common::mb.put(p);
  endtask
endclass
```

* Generates and enqueues random stimulus objects.

---

### 6. Bus Functional Model (BFM) Class

```systemverilog
class bfm;
  tb p;

  task t2();
    p = new();
    common::mb.get(p);
    common::vif.reset = p.reset;
    common::vif.wr_en = p.wr_en;
    common::vif.rd_en = p.rd_en;
    common::vif.wr_data = p.wr_data;
    common::vif.addr = p.addr;
  endtask
endclass
```

* Retrieves stimulus from mailbox and drives the DUT signals.

---

### 7. Top-Level Test Module

```systemverilog
module test;
  bit clock;

  // Clock generation: 10 time units period
  initial begin
    clock = 0;
    forever #5 clock = ~clock;
  end

  // Instantiate interface, generator, BFM, and DUT
  ram_inf pvif(clock);
  gen stimulus_gen = new();
  bfm driver = new();

  ram dut (
    .reset(pvif.reset),
    .clock(pvif.clock),
    .wr_en(pvif.wr_en),
    .rd_en(pvif.rd_en),
    .wr_data(pvif.wr_data),
    .addr(pvif.addr),
    .rd_data(pvif.rd_data)
  );

  initial begin
    common::vif = pvif;
    repeat (10) begin
      stimulus_gen.t1();
      driver.t2();
      @(posedge clock);
    end
    $finish;
  end
endmodule
```

* Generates clock.
* Runs 10 cycles of randomized stimulus.
* Cleanly finishes simulation.

---
