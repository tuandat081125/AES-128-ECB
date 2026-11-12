`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/02/2026 09:05:28 PM
// Design Name: 
// Module Name: rot_word
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rot_word(
  input logic [0:31] key_in,
  output logic [0:31] key_out
);
  
  assign key_out[0:31] = {key_in[8:31], key_in[0:7]};

endmodule
