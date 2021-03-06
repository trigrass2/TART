`timescale 1ns/100ps
/*
 *
 * Performs a "complex correlation step."
 * 
 * NOTE:
 *  + not a normal correlation, but computes real sine and cosine components;
 *  + uses a DSP48E1 for the accumulators, and the lower half of the 48-bit
 *  + adder is used for the `cos` component, and the upper for the `sin`;
 * 
 * TODO:
 * 
 */

module correlate_cos_sin_DSP
  #( parameter ACCUM = 24,      // 24-bit is the maximum for this module
     parameter MSB   = ACCUM-1,
     parameter XSB   = ACCUM+MSB,
     parameter DELAY = 3)
   (
    input          clk,
    input          rst,
    input          clr,
    input          en,
    input          vld,

    input          ar,
    // input                  ai,
    input          br,
    input          bi,

    input [MSB:0]  dcos,
    input [MSB:0]  dsin,

    output reg     oc = 0, // cosine overflow
    output         os, // sine overflow
    output [MSB:0] qcos,
    output [MSB:0] qsin
    );

   //  Operate the DSP48A1 as a 48-bit adder only.
   //  TODO: For the Z-MUX, sometimes use the `ZERO` setting?
   wire [7:0] opmode = 8'b00001111;

   wire [17:0] d = {6'b0, dsin[23:12]};
   wire [17:0] a = {dsin[11:0], dcos[23:18]};
   wire [17:0] b = dcos[17:0];

   wire [XSB:0] c = {{MSB{1'b0}}, ar == bi, {MSB{1'b0}}, ar == br};


   //-------------------------------------------------------------------------
   //  Xilinx Spartan 6 DSP48A1 primitive.
   //-------------------------------------------------------------------------
   DSP48A1
     #(  .OPMODEREG(0),
         .CARRYINREG(0), .CARRYOUTREG(1),
         .A0REG(1), .A1REG(0),
         .B0REG(1), .B1REG(0),
         .CREG (1),
         .DREG (1),
         .MREG (0),
         .PREG (1)
       ) DSP_COS_SIN0
       ( .CLK(clk),
         .RSTOPMODE(1'b0),
         .RSTCARRYIN(1'b0),
         .RSTM(1'b0),

         .CECARRYIN(vld),
         .CEOPMODE(1'b0),
         .CEM(1'b0),
         .CARRYIN(1'b0),
         .PCIN(48'b0),

         .OPMODE(opmode),

         // inputs & input registers:
         .RSTA(clr),              // first 48-bit input
         .CEA(en),
         .A(a),
         .RSTB(clr),
         .CEB(en),
         .B(b),
         .RSTD(clr),
         .CED(en),
         .D(d),

         .RSTC(1'b0),              // second 48-bit input
         .CEC(en),
         .C(c),

         .CARRYOUTF(os),          // sine overflow
         .RSTP(rst),              // output register
         .CEP(vld),
         .P({qsin, qcos})
         );


endmodule // correlate_cos_sin_DSP
