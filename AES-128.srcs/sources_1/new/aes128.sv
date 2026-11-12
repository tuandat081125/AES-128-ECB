`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2026 09:19:05 AM
// Design Name: 
// Module Name: aes128
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


module aes128( 
  input clk,
  input rst,
  input inv,
  input logic [0:127] data_in,
  input logic [0:127] key,
  output logic  [0:127] data_out,
  
  //handshake
  input logic start,
  output logic data_out_ready,
  output logic busy
);

  logic [0:127] state_reg;
  logic [0:127] data_out_reg;
  logic [0:127] key_reg;
  
  logic running;
  logic key_expansion_running;
  logic round_running;
  assign busy = running;
  
  //Running Reg
  always_ff @(posedge clk)
    if(!rst) begin
      running <= 0;
    end
    else if(start) begin
      running <= 1;
    end
    else if(running) begin
      running <= 1;
    end
  
  logic ld_key_expansion_running;
  logic clr_key_expansion_running;
  //Key Expansion Flag
  always_ff @(posedge clk)
    if(!rst) begin
      key_expansion_running <= 0;
    end
    else if(clr_key_expansion_running) begin
      key_expansion_running <= 0;
    end
    else if(ld_key_expansion_running) begin
      key_expansion_running <= 1;
    end
  
  
  logic ld_round_running;
  logic clr_round_running;
  //Round Flag
  always_ff @(posedge clk)
    if(!rst) begin
      round_running <= 0;
    end
    else if(clr_round_running) begin
      round_running <= 0;
    end
    else if(ld_round_running) begin
      round_running <= 1;
    end

  
  //Round Data Path
  logic [0:127] data_in_subbytes;
  logic [0:127] state_in_shiftrows;
  logic [0:127] state_after_subbytes;
  logic [0:127] state_after_shiftrows;
  logic [0:127] state_after_mixcolumns;
  logic [0:127] state_in_addroundkey;
  logic [0:127] state_after_addroundkey;
  logic [0:127] round_key;              // 128-bit round key


  //SubBytes
  sub_bytes u_sub_bytes (
    .state_in  (data_in_subbytes),
    .state_out (state_after_subbytes)
  );

  //ShiftRows
  shift_rows u_shift_rows (
    .state_in  (state_in_shiftrows),
    .state_out (state_after_shiftrows)
  );

  //MixColumns
  mix_columns u_mix_columns (
    .state_in  (state_after_shiftrows),
    .state_out (state_after_mixcolumns)
  );

  //AddRoundKey
  add_round_key u_add_round_key (
    .state_in  (state_in_addroundkey),
    .key       (round_key),
    .state_out (state_after_addroundkey)
  );
  
  //Inv Round Datapath
  logic [0:127] state_in_inv_shiftrows;
  logic [0:127] state_after_inv_shiftrows;
  logic [0:127] state_after_inv_subbytes;
  logic [0:127] state_in_inv_mixcolumns;
  logic [0:127] state_after_inv_mixcolumns;
  logic [0:127] state_in_inv_addroundkey;
  logic [0:127] state_after_inv_addroundkey;
  logic [0:127] inv_round_key;

  //InvShiftRows
  inv_shift_rows u_inv_shift_rows (
    .state_in  (state_in_inv_shiftrows),
    .state_out (state_after_inv_shiftrows)
  );

  //InvSubBytes
  inv_sub_bytes u_inv_sub_bytes (
    .state_in  (state_after_inv_shiftrows),
    .state_out (state_after_inv_subbytes)
  );
  
  //InvAddRoundKey
  add_round_key u_inv_add_round_key (
    .state_in  (state_in_inv_addroundkey),
    .key       (inv_round_key),
    .state_out (state_after_inv_addroundkey)
  );

  //InvMixColumns
  inv_mix_columns u_inv_mix_columns (
    .state_in  (state_in_inv_mixcolumns),
    .state_out (state_after_inv_mixcolumns)
  );
  
  //Key expansion
  logic [0:31] ktemp_in_rotword;
  logic [0:31] ktemp_after_rotword;
  logic [5:0] w_count;
  logic [0:31] ktemp_after_subword;
  logic [0:31] ktemp_after_addrcon;
  
  logic [0:1407] key_expanded;
  
  logic ld_key_expanded;
  logic [0:15] key_expanded_in;
  
  logic [0:31] ktemp_reg;
  logic ld_ktemp;
  
  //RotWord
  rot_word u_rot_word (
    .key_in  (ktemp_in_rotword),
    .key_out (ktemp_after_rotword)
  );
  
  add_rcon u_add_rcon (
    .w (w_count),
    .key_in(ktemp_after_subword),
    .key_out(ktemp_after_addrcon)
  );
  
  //SubBytes Mux
  always_comb begin
    if(key_expansion_running) begin
      data_in_subbytes[0:31] = ktemp_after_rotword;
      ktemp_after_subword = state_after_subbytes[0:31];
      //có thể có Latch ở đây, xem xét sửa sau
    end
    else if(round_running) begin
      data_in_subbytes = state_reg;
      state_in_shiftrows = state_after_subbytes;
    end
  end
  
  logic mode_round0;
  logic mode_round10;
  logic mode_normal;
  logic [0:127] state_after_round;
  
  //AddRounKey Mux
  always_comb begin
    if(mode_round0) begin
      state_in_addroundkey = state_reg;
      //có thể có Latch ở đây, xem xét sửa sau
    end
    else if(mode_round10) begin
      state_in_addroundkey = state_after_shiftrows;
    end
    else if(mode_normal) begin
      state_in_addroundkey = state_after_mixcolumns;
    end
    state_after_round = state_after_addroundkey;
  end
  
  logic mode_inv_round0;
  logic mode_inv_round10;
  logic mode_inv_normal;
  logic state_after_round_inv;
  
  //InvAddRounKey Mux
  always_comb begin
    if(mode_round0) begin
      state_in_inv_addroundkey = state_reg;
      state_after_round_inv = state_after_inv_addroundkey;
      //có thể có Latch ở đây, xem xét sửa sau
    end
    else if(mode_round10) begin
      state_in_inv_addroundkey = state_after_inv_subbytes;
      state_after_round_inv = state_after_inv_addroundkey;
    end
    else if(mode_normal) begin
      state_in_inv_addroundkey = state_after_inv_subbytes;
      state_in_inv_mixcolumns = state_after_addroundkey;
      state_after_round_inv = state_after_inv_mixcolumns;
    end
  end
  
  //Load Key
  logic [4:0] round_count;
  
  always_comb begin
    case (round_count)
      0:  round_key = key_expanded[0:127];
      1:  round_key = key_expanded[128:255];
      2:  round_key = key_expanded[256:383];
      3:  round_key = key_expanded[384:511];
      4:  round_key = key_expanded[512:639];
      5:  round_key = key_expanded[640:767];
      6:  round_key = key_expanded[768:895];
      7:  round_key = key_expanded[896:1023];
      8:  round_key = key_expanded[1024:1151];
      9:  round_key = key_expanded[1152:1279];
      10: round_key = key_expanded[1280:1407];
      default: round_key = 0;
    endcase
  end

  always_comb begin
    case (round_count)
      0:  inv_round_key = key_expanded[1280:1407];
      1:  inv_round_key = key_expanded[1152:1279];
      2:  inv_round_key = key_expanded[1024:1151];
      3:  inv_round_key = key_expanded[896:1023];
      4:  inv_round_key = key_expanded[768:895];
      5:  inv_round_key = key_expanded[640:767];
      6:  inv_round_key = key_expanded[512:639];
      7:  inv_round_key = key_expanded[384:511];
      8:  inv_round_key = key_expanded[256:383];
      9:  inv_round_key = key_expanded[128:255];
      10: inv_round_key = key_expanded[0:127];
      default: inv_round_key = 0;
    endcase
  end
  
  //Load Key Expansion
  always_comb begin
    case (w_count)
      1:  ktemp_in_rotword = key_expanded[96:127];
      2:  ktemp_in_rotword = key_expanded[224:255];
      3:  ktemp_in_rotword = key_expanded[352:383];
      4:  ktemp_in_rotword = key_expanded[480:511];
      5:  ktemp_in_rotword = key_expanded[608:639];
      6:  ktemp_in_rotword = key_expanded[736:767];
      7:  ktemp_in_rotword = key_expanded[864:895];
      8:  ktemp_in_rotword = key_expanded[992:1023];
      9:  ktemp_in_rotword = key_expanded[1120:1151];
      10: ktemp_in_rotword = key_expanded[1248:1279];
      default: ktemp_in_rotword = 0;
    endcase
  end
  
  logic [0:31] woffs [0:3];
  
  //4w caculate
  always_comb begin
    woffs[0] = key_expanded [(w_count*4-4)*32 +: 32] ^ ktemp_reg;
    woffs[1] = key_expanded [(w_count*4-3)*32 +: 32] ^ woffs[0];
    woffs[2] = key_expanded [(w_count*4-2)*32 +: 32] ^ woffs[1];
    woffs[3] = key_expanded [(w_count*4-1)*32 +: 32] ^ woffs[2];
  end 
  //xem lại đoạn này và sửa sau khi xong phần sau, w counter
  
  //Ktemp Reg
  always_ff @(posedge clk) begin
    if(ld_ktemp) begin
      ktemp_reg <= ktemp_after_addrcon;
    end 
  end 
  
  logic start_key_expansion;
  
  //Key Expanded Reg
  always_ff @(posedge clk) begin
    if(!rst) begin
      key_expanded <= 0;
    end
    else if(start && !running) begin
      key_expanded[0:127] <= key;
      key_expanded[128:1047] <= 0;
      start_key_expansion <= 1;
    end
    else if(ld_key_expanded  && running) begin
      key_expanded[(w_count*4)*32 +: 32] <= woffs[0];
      key_expanded[(w_count*4+1)*32 +: 32] <= woffs[1];
      key_expanded[(w_count*4+2)*32 +: 32] <= woffs[2];
      key_expanded[(w_count*4+3)*32 +: 32] <= woffs[3];
    end
  end
  
  logic ld_state;
  
  //State Reg
  always_ff @(posedge clk) begin
    if(!rst) begin
      state_reg <= 0;
    end
    if(start && !running) begin
      state_reg <= data_in;
    end
    else if(ld_state & inv) begin
      state_reg <= state_after_round_inv;
    end
    else if(ld_state) begin
      state_reg <= state_after_round;
    end
  end
  
  logic incr_w_count;
  
  //W Counter Reg
  logic ld_w_count;
  logic [5:0] w_count_in;
  
  always_ff @(posedge clk) begin
    if(!rst) begin
      w_count <= 1;
    end
    else if(incr_w_count) begin
      w_count <= w_count + 1;
    end
    else if(ld_w_count) begin
      w_count <= w_count_in + 1;
    end
  end
  
  //Round CounterReg
  logic incr_round_count;
  logic ld_round_count;
  logic [4:0] round_count_in;
  
  always_ff @(posedge clk) begin
    if(!rst) begin
      round_count <= 0;
    end
    else if(incr_round_count) begin
      round_count <= round_count + 1;
    end
    else if(ld_round_count) begin
      round_count <= round_count_in + 1;
    end
  end
     
  //Controlpath Key Expansion
  logic key_expansion_done;
  
  typedef enum logic [10:0] {
    IDLE_KE,
    TEMP_KE,
    ROUND_KE,
    DONE_KE
  } state_ke_t;
  
  state_ke_t state_ke, next_state_ke;
  
  always_ff @(posedge clk or negedge rst) begin
    if (!rst)
      state_ke <= IDLE_KE;
    else
      state_ke <= next_state_ke;
  end
  
  always_comb begin
    next_state_ke = state_ke;
    case(state_ke)
      IDLE_KE: begin
        if(start_key_expansion) begin
          next_state_ke = TEMP_KE;
        end 
        else
          next_state_ke = IDLE_KE;
      end
      TEMP_KE: begin
        next_state_ke = ROUND_KE;
      end
      ROUND_KE: begin
        if(w_count == 10) begin
          next_state_ke = DONE_KE;
        end
        else begin
          next_state_ke = TEMP_KE;
        end
      end
      DONE_KE: begin
      end
      default: begin
      end
    endcase
  end
  
  always_comb begin
    ld_ktemp = 0;
    incr_w_count = 0;
    ld_key_expanded = 0;
    key_expansion_done = 0;
    case(state_ke)
      IDLE_KE: begin
        if(start_key_expansion) begin
          ld_key_expansion_running = 1;
        end 
      end
      TEMP_KE: begin
        ld_ktemp = 1;
      end
      ROUND_KE: begin
        incr_w_count = 1;
        ld_key_expanded = 1;
        if(w_count == 10) begin
          clr_key_expansion_running = 1;
        end
      end
      DONE_KE: begin
        key_expansion_done = 1;
      end
      default: begin
      end
    endcase
  end
  
  
  //Controlpath Round
  typedef enum logic [3:0] {
    IDLE,
    KEY_EXPANSION,
    ROUND0,
    ROUND1TO9,
    ROUND10,
    DONE
  } state_t;

  state_t state, next_state;
  
  always_ff @(posedge clk or negedge rst) begin
    if (!rst)
      state <= IDLE;
    else
      state <= next_state;
  end
  
  always_comb begin
    next_state = state;
    case(state)
      IDLE: begin
        if(start) begin
          next_state = KEY_EXPANSION;
        end
      end
      KEY_EXPANSION: begin
        if(key_expansion_done) begin
          next_state = ROUND0;
        end
        else begin
          next_state = KEY_EXPANSION;
        end
      end
      ROUND0: begin
        next_state = ROUND1TO9;
      end
      ROUND1TO9: begin
        if(round_count == 9) begin
          next_state = ROUND10;
        end
        else begin
          next_state = ROUND1TO9;
        end
      end
      ROUND10: begin
        next_state = DONE;
      end
      DONE: begin
        if(!rst) begin
          next_state <= IDLE;
        end
      end
      default: begin
      end
    endcase
  end
  
  logic done;
  always_comb begin
    start_key_expansion = 0;
    mode_round0 = 0;
    mode_normal = 0;
    mode_round10 = 0;
    incr_round_count = 0;
    ld_state = 0;
    done = 0;
    case(state)
      IDLE: begin
        if(start) begin
          start_key_expansion = 1;
        end
      end
      KEY_EXPANSION: begin
        if(key_expansion_done) begin
          ld_round_running = 1;
        end
      end
      ROUND0: begin
        ld_state = 1;
        mode_round0 = 1;
        incr_round_count = 1;
      end
      ROUND1TO9: begin
        ld_state = 1;
        mode_normal = 1;
        incr_round_count = 1;
      end
      ROUND10: begin
        ld_state = 1;
        mode_round10 = 1;
        clr_round_running = 1;
      end
      DONE: begin
        done = 1;
      end
      default: begin
      end
    endcase
  end
  
  assign data_out = state_reg;
      
   
endmodule
