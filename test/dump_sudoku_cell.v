module dump();
    initial begin
        $dumpfile ("sudoku_cell.vcd");
        $dumpvars (0, sudoku_cell);
        #1;
    end
endmodule

