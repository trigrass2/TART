`timescale 1ns/1ps
/*
 * Captures data by sampling at a higher (synchronous) clock-rate, and
 * presenting the captured data halfway through each period.
 * 
 * NOTE:
 *  + output is "sample-and-hold" and valid once `ready` asserts;
 * 
 */

module signal_capture
  (
   input      clk,
   input      rst,
   input      ce,

   input      d,
   output reg q,
   output reg ready = 0,
   output reg locked = 0,
   output reg invalid = 0
   );

   // Supersample at the given rate.
   parameter CLOCK_RATE = 12;
   parameter BITS_COUNT = 4;
   parameter HALF_COUNT = (CLOCK_RATE-1) >> 1;

   reg [BITS_COUNT-1:0] count = 0;

   //-------------------------------------------------------------------------
   //  Capture within an IOB's register, and use two samples for edge
   //  detection.
   //-------------------------------------------------------------------------
   (* IOB = "TRUE" *)
   reg                  d_iob;
   reg                  d_reg;
   wire                 edge_found = d_iob ^ d_reg;

   always @(posedge clk)
     if (ce) begin
        d_iob <= d;
        d_reg <= d_iob;
     end

   //-------------------------------------------------------------------------
   //  Count the number of cycles between edges.
   //-------------------------------------------------------------------------
   wire count_wrap = count == CLOCK_RATE-1;

   always @(posedge clk)
     if (rst)
       count <= 0;
     else if (ce) begin
        if (edge_found || count_wrap)
          count <= 0;
        else
          count <= count + 1;
     end

   //-------------------------------------------------------------------------
   //  The signal is considered locked after four clean transitions.
   //-------------------------------------------------------------------------
   reg [1:0] locked_count = 0;
   reg       found = 0;
   wire      valid_count = count > CLOCK_RATE-3 || !found && count < 2;

   always @(posedge clk)
     if (rst) begin
        locked       <= 0;
        locked_count <= 0;
        invalid      <= 0;
     end
     else if (ce && edge_found && valid_count) begin
        locked       <= locked_count == 3;
        locked_count <= locked_count  < 3 ? locked_count + 1 : locked_count ;
        invalid      <= invalid;
     end
     else if (ce && edge_found) begin // Edge too far from acceptable.
        locked       <= 0;
        locked_count <= 0;
        invalid      <= invalid || locked;
     end

   // Track whether an edge was found in the preceding aquisition period.
   always @(posedge clk)
     if (rst)
       found <= 0;
     else if (ce && locked && (edge_found || count_wrap))
       found <= edge_found;
     else
       found <= found;

   //-------------------------------------------------------------------------
   //  Output the captured data-samples.
   //-------------------------------------------------------------------------
   wire ready_w = ce && locked && count == HALF_COUNT; // && !edge_found;
   always @(posedge clk) begin
      ready <= ready_w;
      q <= ready_w ? d_iob : q ;
   end


endmodule // sigcap
