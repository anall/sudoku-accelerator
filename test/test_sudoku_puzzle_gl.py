import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles
import random

async def reset(dut):
  dut.reset <= 1

  await ClockCycles(dut.clk, 5)
  dut.reset <= 0;

async def load_puzzle(dut,puzzle):
  assert(len(puzzle) == 81)

  assert(dut.busy == 0)
  values = list(map(lambda x: 0 if x == ' ' else int(x),puzzle))
  dut.we <= 0b111
  for row in range(9):
    val = 0
    for col in range(9):
      idx = row*9+col
      if ( values[idx] > 0 ):
        val = val | 1<<(values[idx]-1)<<(9*col)
    dut.address <= row
    dut.wdata <= val
    await ClockCycles(dut.clk, 1)

  dut.we <= 0
  await ClockCycles(dut.clk, 1)

async def read_puzzle(dut):
  puzzle = ''

  assert(dut.busy == 0)
  for row in range(9):
    dut.address <= row
    await ClockCycles(dut.clk, 1)

    val = dut.rdata.value.integer

    for col in range(9):
      dval = val & 0b111111111
      cur_number = next(filter(lambda v: val & 1<<v,range(9)),-1)+1
      if ( cur_number == 0 ):
        puzzle = puzzle + ' '
      else:
        puzzle = puzzle + str(cur_number)
      val = val >> 9

  await ClockCycles(dut.clk, 1)

  return puzzle

async def test_puzzle(dut,o_puzzle,s_puzzle,solvable):
  await load_puzzle(dut,o_puzzle)

  print(o_puzzle)
  assert( o_puzzle == await read_puzzle(dut) )

  dut.start_solve <= 1
  await ClockCycles(dut.clk, 1)
  dut.start_solve <= 0

  n = 0
  await ClockCycles(dut.clk, 1)
  while ( dut.busy == 1 and n < 1000 ):
    n = n + 1;
    await ClockCycles(dut.clk, 1)

  if ( dut.busy == 1 ):
    dut.abort <= 1
    await ClockCycles(dut.clk, 10)
    dut.abort <= 0

  if ( dut.busy == 1 ):
    print("solver locked up -- FAILED TO ABORT SOLVER! Cannot read out puzzle state")
    assert( dut.busy == 0 )
    await reset(dut)
  else:
    f_puzzle = await read_puzzle(dut)

    if ( n >= 1000 ):
      print("solver possibly locked up (hit max iteration limit), puzzle progress below")
    if ( dut.stuck == 1 and solvable ):
      print("solver exited stuck (failed to progress puzzle), puzzle progress below")
    if ( dut.stuck == 0 and not solvable ):
      print("solver somehow solved unsolvable puzzle, puzzle below")

    print(f_puzzle)
 
    assert( n < 1000 )
    if ( solvable ):
      assert( dut.solved == 1 and dut.stuck == 0 )
    else:
      assert( dut.solved == 0 and dut.stuck == 1 )
    assert( s_puzzle == f_puzzle )

@cocotb.test()
async def test_sudoku_puzzle(dut):
  dut.VPWR <= 1
  dut.VGND <= 0

  clock = Clock(dut.clk, 10, units="us")
  cocotb.fork(clock.start())

  z81 =  BinaryValue("z")
  dut.wdata <= 0
  dut.address <= 0
  dut.we <= 0
  dut.start_solve <= 0
  dut.abort <= 0
  await reset(dut)

  #           111222333444555666777888999111222333444555666777888999111222333444555666777888999
  await test_puzzle(dut,
    "5 1 6  24 6 4   73 7    1 5     72 88 239 5473  284 9   56  4   2    31 946  17  ",
    "581763924269415873473928165694157238812396547357284691135672489728549316946831752",1)

  await test_puzzle(dut,
    "4   2     35     778 39   45 4      6 2 8 7 3      5 91   48 353     28     3   6",
    "4   2   8 35     778 39   45 4     26 2 8 7 38     5 91   489353     281    3 476",0)
