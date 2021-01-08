`timescale 1ns / 1ps
	
	module  speechfifo_tb;
	
	
	reg i_clk;
	//input i_uart_rx;
	output o_uart_tx;
	wire o_uart_tx;
	
	speechfifo dut(
		i_clk,
		//i_uart_rx,
		o_uart_tx
	);
	
	integer i;
	initial 
		begin
			i_clk = 0;
			for ( i =0; i <=10000; i= i+1)
			#10 i_clk = ~i_clk;
	end
	
	initial
		begin
			$dumpfile("speechfifo.vcd");
			$dumpvars(0, dut);
			//$monitor("A is %b, B is %b.", A, B);
			//#50 A = 4'b1100;
			
			//#868000 $finish;
	end
endmodule
