////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	helloworld.v
//
// Project:	Verilog Tutorial Example file
//
// Purpose:	To create a *very* simple UART test program, which can be used
//		as the top level design file of any FPGA program.
//
//	With some modifications (discussed below), this RTL should be able to
//	run as a top-level testing file, requiring only the UART and clock pin
//	to work.
//
//	Be aware, there may be some remaining bugs that I have left behind
//	in this file.  You should check it with simulation and formal
//	verification before running it in the hardware.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Written and distributed by Gisselquist Technology, LLC
//
// This program is hereby granted to the public domain.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype none
//
module	helloworld(i_clk,
`ifdef	VERILATOR
		o_setup,
`endif
		o_uart_tx);
	parameter	CLOCK_RATE_HZ = 100_000_000; // 100MHz clock
	parameter	BAUD_RATE = 115_200; // 115.2 KBaud
	input		i_clk;
	output	wire	o_uart_tx;

	// Here we set the number of clocks per baud to something appropriate
	// to create a 115200 Baud UART system from a 100MHz clock.
	parameter	INITIAL_UART_SETUP = (CLOCK_RATE_HZ/BAUD_RATE);
`ifdef	VERILATOR
	// Let our Verilator .cpp file know what parameter was selected for
	// the baud rate.  This output word will be read by the Verilator
	// test bench, so it knows how to match the baud rate we are using.
	output	wire	[31:0]	o_setup;
	assign	o_setup = INITIAL_UART_SETUP;
`endif

	//
	// Restart the whole process once a second
	reg		tx_restart;
	reg	[27:0]	hz_counter;

	initial	hz_counter = 28'h16;
	always @(posedge i_clk)
	if (hz_counter == 0)
		hz_counter <= CLOCK_RATE_HZ - 1'b1;
	else
		hz_counter <= hz_counter - 1'b1;

	initial	tx_restart = 0;
	always @(posedge i_clk)
		tx_restart <= (hz_counter == 1);

	//
	// Transmit our message
	//
	wire		tx_busy;
	reg		tx_stb;
	reg	[3:0]	tx_index;
	reg	[7:0]	tx_data;

	initial	tx_index = 4'h0;
	always @(posedge i_clk)
	if ((tx_stb)&&(!tx_busy))
		tx_index <= tx_index + 1'b1;

	always @(posedge i_clk)
	case(tx_index)
	4'h0: tx_data <= "H";
	4'h1: tx_data <= "e";
	4'h2: tx_data <= "l";
	4'h3: tx_data <= "l";
	//
	4'h4: tx_data <= "o";
	4'h5: tx_data <= ",";
	4'h6: tx_data <= " ";
	4'h7: tx_data <= "W";
	//
	4'h8: tx_data <= "o";
	4'h9: tx_data <= "r";
	4'ha: tx_data <= "l";
	4'hb: tx_data <= "d";
	//
	4'hc: tx_data <= "!";
	4'hd: tx_data <= " ";
	4'he: tx_data <= "\n";
	4'hf: tx_data <= "\r";
	//
	endcase

	// tx_stb is a request to send a character.
	initial	tx_stb = 1'b0;
	always @(posedge i_clk)
	if (&tx_restart)
		tx_stb <= 1'b1;
	else if ((tx_stb)&&(!tx_busy)&&(tx_index==4'hf))
		tx_stb <= 1'b0;

	//
	// Instantiate a serial port module here
	//
	txuart #(INITIAL_UART_SETUP[23:0])
		transmitter(i_clk, tx_stb, tx_data, o_uart_tx, tx_busy);

`ifdef	FORMAL
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	always @(*)
	if ((tx_stb)&&(!tx_busy))
	begin
		case(tx_index)
		4'h0: assert(tx_data <= "H");
		4'h1: assert(tx_data <= "e");
		4'h2: assert(tx_data <= "l");
		4'h3: assert(tx_data <= "l");
		//
		4'h4: assert(tx_data <= "o");
		4'h5: assert(tx_data <= ",");
		4'h6: assert(tx_data <= " ");
		4'h7: assert(tx_data <= "W");
		//
		4'h8: assert(tx_data <= "o");
		4'h9: assert(tx_data <= "r");
		4'ha: assert(tx_data <= "l");
		4'hb: assert(tx_data <= "d");
		//
		4'hc: assert(tx_data <= "!");
		4'hd: assert(tx_data <= " ");
		4'he: assert(tx_data <= "\n");
		4'hf: assert(tx_data <= "\r");
		//
		endcase
	end

	always @(posedge i_clk)
	if ((f_past_valid)&&($changed(tx_index)))
		assert(($past(tx_stb))&&(!$past(tx_busy))
				&&(tx_index == $past(tx_index)+1));
	else if (f_past_valid)
		assert(($stable(tx_index))
				&&((!$past(tx_stb))||($past(tx_busy))));

	always @(posedge i_clk)
	if (tx_index != 4'h0)
		assert(tx_stb);

`endif
endmodule
