#!/bin/bash
echo "Removing the obj_dir"

rm -rf obj_dir

#/usr/local/share/verilator
echo "Creating the obj_dir"

verilator -Wall -cc helloworld.v txuart.v
make -C obj_dir -f Vhelloworld.mk
g++ -I/usr/local/share/verilator/include  -I obj_dir     \
		/usr/local/share/verilator/include/verilated.cpp \
		helloworld_tb.cpp uartsim.cpp obj_dir/Vhelloworld__ALL.a      \
		-o helloworld_tb