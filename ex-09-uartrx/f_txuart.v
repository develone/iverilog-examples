////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	f_txuart.v
//
// Project:	Verilog Tutorial Example file
//
// Purpose:	This module should be similar, if not largely identical to the
//		txuart.v module you have been using in this tutorial.  The
//	difference between the two are two output ports:
//
//	- f_data
//		This port contains the data that the transmitter is currently
//		sending.  Once the receiver has finished receiving an item,
//		it should be able to compare the value it has received against
//		this one.  Indeed, it should be able to compare what it has
//		received to this value mid-transition.
//
//	- f_counter
//		This is a one-up counter from the beginning of transmission.
//		It is used to synchronize the formal proof of the receiver
//		with the internal state of the transmitter.
//
//	These two changes should make it possible to use this transmitter
//	as part of a formal property set within the receiver.
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
//
//
module f_txuart(i_clk, i_wr, i_data, o_uart_tx, o_busy, f_data, f_counter);
	parameter	[23:0]	CLOCKS_PER_BAUD = 24'd868;
	input	wire		i_clk;
	input	wire		i_wr;
	input	wire	[7:0]	i_data;
	// And the UART output line itself
	output	wire		o_uart_tx;
	// A line to tell others when we are ready to accept data.  If
	// (i_wr)&&(!o_busy) is ever true, then the core has accepted a byte
	// for transmission.
	output	reg		o_busy;
	//
	//
	output	reg	[7:0]		f_data;
	output	reg	[24+4-1:0]	f_counter;

	// Define several states
	localparam [3:0] START	= 4'h0,
		BIT_ZERO	= 4'h1,
		BIT_ONE		= 4'h2,
		BIT_TWO		= 4'h3,
		BIT_THREE	= 4'h4,
		BIT_FOUR	= 4'h5,
		BIT_FIVE	= 4'h6,
		BIT_SIX		= 4'h7,
		BIT_SEVEN	= 4'h8,
		LAST		= 4'h8,
		IDLE		= 4'hf;

	reg	[23:0]	counter;
	reg	[3:0]	state;
	reg	[8:0]	lcl_data;
	reg		baud_stb;

	// o_busy
	//
	// This is a register, designed to be true is we are ever busy above.
	// originally, this was going to be true if we were ever not in the
	// idle state.  The logic has since become more complex, hence we have
	// a register dedicated to this and just copy out that registers value.

	initial	o_busy = 1'b0;
	initial	state  = IDLE;
	always @(posedge i_clk)
	if ((i_wr)&&(!o_busy))
		// Immediately start us off with a start bit
		{ o_busy, state } <= { 1'b1, START };
	else if (baud_stb)
	begin
		if (state == IDLE) // Stay in IDLE
			{ o_busy, state } <= { 1'b0, IDLE };
		else if (state < LAST) begin
			o_busy <= 1'b1;
			state <= state + 1'b1;
		end else // Wait for IDLE
			{ o_busy, state } <= { 1'b1, IDLE };
	end



	// lcl_data
	//
	// This is our working copy of the i_data register which we use
	// when transmitting.  It is only of interest during transmit, and is
	// allowed to be whatever at any other time.  Hence, if o_busy isn't
	// true, we can always set it.  On the one clock where o_busy isn't
	// true and i_wr is, we set it and o_busy is true thereafter.
	// Then, on any baud_stb (i.e. change between baud intervals)
	// we simple logically shift the register right to grab the next bit.
	initial	lcl_data = 9'h1ff;
	always @(posedge i_clk)
	if ((i_wr)&&(!o_busy))
		lcl_data <= { i_data, 1'b0 };
	else if (baud_stb)
		lcl_data <= { 1'b1, lcl_data[8:1] };

	// o_uart_tx
	//
	// This is the final result/output desired of this core.  It's all
	// centered about o_uart_tx.  This is what finally needs to follow
	// the UART protocol.
	//
	assign	o_uart_tx = lcl_data[0];


	// All of the above logic is driven by the baud counter.  Bits must last
	// CLOCKS_PER_BAUD in length, and this baud counter is what we use to
	// make certain of that.
	//
	// The basic logic is this: at the beginning of a bit interval, start
	// the baud counter and set it to count CLOCKS_PER_BAUD.  When it gets
	// to zero, restart it.
	//
	// However, comparing a 28'bit number to zero can be rather complex--
	// especially if we wish to do anything else on that same clock.  For
	// that reason, we create "baud_stb".  baud_stb is
	// nothing more than a flag that is true anytime baud_counter is zero.
	// It's true when the logic (above) needs to step to the next bit.
	// Simple enough?
	//
	// I wish we could stop there, but there are some other (ugly)
	// conditions to deal with that offer exceptions to this basic logic.
	//
	// 1. When the user has commanded a BREAK across the line, we need to
	// wait several baud intervals following the break before we start
	// transmitting, to give any receiver a chance to recognize that we are
	// out of the break condition, and to know that the next bit will be
	// a stop bit.
	//
	// 2. A reset is similar to a break condition--on both we wait several
	// baud intervals before allowing a start bit.
	//
	// 3. In the idle state, we stop our counter--so that upon a request
	// to transmit when idle we can start transmitting immediately, rather
	// than waiting for the end of the next (fictitious and arbitrary) baud
	// interval.
	//
	// When (i_wr)&&(!o_busy)&&(state == IDLE) then we're not only in
	// the idle state, but we also just accepted a command to start writing
	// the next word.  At this point, the baud counter needs to be reset
	// to the number of CLOCKS_PER_BAUD, and baud_stb set to zero.
	//
	// The logic is a bit twisted here, in that it will only check for the
	// above condition when baud_stb is false--so as to make
	// certain the STOP bit is complete.
	initial	baud_stb = 1'b1;
	initial	counter = 0;
	always @(posedge i_clk)
	if ((i_wr)&&(!o_busy))
	begin
		counter  <= CLOCKS_PER_BAUD - 1'b1;
		baud_stb <= 1'b0;
	end else if (!baud_stb)
	begin
		baud_stb <= (counter == 24'h01);
		counter  <= counter - 1'b1;
	end else if (state != IDLE)
	begin
		counter <= CLOCKS_PER_BAUD - 24'h01;
		if (state == LAST)
			counter <= CLOCKS_PER_BAUD - 24'h02;
		baud_stb <= 1'b0;
	end

//
//
// FORMAL METHODS
//
//
//
`define	ASSUME	assume

	// Setup

	reg	f_past_valid;

	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	// Any outstanding request that was busy on the last cycle,
	// should remain busy on this cycle
	initial	`ASSUME(!i_wr);
	always @(posedge i_clk)
		if ((f_past_valid)&&($past(i_wr))&&($past(o_busy)))
		begin
			`ASSUME(i_wr   == $past(i_wr));
			`ASSUME(i_data == $past(i_data));
		end

	//////////////////////////////////
	//
	// The contract
	//
	//////////////////////////////////

	always @(posedge i_clk)
	if ((i_wr)&&(!o_busy))
		f_data <= i_data;

	always @(posedge i_clk)
	case(state)
	IDLE:		assert(o_uart_tx == 1'b1);
	START:		assert(o_uart_tx == 1'b0);
	BIT_ZERO:	assert(o_uart_tx == f_data[0]);
	BIT_ONE:	assert(o_uart_tx == f_data[1]);
	BIT_TWO:	assert(o_uart_tx == f_data[2]);
	BIT_THREE:	assert(o_uart_tx == f_data[3]);
	BIT_FOUR:	assert(o_uart_tx == f_data[4]);
	BIT_FIVE:	assert(o_uart_tx == f_data[5]);
	BIT_SIX:	assert(o_uart_tx == f_data[6]);
	BIT_SEVEN:	assert(o_uart_tx == f_data[7]);
	default: assert(0);
	endcase

	//////////////////////////////////
	//
	// Internal state checks
	//
	//////////////////////////////////


	//
	// Check the baud counter
	//

	// The baud_stb needs to be identical to our counter being zero
	always @(posedge i_clk)
		assert(baud_stb == (counter == 0));


	always @(posedge i_clk)
	if ((f_past_valid)&&($past(counter != 0)))
		assert(counter == $past(counter - 1'b1));

	always @(posedge i_clk)
		assert(counter < CLOCKS_PER_BAUD);

	always @(posedge i_clk)
	if (!baud_stb)
		assert(o_busy);

	always @(posedge i_clk)
	if (state != IDLE)
		assert(o_busy);

	always @(posedge i_clk)
	case(state)
	IDLE:		assert(lcl_data == 9'h1ff);
	START:		assert(lcl_data == { f_data[7:0], 1'b0 });
	BIT_ZERO:	assert(lcl_data == { 1'b1, f_data[7:0]});
	BIT_ONE:	assert(lcl_data == { 2'h3, f_data[7:1]});
	BIT_TWO:	assert(lcl_data == { 3'h7, f_data[7:2]});
	BIT_THREE:	assert(lcl_data == { 4'hf, f_data[7:3]});
	BIT_FOUR:	assert(lcl_data == { 5'h1f, f_data[7:4]});
	BIT_FIVE:	assert(lcl_data == { 6'h3f, f_data[7:5]});
	BIT_SIX:	assert(lcl_data == { 7'h7f, f_data[7:6]});
	BIT_SEVEN:	assert(lcl_data == { 8'hff, f_data[7:7]});
	default: assert(0);
	endcase

	initial	f_counter = 0;
	always @(posedge i_clk)
	if (!o_busy)
		f_counter  <= 0;
	else
		f_counter <= f_counter + 1;

	always @(*)
	case(state)
	START:		assert(f_counter ==   CLOCKS_PER_BAUD-1-counter);
	BIT_ZERO:	assert(f_counter == 2*CLOCKS_PER_BAUD-1-counter);
	BIT_ONE:	assert(f_counter == 3*CLOCKS_PER_BAUD-1-counter);
	BIT_TWO:	assert(f_counter == 4*CLOCKS_PER_BAUD-1-counter);
	BIT_THREE:	assert(f_counter == 5*CLOCKS_PER_BAUD-1-counter);
	BIT_FOUR:	assert(f_counter == 6*CLOCKS_PER_BAUD-1-counter);
	BIT_FIVE:	assert(f_counter == 7*CLOCKS_PER_BAUD-1-counter);
	BIT_SIX:	assert(f_counter == 8*CLOCKS_PER_BAUD-1-counter);
	BIT_SEVEN:	assert(f_counter == 9*CLOCKS_PER_BAUD-1-counter);
	IDLE:		assert((f_counter== 0)||(!o_busy)
				||(f_counter == 10*CLOCKS_PER_BAUD-2-counter));
	endcase

	always @(*)
		assert(f_counter < 10*CLOCKS_PER_BAUD);

endmodule

