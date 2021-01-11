////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxuart_tb.cpp
//
// Project:	Verilog Tutorial Example file
//
// Purpose:	This test bench sends a file's worth of characters to a serial
//		port receiver, and then prints the results out on the standard
//		output stream.
//
//	This is made just a touch more complicated by the fact that our
//	serial port simulator accepts its file from the standard input port.
//	To solve this, this test bench process forks into two processes,
//	dumps the data into the standard input of the first process, then reads
//	it from the standard output of that process.  It then checks whether
//	the output properly matches the input, reporting success or failure
//	as a result.
//
//	The test vector is a (hopefully text) file that may be given on the
//	command line.  Failing to give any test vector will result in the
//	Psalm 23 being used.
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
#include <verilatedos.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <time.h>
#include <sys/types.h>
#include <signal.h>
#include <ctype.h>
#include "verilated.h"
#include "Vrxuart.h"
#include "uartsim.h"
#include "verilated_vcd_c.h"
#include "testb.h"

void	usage(void) {
	fprintf(stderr, "USAGE: rxuart_tb [<filename.txt>]\n");
	fprintf(stderr, "\n"
"\tWhere ... \n"
"\n"
"\t<filename.txt>\t is the name of a file which will be \"transmitted\"\n"
"\t\tvia UART to the receiver under test.  The output will then be sent\n"
"\t\tboth to the receiver, then through the receiver to the standard\n"
"\t\toutput--but not before being compared against the original file.\n");
};

int	main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	TESTB<Vrxuart>	*tb;
	UARTSIM		*uart;
	unsigned	testcount = 0, baudclocks;
	const char	*matchfile;

	matchfile = "psalm.txt";
	if ((argc > 2)||((argc==2)&&(!isalpha(argv[1][0])))) {
		usage();
		exit(EXIT_FAILURE);
	}

	if (argc == 2)
		matchfile = argv[1];

	if ((!matchfile)||(!matchfile[0])
		||(access(matchfile, R_OK) != 0)) {
		fprintf(stderr, "Could not open pattern file, %s\n", matchfile);
		exit(EXIT_FAILURE);
	}

	//
	// Non-interactive mode is more difficult.  In this case, we
	// must figure out how to determine if the test was successful
	// or not.  Since uartsim dumps the UART output to standard
	// out, we then need to do a bit of work to capture that.
	//
	// In particular, we are going to fork ourselves and set up our
	// child process so that we can read from its standard out
	// (and write to its standard in--although we don't).
	int	childs_stdin[2], childs_stdout[2];
	FILE	*fp = fopen(matchfile, "r");
	long	flen = 0;

	//
	// Before forking (and getting complicated), let's read the
	// file describing the data we are supposed to read.  Our goal
	// will basically be to do an strncmp with the data in this
	// file, and then to check for zero (equality).
	//
	if (fp == NULL) {
		fprintf(stderr, "ERR - could not open %s\n", matchfile);
		perror("O/S Err:");
		printf("FAIL\n");
		exit(EXIT_FAILURE);
	}

	// Quick, look up how long this file is.  We'll store the file length
	// into flen
	fseek(fp, 0l, SEEK_END);
	flen = ftell(fp);
	fseek(fp, 0l, SEEK_SET);

	if (flen <= 0) {
		if (flen == 0)
			fprintf(stderr, "ERR - zero length match file!\n");
		else {
			fprintf(stderr, "ERR - getting file length\n");
			perror("O/S Err:");
		}
		printf("FAIL\n");
		exit(EXIT_FAILURE);
	}


	// We are ready to do our forking magic.  So, let's allocate
	// pipes for the childs standard input and output streams.
	if ((pipe(childs_stdin)!=0)||(pipe(childs_stdout) != 0)) {
		fprintf(stderr, "ERR setting up child pipes\n");
		perror("O/S Err:");
		printf("FAIL\n");
		exit(EXIT_FAILURE);
	}

	
	//
	//	FORK	!!!!!
	//
	// After this line, there are two threads running--a parent and
	// a child.  The childs child_pid will be zero, the parents
	// child_pid will be the pid of the child.
	pid_t	child_pid = fork();

	// Make sure the fork worked ...
	if (child_pid < 0) {
		fprintf(stderr, "ERR setting up child process fork\n");
		perror("O/S Err:");
		printf("FAIL\n");
		exit(EXIT_FAILURE);
	}

	if (child_pid) {
		int	nr = -2, rd, fail;

		// We are the parent
		// Adjust our pipe file descriptors so that they are
		// useful.
		close(childs_stdin[ 0]); // Close the read end
		close(childs_stdout[1]); // Close the write end

		// Let's allocate some buffers to contain both our
		// match file (string), and what we read from the 
		// UART.  Nominally, we would only need flen+1
		// characters, but this number doesn't quite work--since
		// mkspeech turned all of the the LFs into CR/LF pairs.
		// In the worst case, this would double the number of
		// characters we would need.  Hence, we read allocate
		// enough for the worst case.
		char	*string = (char *)malloc((size_t)(flen+2)),
			*rdbuf  = (char *)malloc((size_t)(flen+2));

		// If this doesn't work, admit to a failure
		if ((string == NULL)||(rdbuf == NULL)) {
			fprintf(stderr, "ERR Malloc failure --- cannot allocate space to read match file\n");
			perror("O/S Err:");
			printf("FAIL\n");
			exit(EXIT_FAILURE);
		}

		// Read the string we are going to match against from
		// the matchfile.  Keep track of the resulting length
		// (in flen), and terminate the string with a null character.
		//

		// Read string, and place a null at the end of it
		nr = fread(string, 1, flen, fp);
		assert(nr == flen);
		string[nr] = '\0';
		flen = strlen(string);


		//
		// Enough setup, let's do our work:
		//
		// 1. Transmit our string to our slave via the pipe we've just
		//	set up.
		nr = write(childs_stdin[1], string, flen);
		// Stop here if we haven't been successful
		assert(nr == flen);

		//
		// 2. Read a character from the pipe and compare it against
		// what we are expecting.  Break on any comparison failure.
		//
		nr = 0;
		rd = 0;
		fail = -1;
		while((nr<flen)&&((rd = read(childs_stdout[0],
				&rdbuf[nr], flen-nr))>0)) {
			for(int i=0; i<rd; i++) {
				putchar(rdbuf[nr+i]);
				if (rdbuf[nr+i] != string[nr+i]) {
					fail = nr+i;
					break;
				}
			}
			if (fail>=0)
				break;
			rdbuf[rd+nr] = 0;
			nr += rd;

			if (rd <= 0) {
				printf("\n\nERROR: Stream ended early\n");
				fail = nr;
				break;
			}
		}

		// Separate ourselves from the message
		printf("\n\n");

		// Tell the user how many (of how many) characters we
		// compared (that matched), for debugging purposes.
		//
		if (fail < 0) {
			printf("SUCCESS - all %d characters matched\n", nr);
			printf("PASS\n");
		} else {
			//
			// We failed.  Report where and how we failed
			printf("ERROR: Character %d did not match\n", fail);
			printf("       as shown above.\n");
			printf("FAIL\n");

			kill(child_pid, SIGKILL);

			free(string);
			free(rdbuf);

			//
			// At this point, the parent is complete, and can
			// exit.
		}
	} else {
		//
		// If childs_pid == 0, then we are the child
		//
		// The child reports the uart result via stdout, so
		// let's make certain it points to STDOUT_FILENO.
		//
		close(childs_stdin[ 1]); // Close the write end
		close(childs_stdout[0]); // Close the read end

		// Now, adjust our stdin/stdout file numbers
		// Stdin first.  This is the channel we'll receive
		// our test file on.
		close(STDIN_FILENO);
		if (dup(childs_stdin[0]) != STDIN_FILENO) {
			fprintf(stderr, "Could not create childs stdin\n");
			perror("O/S ERR");
			exit(EXIT_FAILURE);
		}

		// Set up the standard out file descriptor so that it
		// points to our pipe.  Our output will be sent over
		// this port, and then received here and then sent over
		// the UART simulator.
		close(STDOUT_FILENO);
		if (dup(childs_stdout[1]) != STDOUT_FILENO) {
			fprintf(stderr, "Could not create childs stdout\n");
			perror("O/S ERR");
			exit(EXIT_FAILURE);
		}

		// Allocate our test-bench class
		tb = new TESTB<Vrxuart>;

		// Create an output trace file
		tb->opentrace("rxuart.vcd");

		// Create our UART simulator
		uart = new UARTSIM();
		// Set up our baud rate, stop bits, parity, etc.
		// properly
		baudclocks = tb->m_core->o_setup;
		uart->setup(baudclocks);

		// Make sure the input starts idle, as it should
		tb->m_core->i_uart_rx = 1;

		//
		// Now ... we're finally ready to run our simulation.
		//
		const	int	LARGE_NUMBER = 0x007fffff;
		// LARGE_NUMBER should nominally be (baudclocks * 10 + 2)
		// 	* flen + 16)
		// However, if the transmitter waits to give us a value, it
		// may take longer.  Hence, we wait much longer.
		// The transmitter will kill us once we are complete--so we
		// don't need to worry about going too long here.
		int	num_received = 0;
		while((testcount++ < LARGE_NUMBER)
			       &&(num_received < flen))	{
			tb->tick();

			// Advance the UART based upon the input
			// i_uart_tx value.  We'll ignore the output here,
			// knowing that the UARTSIMulator will place it on
			// the standard output stream.
			tb->m_core->i_uart_rx = (*uart)(1);

			// If we've managed to receive a character, output
			// it to the standard output port
			if (tb->m_core->o_wr) {
				num_received++;
				putchar(tb->m_core->o_data);
			}
		}

		// Quietly exit successfully if we've gotten this far
		exit(EXIT_SUCCESS);
	}
}
