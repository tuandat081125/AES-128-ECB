`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/04/2026 02:21:21 PM
// Design Name: 
// Module Name: inv_mix_columns
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


module inv_mix_columns(  
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
  
  function automatic logic [7:0] xmul4(
    input logic [7:0] x
  );
    xmul4 = xmul2(xmul2(x));
  endfunction
  
  function automatic logic [7:0] xmul8(
    input logic [7:0] x
  );
    xmul8 = xmul2(xmul4(x));
  endfunction
  
  function automatic logic [7:0] xmul9(
    input logic [7:0] x
  );
    xmul9 = xmul8(x) ^ x;
  endfunction

  function automatic logic [7:0] xmulB(
    input logic [7:0] x
  );
    xmulB = xmul8(x) ^ xmul2(x) ^ x;
  endfunction

  function automatic logic [7:0] xmulD(
    input logic [7:0] x
  );
    xmulD = xmul8(x) ^ xmul4(x) ^ x;
  endfunction

  function automatic logic [7:0] xmulE(
    input logic [7:0] x
  );
    xmulE = xmul8(x) ^ xmul4(x) ^ xmul2(x);
  endfunction
  
  logic [7:0] c0, c1, c2, c3;
  logic [7:0] r0, r1, r2, r3;
  
  always_comb begin
    for (int col = 0; col <= 3; col++) begin
      c0 = state_in[col*32 +  0 +: 8];
      c1 = state_in[col*32 +  8 +: 8];
      c2 = state_in[col*32 + 16 +: 8];
      c3 = state_in[col*32 + 24 +: 8];
      
      r0 = xmulE(c0) ^ xmulB(c1) ^ xmulD(c2) ^ xmul9(c3);
      r1 = xmul9(c0) ^ xmulE(c1) ^ xmulB(c2) ^ xmulD(c3);
      r2 = xmulD(c0) ^ xmul9(c1) ^ xmulE(c2) ^ xmulB(c3);
      r3 = xmulB(c0) ^ xmulD(c1) ^ xmul9(c2) ^ xmulE(c3);
      
      state_out[col*32 +  0 +: 8] = r0;
      state_out[col*32 +  8 +: 8] = r1;
      state_out[col*32 + 16 +: 8] = r2;
      state_out[col*32 + 24 +: 8] = r3;
    
    end
  end

endmodule
