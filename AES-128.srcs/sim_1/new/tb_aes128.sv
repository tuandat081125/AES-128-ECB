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


//-------------------------------------------
// Interface chính (port của DUT)
//-------------------------------------------
interface aes_if (input logic clk, input logic rst);
  logic         inv;
  logic [0:127] data_in;
  logic [0:127] key;
  logic [0:127] data_out;
  logic         start;
  logic         data_out_ready;
  logic         busy;

  clocking drv_cb @(posedge clk);
    default input #1step output #1;
    output inv, data_in, key, start;
    input  data_out, data_out_ready, busy;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input inv, data_in, key, start, data_out, data_out_ready, busy;
  endclocking
  
endinterface

//-------------------------------------------
// Probe interface
//-------------------------------------------
interface aes_probe_if (
  input logic         clk,
  input logic [3:0]   fsm_state,        // IDLE=0 KEY_EXP=1 ROUND0=2 R1TO9=3 ROUND10=4 DONE=5
  input logic [4:0]   round_count,
  input logic         ld_state,
  input logic [0:127] state_reg,

  // Encrypt path
  input logic [0:127] after_subbytes,
  input logic [0:127] after_shiftrows,
  input logic [0:127] after_mixcolumns,
  input logic [0:127] after_addroundkey,

  // Decrypt path (inverse)
  input logic [0:127] after_inv_subbytes,
  input logic [0:127] after_inv_shiftrows,
  input logic [0:127] after_inv_mixcolumns,
  input logic [0:127] after_inv_addroundkey,

  input logic [0:127] round_key,
  input logic [0:127] inv_round_key
);
  clocking mon_cb @(posedge clk);
    default input #1step;
    input fsm_state, round_count, ld_state, state_reg,
          after_subbytes, after_shiftrows, after_mixcolumns,
          after_addroundkey,
          after_inv_subbytes, after_inv_shiftrows, after_inv_mixcolumns,
          after_inv_addroundkey,
          round_key, inv_round_key;
  endclocking

endinterface

//-------------------------------------------
// Bind
//-------------------------------------------
bind aes128 aes_probe_if obs (
  .clk                   (clk),
  .fsm_state             (state),
  .round_count           (round_count),
  .ld_state              (ld_state),
  .state_reg             (state_reg),

  // Encrypt path
  .after_subbytes        (state_after_subbytes),
  .after_shiftrows       (state_after_shiftrows),
  .after_mixcolumns      (state_after_mixcolumns),
  .after_addroundkey     (state_after_addroundkey),

  // Decrypt path (inverse)
  .after_inv_subbytes    (state_after_inv_subbytes),
  .after_inv_shiftrows   (state_after_inv_shiftrows),
  .after_inv_mixcolumns  (state_after_inv_mixcolumns),
  .after_inv_addroundkey (state_after_inv_addroundkey),

  .round_key             (round_key),
  .inv_round_key         (inv_round_key)
);

//-------------------------------------------
// Transaction
//-------------------------------------------
class aes_txn;
  rand bit [127:0] key;
  rand bit [127:0] data_in;
  rand bit         inv;
  bit      [127:0] data_out;      // kết quả DUT, monitor điền

  function string sprint();
    return $sformatf("inv=%0b key=%h data_in=%h data_out=%h", inv, key, data_in, data_out);
  endfunction
  
endclass

//-------------------------------------------
// Internal State
//-------------------------------------------
class internal_state;
  logic inv;
  logic [0:127] state_in;
  logic [0:127] after_subbytes   [1:10];
  logic [0:127] after_shiftrows  [1:10];
  logic [0:127] after_mixcolumns [1:9];
  logic [0:127] after_addroundkey [0:10];
  logic [0:127] round_key [0:10];
  
endclass

//-------------------------------------------
//Generator
//-------------------------------------------
class aes_generator;
  mailbox #(aes_txn) gen2drv;

  function new(mailbox #(aes_txn) m); 
    gen2drv = m; 
  endfunction

  task run_vector_c();
    aes_txn t;
    // directed: vector FIPS-197 C.1
    t = new(); 
    t.key = 128'h000102030405060708090a0b0c0d0e0f;
    t.data_in = 128'h00112233445566778899aabbccddeeff; t.inv = 0;
    gen2drv.put(t);
    
    t = new(); 
    t.key = 128'h000102030405060708090a0b0c0d0e0f;
    t.data_in = 128'h69c4e0d86a7b0430d8cdb78070b4c55a; t.inv = 1;
    gen2drv.put(t);
  endtask
    
  
endclass

//-------------------------------------------
//Driver
//-------------------------------------------
class aes_driver;
  virtual aes_if vif;
  mailbox #(aes_txn) gen2drv;

  function new(virtual aes_if v, mailbox #(aes_txn) m);
    vif = v; gen2drv = m;
  endfunction

  task run();
    aes_txn t;
    forever begin
      gen2drv.get(t);
      @(vif.drv_cb);
      vif.drv_cb.key   <= t.key;
      vif.drv_cb.data_in   <= t.data_in;
      vif.drv_cb.inv  <= t.inv;
      vif.drv_cb.start <= 1'b1;
      @(vif.drv_cb);
      vif.drv_cb.start <= 1'b0;
      wait (vif.drv_cb.data_out_ready);       // chờ DUT xong rồi mới nhận txn tiếp
    end
  endtask
  
endclass

//-------------------------------------------
//Monitor
//-------------------------------------------
class aes_monitor;
  virtual aes_if vif;
  mailbox #(aes_txn) mon2scb;

  function new(virtual aes_if v, mailbox #(aes_txn) m);
    vif = v; mon2scb = m;
  endfunction

  task run();
    aes_txn t;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.start) begin
        t = new();
        t.key = vif.mon_cb.key; 
        t.data_in = vif.mon_cb.data_in; 
        t.inv = vif.mon_cb.inv;
        do @(vif.mon_cb); 
        while (!vif.mon_cb.data_out_ready);
        t.data_out = vif.mon_cb.data_out;
        mon2scb.put(t);
      end
    end
  endtask
  
endclass

//-------------------------------------------
//Internal Monitor
//-------------------------------------------
class aes_internal_monitor;
  virtual aes_if vif;
  virtual aes_probe_if pvif;
  
  mailbox #(internal_state) mon2scb;

  function new(virtual aes_if v, mailbox #(internal_state) m, virtual aes_probe_if pv);
    vif = v; mon2scb = m; pvif = pv;
  endfunction

  task run();
    aes_txn t;
    internal_state s;
    
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.start) begin
        t = new();
        s = new();
       
        s.state_in = vif.mon_cb.data_in;
        s.inv = vif.mon_cb.inv;
        
        forever begin
        @(pvif.mon_cb);
        if (pvif.mon_cb.ld_state) begin 
          if (pvif.mon_cb.round_count == 0) begin
            if (s.inv == 1) begin
              s.after_addroundkey[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_addroundkey;
              s.round_key[pvif.mon_cb.round_count] = pvif.mon_cb.inv_round_key;
            end
            else begin
              s.after_addroundkey[pvif.mon_cb.round_count] = pvif.mon_cb.after_addroundkey;
              s.round_key[pvif.mon_cb.round_count] = pvif.mon_cb.round_key;
            end
          end
          else if (pvif.mon_cb.round_count > 0 && pvif.mon_cb.round_count < 10) begin
            if (s.inv == 1) begin
              s.after_subbytes[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_subbytes;
              s.after_shiftrows[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_shiftrows;
              s.after_mixcolumns[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_mixcolumns;  
              s.after_addroundkey[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_addroundkey;
              s.round_key[pvif.mon_cb.round_count] = pvif.mon_cb.inv_round_key;
            end
            else begin
              s.after_subbytes[pvif.mon_cb.round_count] = pvif.mon_cb.after_subbytes;
              s.after_shiftrows[pvif.mon_cb.round_count] = pvif.mon_cb.after_shiftrows;
              s.after_mixcolumns[pvif.mon_cb.round_count] = pvif.mon_cb.after_mixcolumns;  
              s.after_addroundkey[pvif.mon_cb.round_count] = pvif.mon_cb.after_addroundkey;
              s.round_key[pvif.mon_cb.round_count] = pvif.mon_cb.round_key;
            end
          end   
          else if (pvif.mon_cb.round_count == 10) begin
            if (s.inv == 1) begin
              s.after_subbytes[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_subbytes;
              s.after_shiftrows[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_shiftrows; 
              s.after_addroundkey[pvif.mon_cb.round_count] = pvif.mon_cb.after_inv_addroundkey;
              s.round_key[pvif.mon_cb.round_count] = pvif.mon_cb.inv_round_key;
            end
            else begin
              s.after_subbytes[pvif.mon_cb.round_count] = pvif.mon_cb.after_subbytes;
              s.after_shiftrows[pvif.mon_cb.round_count] = pvif.mon_cb.after_shiftrows; 
              s.after_addroundkey[pvif.mon_cb.round_count] = pvif.mon_cb.after_addroundkey;
              s.round_key[pvif.mon_cb.round_count] = pvif.mon_cb.round_key;
            end
            break;
          end             
        end
        end
        
        mon2scb.put(s);
      
      end
    end
  endtask
  
endclass

//-------------------------------------------
//Reference model
//-------------------------------------------
class aes_ref_model;
  internal_state s;

  function new();
  endfunction
  
  function bit [0:127] compute(bit [127:0] key, bit [127:0] din, bit mode);
    // TODO
    return '0;
  endfunction
  
  function internal_state get_vector(bit inv);
    s = new();
    if (inv == 0) begin
      // ENCRYPT (FIPS-197 C.1, AES-128)
      s.state_in = 128'h00112233445566778899aabbccddeeff;
      s.after_addroundkey[0]  = 128'h00102030405060708090a0b0c0d0e0f0;
      s.after_subbytes[1]    = 128'h63cab7040953d051cd60e0e7ba70e18c;
      s.after_shiftrows[1]   = 128'h6353e08c0960e104cd70b751bacad0e7;
      s.after_mixcolumns[1]  = 128'h5f72641557f5bc92f7be3b291db9f91a;
      s.after_addroundkey[1]  = 128'h89d810e8855ace682d1843d8cb128fe4;
      s.after_subbytes[2]    = 128'ha761ca9b97be8b45d8ad1a611fc97369;
      s.after_shiftrows[2]   = 128'ha7be1a6997ad739bd8c9ca451f618b61;
      s.after_mixcolumns[2]  = 128'hff87968431d86a51645151fa773ad009;
      s.after_addroundkey[2]  = 128'h4915598f55e5d7a0daca94fa1f0a63f7;
      s.after_subbytes[3]    = 128'h3b59cb73fcd90ee05774222dc067fb68;
      s.after_shiftrows[3]   = 128'h3bd92268fc74fb735767cbe0c0590e2d;
      s.after_mixcolumns[3]  = 128'h4c9c1e66f771f0762c3f868e534df256;
      s.after_addroundkey[3]  = 128'hfa636a2825b339c940668a3157244d17;
      s.after_subbytes[4]    = 128'h2dfb02343f6d12dd09337ec75b36e3f0;
      s.after_shiftrows[4]   = 128'h2d6d7ef03f33e334093602dd5bfb12c7;
      s.after_mixcolumns[4]  = 128'h6385b79ffc538df997be478e7547d691;
      s.after_addroundkey[4]  = 128'h247240236966b3fa6ed2753288425b6c;
      s.after_subbytes[5]    = 128'h36400926f9336d2d9fb59d23c42c3950;
      s.after_shiftrows[5]   = 128'h36339d50f9b539269f2c092dc4406d23;
      s.after_mixcolumns[5]  = 128'hf4bcd45432e554d075f1d6c51dd03b3c;
      s.after_addroundkey[5]  = 128'hc81677bc9b7ac93b25027992b0261996;
      s.after_subbytes[6]    = 128'he847f56514dadde23f77b64fe7f7d490;
      s.after_shiftrows[6]   = 128'he8dab6901477d4653ff7f5e2e747dd4f;
      s.after_mixcolumns[6]  = 128'h9816ee7400f87f556b2c049c8e5ad036;
      s.after_addroundkey[6]  = 128'hc62fe109f75eedc3cc79395d84f9cf5d;
      s.after_subbytes[7]    = 128'hb415f8016858552e4bb6124c5f998a4c;
      s.after_shiftrows[7]   = 128'hb458124c68b68a014b99f82e5f15554c;
      s.after_mixcolumns[7]  = 128'hc57e1c159a9bd286f05f4be098c63439;
      s.after_addroundkey[7]  = 128'hd1876c0f79c4300ab45594add66ff41f;
      s.after_subbytes[8]    = 128'h3e175076b61c04678dfc2295f6a8bfc0;
      s.after_shiftrows[8]   = 128'h3e1c22c0b6fcbf768da85067f6170495;
      s.after_mixcolumns[8]  = 128'hbaa03de7a1f9b56ed5512cba5f414d23;
      s.after_addroundkey[8]  = 128'hfde3bad205e5d0d73547964ef1fe37f1;
      s.after_subbytes[9]    = 128'h5411f4b56bd9700e96a0902fa1bb9aa1;
      s.after_shiftrows[9]   = 128'h54d990a16ba09ab596bbf40ea111702f;
      s.after_mixcolumns[9]  = 128'he9f74eec023020f61bf2ccf2353c21c7;
      s.after_addroundkey[9]  = 128'hbd6e7c3df2b5779e0b61216e8b10b689;
      s.after_subbytes[10]   = 128'h7a9f102789d5f50b2beffd9f3dca4ea7;
      s.after_shiftrows[10]  = 128'h7ad5fda789ef4e272bca100b3d9ff59f;
      s.after_addroundkey[10] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
      // Round keys (FIPS-197 A.1, applied order K0..K10)
      s.round_key[0]  = 128'h000102030405060708090a0b0c0d0e0f;
      s.round_key[1]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
      s.round_key[2]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
      s.round_key[3]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
      s.round_key[4]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
      s.round_key[5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
      s.round_key[6]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;
      s.round_key[7]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;
      s.round_key[8]  = 128'h47438735a41c65b9e016baf4aebf7ad2;
      s.round_key[9]  = 128'h549932d1f08557681093ed9cbe2c974e;
      s.round_key[10] = 128'h13111d7fe3944a17f307a78b4d2b30c5;
    end
    else begin
      // DECRYPT (Inverse Cipher): InvShiftRows -> InvSubBytes -> AddRoundKey -> InvMixColumns
      s.state_in = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;
      s.after_addroundkey[0]  = 128'h7ad5fda789ef4e272bca100b3d9ff59f;
      s.after_shiftrows[1]   = 128'h7a9f102789d5f50b2beffd9f3dca4ea7;
      s.after_subbytes[1]    = 128'hbd6e7c3df2b5779e0b61216e8b10b689;
      s.after_addroundkey[1]  = 128'he9f74eec023020f61bf2ccf2353c21c7;
      s.after_mixcolumns[1]  = 128'h54d990a16ba09ab596bbf40ea111702f;
      s.after_shiftrows[2]   = 128'h5411f4b56bd9700e96a0902fa1bb9aa1;
      s.after_subbytes[2]    = 128'hfde3bad205e5d0d73547964ef1fe37f1;
      s.after_addroundkey[2]  = 128'hbaa03de7a1f9b56ed5512cba5f414d23;
      s.after_mixcolumns[2]  = 128'h3e1c22c0b6fcbf768da85067f6170495;
      s.after_shiftrows[3]   = 128'h3e175076b61c04678dfc2295f6a8bfc0;
      s.after_subbytes[3]    = 128'hd1876c0f79c4300ab45594add66ff41f;
      s.after_addroundkey[3]  = 128'hc57e1c159a9bd286f05f4be098c63439;
      s.after_mixcolumns[3]  = 128'hb458124c68b68a014b99f82e5f15554c;
      s.after_shiftrows[4]   = 128'hb415f8016858552e4bb6124c5f998a4c;
      s.after_subbytes[4]    = 128'hc62fe109f75eedc3cc79395d84f9cf5d;
      s.after_addroundkey[4]  = 128'h9816ee7400f87f556b2c049c8e5ad036;
      s.after_mixcolumns[4]  = 128'he8dab6901477d4653ff7f5e2e747dd4f;
      s.after_shiftrows[5]   = 128'he847f56514dadde23f77b64fe7f7d490;
      s.after_subbytes[5]    = 128'hc81677bc9b7ac93b25027992b0261996;
      s.after_addroundkey[5]  = 128'hf4bcd45432e554d075f1d6c51dd03b3c;
      s.after_mixcolumns[5]  = 128'h36339d50f9b539269f2c092dc4406d23;
      s.after_shiftrows[6]   = 128'h36400926f9336d2d9fb59d23c42c3950;
      s.after_subbytes[6]    = 128'h247240236966b3fa6ed2753288425b6c;
      s.after_addroundkey[6]  = 128'h6385b79ffc538df997be478e7547d691;
      s.after_mixcolumns[6]  = 128'h2d6d7ef03f33e334093602dd5bfb12c7;
      s.after_shiftrows[7]   = 128'h2dfb02343f6d12dd09337ec75b36e3f0;
      s.after_subbytes[7]    = 128'hfa636a2825b339c940668a3157244d17;
      s.after_addroundkey[7]  = 128'h4c9c1e66f771f0762c3f868e534df256;
      s.after_mixcolumns[7]  = 128'h3bd92268fc74fb735767cbe0c0590e2d;
      s.after_shiftrows[8]   = 128'h3b59cb73fcd90ee05774222dc067fb68;
      s.after_subbytes[8]    = 128'h4915598f55e5d7a0daca94fa1f0a63f7;
      s.after_addroundkey[8]  = 128'hff87968431d86a51645151fa773ad009;
      s.after_mixcolumns[8]  = 128'ha7be1a6997ad739bd8c9ca451f618b61;
      s.after_shiftrows[9]   = 128'ha761ca9b97be8b45d8ad1a611fc97369;
      s.after_subbytes[9]    = 128'h89d810e8855ace682d1843d8cb128fe4;
      s.after_addroundkey[9]  = 128'h5f72641557f5bc92f7be3b291db9f91a;
      s.after_mixcolumns[9]  = 128'h6353e08c0960e104cd70b751bacad0e7;
      s.after_shiftrows[10]  = 128'h63cab7040953d051cd60e0e7ba70e18c;
      s.after_subbytes[10]   = 128'h00102030405060708090a0b0c0d0e0f0;
      s.after_addroundkey[10] = 128'h00112233445566778899aabbccddeeff;
      // Round keys (FIPS-197 A.1, applied order K10..K0 for decryption)
      s.round_key[0]  = 128'h13111d7fe3944a17f307a78b4d2b30c5;
      s.round_key[1]  = 128'h549932d1f08557681093ed9cbe2c974e;
      s.round_key[2]  = 128'h47438735a41c65b9e016baf4aebf7ad2;
      s.round_key[3]  = 128'h14f9701ae35fe28c440adf4d4ea9c026;
      s.round_key[4]  = 128'h5e390f7df7a69296a7553dc10aa31f6b;
      s.round_key[5]  = 128'h3caaa3e8a99f9deb50f3af57adf622aa;
      s.round_key[6]  = 128'h47f7f7bc95353e03f96c32bcfd058dfd;
      s.round_key[7]  = 128'hb6ff744ed2c2c9bf6c590cbf0469bf41;
      s.round_key[8]  = 128'hb692cf0b643dbdf1be9bc5006830b3fe;
      s.round_key[9]  = 128'hd6aa74fdd2af72fadaa678f1d6ab76fe;
      s.round_key[10] = 128'h000102030405060708090a0b0c0d0e0f;
    end
    return s;
  endfunction
  
endclass

//-------------------------------------------
//Scoreboard
//-------------------------------------------
class aes_scoreboard;
  mailbox #(aes_txn) mon2scb;
  aes_ref_model      model = new();
  int pass_cnt, fail_cnt;

  function new(mailbox #(aes_txn) m); mon2scb = m; endfunction

  task run();
    aes_txn t;
    bit [127:0] exp;
    forever begin
      mon2scb.get(t);
      exp = model.compute(t.key, t.data_in, t.inv);
      if (t.data_out === exp) pass_cnt++;
      else begin
        fail_cnt++;
        $error("MISMATCH %s exp=%h", t.sprint(), exp);
      end
    end
  endtask

  function void report();
    $display("SCOREBOARD: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
  endfunction
endclass

//-------------------------------------------
//Internal Scoreboard
//-------------------------------------------
class aes_internal_scoreboard;
  mailbox #(internal_state) mon2scb;
  aes_ref_model      model = new();
  int pass_cnt, fail_cnt;

  function new(mailbox #(internal_state) m); 
    mon2scb = m; 
  endfunction

  task run();
    internal_state s;
    internal_state exp;
    int round;
    forever begin
      mon2scb.get(s);
      exp = model.get_vector(s.inv);
      round = 0;
      
      for(int round = 0; round <= 10; round++) begin
        if (round == 0)
          if (s.state_in === exp.state_in) pass_cnt++;
          else begin
            fail_cnt++;
            $error("MISMATCH STATE IN got=%h exp=%h", s.state_in, exp.state_in);
          end
        if (s.round_key[round] === exp.round_key[round]) pass_cnt++;
        else begin
          fail_cnt++;
          $error("MISMATCH ROUND KEY round=%0d got=%h exp=%h", round, s.round_key[round], exp.round_key[round]);
        end
        if (round != 0) begin
          if (s.after_subbytes[round] === exp.after_subbytes[round]) pass_cnt++;
          else begin
            fail_cnt++;
            $error("MISMATCH SUBBYTES round=%0d got=%h exp=%h", round, s.after_subbytes[round], exp.after_subbytes[round]);
          end
          if (s.after_shiftrows[round] === exp.after_shiftrows[round]) pass_cnt++;
          else begin
            fail_cnt++;
            $error("MISMATCH SHIFTROWS round=%0d got=%h exp=%h", round, s.after_shiftrows[round], exp.after_shiftrows[round]);
          end
        end
        if (round != 0 && round != 10) begin
          if (s.after_mixcolumns[round] === exp.after_mixcolumns[round]) pass_cnt++;
          else begin
            fail_cnt++;
            $error("MISMATCH MIXCOLUMNS round=%0d got=%h exp=%h", round, s.after_mixcolumns[round], exp.after_mixcolumns[round]);
          end
        end
        if (s.after_addroundkey[round] === exp.after_addroundkey[round]) pass_cnt++;
        else begin
          fail_cnt++;
          $error("MISMATCH ADDROUNDKEY round=%0d got=%h exp=%h", round, s.after_addroundkey[round], exp.after_addroundkey[round]);
        end
      end
    end
  endtask

  function void report();
    $display("SCOREBOARD: PASS=%0d FAIL=%0d", pass_cnt, fail_cnt);
  endfunction
endclass

//-------------------------------------------
//Environment
//-------------------------------------------
class aes_env;
  aes_generator  gen;
  aes_driver     drv;
  aes_monitor    mon;
  aes_scoreboard scb;
  aes_internal_monitor in_mon; 
  aes_internal_scoreboard in_scb;
  
  
  mailbox #(aes_txn) gen2drv = new();
  mailbox #(aes_txn) mon2scb = new();
  
  mailbox #(internal_state) in_mon2scb = new();

  function new(virtual aes_if vif, virtual aes_probe_if pvif);
    gen = new(gen2drv);
    drv = new(vif, gen2drv);
    mon = new(vif, mon2scb);
    scb = new(mon2scb);
    
    in_mon = new(vif, in_mon2scb, pvif);
    in_scb = new(in_mon2scb);
  endfunction

  task run();
    fork
      gen.run_vector_c(); drv.run(); mon.run(); scb.run(); in_mon.run(); in_scb.run();
    join_none

    fork
      begin
        #5000;
        $error("TIMEOUT: in_scb pass=%0d fail=%0d, scb pass=%0d fail=%0d",
               in_scb.pass_cnt, in_scb.fail_cnt, scb.pass_cnt, scb.fail_cnt);
      end
    join_any
    disable fork;

    scb.report();
    in_scb.report();
  endtask
endclass


//-------------------------------------------
// Top
//-------------------------------------------
module tb_aes128;

  logic clk;
  logic rst;                       // active low

  initial clk = 0;
  always #5 clk = ~clk;

  aes_if aif (clk, rst);

  aes128 dut (
    .clk           (clk),
    .rst           (rst),
    .inv           (aif.inv),
    .data_in       (aif.data_in),
    .key           (aif.key),
    .data_out      (aif.data_out),
    .start         (aif.start),
    .data_out_ready(aif.data_out_ready),
    .busy          (aif.busy)
  );

  // Lấy "con trỏ" tới probe đã bind (tên instance là obs)
  virtual aes_probe_if pvif;
  initial pvif = dut.obs;

  initial begin
    aes_env env;
    rst = 0;
    pvif = dut.obs;
    env  = new(aif, pvif);
    #20 rst = 1;
    env.run();
    $finish;
  end

endmodule
