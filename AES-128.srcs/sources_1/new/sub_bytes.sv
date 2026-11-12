`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2026 09:20:11 AM
// Design Name: 
// Module Name: sub_bytes
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


module sub_bytes(  
  input logic [0:127] state_in,
  output logic [0:127] state_out
);

  logic [3:0] row [15:0];
  logic [3:0] col [15:0];
  logic [7:0] dout [15:0];

  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1) begin : gen_sbox
      assign row[i] = state_in[i*8 +: 4];
      assign col[i] = state_in[i*8 + 4 +: 4];
      
      sbox u_sbox (
        .row(row[i]),
        .col(col[i]),
        .dout(dout[i])
      );
      
      assign state_out[i*8 +: 8] = dout[i];
      
    end
  endgenerate
  

endmodule
