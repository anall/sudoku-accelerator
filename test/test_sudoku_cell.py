# SPDX-FileCopyrightText: 2021 Andrea Nall
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0

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

    dut.wdata <= 0

    dut.address <= 0
    dut.we <= 0

    dut.latch_singleton <= 0
    await reset(dut)

    await ClockCycles(dut.clk, 1)

    assert (dut.value == 0b00000000)

    dut.latch_singleton <= 1
    await ClockCycles(dut.clk, 1)
    dut.latch_singleton <= 0

    await ClockCycles(dut.clk, 1)
    assert (dut.rdata == 0b000000000)

    dut.we <= 1
    dut.address <= 1
    dut.wdata <= 0b100011100
    await ClockCycles(dut.clk, 1)

    dut.wdata <= 0b100101101
    await ClockCycles(dut.clk, 1)

    dut.wdata <= 0b100010001
    await ClockCycles(dut.clk, 1)

    dut.we <= 0;

    await ClockCycles(dut.clk, 1)
    assert (dut.valid == 0b100000000)

    dut.address <= 1
    await ClockCycles(dut.clk, 1)
    assert (dut.rdata.value == dut.valid.value)
    assert (dut.is_singleton)

    dut.latch_singleton <= 1
    await ClockCycles(dut.clk, 1)
    dut.latch_singleton <= 0

    await ClockCycles(dut.clk, 1)
    assert (dut.value == 0b100000000)
    assert (dut.solved)

    dut.address <= 0
    await ClockCycles(dut.clk, 1)
    assert (dut.rdata.value == dut.value.value)

