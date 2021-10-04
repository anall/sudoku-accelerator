import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random

async def reset(dut):
    dut.reset <= 1

    await ClockCycles(dut.clk, 5)
    dut.reset <= 0;

@cocotb.test()
async def test_sudoku_cell(dut):
    clock = Clock(dut.clk, 10, units="us")
    cocotb.fork(clock.start())

    z9 = BinaryValue("zzzzzzzzz")

    dut.value_io <= z9

    dut.address <= 0
    dut.we <= 0
    dut.oe <= 0

    dut.latch_valid <= 0
    dut.latch_singleton <= 0
    await reset(dut)

    await ClockCycles(dut.clk, 1)

    assert (dut.value == 0)
    assert (dut.value_io.value.binstr == "zzzzzzzzz")

    assert (dut.value == 0b00000000)

    dut.value_io <= 0b000000101
    dut.we <= 1
    dut.address <= 1
    await ClockCycles(dut.clk, 1)
    dut.value_io <= z9
    dut.we <= 0

    await ClockCycles(dut.clk, 1)
    assert (dut.pencil_out == 0b00000101)

    dut.latch_singleton <= 1
    await ClockCycles(dut.clk, 1)
    dut.latch_singleton <= 0

    await ClockCycles(dut.clk, 1)
    assert (dut.value == 0b000000000)

    dut.oe <= 1
    await ClockCycles(dut.clk, 1)
    assert (dut.value_io.value == dut.pencil_out.value)
    dut.oe <= 0
    await ClockCycles(dut.clk, 1)

    dut.latch_valid <= 1
    dut.value_io <= 0b100011101
    await ClockCycles(dut.clk, 1)

    dut.value_io <= 0b100101101
    await ClockCycles(dut.clk, 1)

    dut.value_io <= 0b100010101
    await ClockCycles(dut.clk, 1)

    dut.value_io <= z9
    dut.latch_valid <= 0

    await ClockCycles(dut.clk, 1)
    assert (dut.valid == 0b100000000)

    dut.oe <= 1
    dut.address <= 2
    await ClockCycles(dut.clk, 1)
    assert (dut.value_io.value == dut.valid.value)
    assert (dut.is_singleton)
    dut.oe <= 0

    dut.latch_singleton <= 1
    await ClockCycles(dut.clk, 1)
    dut.latch_singleton <= 0

    await ClockCycles(dut.clk, 1)
    assert (dut.value == 0b100000000)
    assert (dut.solved)

    dut.oe <= 1
    dut.address <= 0
    await ClockCycles(dut.clk, 1)
    assert (dut.value_io.value == dut.value)

    # reset and test a fast cycle
    dut.value_io <= z9

    dut.address <= 0
    dut.we <= 0
    dut.oe <= 0

    dut.latch_valid <= 0
    dut.latch_singleton <= 0
    await reset(dut)

    dut.latch_valid <= 1
    dut.value_io <= 0b100011101
    await ClockCycles(dut.clk, 1)

    dut.value_io <= 0b100101001
    await ClockCycles(dut.clk, 1)

    dut.value_io <= 0b100010100
    await ClockCycles(dut.clk, 1)

    dut.latch_valid <= 0
    dut.latch_singleton <= 1
    await ClockCycles(dut.clk, 1)
    dut.latch_singleton <= 0
    await ClockCycles(dut.clk, 1)

    assert (dut.value == 0b100000000)
    assert (dut.solved)

    dut.latch_singleton <= 1
    assert (dut.is_singleton == 0)
    await ClockCycles(dut.clk, 1)

    assert (dut.solved)
