module SDRAM_Controller( //directly interfaces with SDRAM to read and write data to memory
	input clk, //SDRAM clock input; runs at 700HZ
	input wReq, //write enable signal
	input [12:0] wAddr, //address for writing to memory
	input [15:0] wData, 
	input rReq,//read enable signal
	input [12:0] rAddr, //address for reading from memory
	output [15:0] rData //data to read from memory
);






endmodule
