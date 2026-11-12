`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2026 01:35:54 PM
// Design Name: 
// Module Name: mix_columns
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


module mix_columns(  
  input logic [0:127] state_in,
  output logic [0:127] state_out
);
    
  function automatic logic [7:0] xmul2(
    input logic [7:0] state
  );
    logic [7:0] temp;
    if (state[7]) begin
      temp = state << 1;
      temp = temp ^ 8'h1B;
    end
    else begin
      temp = state << 1;
    end
    return temp;
  endfunction
  
  function automatic logic [7:0] xmul3(
    input logic [7:0] state
  );
    logic [7:0] temp;
    temp = xmul2(state);
    temp = temp ^ state;
    return temp;
  endfunction
  
  logic [7:0] c0, c1, c2, c3;
  logic [7:0] r0, r1, r2, r3;
  
  always_comb begin
    for (int col = 0; col <= 3; col++) begin
      c0 = state_in[col*32 +  0 +: 8];
      c1 = state_in[col*32 +  8 +: 8];
      c2 = state_in[col*32 + 16 +: 8];
      c3 = state_in[col*32 + 24 +: 8];
      
      r0 = xmul2(c0) ^ xmul3(c1) ^ c2 ^ c3;
      r1 = c0 ^ xmul2(c1) ^ xmul3(c2) ^ c3;
      r2 = c0 ^ c1 ^ xmul2(c2) ^ xmul3(c3);
      r3 = xmul3(c0) ^ c1 ^ c2 ^ xmul2(c3);
      
      state_out[col*8*4 + 0*8 +: 8] = r0;
      state_out[col*8*4 + 1*8 +: 8] = r1;
      state_out[col*8*4 + 2*8 +: 8] = r2;
      state_out[col*8*4 + 3*8 +: 8] = r3;
    
      end
  end
endmodule
