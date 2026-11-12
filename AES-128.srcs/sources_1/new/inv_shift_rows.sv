`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/04/2026 02:20:56 PM
// Design Name: 
// Module Name: inv_shift_rows
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


module inv_shift_rows(
  input logic [0:127] state_in,
  output logic [0:127] state_out
);
  
  always_comb begin
    for (int row = 0; row <= 3; row++)
      for (int col = 0; col <= 3; col ++) begin
        state_out[(col*8)*4 + row*8 +: 8] =
          state_in[(((col - row) % 4)*8)*4 + row*8 +: 8];
      end
  end
  
endmodule
