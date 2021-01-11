////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxuart.v
//
// Project:	Verilog Tutorial Example file
//
// Purpose:	Receives a character from a UART (serial port) wire.  Key
//		features of this core include:
//
//	- The baud rate is constant, and set by the CLOCKS_PER_BAUD parameter.
//		To be successful, one baud interval must be (approximately)
//		equal to CLOCKS_PER_BAUD / CLOCK_RATE_HZ seconds long.
//
//	- The protocol used is the basic 8N1: 8 data bits, 1 stop bit, and no
//		parity.
//
//	- This core has no reset
//	- This core has no error detection for frame errors
//	- This core cannot detect, report, or even recover from, a break
//		condition on the line.  A break condition is defined as a
//		period of time where the i_uart_rx line is held low for longer
//		than one data byte (10 baud intervals)
//
//	- There's no clock rate detection in this core
//
//	Perhaps one of the nicer features of this core is that it (can be)
//	formally verified.  It depends upon a separate (formally verified)
//	transmit core for this purpose.
//
//	As with the other cores within this tutorial, there may (or may not) be
//	bugs within this design for you to find.
//
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
`default_nettype	none
//
module rxuart(i_clk, i_uart_rx, o_wr, o_data
`ifdef	VERILATOR
		, o_setup
`endif
	);
`ifdef	VERILATOR
	parameter  [15:0]	CLOCKS_PER_BAUD = 25;
`else
	parameter  [15:0]	CLOCKS_PER_BAUD = 868;
`endif
	//
	localparam	[3:0]	IDLE      = 4'h0;
	localparam	[3:0]	BIT_ZERO  = 4'h1;
	// localparam	[3:0]	BIT_ONE   = 4'h2;
	// localparam	[3:0]	BIT_TWO   = 4'h3;
	// localparam	[3:0]	BIT_THREE = 4'h4;
	// localparam	[3:0]	BIT_FOUR  = 4'h5;
	// localparam	[3:0]	BIT_FIVE  = 4'h6;
	// localparam	[3:0]	BIT_SIX   = 4'h7;
	// localparam	[3:0]	BIT_SEVEN = 4'h8;
	localparam	[3:0]	STOP_BIT  = 4'h9;
	//
	input	wire		i_clk;
	input	wire		i_uart_rx;
	output	reg		o_wr;
	output	reg	[7:0]	o_data;
`ifdef	VERILATOR
	output	wire	[15:0]	o_setup;

	assign	o_setup = CLOCKS_PER_BAUD;
`endif

	reg	[3:0]		state;
	reg	[15:0]		baud_counter;
	reg			zero_baud_counter;

	// 2FF Synchronizer
	//
	reg		ck_uart;
	reg		q_uart;
	initial	{ ck_uart, q_uart } = -1;
	always @(posedge i_clk)
		{ ck_uart, q_uart } <= { q_uart, i_uart_rx };

	initial	state = IDLE;
	initial	baud_counter = 0;
	always @(posedge i_clk)
	if (state == IDLE)
	begin
		state <= IDLE;
		baud_counter <= 0;
		if (!ck_uart)
		begin
			state <= BIT_ZERO;
			baud_counter <= CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2-1'b1;
		end
	end else if (zero_baud_counter)
	begin
		state <= state + 1;
		baud_counter <= CLOCKS_PER_BAUD-1'b1;
		if (state == STOP_BIT)
		begin
			state <= IDLE;
			baud_counter <= 0;
		end
	end else
		baud_counter <= baud_counter - 1'b1;

	always @(*)
		zero_baud_counter = (baud_counter == 0);

	always @(posedge i_clk)
	if ((zero_baud_counter)&&(state != STOP_BIT))
		o_data <= { ck_uart, o_data[7:1] };

	initial	o_wr = 1'b0;
	always @(posedge i_clk)
		o_wr <= ((zero_baud_counter)&&(state == STOP_BIT));

`ifdef	FORMAL
	////////////////////////////////////////////////////////////////////////
	//
	// Assume a transmitter
	//
	////////////////////////////////////////////////////////////////////////
	(* anyseq *)	reg		f_tx_iwr;
	(* anyseq *)	reg	[7:0]	f_tx_idata;
			wire		f_tx_uart, f_tx_busy;
			wire	[7:0]	f_txdata;
			wire   [28-1:0] f_tx_counter;

	f_txuart #(CLOCKS_PER_BAUD)
		tx(i_clk, f_tx_iwr, f_tx_idata, f_tx_uart, f_tx_busy,
			f_txdata, f_tx_counter);

	always @(*)
		assume(i_uart_rx == f_tx_uart);

	////////////////////////////////////////////////////////////////////////
	//
	// Receiver checks!
	//
	////////////////////////////////////////////////////////////////////////
	//
	//

	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	////////////////////////////////////////////////////////////////////////
	//
	// Contract
	//
	////////////////////////////////////////////////////////////////////////
	always @(*)
	if (o_wr)
		assert(o_data == f_txdata);

	always @(*)
		assert(o_wr == (f_tx_counter == 9 * CLOCKS_PER_BAUD + CLOCKS_PER_BAUD / 2 + 3));
	always @(*)
	if (state != IDLE)
		assert(f_tx_busy);

	////////////////////////////////////////////////////////////////////////
	//
	// Synchronize to the transmitter
	//
	////////////////////////////////////////////////////////////////////////
	always @(*)
	case(state)
	4'h0: begin // Idle state
		if (f_tx_uart)
			assert((f_tx_counter == 0)
			||f_tx_counter > CLOCKS_PER_BAUD * 9 + CLOCKS_PER_BAUD/2);
		else // if (!f_tx_uart)
			assert(f_tx_counter < 3);
		end
	4'h1: begin
		// Start state
		assert(CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		end
	4'h2:	begin
		assert(2*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7] == f_txdata[0]);
		end
	4'h3:	begin
		assert(3*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7:6] == f_txdata[1:0]);
		end
	4'h4:	begin
		assert(4*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7:5] == f_txdata[2:0]);
		end
	4'h5:	begin
		assert(5*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7:4] == f_txdata[3:0]);
		end
	4'h6:	begin
		assert(6*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7:3] == f_txdata[4:0]);
		end
	4'h7:	begin
		assert(7*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7:2] == f_txdata[5:0]);
		end
	4'h8:	begin
		assert(8*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7:1] == f_txdata[6:0]);
		end
	4'h9:	begin
		assert(9*CLOCKS_PER_BAUD+CLOCKS_PER_BAUD/2 - baud_counter == f_tx_counter-2);
		assert(o_data[7:0] == f_txdata[7:0]);
		end
	endcase

	always @(*)
	begin
	assert(state <= STOP_BIT);
	if (state == IDLE)
		assert(zero_baud_counter);
	end

	always @(*)
	if (o_wr)
		assert((state == IDLE)&&(zero_baud_counter));

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(state != STOP_BIT)))
		assert(!o_wr);

	////////////////////////////////////////////////////////////////////////
	//
	// Cover
	//
	////////////////////////////////////////////////////////////////////////
	always @(posedge i_clk)
	if (f_past_valid)
		cover($past(o_wr));

	always @(posedge i_clk)
	begin
		cover((o_wr)&&(o_data == 8'hff));
		cover((o_wr)&&(o_data == 8'h00));
		cover((o_wr)&&(o_data == 8'h55));
		cover((o_wr)&&(o_data == 8'h33));
		cover((o_wr)&&(o_data == 8'h11));
		cover((o_wr)&&(o_data == 8'hf0));
		cover((o_wr)&&(o_data == 8'hcc));
	end

	reg	f_first_hit;

	initial	f_first_hit = 1'b0;
	always @(posedge i_clk)
	if ((o_wr)&&(o_data == 8'hf9))
		f_first_hit <= 1'b1;

	always @(posedge i_clk)
		cover((f_first_hit)&&(o_wr)&&(o_data == 8'hf9));

`endif // FORMAL
endmodule
