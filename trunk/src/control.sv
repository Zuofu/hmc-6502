// control.sv
// control FSM and opcode ROM for hmc-6502 CPU
// 31oct07
// tbarr at cs hmc edu

`timescale 1 ns / 1 ps
`default_nettype none

// always kept in this order!
parameter C_STATE_WIDTH = 32;
parameter C_OP_WIDTH = 14;
parameter C_INT_WIDTH = 12; // total width of internal state signals

parameter BRANCH_TAKEN_STATE = 8'd63;
parameter BRANCH_NOT_TAKEN_STATE = 8'd00;

parameter C_TOTAL = (C_STATE_WIDTH + C_OP_WIDTH + C_INT_WIDTH);

module control(input logic [7:0] data_in, p,
               input logic ph1, ph2, reset,
               output logic [7:0] op_flags,
               output logic [(C_STATE_WIDTH + C_OP_WIDTH - 1):0] controls_s1);
               
  // all controls become valid on ph1, and hold through end of ph2.
  logic [7:0] latched_opcode;
  logic first_cycle, last_cycle, c_op_sel, last_cycle_s2;
  
  logic [(C_OP_WIDTH - 1):0] c_op_state, c_op_opcode;
  logic [(C_OP_WIDTH - 1):0] c_op_selected;
  logic [(C_STATE_WIDTH - 1):0] c_state;
  
  logic branch_polarity, branch_taken;
  
  logic [7:0] state, next_state, next_state_states, next_state_opcode;
  logic [7:0] next_state_s2;
  logic [7:0] next_state_branch;
  logic [1:0] next_state_sel;
  
  // opcode logic
  latch #1 opcode_lat_p1(last_cycle, last_cycle_s2, ph1);
  latch #1 opcode_lat_p2(last_cycle_s2, first_cycle, ph2);
  latchen #8 opcode_buf(data_in, latched_opcode, ph1, first_cycle);
  opcode_pla opcode_pla(latched_opcode, {c_op_opcode, branch_polarity, 
                                         op_flags, next_state_opcode});
  
  // branch logic
  // - p is stable 1, but won't be written on the branch op.
  // - the paranoid would add a latch to make it stable 2.
  branchlogic branchlogic(p, op_flags, branch_polarity, branch_taken);
  mux2 #8 branch_state_sel(BRANCH_NOT_TAKEN_STATE, 
                           BRANCH_TAKEN_STATE, branch_taken, next_state_branch);
  
  // next state logic
  mux3 #8 next_state_mux(next_state_states, next_state_opcode, next_state_branch,
                         next_state_sel, next_state);
  
  // state PLA
  latchr #8 state_lat_p1(next_state, next_state_s2, ph1, reset);
  latchr #8 state_lat_p2(next_state_s2, state, ph2, reset);
  
  state_pla state_pla(state, {c_state, c_op_state, {last_cycle,
                                                    c_op_sel,
                                                    next_state_sel,
                                                    next_state_states}});
  
  // opcode specific controls
  mux2 #(C_OP_WIDTH) func_mux(c_op_state, c_op_opcode, c_op_sel, c_op_selected);
  
  // output
  latch #(C_STATE_WIDTH + C_OP_WIDTH) controls_latch({c_state, c_op_selected}, controls_s1,
                        ph1);
endmodule

module state_pla(input logic [7:0] state,
                 output logic [(C_TOTAL - 1):0] out_controls);
  always_comb
  case(state)
// reset:0
8'd000 : out_controls <= 58'b10000010001100000001001111110000_00000000000000_000000000001;
8'd001 : out_controls <= 58'b00000000101100100101001100000000_00000000000000_100000000010;

// base:2
8'd002 : out_controls <= 58'b00000010101000000001001000000000_00001000000000_000100000010;

// none:3
8'd003 : out_controls <= 58'b00000010101000000001001000000000_00000000000000_100000000010;

// single_byte:4
8'd004 : out_controls <= 58'b00000000001000000000011000000000_00000000000000_110000000010;

// imm:5
8'd005 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_110000000010;

// mem_ex_zpa:6
8'd006 : out_controls <= 58'b00000000001001000101001000000000_00001000000000_000000000111;
8'd007 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_110000000010;

// mem_wr_zpa:8
8'd008 : out_controls <= 58'b00000000001011000101000000000000_00001000000000_010000001001;
8'd009 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_100000000010;

// mem_wr_abs:10
8'd010 : out_controls <= 58'b00100010101000000001001000000000_00001000000000_000000001011;
8'd011 : out_controls <= 58'b00000000001010011001000000000000_00001000000000_010000001100;
8'd012 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_100000000010;

// abs:13
8'd013 : out_controls <= 58'b00100010101000000001001000000000_00001000000000_000000001110;
8'd014 : out_controls <= 58'b00000000001000011001001000000000_00001000000000_000000001111;
8'd015 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_110000000010;

// indirect_x:16
8'd016 : out_controls <= 58'b00000000001001000101001000000000_00101000010000_000000010001;
8'd017 : out_controls <= 58'b00100000001001000001001000000000_00001000000000_000000010010;
8'd018 : out_controls <= 58'b00000000001001000101101000000000_00101000010000_000000010011;
8'd019 : out_controls <= 58'b00000000001000011001001000000000_00001000000000_000000010100;
8'd020 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_110000000010;

// abs_x:21
8'd021 : out_controls <= 58'b00100010101000000001001000000000_00101000010000_000000010110;
8'd022 : out_controls <= 58'b00000000001000011000101000000000_00001000000000_000000010111;
8'd023 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_110000000010;

// zp_x:24
8'd024 : out_controls <= 58'b00000000001001000101001000000000_00101000010000_000000011001;
8'd025 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_110000000010;

// indirect_y:26
8'd026 : out_controls <= 58'b00000000001001000101001000000000_00001000000000_000000011011;
8'd027 : out_controls <= 58'b00100000001000000001001000000000_00001000000000_000000011100;
8'd028 : out_controls <= 58'b00000000001001000101101000000000_00001000000000_000000011101;
8'd029 : out_controls <= 58'b10000000001000011001001000000000_00001000000000_000000011110;
8'd030 : out_controls <= 58'b00110000001000100101001000000000_00100000100000_000000011111;
8'd031 : out_controls <= 58'b11000000001000011000101000000000_00000000000000_000000100000;
8'd032 : out_controls <= 58'b00000010101000000000011000000000_00001000000000_110000000010;

// push:33
8'd033 : out_controls <= 58'b00000000001001010101100000000000_00010111001110_010000100010;
8'd034 : out_controls <= 58'b00000000001000000000001000000000_00000000000000_100000000010;

// pull:35
8'd035 : out_controls <= 58'b00000000001001010101001000000000_00000011000010_000000100100;
8'd036 : out_controls <= 58'b00000000001000000001001000000000_00001000000000_010000100101;
8'd037 : out_controls <= 58'b00000010101000000001101000000000_00000111001110_100000000010;

// jsr:38
8'd038 : out_controls <= 58'b00100010101000000001001000000000_00001000000000_000000100111;
8'd039 : out_controls <= 58'b10000000001000000001001000000000_00001000000000_000000101000;
8'd040 : out_controls <= 58'b00000001001001010101100000000000_00010111001110_000000101001;
8'd041 : out_controls <= 58'b00000000011000101001100000000000_00010111001110_000000101010;
8'd042 : out_controls <= 58'b00010000101100000001001000000000_00000000000000_000000101011;
8'd043 : out_controls <= 58'b01000010001100101001001000000000_00000000000000_100000000010;

// jmp_abs:44
8'd044 : out_controls <= 58'b00100010101000000001001000000000_00001000000000_000000101101;
8'd045 : out_controls <= 58'b10000010001100011001001000000000_00001000000000_000000101110;
8'd046 : out_controls <= 58'b00010000101100101001001000000000_00000000000000_100000000010;

// jmp_ind:47
8'd047 : out_controls <= 58'b00100010101000000001001000000000_00001000000000_000000110000;
8'd048 : out_controls <= 58'b10000000001000011001001000000000_00001000000000_000000110001;
8'd049 : out_controls <= 58'b00000000101100000001001000000000_00001000000000_000000110010;
8'd050 : out_controls <= 58'b00010000001000100101101000000000_00000000000000_000000110011;
8'd051 : out_controls <= 58'b00000010001100010001001000000000_00001000000000_100000000010;

// rts:52
8'd052 : out_controls <= 58'b00000000001001010101001000000000_00000011000010_000000110101;
8'd053 : out_controls <= 58'b00000000101100000001001000000000_00001000000000_000000110110;
8'd054 : out_controls <= 58'b00000000001001010101101000000000_00010111001110_000000110111;
8'd055 : out_controls <= 58'b00000010001100000001001000000000_00001000000000_000000111000;
8'd056 : out_controls <= 58'b00000010101000000001101000000000_00010111001110_100000000010;

// rti:57
8'd057 : out_controls <= 58'b00000000001001010101001000000000_00000011000010_000000111010;
8'd058 : out_controls <= 58'b00000000001000000001011000000000_00001000000000_000000111011;
8'd059 : out_controls <= 58'b00000000001001010101101000000000_00010111001110_000000111100;
8'd060 : out_controls <= 58'b00000000101100000001001000000000_00001000000000_000000111101;
8'd061 : out_controls <= 58'b00000000001001010101101000000000_00010111001110_000000111110;
8'd062 : out_controls <= 58'b00000010001100000001001000000000_00001000000000_000000111111;
8'd063 : out_controls <= 58'b00000010101000000001101000000000_00010111001110_100000000010;

// branch_head:64
8'd064 : out_controls <= 58'b00100010111000000001001000000000_00101000000000_101000000010;

// branch_taken:65
8'd065 : out_controls <= 58'b10000011001100000000001100000000_00000000000000_000001000010;
8'd066 : out_controls <= 58'b00010000101100101001001000000000_00000000000000_100000000010;
      default: out_controls <= 'x;
    endcase
endmodule

module opcode_pla(input logic [7:0] opcode,
                 output logic [(C_OP_WIDTH + 17 - 1):0] out_data);
  always_comb
  case(opcode)
    8'h69: out_data <= 31'b0010_1_1_00_00_00_0_1__0_00000010_00000101;
    8'h65: out_data <= 31'b0010_1_1_00_00_00_0_1__0_00000000_00000110;
    8'h85: out_data <= 31'b0000_1_0_00_00_00_0_1__0_00000000_00001000;
    8'h85: out_data <= 31'b0000_1_0_00_00_00_0_1__0_00000000_00001000;
    8'h8d: out_data <= 31'b0000_1_0_00_00_00_0_1__0_00000000_00001010;
    8'hf0: out_data <= 31'b0010_0_0_00_00_00_0_0__0_00000010_01000000;
    8'h00: out_data <= 31'b0010_0_0_00_00_00_0_0__0_00000000_00000000;
    default: out_data <= 'x;
  endcase
endmodule