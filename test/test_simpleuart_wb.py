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
from cocotbext.wishbone.driver import WishboneMaster
from cocotbext.wishbone.driver import WBOp
from os import environ
import random

async def reset(dut):
    dut.wb_rst_i <= 1

    await ClockCycles(dut.wb_clk_i, 5)
    dut.wb_rst_i <= 0

@cocotb.test()
async def test_writeread(dut): # doing both in the same out of laziness
    clock_freq = 10_000_000;
    baud = 115200;
    if environ.get("IN_ACCEL"):
      base_addr = 0x3080_0000;
    else:
      base_addr = 0x2000_0000;

    clock = Clock(dut.wb_clk_i, 100, units="ns")
    cocotb.fork(clock.start())

    uart_source = UartSource(dut.ser_rx, baud=baud, bits=8)
    uart_sink   = UartSink(dut.ser_tx, baud=baud, bits=8)

    wbs = WishboneMaster(dut, "wb", dut.wb_clk_i,
      width=32,   # size of data bus
      timeout=10, # in clock cycle number
      signals_dict={
        "cyc":  "cyc_i",
        "stb":  "stb_i",
        "sel":  "sel_i",
        "we":   "we_i",
        "adr":  "adr_i",
        "datwr":"dat_i",
        "datrd":"dat_o",
        "ack":  "ack_o" })

    dut.ser_rx <= 0
    await reset(dut)

    await wbs.send_cycle([
      WBOp(base_addr|0,int(clock_freq/baud)),
      WBOp(base_addr|8,0b11)])

    string = b'sphinx'
    await uart_source.write(string)

    result = b''
    while ( len(result) < 2 ):
      while ( dut.interrupt == 0 ):
        await ClockCycles(dut.wb_clk_i, 1)
      wb = (await wbs.send_cycle([WBOp(base_addr|4)]))[0]
      await ClockCycles(dut.wb_clk_i, 2)
      assert( dut.interrupt == 0 )
      assert( wb.datrd != 0xffffffff );
      result = result + bytes(chr(wb.datrd&0xff),'ascii')
      
    await uart_source.wait()  
    
    wbc = (await wbs.send_cycle([WBOp(base_addr|4,idle=1),WBOp(base_addr|4,idle=4),WBOp(base_addr|4,idle=1),WBOp(base_addr|4,idle=1)]))
    for wb in wbc:
      assert( wb.datrd != 0xffffffff );
      result = result + bytes(chr(wb.datrd&0xff),'ascii')

    print(result)
    assert(result == string)

    await wbs.send_cycle([
      WBOp(base_addr|0,int(clock_freq/baud)),
      WBOp(base_addr|8,0b101)])

    while ( dut.interrupt == 0 ):
      await ClockCycles(dut.wb_clk_i, 1)

    string = b'sphinx of black quartz'
    await wbs.send_cycle([
      WBOp(base_addr|4,ch,idle=1) for ch in string
    ])
    print('waiting for interrupt');
    while ( dut.interrupt == 0 ): # wait for interrupt
      await ClockCycles(dut.wb_clk_i, 1)
    assert( (await wbs.send_cycle([WBOp(base_addr|8)]))[0].datrd & 1<<10 ); # make sure this is fifo empty
    await wbs.send_cycle([WBOp(base_addr|8,0b001)]) # disable interrupt
    assert( dut.interrupt == 0 ) # and verify
    print("waiting for idle uart") 
    while ( not (await wbs.send_cycle([WBOp(base_addr|8)]))[0].datrd & 1<<12 ):
      pass

    result = await uart_sink.read(len(string))

    print(result)
    assert( string == result )
