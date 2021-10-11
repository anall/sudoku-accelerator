export COCOTB_REDUCED_LOG_FMT=1

all: test_components test_wrapped_components
test_wrapped_components: test_sudoku_puzzle_wb_accel test_simpleuart_wb_accel

test_components: test_sudoku_puzzle test_sudoku_cell test_simpleuart test_simpleuart_wb test_sudoku_puzzle_wb

test_sudoku_puzzle:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_puzzle -s dump -g2012 src/sudoku_puzzle.v src/sudoku_cell.v test/dump_sudoku_puzzle.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_puzzle vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_sudoku_puzzle_gl:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_puzzle -s dump -g2012 gl/sudoku_puzzle.lvs.powered.v test/dump_sudoku_puzzle.v -I $(PDK_ROOT)/sky130A
	GATELEVEL=1 PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_puzzle vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_sudoku_puzzle_wb:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_puzzle_wb -s dump -g2012 src/sudoku_puzzle_wb.v src/sudoku_puzzle.v src/sudoku_cell.v test/dump_sudoku_puzzle_wb.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_puzzle_wb vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_sudoku_puzzle_wb_accel:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_accelerator -s dump -g2012 src/sudoku_accelerator.v src/simpleuart.v src/sudoku_puzzle_wb.v src/sudoku_puzzle.v src/sudoku_cell.v test/dump_sudoku_accelerator.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_puzzle_wb vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_simpleuart_wb_accel:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_accelerator -s dump -g2012 src/sudoku_accelerator.v src/simpleuart.v src/sudoku_puzzle_wb.v src/sudoku_puzzle.v src/sudoku_cell.v test/dump_sudoku_accelerator.v
	PYTHONOPTIMIZE=${NOASSERT} IN_ACCEL=1 MODULE=test.test_simpleuart_wb vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_sudoku_puzzle_wb_gl:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_puzzle_wb -s dump -g2012 gl/sudoku_puzzle_wb.lvs.powered.v test/dump_sudoku_puzzle_wb.v -I $(PDK_ROOT)/sky130A
	GATELEVEL=1 PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_puzzle_wb vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_sudoku_cell:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s sudoku_cell -s dump -g2012 src/sudoku_cell.v test/dump_sudoku_cell.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_sudoku_cell vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_simpleuart:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s simpleuart -s dump -g2012 src/simpleuart.v test/dump_simpleuart.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_simpleuart vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

test_simpleuart_wb:
	rm -rf sim_build/
	mkdir sim_build/
	iverilog -o sim_build/sim.vvp -s simpleuart_wb -s dump -g2012 src/simpleuart.v test/dump_simpleuart_wb.v
	PYTHONOPTIMIZE=${NOASSERT} MODULE=test.test_simpleuart_wb vvp -M $$(cocotb-config --prefix)/cocotb/libs -m libcocotbvpi_icarus sim_build/sim.vvp

show_synth_%: src/%.v
	yosys -p "read_verilog $<; proc; opt; show -colors 2 -width -signed"

show_%: vcd/%.vcd gtkw/%.gtkw
	gtkwave $^ 

clean:
	rm -rf *.vcd sim_build test/__pycache__
