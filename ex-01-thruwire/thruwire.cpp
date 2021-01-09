////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	thruwire.cpp
//
// Project:	Verilog Tutorial Example file
//
// Purpose:	Main Verilator simulation script for the thruwire design
//
//	In this script, we toggle the input, and (hopefully) watch the output
//	toggle.
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
#include <stdio.h>
#include <stdlib.h>
#include "Vthruwire.h"
#include "verilated.h"

int main(int argc, char **argv) {
	// Call commandArgs first!
	Verilated::commandArgs(argc, argv);

	// Instantiate our design
	Vthruwire *tb = new Vthruwire;

	tb->i_sw = 0;
	for(int k=0; k<20; k++) {
		// We'll set the switch input
		// to the LSB of our counter
		tb->i_sw = k&1;

		tb->eval();

		// Now let's print our results
		printf("k = %2d, ", k);
		printf("sw = %d, ", tb->i_sw);
		printf("led = %d\n", tb->o_led);
	}
}
