////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	echotest.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	To test that the txuart and rxuart modules work properly, by
//		echoing the input directly to the output.
//
//	This module may be run as either a DUMBECHO, simply forwarding the input
//	wire to the output with a touch of clock in between, or it can run as
//	a smarter echo routine that decodes text before returning it.  The
//	difference depends upon whether or not OPT_DUMBECHO is defined, as 
//	discussed below.
//
//	With some modifications (discussed below), this RTL should be able to
//	run as a top-level testing file, requiring only the transmit and receive
//	UART pins and the clock to work.
//
//	DON'T FORGET TO TURN OFF HARDWARE FLOW CONTROL!  ... or this'll never
//	work.  If you want to run with hardware flow control on, add another
//	wire to this module in order to set o_cts to 1'b1.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
// Uncomment the next line defining OPT_DUMBECHO in order to test the wires
// and external functionality of any UART, independent of the UART protocol.
//
//`define	OPT_DUMBECHO
//
//
// One issue with the design is how to set the values of the setup register.
// (*This is a comment, not a verilator attribute ... )  Verilator needs to
// know/set those values in order to work.  However, this design can also be
// used as a stand-alone top level configuration file.  In this latter case,
// the setup register needs to be set internal to the file.  Here, we use
// OPT_STANDALONE to distinguish between the two.  If set, the file runs under
// (* Another comment still ...) Verilator and we need to get i_setup from the
// external environment.  If not, it must be set internally.
//
`ifndef	VERILATOR
`define OPT_STANDALONE
`endif
//
//
// Two versions of the UART can be found in the rtl directory: a full featured
// UART, and a LITE UART that only handles 8N1 -- no break sending, break
// detection, parity error detection, etc.  If we set USE_LITE_UART here, those
// simplified UART modules will be used.
//
`define	USE_LITE_UART
//
//
module	echotest(i_clk,
`ifndef	OPT_STANDALONE
			i_setup,
`endif
			i_uart_rx, o_uart_tx);
	input		i_clk;
`ifndef	OPT_STANDALONE
	input	[30:0]	i_setup;
`endif
	input		i_uart_rx;
	output	wire	o_uart_tx;

`ifdef	OPT_DUMBECHO
	reg	r_uart_tx;

	initial	r_uart_tx = 1'b1;
	always @(posedge i_clk)
		r_uart_tx <= i_uart_rx;
	assign	o_uart_tx = r_uart_tx;
`else
	// This is the "smart" echo verion--one that decodes, and then
	// re-encodes, values over the UART.  There is a risk, though, doing
	// things in this manner that the receive UART might run *just* a touch
	// faster than the transmitter, and hence drop a bit every now and
	// then.  Hence, it works nicely for hand-testing, but not as nicely
	// for high-speed UART testing.



	// If i_setup isnt set up as an input parameter, it needs to be set.
	// We do so here, to a setting appropriate to create a 115200 Baud
	// comms system from a 100MHz clock.  This also sets us to an 8-bit
	// data word, 1-stop bit, and no parity.
	//
	// This code only applies if OPT_DUMBECHO is not defined.
`ifdef	OPT_STANDALONE
	wire	[30:0]	i_setup;
	assign		i_setup = 31'd100;	// 115200 Baud, if clk @ 100MHz
`endif

	// Create a reset line that will always be true on a power on reset
	reg	pwr_reset;
	initial	pwr_reset = 1'b1;
	always @(posedge i_clk)
		pwr_reset = 1'b0;



	// The UART Receiver
	//
	// This is where everything begins, by reading data from the UART.
	//
	// Data (rx_data) is present when rx_stb is true.  Any parity or
	// frame errors will also be valid at that time.  Finally, we'll ignore
	// errors, and even the clocked uart input distributed from here.
	//
	// This code only applies if OPT_DUMBECHO is not defined.
	wire	rx_stb, rx_break, rx_perr, rx_ferr, rx_ignored;
	wire	[7:0]	rx_data;

`ifdef	USE_LITE_UART
	//
	// NOTE: this depends upon the Verilator implementation using a setup
	// of 868, since we cannot change the setup of the RXUARTLITE module.
	//
	rxuartlite	#(24'd100)
		receiver(i_clk, i_uart_rx, rx_stb, rx_data);
`else
	rxuart	receiver(i_clk, pwr_reset, i_setup, i_uart_rx, rx_stb, rx_data,
			rx_break, rx_perr, rx_ferr, rx_ignored);
`endif

	// Bypass any transmit hardware flow control.
	wire	cts_n;
	assign cts_n = 1'b0;

	wire	tx_busy;
`ifdef	USE_LITE_UART
	//
	// NOTE: this depends upon the Verilator implementation using a setup
	// of 868, since we cannot change the setup of the TXUARTLITE module.
	//
	txuartlite #(24'd100)
		transmitter(i_clk, rx_stb, rx_data, o_uart_tx, tx_busy);
`else
	txuart	transmitter(i_clk, pwr_reset, i_setup, rx_break,
			rx_stb, rx_data, rts, o_uart_tx, tx_busy);
`endif

`endif

endmodule

////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	txuartlite.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	Transmit outputs over a single UART line.  This particular UART
//		implementation has been extremely simplified: it does not handle
//	generating break conditions, nor does it handle anything other than the
//	8N1 (8 data bits, no parity, 1 stop bit) UART sub-protocol.
//
//	To interface with this module, connect it to your system clock, and
//	pass it the byte of data you wish to transmit.  Strobe the i_wr line
//	high for one cycle, and your data will be off.  Wait until the 'o_busy'
//	line is low before strobing the i_wr line again--this implementation
//	has NO BUFFER, so strobing i_wr while the core is busy will just
//	get ignored.  The output will be placed on the o_txuart output line.
//
//	(I often set both data and strobe on the same clock, and then just leave
//	them set until the busy line is low.  Then I move on to the next piece
//	of data.)
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
`define	TXUL_BIT_ZERO	4'h0
`define	TXUL_BIT_ONE	4'h1
`define	TXUL_BIT_TWO	4'h2
`define	TXUL_BIT_THREE	4'h3
`define	TXUL_BIT_FOUR	4'h4
`define	TXUL_BIT_FIVE	4'h5
`define	TXUL_BIT_SIX	4'h6
`define	TXUL_BIT_SEVEN	4'h7
`define	TXUL_STOP	4'h8
`define	TXUL_IDLE	4'hf
//
//
module txuartlite(i_clk, i_wr, i_data, o_uart_tx, o_busy);
	parameter	[23:0]	CLOCKS_PER_BAUD = 24'd8; // 24'd100;
	input	wire		i_clk;
	input	wire		i_wr;
	input	wire	[7:0]	i_data;
	// And the UART input line itself
	output	reg		o_uart_tx;
	// A line to tell others when we are ready to accept data.  If
	// (i_wr)&&(!o_busy) is ever true, then the core has accepted a byte
	// for transmission.
	output	wire		o_busy;

	reg	[23:0]	baud_counter;
	reg	[3:0]	state;
	reg	[7:0]	lcl_data;
	reg		r_busy, zero_baud_counter;

	initial	r_busy = 1'b1;
	initial	state  = `TXUL_IDLE;
	always @(posedge i_clk)
	begin
		if (!zero_baud_counter)
			// r_busy needs to be set coming into here
			r_busy <= 1'b1;
		else if (state == `TXUL_IDLE)	// STATE_IDLE
		begin
			r_busy <= 1'b0;
			if ((i_wr)&&(!r_busy))
			begin	// Immediately start us off with a start bit
				r_busy <= 1'b1;
				state <= `TXUL_BIT_ZERO;
			end
		end else begin
			// One clock tick in each of these states ...
			r_busy <= 1'b1;
			if (state <=`TXUL_STOP) // start bit, 8-d bits, stop-b
				state <= state + 1;
			else
				state <= `TXUL_IDLE;
		end
	end

	// o_busy
	//
	// This is a wire, designed to be true is we are ever busy above.
	// originally, this was going to be true if we were ever not in the
	// idle state.  The logic has since become more complex, hence we have
	// a register dedicated to this and just copy out that registers value.
	assign	o_busy = (r_busy);


	// lcl_data
	//
	// This is our working copy of the i_data register which we use
	// when transmitting.  It is only of interest during transmit, and is
	// allowed to be whatever at any other time.  Hence, if r_busy isn't
	// true, we can always set it.  On the one clock where r_busy isn't
	// true and i_wr is, we set it and r_busy is true thereafter.
	// Then, on any zero_baud_counter (i.e. change between baud intervals)
	// we simple logically shift the register right to grab the next bit.
	initial	lcl_data = 8'hff;
	always @(posedge i_clk)
		if ((i_wr)&&(!r_busy))
			lcl_data <= i_data;
		else if (zero_baud_counter)
			lcl_data <= { 1'b1, lcl_data[7:1] };

	// o_uart_tx
	//
	// This is the final result/output desired of this core.  It's all
	// centered about o_uart_tx.  This is what finally needs to follow
	// the UART protocol.
	//
	initial	o_uart_tx = 1'b1;
	always @(posedge i_clk)
		if ((i_wr)&&(!r_busy))
			o_uart_tx <= 1'b0;	// Set the start bit on writes
		else if (zero_baud_counter)	// Set the data bit.
			o_uart_tx <= lcl_data[0];


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
	// that reason, we create "zero_baud_counter".  zero_baud_counter is
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
	// When (i_wr)&&(!r_busy)&&(state == `TXUL_IDLE) then we're not only in
	// the idle state, but we also just accepted a command to start writing
	// the next word.  At this point, the baud counter needs to be reset
	// to the number of CLOCKS_PER_BAUD, and zero_baud_counter set to zero.
	//
	// The logic is a bit twisted here, in that it will only check for the
	// above condition when zero_baud_counter is false--so as to make
	// certain the STOP bit is complete.
	initial	zero_baud_counter = 1'b0;
	initial	baud_counter = 24'h05;
	always @(posedge i_clk)
	begin
		zero_baud_counter <= (baud_counter == 24'h01);
		if (state == `TXUL_IDLE)
		begin
			baud_counter <= 24'h0;
			zero_baud_counter <= 1'b1;
			if ((i_wr)&&(!r_busy))
			begin
				baud_counter <= CLOCKS_PER_BAUD - 24'h01;
				zero_baud_counter <= 1'b0;
			end
		end else if (!zero_baud_counter)
			baud_counter <= baud_counter - 24'h01;
		else
			baud_counter <= CLOCKS_PER_BAUD - 24'h01;
	end

//
//
// FORMAL METHODS
//
//
//
`ifdef	FORMAL

`ifdef	TXUARTLITE
`define	ASSUME	assume
`else
`define	ASSUME	assert
`endif

	// Setup

	reg	f_past_valid, f_last_clk;

	always @($global_clock)
	begin
		restrict(i_clk == !f_last_clk);
		f_last_clk <= i_clk;
		if (!$rose(i_clk))
		begin
			`ASSUME($stable(i_wr));
			`ASSUME($stable(i_data));
		end
	end

	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	always @(posedge i_clk)
		if ((f_past_valid)&&($past(i_wr))&&($past(o_busy)))
		begin
			`ASSUME(i_wr   == $past(i_wr));
			`ASSUME(i_data == $past(i_data));
		end

	// Check the baud counter
	always @(posedge i_clk)
		if (zero_baud_counter)
			assert(baud_counter == 0);

	always @(posedge i_clk)
		if ((f_past_valid)&&($past(baud_counter != 0))&&($past(state != `TXUL_IDLE)))
			assert(baud_counter == $past(baud_counter - 1'b1));

	always @(posedge i_clk)
		if ((f_past_valid)&&(!$past(zero_baud_counter))&&($past(state != `TXUL_IDLE)))
			assert($stable(o_uart_tx));

	reg	[23:0]	f_baud_count;
	initial	f_baud_count = 1'b0;
	always @(posedge i_clk)
		if (zero_baud_counter)
			f_baud_count <= 0;
		else
			f_baud_count <= f_baud_count + 1'b1;

	always @(posedge i_clk)
		assert(f_baud_count < CLOCKS_PER_BAUD);

	always @(posedge i_clk)
		if (baud_counter != 0)
			assert(o_busy);

	reg	[9:0]	f_txbits;
	initial	f_txbits = 0;
	always @(posedge i_clk)
		if (zero_baud_counter)
			f_txbits <= { o_uart_tx, f_txbits[9:1] };

	reg	[3:0]	f_bitcount;
	initial	f_bitcount = 0;
	always @(posedge i_clk)
		//if (baud_counter == CLOCKS_PER_BAUD - 24'h01)
			//f_bitcount <= f_bitcount + 1'b1;
		if ((!f_past_valid)||(!$past(f_past_valid)))
			f_bitcount <= 0;
		else if ((state == `TXUL_IDLE)&&(zero_baud_counter))
			f_bitcount <= 0;
		else if (zero_baud_counter)
			f_bitcount <= f_bitcount + 1'b1;

	always @(posedge i_clk)
		assert(f_bitcount <= 4'ha);

	reg	[7:0]	f_request_tx_data;
	always @(posedge i_clk)
		if ((i_wr)&&(!o_busy))
			f_request_tx_data <= i_data;

	wire	[3:0]	subcount;
	assign	subcount = 10-f_bitcount;
	always @(posedge i_clk)
		if (f_bitcount > 0)
			assert(!f_txbits[subcount]);
/*

	always @(posedge i_clk)
		if ((f_bitcount > 2)&&(f_bitcount <= 10))
			assert(f_txbits[f_bitcount-2:0]
				== f_request_tx_data[7:(9-f_bitcount)]);
*/

	always @(posedge i_clk)
		if (f_bitcount == 4'ha)
		begin
			assert(f_txbits[8:1] == f_request_tx_data);
			assert( f_txbits[9]);
		end

	always @(posedge i_clk)
		assert((state <= `TXUL_STOP + 1'b1)||(state == `TXUL_IDLE));
//
//

`endif	// FORMAL
endmodule

////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxuartlite.v
//
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	Receive and decode inputs from a single UART line.
//
//
//	To interface with this module, connect it to your system clock,
//	and a UART input.  Set the parameter to the number of clocks per
//	baud.  When data becomes available, the o_wr line will be asserted
//	for one clock cycle.
//
//	This interface only handles 8N1 serial port communications.  It does
//	not handle the break, parity, or frame error conditions.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
`define	RXUL_BIT_ZERO		4'h0
`define	RXUL_BIT_ONE		4'h1
`define	RXUL_BIT_TWO		4'h2
`define	RXUL_BIT_THREE		4'h3
`define	RXUL_BIT_FOUR		4'h4
`define	RXUL_BIT_FIVE		4'h5
`define	RXUL_BIT_SIX		4'h6
`define	RXUL_BIT_SEVEN		4'h7
`define	RXUL_STOP		4'h8
`define	RXUL_IDLE		4'hf

module rxuartlite(i_clk, i_uart_rx, o_wr, o_data);
	parameter [23:0] CLOCKS_PER_BAUD = 24'd100;
	input	wire		i_clk;
	input	wire		i_uart_rx;
	output	reg		o_wr;
	output	reg	[7:0]	o_data;


	wire	[23:0]	half_baud;
	reg	[3:0]	state;

	assign	half_baud = { 1'b0, CLOCKS_PER_BAUD[23:1] } - 24'h1;
	reg	[23:0]	baud_counter;
	reg		zero_baud_counter;


	// Since this is an asynchronous receiver, we need to register our
	// input a couple of clocks over to avoid any problems with 
	// metastability.  We do that here, and then ignore all but the
	// ck_uart wire.
	reg	q_uart, qq_uart, ck_uart;
	initial	q_uart  = 1'b0;
	initial	qq_uart = 1'b0;
	initial	ck_uart = 1'b0;
	always @(posedge i_clk)
	begin
		q_uart <= i_uart_rx;
		qq_uart <= q_uart;
		ck_uart <= qq_uart;
	end

	// Keep track of the number of clocks since the last change.
	//
	// This is used to determine if we are in either a break or an idle
	// condition, as discussed further below.
	reg	[23:0]	chg_counter;
	initial	chg_counter = 24'h00;
	always @(posedge i_clk)
		if (qq_uart != ck_uart)
			chg_counter <= 24'h00;
		else
			chg_counter <= chg_counter + 1;

	// Are we in the middle of a baud iterval?  Specifically, are we
	// in the middle of a start bit?  Set this to high if so.  We'll use
	// this within our state machine to transition out of the IDLE
	// state.
	reg	half_baud_time;
	initial	half_baud_time = 0;
	always @(posedge i_clk)
		half_baud_time <= (~ck_uart)&&(chg_counter >= half_baud);


	initial	state = `RXUL_IDLE;
	always @(posedge i_clk)
	begin
		if (state == `RXUL_IDLE)
		begin // Idle state, independent of baud counter
			// By default, just stay in the IDLE state
			state <= `RXUL_IDLE;
			if ((~ck_uart)&&(half_baud_time))
				// UNLESS: We are in the center of a valid
				// start bit
				state <= `RXUL_BIT_ZERO;
		end else if (zero_baud_counter)
		begin
			if (state < `RXUL_STOP)
				// Data arrives least significant bit first.
				// By the time this is clocked in, it's what
				// you'll have.
				state <= state + 1;
			else // Wait for the next character
				state <= `RXUL_IDLE;
		end
	end

	// Data bit capture logic.
	//
	// This is drastically simplified from the state machine above, based
	// upon: 1) it doesn't matter what it is until the end of a captured
	// byte, and 2) the data register will flush itself of any invalid
	// data in all other cases.  Hence, let's keep it real simple.
	reg	[7:0]	data_reg;
	always @(posedge i_clk)
		if (zero_baud_counter)
			data_reg <= { ck_uart, data_reg[7:1] };

	// Our data bit logic doesn't need nearly the complexity of all that
	// work above.  Indeed, we only need to know if we are at the end of
	// a stop bit, in which case we copy the data_reg into our output
	// data register, o_data, and tell others (for one clock) that data is
	// available.
	//
	initial	o_data = 8'h00;
	always @(posedge i_clk)
		if ((zero_baud_counter)&&(state == `RXUL_STOP))
		begin
			o_wr   <= 1'b1;
			o_data <= data_reg;
		end else
			o_wr   <= 1'b0;

	// The baud counter
	//
	// This is used as a "clock divider" if you will, but the clock needs
	// to be reset before any byte can be decoded.  In all other respects,
	// we set ourselves up for CLOCKS_PER_BAUD counts between baud
	// intervals.
	always @(posedge i_clk)
		if ((zero_baud_counter)|||(state == `RXUL_IDLE))
			baud_counter <= CLOCKS_PER_BAUD-1'b1;
		else
			baud_counter <= baud_counter-1'b1;

	// zero_baud_counter
	//
	// Rather than testing whether or not (baud_counter == 0) within our
	// (already too complicated) state transition tables, we use
	// zero_baud_counter to pre-charge that test on the clock
	// before--cleaning up some otherwise difficult timing dependencies.
	initial	zero_baud_counter = 1'b0;
	always @(posedge i_clk)
		if (state == `RXUL_IDLE)
			zero_baud_counter <= 1'b0;
		else
			zero_baud_counter <= (baud_counter == 24'h01);


endmodule


