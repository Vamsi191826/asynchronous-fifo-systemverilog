# Asynchronous FIFO with Gray-Code Clock Domain Crossing

A parameterized dual-clock FIFO written in SystemVerilog. The design uses synchronized Gray-coded read and write pointers for full/empty status across independently clocked domains.

## Design at a glance

- **Languages:** SystemVerilog (RTL and testbench)
- **Default parameters:** 8 entries, 8-bit data; `PTR_WIDTH=$clog2(DEPTH)`
- **Separate clocks and resets:** `wclk` / `wrst_n`, `rclk` / `rrst_n`
- **Clock-domain crossing:** 2-flop synchronization of Gray-coded pointers
- **Flags:** Gray pointer comparison, including two-MSB inversion for full detection
- **Data path:** Dual-clock memory; write and read are accepted only when not full or empty, respectively
- **Read behavior:** Registered `data_out` on the read clock

This FIFO assumes a power-of-two depth and a synchronous interface on each side. Synchronizing Gray pointers reduces CDC risks, but does not by itself replace proper physical CDC and reset analysis.

## Repository layout

```text
rtl/
  asynchronous_fifo.sv     Top-level FIFO
  fifo_mem.sv              Dual-clock storage
  synchronizer.sv          Two-stage Gray-pointer synchronizer
  wptr_handler.sv          Write pointer and full flag
  rptr_handler.sv          Read pointer and empty flag
tb/
  tb_async_fifo_resume.sv  Directed and randomized testbench
constraints/
  async_fifo.xdc           Source timing constraints; review for your target
```

## Design explanation

Binary pointers address storage while their Gray-coded versions cross clock domains. The read clock domain sees the synchronized write pointer to determine whether the FIFO is empty; the write clock domain sees the synchronized read pointer to determine whether the FIFO is full. Flag deassertion can lag after activity in the opposite domain due to synchronization latency.

## Simulation

With Icarus Verilog supporting SystemVerilog:

```sh
iverilog -g2012 -s tb_async_fifo_resume -o fifo_sim \
  rtl/synchronizer.sv rtl/wptr_handler.sv rtl/rptr_handler.sv \
  rtl/fifo_mem.sv rtl/asynchronous_fifo.sv tb/tb_async_fifo_resume.sv
vvp fifo_sim
```

The testbench includes asynchronous clocks, directed sequences, random stress, scoreboard checks, assertions, coverage counters and a VCD dump. It is a **non-UVM** testbench.

## What to look for in results

- No data-order mismatches in the scoreboard
- Correct full and empty behavior
- No pointer advances on rejected accesses
- Simulation final summary has `fail_count == 0`
- Test full/empty transitions after cross-domain activity

**Verification status:** RTL and an accompanying testbench are included, but this prepared package was not rerun in a simulator. Run the testbench locally and add a screenshot and a verified log before stating a numerical pass result.

## CDC and implementation notes

- Synchronization latency is expected; it is not necessarily a design fault.
- Verify reset assertion/deassertion behavior per clock domain.
- Apply constraints appropriate for Gray-pointer CDC paths on your target technology.
- Any FPGA utilization/timing values must be taken from your own tool reports; no fresh synthesis was run for this package.

## Authorship and reuse

Confirm course/project code-sharing permissions before making public. Add attribution if any starter code was used. No license is granted automatically by this repository.
