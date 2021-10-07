export COCOTB_REDUCED_LOG_FMT=1

all: test_sudoku_puzzle test_sudoku_cell

test_sudoku_puzzle:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_puzzle -s dump -g2012 src/sudoku_puzzle.v src/sudoku_cell.v test/dump_sudoku_puzzle.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_puzzle vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_sudoku_puzzle_gl:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_puzzle -s dump -g2012 gl/sudoku_puzzle.lvs.powered.v test/dump_sudoku_puzzle.v -I $(PDK_ROOT)/sky130A
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_puzzle_gl vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp


test_sudoku_cell:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_cell -s dump -g2012 src/sudoku_cell.v test/dump_sudoku_cell.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_cell vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

show_synth_%: src/%.v
	yosys -p "read_verilog $<; proc; opt; show -colors 2 -width -signed"

show_%: %.vcd %.gtkw
	gtkwave $^ 

clean:
	rm -rf *.vcd sim_build test/__pycache__
