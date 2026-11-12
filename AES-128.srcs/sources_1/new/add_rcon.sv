`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/03/2026 12:25:56 PM
// Design Name: 
// Module Name: add_rcon
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


module add_rcon(
  input logic [3:0] w,
  input logic [0:31] key_in,
  
  output logic [0:31] key_out
);

  logic [31:0] rcon;

  always_comb begin
    case (w)
      1: rcon = 32'h01000000;
      2: rcon = 32'h02000000;
      3: rcon = 32'h04000000;
      4: rcon = 32'h08000000;
      5: rcon = 32'h10000000;
      6: rcon = 32'h20000000;
      7: rcon = 32'h40000000;
      8: rcon = 32'h80000000;
      9: rcon = 32'h1B000000;
      10: rcon = 32'h36000000;
      default: rcon = 32'h00000000;
    endcase
    
    key_out = key_in ^ rcon;
    
  end

  
endmodule
