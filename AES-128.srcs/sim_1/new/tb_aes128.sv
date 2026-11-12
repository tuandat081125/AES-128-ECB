`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/09/2026 01:48:13 PM
// Design Name: 
// Module Name: tb_aes128
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


module tb_aes128;

  logic         clk;
  logic         rst;
  logic         inv;
  logic [0:127] data_in;
  logic [0:127] key;
  logic [0:127] data_out;
  logic         start;
  logic         data_out_ready;
  logic         busy;

  // DUT
  aes128 dut (
    .clk            (clk),
    .rst            (rst),
    .inv            (inv),
    .data_in        (data_in),
    .key            (key),
    .data_out       (data_out),
    .start          (start),
    .data_out_ready (data_out_ready),
    .busy           (busy)
  );

  // Clock 100MHz
  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    // Khởi tạo (rst tích cực mức thấp)
    rst     = 0;
    start   = 0;
    inv     = 0;                 // 0: mã hóa, 1: giải mã
    data_in = 128'h00112233445566778899aabbccddeeff;
    key     = 128'h000102030405060708090a0b0c0d0e0f;

    // Giữ reset 3 chu kỳ rồi nhả
    repeat (3) @(posedge clk);
    rst = 1;
    repeat (2) @(posedge clk);

    // Dữ liệu + key đã nằm sẵn trên kênh, bắt đầu pulse start 1 chu kỳ
    @(posedge clk);
    start = 1;
    @(posedge clk);
    start = 0;

    // Chờ có kết quả (có timeout tránh treo)
    fork
      begin
        wait (data_out_ready);
        @(posedge clk);
        $display("[%0t] DONE  data_out = %h", $time, data_out);
      end
      begin
        repeat (1000) @(posedge clk);
        $display("[%0t] TIMEOUT: data_out_ready khong len", $time);
      end
    join_any
    disable fork;

    repeat (5) @(posedge clk);
    $finish;
  end

  // Check ktemp vòng đầu (round 1): key = 000102...0f, w3 = 0c0d0e0f
  // Thứ tự chuẩn AES: RotWord -> SubWord -> AddRcon
  initial begin
    logic [0:31] w3, rcon1;
    logic [0:31] exp_in, exp_rot, exp_sub, exp_rcon;

    w3       = 32'h0c0d0e0f;
    rcon1    = 32'h01000000;
    
    exp_in = w3;
    exp_rot  = {w3[8:31], w3[0:7]};   // RotWord : 0c0d0e0f -> 0d0e0f0c
    exp_sub  = 32'hd7ab76fe;          // SubWord : S(0d,0e,0f,0c) = d7,ab,76,fe
    exp_rcon = exp_sub ^ rcon1;       // AddRcon : d7ab76fe ^ 01000000 = d6ab76fe

    @(posedge dut.ld_ktemp);
    #1;

    $display("[%0t] load_ktemp len, check round 1", $time);
    // 0) Input
    if (dut.ktemp_in_rotword !== exp_in)
      $display("[%0t] FAIL ktemp_in_rotword: expected %h, got %h",
               $time, exp_rot, dut.ktemp_in_rotword);
    else
      $display("[%0t] PASS ktemp_in_rotword = %h", $time, dut.ktemp_in_rotword);
      
    // 1) RotWord
    if (dut.ktemp_after_rotword !== exp_rot)
      $display("[%0t] FAIL ktemp_after_rotword: expected %h, got %h",
               $time, exp_rot, dut.ktemp_after_rotword);
    else
      $display("[%0t] PASS ktemp_after_rotword = %h", $time, dut.ktemp_after_rotword);

    // 2) SubWord
    if (dut.ktemp_after_subword !== exp_sub)
      $display("[%0t] FAIL ktemp_after_subword: expected %h, got %h",
               $time, exp_sub, dut.ktemp_after_subword);
    else
      $display("[%0t] PASS ktemp_after_subword = %h", $time, dut.ktemp_after_subword);

    // 3) AddRcon
    if (dut.ktemp_after_addrcon !== exp_rcon)
      $display("[%0t] FAIL ktemp_after_addrcon: expected %h, got %h",
               $time, exp_rcon, dut.ktemp_after_addrcon);
    else
      $display("[%0t] PASS ktemp_after_addrcon = %h", $time, dut.ktemp_after_addrcon);
  end
  
  initial begin
    logic [0:127] exp_rk [0:10];

    wait(dut.key_expansion_done);
    @(posedge clk);

    // Round key kỳ vọng (FIPS-197 C.1, key = 000102...0f)
    exp_rk[0]  = 128'h000102030405060708090a0b0c0d0e0f;
    exp_rk[1]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
    exp_rk[2]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
    exp_rk[3]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
    exp_rk[4]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
    exp_rk[5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
    exp_rk[6]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;
    exp_rk[7]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;
    exp_rk[8]  = 128'h47438735a41c65b9e016baf4aebf7ad2;
    exp_rk[9]  = 128'h549932d1f08557681093ed9cbe2c974e;
    exp_rk[10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;

    for (int i = 0; i <= 10; i++) begin
      if (dut.key_expanded[i*128 +: 128] !== exp_rk[i])
        $display("[%0t] FAIL round_key[%0d]: expected %h, got %h",
                 $time, i, exp_rk[i], dut.key_expanded[i*128 +: 128]);
      else
        $display("[%0t] PASS round_key[%0d] = %h",
                 $time, i, dut.key_expanded[i*128 +: 128]);
    end
  end
  
  // ------------------------------------------------------------
  // Check state_reg theo round_count (mã hóa, FIPS-197 C.1)
  // exp_state[k] = state sau vòng k (k = 0: sau AddRoundKey ban đầu)
  // round_count = k+1 -> state_reg = exp_state[k], vòng k+1 đang được tính
  // ------------------------------------------------------------
  logic [0:127] exp_state [0:10];

  initial begin
    wait (dut.key_expansion_done);
    exp_state[0]  = 128'h00102030405060708090a0b0c0d0e0f0; // sau AddRoundKey ban đầu
    exp_state[1]  = 128'h89d810e8855ace682d1843d8cb128fe4; // sau vòng 1
    exp_state[2]  = 128'h4915598f55e5d7a0daca94fa1f0a63f7; // sau vòng 2
    exp_state[3]  = 128'hfa636a2825b339c940668a3157244d17; // sau vòng 3
    exp_state[4]  = 128'h247240236966b3fa6ed2753288425b6c; // sau vòng 4
    exp_state[5]  = 128'hc81677bc9b7ac93b25027992b0261996; // sau vòng 5
    exp_state[6]  = 128'hc62fe109f75eedc3cc79395d84f9cf5d; // sau vòng 6
    exp_state[7]  = 128'hd1876c0f79c4300ab45594add66ff41f; // sau vòng 7
    exp_state[8]  = 128'hfde3bad205e5d0d73547964ef1fe37f1; // sau vòng 8
    exp_state[9]  = 128'hbd6e7c3df2b5779e0b61216e8b10b689; // sau vòng 9
    exp_state[10] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a; // sau vòng 10 (ciphertext)
  end

  always @(dut.round_count) begin
    #1;  // chờ state_reg và round_count cùng ổn định sau cạnh clock
    if (dut.round_count >= 1 && dut.round_count <= 10) begin
      if (dut.state_reg !== exp_state[dut.round_count - 1])
        $display("[%0t] FAIL round_count=%0d (sau vong %0d): expected %h, got %h (xor %h)",
                 $time, dut.round_count, dut.round_count - 1,
                 exp_state[dut.round_count - 1], dut.state_reg,
                 dut.state_reg ^ exp_state[dut.round_count - 1]);
      else
        $display("[%0t] PASS round_count=%0d (sau vong %0d): state_reg = %h",
                 $time, dut.round_count, dut.round_count - 1, dut.state_reg);
    end
  end
  
  // Check kết quả cuối khi data_out_ready lên 1
  initial begin
    logic [0:127] exp_out;

    exp_out = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;  // FIPS-197 C.1

    wait (dut.done);
    @(posedge clk);
    #1;

    if (data_out !== exp_out)
      $display("[%0t] FAIL data_out: expected %h, got %h (xor diff %h)",
               $time, exp_out, data_out, data_out ^ exp_out);
    else
      $display("[%0t] PASS data_out = %h", $time, data_out);
  end
  
  // Check vòng cuối (vòng 10) tại cuối chu kỳ khi round_count = 10
  initial begin
    logic [0:127] exp_sub, exp_row, exp_ark;

    exp_sub = 128'h7a9f102789d5f50b2beffd9f3dca4ea7;  // round[10].s_box
    exp_row = 128'h7ad5fda789ef4e272bca100b3d9ff59f;  // round[10].s_row
    exp_ark = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;  // round[10].output

    wait (dut.round_count == 10);
    @(negedge clk);   // giữa chu kỳ, logic tổ hợp đã ổn định, trước cạnh lên kế tiếp

    $display("[%0t] round_count = 10, check vong cuoi", $time);

    // 1) SubBytes
    if (dut.state_after_subbytes !== exp_sub)
      $display("[%0t] FAIL state_after_subbytes: expected %h, got %h (xor diff %h)",
               $time, exp_sub, dut.state_after_subbytes, dut.state_after_subbytes ^ exp_sub);
    else
      $display("[%0t] PASS state_after_subbytes = %h", $time, dut.state_after_subbytes);

    // 2) ShiftRows
    if (dut.state_after_shiftrows !== exp_row)
      $display("[%0t] FAIL state_after_shiftrows: expected %h, got %h (xor diff %h)",
               $time, exp_row, dut.state_after_shiftrows, dut.state_after_shiftrows ^ exp_row);
    else
      $display("[%0t] PASS state_after_shiftrows = %h", $time, dut.state_after_shiftrows);

    // 3) AddRoundKey
    if (dut.state_in_addroundkey !== exp_row)
      $display("[%0t] FAIL state_in_addroundkey: expected %h, got %h (xor diff %h)",
               $time, exp_row, dut.state_in_addroundkey, dut.state_in_addroundkey ^ exp_row);
    else
      $display("[%0t] PASS state_in_addroundkey = %h", $time, dut.state_in_addroundkey);
    
    if (dut.state_after_addroundkey !== exp_ark)
      $display("[%0t] FAIL state_after_addroundkey: expected %h, got %h (xor diff %h)",
               $time, exp_ark, dut.state_after_addroundkey, dut.state_after_addroundkey ^ exp_ark);
    else
      $display("[%0t] PASS state_after_addroundkey = %h", $time, dut.state_after_addroundkey);
  end
  

endmodule
