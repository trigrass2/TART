`timescale 1ns/100ps
/*
 * Module      : verilog/correlator_block.v
 * Copyright   : (C) Tim Molteno     2016
 *             : (C) Max Scheel      2016
 *             : (C) Patrick Suggate 2016
 * License     : LGPL3
 * 
 * Maintainer  : Patrick Suggate <patrick.suggate@gmail.com>
 * Stability   : Experimental
 * Portability : only tested with Icarus Verilog
 * 
 * Time-multiplexed block of correlator-blocks.
 * 
 * NOTE:
 *  + typically several of these would be attached to a common set of antenna
 *    and a system bus;
 *  + a bank-switch command causes accumulator values to be cleared upon first
 *    access after a switch, by giving the accumulator a zero input;
 *  + the bus clock can be much slower than the correlation clock, as multi-
 *    port SRAM's are used;
 *  + bus transactions read from the currently-innactive bank, to prevent
 *    possible metastability/corruption;
 *  + potentially uses quite a lot of the FPGA's distributed-RAM resources;
 * 
 * Changelog:
 *  + ??/06/2016  --  initial file;
 * 
 */

`include "tartcfg.v"

module correlator_block
  #( // Pairs of antennas to correlate, for each block.
     parameter PAIRS0 = 120'hb1a191817161b0a090807060,
     parameter PAIRS1 = 120'hb3a393837363b2a292827262,
     parameter PAIRS2 = 120'hb5a595857565b4a494847464,
     parameter PAIRS3 = 120'hb1a191817161b0a090807060, // TODO:
     parameter ACCUM = `ACCUM_BITS,
     parameter MSB   = ACCUM - 1,
`ifdef __USE_SDP_DSRAM
     parameter ABITS = 11,
`else
     parameter ABITS = 7,
`endif
     parameter ASB   = ABITS - 1,
     parameter WIDTH = ACCUM+ACCUM, // Combined Re & Im components
     parameter WSB   = WIDTH-1,
     parameter XBITS = WIDTH<<2, // Wide SRAM bit-width
     parameter XSB   = XBITS-1,
     parameter SSB   = WIDTH+WIDTH-1,
     parameter MRATE = 12,       // Time-multiplexing rate
     parameter MBITS = 4,
     parameter TSB   = MBITS - 1,
     parameter BADDR = `BLOCK_BITS, // Buffer address bit-width
     parameter BSB   = BADDR - 1,
     parameter VSIZE = 1 << (BADDR + MBITS),
     parameter DELAY = 3)
   (
    input              clk_x, // correlator clock
    input              rst,

    // Wishbone-like bus interface for reading visibilities.
    input              clk_i, // bus clock
    input              cyc_i,
    input              stb_i,
    input              we_i, // writes are ignored
    input              bst_i, // Bulk Sequential Transfer?
    output reg         ack_o = 0,
    input [ASB:0]      adr_i,
    input [MSB:0]      dat_i,
    output reg [MSB:0] dat_o,

    // Real and imaginary components from the antennas.
    input              sw, // switch banks
    input              en, // data is valid
    input [23:0]       re,
    input [23:0]       im,

    output reg         overflow_cos = 0,
    output reg         overflow_sin = 0
    );


   //-------------------------------------------------------------------------
   //  Visibilities buffer.
   //-------------------------------------------------------------------------
   reg [3:0]       block = 0;
   wire [XSB:0]    vis, dat;


   //-------------------------------------------------------------------------
   //  Wishbone-like bus interface.
   //-------------------------------------------------------------------------
   wire [3:0]      oc, os;
   reg             ack = 0;
   reg [2:0]       adr = 0;
   wire            vld;

   //  Acknowledge any request, even if ignored.
   always @(posedge clk_i)
     if (rst) {ack_o, ack} <= #DELAY 2'b00;
     else     {ack_o, ack} <= #DELAY {cyc_i && ack, cyc_i && stb_i};

   //  Put data onto the WB bus, in two steps.
   always @(posedge clk_i) begin
      if (cyc_i && stb_i) adr <= #DELAY adr_i[2:0];
      case (adr) // 8:1 MUX to select the desired word:
        0: dat_o <= #DELAY dat[ACCUM*1-1:ACCUM*0];
        1: dat_o <= #DELAY dat[ACCUM*2-1:ACCUM*1];
        2: dat_o <= #DELAY dat[ACCUM*3-1:ACCUM*2];
        3: dat_o <= #DELAY dat[ACCUM*4-1:ACCUM*3];
        4: dat_o <= #DELAY dat[ACCUM*5-1:ACCUM*4];
        5: dat_o <= #DELAY dat[ACCUM*6-1:ACCUM*5];
        6: dat_o <= #DELAY dat[ACCUM*7-1:ACCUM*6];
        7: dat_o <= #DELAY dat[ACCUM*8-1:ACCUM*7];
      endcase // case (adr_i[2:0])
   end


   //-------------------------------------------------------------------------
   //  Correlator memory pointers.
   //-------------------------------------------------------------------------
   reg [TSB:0]         x_rd_adr = 0, x_wt_adr = 0, x_wr_adr = 0;
   wire [TSB:0]        next_x_rd_adr = wrap_x_rd_adr ? 0 : x_rd_adr + 1 ;
   wire                wrap_x_rd_adr = x_rd_adr == MRATE - 1;
   wire                wrap_x_wr_adr = x_wr_adr == MRATE - 1;

   always @(posedge clk_x)
     go <= #DELAY en;

   //  Pipelined correlator requires cycles for:
   //    { read, MAC, write } .
   always @(posedge clk_x)
     if (rst) begin
        x_rd_adr <= #DELAY 0;
        x_wt_adr <= #DELAY 0;
        x_wr_adr <= #DELAY 0;
     end
     else begin
        x_rd_adr <= #DELAY en  ? next_x_rd_adr : x_rd_adr;
        x_wt_adr <= #DELAY go  ? x_rd_adr      : x_wt_adr;
        x_wr_adr <= #DELAY vld ? x_wt_adr      : x_wr_adr;
     end


   //-------------------------------------------------------------------------
   //  Banks are switched at the next address-wrap event.
   //-------------------------------------------------------------------------
   reg                 go = 0, swap = 0, clear = 1;
   wire                w_swp = wrap_x_rd_adr && (sw || swap);
   wire                w_inc = wrap_x_wr_adr && clear;
                
   always @(posedge clk_x)
     if (rst)
       swap  <= #DELAY 0;
     else if (w_swp) // swap banks
       swap  <= #DELAY 0;
     else if (sw && !swap) // swap banks @next wrap
       swap  <= #DELAY 1;

   //  Increment the block-counter two cycles later, so that the correct data
   //  is stored within the SRAM's.
   always @(posedge clk_x)
     if (rst)        block <= #DELAY 0;
     else if (w_inc) block <= #DELAY block + 1;
   
   //  Clear a bank when correlators are enabled, or during the first set of
   //  writes after a bank-switch.
   always @(posedge clk_x)
     if (rst || !en)
        clear <= #DELAY 1;
     else if (w_swp)
        clear <= #DELAY 1;
     else if (wrap_x_rd_adr && clear) // finished restarting counters
        clear <= #DELAY 0;


   //-------------------------------------------------------------------------
   //  Correlator instances.
   //-------------------------------------------------------------------------
   correlator_sdp
     #(  .ACCUM(ACCUM),
         .MBITS(MBITS),
         .PAIRS(PAIRS0),
         .DELAY(DELAY)
         ) CORRELATOR0
       ( .clk_x(clk_x),
         .rst(rst),

         .sw(clear),
         .en(en),
         .re(re),
         .im(im),
         .rd(x_rd_adr),
         .wr(x_wr_adr),

         .vld(vld),
         .vis(vis[WSB:0]),

         .overflow_cos(oc[0]),
         .overflow_sin(os[0])
         );

   correlator_sdp
     #(  .ACCUM(ACCUM),
         .MBITS(MBITS),
         .PAIRS(PAIRS1),
         .DELAY(DELAY)
         ) CORRELATOR1
       ( .clk_x(clk_x),
         .rst(rst),

         .sw(clear),
         .en(en),
         .re(re),
         .im(im),
         .rd(x_rd_adr),
         .wr(x_wr_adr),

         .vld(),
         .vis(vis[WIDTH+WSB:WIDTH]),

         .overflow_cos(oc[1]),
         .overflow_sin(os[1])
         );

   correlator_sdp
     #(  .ACCUM(ACCUM),
         .MBITS(MBITS),
         .PAIRS(PAIRS2),
         .DELAY(DELAY)
         ) CORRELATOR2
       ( .clk_x(clk_x),
         .rst(rst),

         .sw(clear),
         .en(en),
         .re(re),
         .im(im),
         .rd(x_rd_adr),
         .wr(x_wr_adr),

         .vld(),
         .vis(vis[WIDTH+WIDTH+WSB:WIDTH+WIDTH]),

         .overflow_cos(oc[2]),
         .overflow_sin(os[2])
         );

   correlator_sdp
     #(  .ACCUM(ACCUM),
         .MBITS(MBITS),
         .PAIRS(PAIRS3),
         .DELAY(DELAY)
         ) CORRELATOR3
       ( .clk_x(clk_x),
         .rst(rst),

         .sw(clear),
         .en(en),
         .re(re),
         .im(im),
         .rd(x_rd_adr),
         .wr(x_wr_adr),

         .vld(),
         .vis(vis[WIDTH+WIDTH+WIDTH+WSB:WIDTH+WIDTH+WIDTH]),

         .overflow_cos(oc[3]),
         .overflow_sin(os[3])
         );


   //-------------------------------------------------------------------------
   //  Explicit instantiation, because XST sometimes gets it wrong.
   //-------------------------------------------------------------------------
   RAMB8X32_SDP #(.DELAY(DELAY)) VISRAM [5:0]
     ( .WCLK(clk_i),
       .WE(vld),
       .WADDR({block, x_wr_adr}),
       .DI(vis),
       .RCLK(clk_i),
       .CE(1'b1),
       .RADDR(adr_i[ASB:3]),
       .DO(dat)
       );

   
endmodule // correlator_block
