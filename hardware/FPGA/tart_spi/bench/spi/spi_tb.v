`timescale 1ns/1ps
module spi_tb;

   wire [7:0] master_data_received, slave_data_received;
   reg [7:0]  status;
   reg        clk = 0, rst = 0, cyc = 0, stb = 0, ack2 = 0;
   wire       ack, rdy, cyc2, stb2, we2;
   
   reg        sck = 0;
   wire       sck_en, ssel, mosi, miso;
   wire       sck_w = sck & sck_en;

   reg [7:0]  tx_ram [0:15];
   reg [3:0]  mcnt = 0, tx_cnt = 8, rx_cnt = 8;

   wire [7:0] master_data_to_send = tx_ram[mcnt];
   wire [7:0] slave_data_to_send  = tx_ram[tx_cnt];

   
   // Some free-running clocks.
   always #5  clk <= ~clk;
   always #20 sck <= ~sck;


   integer    i;
   initial begin : FILL_RAM
      for (i = 0; i < 16; i = i + 1)
        tx_ram[i] = $random;
   end

   initial begin : SPI_TB
      $dumpfile ("spi_tb.vcd");
      $dumpvars;

      status <= $random;
      #20 rst <= 1;
      #50 rst <= 0;
      
      #30;                      // Begin a SPI transfer.
      cyc <= 1;
      stb <= 1;
      #10 while (!ack) #10;
      mcnt <= mcnt + 1;
      #10 while (!ack) #10;
      mcnt <= mcnt + 1;
      #10 while (!ack) #10;
      mcnt <= mcnt + 1;
      stb <= 0;
      while (!rdy) #10;
      #10 while (!rdy) #10;
      #10 while (!rdy) #10;
      cyc <= 0;
      #20 while (!ssel) #20;

      #20;
      cyc <= 1;
      stb <= 1;
      #10 while (!ack) #10;
      mcnt <= mcnt + 1;
      stb <= 0;
      while (!rdy) #10;
      cyc <= 0;
      #20 while (!ssel) #20;

      #160 $finish;
   end

   initial begin : SPI_FAILED
      #4000 $display ("TIMEOUT!");
      $finish;
   end


   // Simulate a WB slave.
   wire #2 ack2_w = cyc2 && stb2 &&  we2;
   wire #2 rdy2_w = cyc2 && stb2 && !we2;
   always @(posedge clk)
     if (!cyc2)                 // Clear any (unused) prefetched data
       tx_cnt <= rx_cnt;
     else if (rdy2_w && !ack2)
       begin
          ack2   <= rdy2_w;
          tx_cnt <= tx_cnt + 1;
       end
     else if (ack2_w && !ack2)
       begin
          ack2   <= ack2_w;
          rx_cnt <= rx_cnt + 1;
          $display ("%10t: Slave data received: 0x%02x", $time, slave_data_received);
       end
     else
       ack2 <= 0;


   spi_master SPI_MASTER0
     ( .clk_i(clk),
       .rst_i(rst),
       .cyc_i(cyc),
       .stb_i(stb),
       .ack_o(ack),
       .rdy_o(rdy),
       .dat_i(master_data_to_send),
       .dat_o(master_data_received),
       
       .SCK(sck),
       .SCK_enable(sck_en),
       .SSEL(ssel),
       .MOSI(mosi),
       .MISO(miso)
       );

   spi_target SPI_TARGET0
//    spi_slave SPI_SLAVE0
     ( .clk_i(clk),
       .rst_i(rst),
       .cyc_o(cyc2),
       .stb_o(stb2),
       .we_o (we2),
       .ack_i(ack2),
       .dat_i(slave_data_to_send),
       .dat_o(slave_data_received),

//        .header_i(status),
       
       .SCK(sck_w),
       .SSEL(ssel),
       .MOSI(mosi),
       .MISO(miso)
       );
   
       
endmodule // spi_tb
