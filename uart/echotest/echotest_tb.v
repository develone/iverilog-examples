`timescale 1ns / 1ps

	module  echotest_tb;
	
	reg i_clk;
	
	input wire i_uart_rx;
	
	reg r_uart_rx;
	
	output wire o_uart_tx;
	
		
	echotest dut (
		i_clk,
		i_uart_rx,
		o_uart_tx
	);
	
	initial
		begin
		#15 r_uart_rx = i_uart_rx;
	end
	
	integer i;
	initial 
		begin
			i_clk = 0;
			for ( i =0; i <=10000; i= i+1)
			#10 i_clk = ~i_clk;
	end
	
	initial
		begin
			$dumpfile("echotest.vcd");
			$dumpvars(0, dut);
			//$monitor("A is %b, B is %b.", A, B);
			//#50 A = 4'b1100;
			
			//#50 $finish;
	end
endmodule
