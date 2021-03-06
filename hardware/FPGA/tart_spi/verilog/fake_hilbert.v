`timescale 1ns/100ps
/*
 *
 * Approximate Hilbert transform, for a 1-bit signal.
 * 
 * NOTE:
 *  + for 4x oversampled signals, the 90 degree phase difference between
 *    samples is approximately equal to the complex component of the previous
 *    sample, and is very cheap to compute;
 * 
 * TODO:
 * 
 */

module fake_hilbert
  #( parameter WIDTH = 1,
     parameter DELAY = 3)
   (
    input                  clk,
    input                  rst,
    input                  en,
    input [WIDTH-1:0]      d,
    output reg             valid = 0,

    (* KEEP = "TRUE", IOB = "FALSE" *)
    output reg [WIDTH-1:0] re = 0,
    (* KEEP = "TRUE", IOB = "FALSE" *)
    output reg [WIDTH-1:0] im = 0
    );

   reg                     go = 0;

   always @(posedge clk)
     if (rst) {valid, go} <= #DELAY 0;
     else     {valid, go} <= #DELAY {go & en, en | go};

   always @(posedge clk)
     if (rst)     re <= #DELAY 0;
     else if (en) re <= #DELAY d;
     else         re <= #DELAY re;

   always @(posedge clk)
     if (rst)     im <= #DELAY 0;
     else if (go) im <= #DELAY re;
     else         im <= #DELAY im;

endmodule // fake_hilbert
