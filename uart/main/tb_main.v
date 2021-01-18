module tb_main;

reg iClk;
wire iRX;
wire oTX;

initial begin
    $from_myhdl(
        iClk
    );
    $to_myhdl(
        iRX,
        oTX
    );
end

main dut(
    iClk,
    iRX,
    oTX
);

endmodule
