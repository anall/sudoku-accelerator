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
from cocotbext.wishbone.driver import WishboneMaster
from cocotbext.wishbone.driver import WBOp
import random
from os import environ

async def reset(dut):
  dut.reset <= 1

  await ClockCycles(dut.clk, 5)
  dut.reset <= 0;

def load_puzzle(wbm,pid,puzzle):
  assert(len(puzzle) == 81)

  values = list(map(lambda x: 0 if x == '.' else int(x),puzzle))
  base_address = 0x3000_1000 | pid<<10 | 1<<9;
  operations = []
  for row in range(9):
    for sub in range(3):
      val = values[row*9+sub*3] | values[row*9+sub*3+1] << 8 | values[row*9+sub*3+2] << 16;

      operations.append(WBOp(base_address | row<<4 | sub << 2,val,0,0b1111));
  
  return wbm.send_cycle(operations)

def read_puzzle(wbm,pid):
  base_address = 0x3000_1000 | pid<<10 | 1<<9;
  operations = []
  for row in range(9):
    for sub in range(3):
      operations.append(WBOp(base_address | row<<4 | sub << 2,None,0,0b1111));
  return wbm.send_cycle(operations)

@cocotb.test()
async def test_sudoku_puzzle(dut):
  clock = None
  if environ.get("GATELEVEL"):
    dut.VPWR <= 1
    dut.VGND <= 0

  clock = Clock(dut.clk, 100, units="ns")
  cocotb.fork(clock.start())

  wbm = WishboneMaster(dut, "wb", dut.clk,
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

  await reset(dut)

  i_puzzle = "..1.6..24.6.4...73.7....1.5.....72.88.239.5473..284.9...56..4...2....31.946..17..";
  await load_puzzle(wbm,0,i_puzzle)
  await wbm.send_cycle([
    WBOp(0x3000_1000 | 0<<10 | 1<<9 | 0<<4 | 0<<2,5,0,0b1),
  ]);
  o_puzzle = await read_puzzle(wbm,0)
  
  await wbm.send_cycle([WBOp(0x3000_0000,1)]);

  i_puzzle = "4...2.....35.....778.39...45.4......6.2.8.7.3......5.91...48.353.....28.....3...6";
  await load_puzzle(wbm,1,i_puzzle)
  
  await wbm.send_cycle([WBOp(0x3000_0000,1<<8)]);

  while ( (await wbm.send_cycle([WBOp(0x3000_0000,None,0,0b1111)]))[0].datrd & 1 == 1 ):
    pass
  s_puzzle1 = await read_puzzle(wbm,0)
  while ( (await wbm.send_cycle([WBOp(0x3000_0000,None,0,0b1111)]))[0].datrd & 1<<8 == 1<<8 ):
    pass
  s_puzzle2 = await read_puzzle(wbm,1)
