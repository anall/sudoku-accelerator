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
  dut.wb_rst_i <= 1

  await ClockCycles(dut.wb_clk_i, 5)
  dut.wb_rst_i <= 0;

def load_puzzle(wbm,pid,puzzle):
  base_address = 0x3000_1000 | (pid<<10) | (1<<9);

  assert(len(puzzle) == 81)

  values = list(map(lambda x: 0 if x == '.' else int(x),puzzle))
  operations = []
  for row in range(9):
    for sub in range(3):
      val = values[row*9+sub*3] | values[row*9+sub*3+1] << 8 | values[row*9+sub*3+2] << 16;

      operations.append(WBOp(base_address | row<<4 | sub<<2,val,0,0b1111));
  
  return wbm.send_cycle(operations)

def puzzle_cell(n):
  if ( n == 0 ):
    return '.'
  else:
    return chr(n + ord('0'))
  
async def read_puzzle(wbm,pid):
  base_address = 0x3000_1000 | (pid<<10) | (1<<9);
  operations = []
  for row in range(9):
    for sub in range(3):
      operations.append(WBOp(base_address | row<<4 | sub<<2,None,0,0b1111));
  values = await wbm.send_cycle(operations)

  puzzle = ''
  for v in values:
    dat = v.datrd;

    puzzle = puzzle + puzzle_cell( dat&0xF ) + puzzle_cell( (dat&0xF00)>>8 ) + puzzle_cell( (dat&0xF0000)>>16 )

  return puzzle
  

@cocotb.test()
async def test_sudoku_puzzle(dut):
  clock = None
  if environ.get("GATELEVEL"):
    dut.vccd1 <= 1
    dut.vssd1 <= 0

  clock = Clock(dut.wb_clk_i, 100, units="ns")
  cocotb.fork(clock.start())

  wbm = WishboneMaster(dut, "wb", dut.wb_clk_i,
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

  i_puzzle = "5.1.6..24.6.4...73.7....1.5.....72.88.239.5473..284.9...56..4...2....31.946..17..";
  await load_puzzle(wbm,0,i_puzzle)
  #await wbm.send_cycle([
  #  WBOp(0x3000_1000 | 0<<10 | 1<<9 | 0<<4 | 0<<2,5,0,0b1),
  #]);
  v_puzzle = "5.1.6..24.6.4...73.7....1.5.....72.88.239.5473..284.9...56..4...2....31.946..17..";
  o_puzzle = await read_puzzle(wbm,0)
  print(v_puzzle)
  print(o_puzzle)

  assert(o_puzzle == v_puzzle)

  await load_puzzle(wbm,1,v_puzzle)
  o_puzzle = await read_puzzle(wbm,1)
  print(o_puzzle)
  
#  await wbm.send_cycle([WBOp(0x3000_0000,1<<17,0,0b1111)]);
#  await wbm.send_cycle([WBOp(0x3000_0008,0b100)]);
#
#  while ( dut.interrupt == 0 ):
#    await ClockCycles(dut.wb_clk_i, 1)
#
#  assert ( (await wbm.send_cycle([WBOp(0x3000_0008)]))[0].datrd & 0b10000000000 == 0b10000000000 )
#  await wbm.send_cycle([WBOp(0x3000_0008,0b00)])
#  assert( (await wbm.send_cycle([WBOp(0x3000_0008)]))[0].datrd == 0 )

  c_puzzle = await read_puzzle(wbm,1)
  print(c_puzzle)

  assert(c_puzzle == v_puzzle)

  await wbm.send_cycle([WBOp(0x3000_0000,1|1<<8)]);
  await wbm.send_cycle([WBOp(0x3000_0008,0b11)]);

  while ( dut.interrupt == 0 ):
    await ClockCycles(dut.wb_clk_i, 1)
  
  while ( (await wbm.send_cycle([WBOp(0x3000_0008)]))[0].datrd & 0b1100000000 != 0b1100000000 ):
    pass

  await wbm.send_cycle([WBOp(0x3000_0008,0b00)])
  assert( (await wbm.send_cycle([WBOp(0x3000_0008)]))[0].datrd == 0 )

  s_puzzle0 = await read_puzzle(wbm,0)
  s_puzzle1 = await read_puzzle(wbm,1)
  print(s_puzzle0)
  print(s_puzzle1)

#  i_puzzle = "4...2.....35.....778.39...45.4......6.2.8.7.3......5.91...48.353.....28.....3...6";
#  await load_puzzle(wbm,1,i_puzzle)
#  
#
#  while ( (await wbm.send_cycle([WBOp(0x3000_0000,None,0,0b1111)]))[0].datrd & 1 == 1 ):
#    pass
#
#  s_puzzle1 = await read_puzzle(wbm,0)
#  print(s_puzzle1)
#
#  while ( (await wbm.send_cycle([WBOp(0x3000_0000,None,0,0b1111)]))[0].datrd & 1<<8 == 1<<8 ):
#    pass
#
#  s_puzzle2 = await read_puzzle(wbm,1)
#  print(s_puzzle2)
