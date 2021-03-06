/***************************************************************************
 *                                                                         *
 *   sfifo32.v - A synchronous First-In/First-Out circular buffer, n-bits  *
 *     wide with 32 entries.                                               *
 *                                                                         *
 *   Copyright (C) 2007 by Patrick Suggate                                 *
 *   patrick@physics.otago.ac.nz                                           *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

// TODO: Tweak this to easily run at 200 MHz.
`timescale 1ns/100ps
module sfifo32 (
		clock_i,
		reset_i,
		
		read_i,		// Read so advance to next item
		write_i,	// Write input data into FIFO
		data_i,
		data_o,
		
		empty_no,
		full_o
	);
	
	//	Default width of 16-bits, but is user specifiable.
	parameter	WIDTH	= 8'd16;
	
	input	clock_i;
	input	reset_i;
	
	input	read_i;
	input	write_i;
	input	[WIDTH - 1:0]	data_i;
	output	[WIDTH - 1:0]	data_o;
	
	output	empty_no;
	output	full_o;
	// output	almost_empty_o;	// TODO
	
	
	// Pointers for the FIFO.
	// Using 5-bit points enables full/empty conditions to be checked
	// easily.
	reg	[5:0]	f_start	= 5'h0;
	reg	[5:0]	f_end	= 5'h0;
	
	wire	ptrs_equal;
	
	// synthesis attribute ram_style of mem is distributed ;
	reg    [WIDTH - 1:0]  mem[0:31]; // pragma attribute mem ram_block FALSE ;
	
	
	// Status signals.
	// TODO: These have long combinational logic path delays. They need
	// to be shorter, which means registered?
	assign	ptrs_equal	= (f_start [4:0] == f_end [4:0]);
	assign	empty_no	= !((f_start [5] == f_end [5]) && ptrs_equal);
	assign	full_o		= ((f_start [5] != f_end [5]) && ptrs_equal);
	
	assign data_o		= mem [f_start [4:0]];
	
	
	// Dequeue data from the FIFO.
	always @(posedge clock_i)
	begin
		if (reset_i)
			f_start	<= 0;
		else
		begin
			if (read_i && empty_no)
				f_start	<= f_start + 1;
			else
				f_start	<= f_start;
		end
	end
	
	
	// Add data to the FIFO.
	always @(posedge clock_i)
	begin
		if (reset_i)
			f_end	<= 0;
		else
		begin
			if (write_i && !full_o)
				f_end	<= f_end + 1;
			else
				f_end	<= f_end;
		end
	end
	
	
	always @ (posedge clock_i)
	begin
		if (write_i && !full_o)
		begin
			mem [f_end [4:0]]  <= data_i;
		end
	end
	
	
	
`ifdef __icarus
	//-----------------------------------------------------------------------
	//  Simulation only:
	//  Zero the SRAM for simulation as this is the default state for
	//  Xilinx.
	initial begin : Init
		init_mem (0);
	end	// Init
	
	
	task init_mem;
		input	val;
		integer	val, n;
	begin : Init_Mem
		for (n = 0; n < 32; n = n + 1)
			mem[n]	= val;
	end	// Init_Mem
	endtask	// init_mem
`endif
	
	
endmodule	// fifo32s
