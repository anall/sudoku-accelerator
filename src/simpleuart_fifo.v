`default_nettype none
`timescale 1ns/1ns
/*
 *  SPDX-FileCopyrightText: 2015 Clifford Wolf
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *  SPDX-License-Identifier: ISC
 */
// Modified 2021 Andrea Nall, added FIFO
module simpleuart_fifo_wb # (
    parameter BASE_ADR = 32'h 2000_0000,
    parameter CLK_DIV = 8'h00,
    parameter DATA = 8'h04,
    parameter CONFIG = 8'h08
) (
    input wb_clk_i,
    input wb_rst_i,

    input [31:0] wb_adr_i,      // (verify): input address was originaly 22 bits , why ? (max number of words ?)
    input [31:0] wb_dat_i,
    input [3:0]  wb_sel_i,
    input wb_we_i,
    input wb_cyc_i,
    input wb_stb_i,

    output wb_ack_o,
    output [31:0] wb_dat_o,

    output uart_enabled,
    output ser_tx,
    input  ser_rx,
    output interrupt

);
    wire [31:0] simpleuart_reg_div_do;
    wire [31:0] simpleuart_reg_dat_do;
    wire [31:0] simpleuart_reg_cfg_do;
    wire reg_dat_wait;

    wire resetn = ~wb_rst_i;
    wire valid = wb_stb_i && wb_cyc_i; 
    wire simpleuart_reg_div_sel = valid && (wb_adr_i == (BASE_ADR | CLK_DIV));
    wire simpleuart_reg_dat_sel = valid && (wb_adr_i == (BASE_ADR | DATA));
    wire simpleuart_reg_cfg_sel = valid && (wb_adr_i == (BASE_ADR | CONFIG));

    wire [3:0] reg_div_we = simpleuart_reg_div_sel ? (wb_sel_i & {4{wb_we_i}}): 4'b 0000; 
    wire reg_dat_we = simpleuart_reg_dat_sel ? (wb_sel_i[0] & wb_we_i): 1'b0;      // simpleuart_reg_dat_sel ? mem_wstrb[0] : 1'b 0
    wire reg_cfg_we = simpleuart_reg_cfg_sel ? (wb_sel_i[0] & wb_we_i): 1'b0; 

    wire [31:0] mem_wdata = wb_dat_i;
    wire reg_dat_re = simpleuart_reg_dat_sel && wb_stb_i && ~wb_we_i; // read_enable

    assign wb_dat_o =
      simpleuart_reg_div_sel ? simpleuart_reg_div_do:
      simpleuart_reg_cfg_sel ? simpleuart_reg_cfg_do:
          simpleuart_reg_dat_do;
    assign wb_ack_o = (simpleuart_reg_div_sel || simpleuart_reg_dat_sel
          || simpleuart_reg_cfg_sel) && (!reg_dat_wait);
    
    simpleuart_fifo simpleuart (
        .clk    (wb_clk_i),
        .resetn (resetn),

        .ser_tx      (ser_tx),
        .ser_rx      (ser_rx),
        .enabled     (uart_enabled),

        .reg_div_we  (reg_div_we), 
        .reg_div_di  (mem_wdata),
        .reg_div_do  (simpleuart_reg_div_do),

        .reg_cfg_we  (reg_cfg_we), 
        .reg_cfg_di  (mem_wdata),
        .reg_cfg_do  (simpleuart_reg_cfg_do),

        .reg_dat_we  (reg_dat_we),
        .reg_dat_re  (reg_dat_re),
        .reg_dat_di  (mem_wdata),
        .reg_dat_do  (simpleuart_reg_dat_do),
        .reg_dat_wait(reg_dat_wait),

        .interrupt(interrupt)
    );

endmodule

module simpleuart_fifo (
    input clk,
    input resetn,

    output enabled,
    output ser_tx,
    input  ser_rx,

    input   [3:0] reg_div_we,         
    input  [31:0] reg_div_di,         
    output [31:0] reg_div_do,         

    input         reg_cfg_we,         
    input  [31:0] reg_cfg_di,         
    output [31:0] reg_cfg_do,         

    input         reg_dat_we,         
    input         reg_dat_re,         
    input  [31:0] reg_dat_di,
    output [31:0] reg_dat_do,
    output        reg_dat_wait,
    output        interrupt
);
    reg [31:0]  cfg_divider;
    reg         enabled;

    reg [7:0]   recv_fifo [15:0];
    reg [3:0]   recv_fifo_r;
    reg [3:0]   recv_fifo_w;
    reg         recv_fifo_wrap;
    reg         recv_ie;

    reg         recv_valid;
    reg [3:0]   recv_state;
    reg [31:0]  recv_divcnt;
    reg [7:0]   recv_pattern;

    reg [7:0]   send_fifo [15:0];
    reg [3:0]   send_fifo_r;
    reg [3:0]   send_fifo_w;
    reg         send_empty_ie;

    reg [9:0]   send_pattern;
    reg [3:0]   send_bitcnt;
    reg [31:0]  send_divcnt;
    reg         send_dummy;

    wire send_fifo_full   = ((send_fifo_w+1)&15) == send_fifo_r;
    wire send_fifo_empty  = send_fifo_r == send_fifo_w;
    wire send_idle        = !(send_bitcnt || send_dummy) && send_fifo_empty; // && !send_fifo_empty,

    assign reg_div_do = cfg_divider;
    assign reg_cfg_do = {23'd0,
              send_idle,                  // 12
              send_fifo_full,             // 11
              send_fifo_empty,            // 10
              recv_fifo_wrap,             // 9
              recv_fifo_r != recv_fifo_w, // 8 (recv fifo not empty)
              5'd0,
              send_empty_ie,
              recv_ie,
              enabled};

    assign interrupt = (enabled &
      (recv_ie & recv_fifo_r != recv_fifo_w) || (send_empty_ie & send_fifo_empty));

    assign reg_dat_wait = reg_dat_we && send_fifo_full;
    assign reg_dat_do = (recv_fifo_r != recv_fifo_w) ? recv_fifo[recv_fifo_r] : ~0;

    always @(posedge clk) begin
        if (!resetn) begin
            cfg_divider <= 1;
	          enabled <= 1'b0;
            recv_ie <= 0;
            send_empty_ie <= 0;
        end else begin
            if (reg_div_we[0]) cfg_divider[ 7: 0] <= reg_div_di[ 7: 0];
            if (reg_div_we[1]) cfg_divider[15: 8] <= reg_div_di[15: 8];
            if (reg_div_we[2]) cfg_divider[23:16] <= reg_div_di[23:16];
            if (reg_div_we[3]) cfg_divider[31:24] <= reg_div_di[31:24];
            if (reg_cfg_we) begin
              enabled <= reg_cfg_di[0];
              recv_ie <= reg_cfg_di[1];
              send_empty_ie <= reg_cfg_di[2];
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            recv_state <= 0;
            recv_divcnt <= 0;
            recv_pattern <= 0;
            recv_valid <= 0;

            recv_fifo_r <= 0;
            recv_fifo_w <= 0;
            recv_fifo_wrap <= 0;
        end else begin
            recv_divcnt <= recv_divcnt + 1;
            if (reg_dat_re && recv_fifo_r != recv_fifo_w ) begin
                recv_fifo_r <= recv_fifo_r + 1;
                recv_fifo_wrap <= 0;            
            end else if ( recv_valid ) begin
                recv_valid <= 0;
                recv_fifo[recv_fifo_w] <= recv_pattern;
                recv_fifo_w = recv_fifo_w+1;
                if ( recv_fifo_w == recv_fifo_r ) begin
                    recv_fifo_r <= recv_fifo_r+1;
                    recv_fifo_wrap <= 1;
                end
            end

            case (recv_state)
                0: begin
                    if (!ser_rx && enabled)
                        recv_state <= 1;
                end
                1: begin
                    if (2*recv_divcnt > cfg_divider) begin
                        recv_state <= 2;
                        recv_divcnt <= 0;
                    end
                end
                10: begin
                    if (recv_divcnt > cfg_divider) begin
                      recv_valid <= 1;
                      recv_state <= 0;
                    end
                end
                default: begin
                    if (recv_divcnt > cfg_divider) begin
                        recv_pattern <= {ser_rx, recv_pattern[7:1]};
                        recv_state <= recv_state + 1;
                        recv_divcnt <= 0;
                    end
                end
            endcase
        end
    end

    assign ser_tx = send_pattern[0];

    always @(posedge clk) begin
        if (reg_div_we && enabled)
            send_dummy <= 1;
        send_divcnt <= send_divcnt + 1;
        if (!resetn) begin
            send_pattern <= ~0;
            send_bitcnt <= 0;
            send_divcnt <= 0;
            send_dummy <= 1;

            send_fifo_r <= 0;
            send_fifo_w <= 0;
        end else begin
            if ( !send_fifo_full && reg_dat_we ) begin
              send_fifo[send_fifo_w] <= reg_dat_di[7:0];
              send_fifo_w <= send_fifo_w + 1;
            end
            if (send_dummy && !send_bitcnt) begin
                send_pattern <= ~0;
                send_bitcnt <= 15;
                send_divcnt <= 0;
                send_dummy <= 0;
            end else if ( !send_fifo_empty && !send_bitcnt) begin
                send_pattern <= {1'b1, send_fifo[send_fifo_r], 1'b0};
                send_fifo_r <= send_fifo_r + 1;
                send_bitcnt <= 10;
                send_divcnt <= 0;
            end else if (send_divcnt > cfg_divider && send_bitcnt) begin
                send_pattern <= {1'b1, send_pattern[9:1]};
                send_bitcnt <= send_bitcnt - 1;
                send_divcnt <= 0;
            end
        end
    end
endmodule
