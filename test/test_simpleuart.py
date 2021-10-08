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
from cocotbext.uart import UartSource, UartSink
import random

async def reset(dut):
    dut.resetn <= 0

    await ClockCycles(dut.clk, 5)
    dut.resetn <= 1

@cocotb.test()
async def test_read(dut):
    clock_freq = 10_000_000;
    baud = 115200;

    clock = Clock(dut.clk, 100, units="ns")
    cocotb.fork(clock.start())

    uart_source = UartSource(dut.ser_rx, baud=baud, bits=8)

    dut.reg_div_we <= 0
    dut.reg_div_di <= 0
    dut.reg_cfg_we <= 0
    dut.reg_dat_we <= 0
    dut.reg_dat_re <= 0
    dut.reg_dat_di <= 0

    await reset(dut)

    await ClockCycles(dut.clk, 5)

    dut.reg_div_di <= int(clock_freq/baud)
    dut.reg_div_we <= 0b1111

    await ClockCycles(dut.clk, 1)
    
    dut.reg_div_we <= 0
    dut.reg_cfg_di <= 0b011
    dut.reg_cfg_we <= 1

    await ClockCycles(dut.clk, 1)

    assert (dut.interrupt == 0)
    dut.reg_cfg_we <= 0
    await ClockCycles(dut.clk, 1)

                             #rXrX123456789abcdef
    await uart_source.write(b'deadbeef01234567890')

    while ( dut.interrupt == 0 ):
      await ClockCycles(dut.clk, 1)

    assert( dut.reg_cfg_do.value & 1<<8 ) # recv has data
    dut.reg_dat_re <= 1;
    assert( dut.reg_dat_do == ord(b'd') )
    await ClockCycles(dut.clk, 1)
    dut.reg_dat_re <= 0;
    await ClockCycles(dut.clk, 1)
    assert( not (dut.reg_cfg_do.value & 1<<8 ) ) # recv has data

    while ( not (dut.reg_cfg_do.value & 1<<9 ) ): # recv wrap
      await ClockCycles(dut.clk, 1)
    
    dut.reg_dat_re <= 1;
    assert( dut.reg_dat_do == ord(b'a') )
    await ClockCycles(dut.clk, 1)
    dut.reg_dat_re <= 0;
    await ClockCycles(dut.clk, 1)
    assert( (dut.reg_cfg_do.value & 1<<8 ) ) # recv data
    assert( not (dut.reg_cfg_do.value & 1<<9 ) ) # recv wrap

    await uart_source.wait()
    
    out_str = ''
    assert( (dut.reg_cfg_do.value & 1<<9 ) ) # recv wrap
    while ( (dut.reg_cfg_do.value & 1<<8) ): # recv data
      dut.reg_dat_re <= 1;
      out_str = out_str + chr(dut.reg_dat_do.value)
      await ClockCycles(dut.clk, 1)
      dut.reg_dat_re <= 0;
      await ClockCycles(dut.clk, 1)

    assert( not (dut.reg_cfg_do.value & 1<<8) )  # recv data
    assert( not (dut.reg_cfg_do.value & 1<<9) ) # recv wrap
    assert(out_str == 'beef01234567890')

@cocotb.test()
async def test_write(dut):
    clock_freq = 10_000_000;
    baud = 115200;

    clock = Clock(dut.clk, 100, units="ns")
    cocotb.fork(clock.start())

    uart_sink   = UartSink(dut.ser_tx, baud=baud, bits=8)

    dut.reg_div_we <= 0
    dut.reg_div_di <= 0
    dut.reg_cfg_we <= 0
    dut.reg_dat_we <= 0
    dut.reg_dat_re <= 0
    dut.reg_dat_di <= 0

    await reset(dut)

    await ClockCycles(dut.clk, 5)

    dut.reg_div_di <= int(clock_freq/baud)
    dut.reg_div_we <= 0b1111

    await ClockCycles(dut.clk, 1)
    
    dut.reg_div_we <= 0
    dut.reg_cfg_di <= 0b101
    dut.reg_cfg_we <= 1

    await ClockCycles(dut.clk, 1)
    dut.reg_div_we <= 0

    string = b'sphinx of black quartz'

    for ch in string:
      dut.reg_dat_di <= ch
      dut.reg_dat_we <= 1
      await ClockCycles(dut.clk, 1)

      while ( dut.reg_dat_wait == 1 ):
        await ClockCycles(dut.clk, 1)
      assert( dut.reg_dat_wait == 0 );
      dut.reg_dat_we <= 0
      await ClockCycles(dut.clk, 1)

    print("done writing, waiting for FIFO to empty")
    while ( not (dut.reg_cfg_do.value & 1<<10) ): # send fifo empty
      await ClockCycles(dut.clk, 1)
    print("waiting for UART to be idle")
    while ( not (dut.reg_cfg_do.value & 1<<12) ): # send idle
      await ClockCycles(dut.clk, 1)

    result = uart_sink.read_nowait(len(string))

    print(result)
    assert( result == string ) 
