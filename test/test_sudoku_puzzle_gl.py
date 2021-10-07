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

  values = list(map(lambda x: 0 if x == ' ' else int(x),puzzle))
  dut.we <= 0b111
  for row in range(9):
    val = 0
    for col in range(9):
      idx = row*9+col
      if ( values[idx] > 0 ):
        val = val | 1<<(values[idx]-1)<<(9*col)
    dut.address <= row
    dut.data <= val
    await ClockCycles(dut.clk, 1)

  dut.we <= 0
  dut.data <= BinaryValue("z")
  await ClockCycles(dut.clk, 1)

async def read_puzzle(dut):
  puzzle = ''

  dut.data <= BinaryValue("z")
  dut.oe <= 1
  for row in range(9):
    dut.address <= row
    await ClockCycles(dut.clk, 1)

    val = dut.data.value.integer

    for col in range(9):
      dval = val & 0b111111111
      cur_number = next(filter(lambda v: val & 1<<v,range(9)),-1)+1
      if ( cur_number == 0 ):
        puzzle = puzzle + ' '
      else:
        puzzle = puzzle + str(cur_number)
      val = val >> 9

  dut.oe <= 0
  await ClockCycles(dut.clk, 1)

  return puzzle

@cocotb.test()
async def test_sudoku_puzzle(dut):
  dut.VPWR <= 1
  dut.VGND <= 0

  clock = Clock(dut.clk, 30, units="ns")
  cocotb.fork(clock.start())

  z81 =  BinaryValue("z")
  dut.data <= z81
  dut.address <= 0
  dut.oe <= 0
  dut.we <= 0
  dut.start_solve <= 0
  dut.abort <= 0
  await reset(dut)

  #           111222333444555666777888999111222333444555666777888999111222333444555666777888999
  o_puzzle = "5 1 6  24 6 4   73 7    1 5     72 88 239 5473  284 9   56  4   2    31 946  17  "
  s_puzzle = "581763924269415873473928165694157238812396547357284691135672489728549316946831752"
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
  else:
    f_puzzle = await read_puzzle(dut)

    if ( n >= 1000 ):
      print("solver possibly locked up (hit max iteration limit), puzzle progress below")
    if ( dut.stuck == 1 ):
      print("solver exited stuck (failed to progress puzzle), puzzle progress below")

    print(f_puzzle)
  
    assert( n < 1000 and dut.solved == 1 and dut.stuck == 0 )
    assert( s_puzzle == f_puzzle )
