################################################################################
##
## Filename: 	Makefile
##
## Project:	Verilog Tutorial Example file
##
## Purpose:	Builds the thruwire Verilator simulationo
##
## Targets:
##
##	The (default) or all target will build the thruwire verilator
##	simulation.
##
##	clean	Removes all build products
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Written and distributed by Gisselquist Technology, LLC
##
## This program is hereby granted to the public domain.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.
##
################################################################################
##
##
.PHONY: all
all: thruwire

obj_dir/Vthruwire.cpp: thruwire.v
	verilator -Wall -cc thruwire.v

obj_dir/Vthruwire__ALL.a: obj_dir/Vthruwire.cpp
	make -C obj_dir -f Vthruwire.mk

# Build a simulation
thruwire: thruwire.cpp obj_dir/Vthruwire__ALL.a
	@echo "Building a Verilator-based simulation of thruwire"
	g++ -I/usr/share/verilator/include  -I obj_dir     \
		/usr/share/verilator/include/verilated.cpp \
		thruwire.cpp obj_dir/Vthruwire__ALL.a      \
		-o thruwire

.PHONY: yosys nextpnr icepack
yosys: thruwire.json
thruwire.json:	thruwire.v
	yosys -p 'synth_ice40 -json thruwire.json' thruwire.v

#
# This is the appropriate build script for an ICO board
# Your build script will vary depending upon your board
#
nextpnr: thruwire.asc
thruwire.asc: thruwire.json demo.pcf
	nextpnr-ice40 --hx8k --package ct256 --pcf demo.pcf --json thruwire.json

icepack: thruwire.bin
thruwire.bin: thruwire.asc
	icepack thruwire.asc thruwire.bin
	

.PHONY: clean
clean:
	rm -rf obj_dir/ thruwire
