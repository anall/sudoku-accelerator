module dump();
    initial begin
        $dumpfile ("sudoku_puzzle.vcd");
        $dumpvars (0, sudoku_puzzle);
        #1;
    end
endmodule

