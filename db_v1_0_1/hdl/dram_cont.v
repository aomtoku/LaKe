//
// Copyright (C) 2019 Yuta Tokusashi
// All rights reserved.
//
// This software was developed by
// Stanford University and the University of Cambridge Computer Laboratory
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@
//
`timescale 1ps/100fs

module dram_cont #(
	parameter C_M_AXIS_DATA_WIDTH    = 512,
	parameter C_S_AXIS_DATA_WIDTH    = 512,
	parameter C_M_AXIS_TUSER_WIDTH   = 128,
	parameter C_S_AXIS_TUSER_WIDTH   = 128,
	parameter C_M_AXIS_TDEST_WIDTH   = 3,
	parameter C_S_AXIS_TDEST_WIDTH   = 3,
	parameter CK_WIDTH              = 1,
	parameter nCS_PER_RANK          = 1,
	parameter CKE_WIDTH             = 1,
	parameter DM_WIDTH              = 8,
	parameter ODT_WIDTH             = 1,
	parameter BANK_WIDTH            = 3,
	parameter COL_WIDTH             = 10,
	parameter CS_WIDTH              = 1,
	parameter DQ_WIDTH              = 64,
	parameter DQS_WIDTH             = 8,
	parameter DQS_CNT_WIDTH         = 3,
	parameter DRAM_WIDTH            = 8,
	parameter ECC                   = "OFF",
	parameter ECC_TEST              = "OFF",
	parameter nBANK_MACHS           = 4,
	parameter RANKS                 = 1,
	parameter ROW_WIDTH             = 16,
	parameter ADDR_WIDTH            = 30,
	
	parameter BURST_MODE            = "8",
	                                  // DDR3 SDRAM:
	                                  // Burst Length (Mode Register 0).
	                                  // # = "8", "4", "OTF".
	parameter CLKIN_PERIOD          = 5000,
	parameter CLKFBOUT_MULT         = 8,
	parameter DIVCLK_DIVIDE         = 1,
	parameter CLKOUT0_PHASE         = 337.5,
	parameter CLKOUT0_DIVIDE        = 2,
	parameter CLKOUT1_DIVIDE        = 2,
	parameter CLKOUT2_DIVIDE        = 32,
	parameter CLKOUT3_DIVIDE        = 8,
	parameter MMCM_VCO              = 800,
	parameter MMCM_MULT_F           = 4,
	parameter MMCM_DIVCLK_DIVIDE    = 1,
	
	//parameter SIMULATION            = "FALSE",
	parameter TCQ                   = 100,
	parameter DRAM_TYPE             = "DDR3",
	parameter nCK_PER_CLK           = 4,
	parameter DEBUG_PORT            = "OFF",
	
	parameter RST_ACT_LOW           = 1
)(
	/* General pins */
	input  wire sys_rst,
	input  [7:0] config_dram_node,
	output reg [2:0] debug,
`ifndef REMOVE_DRAM_IMP
	output reg     init_calib_complete,
`else
	output        init_calib_complete,
`endif
	output [31:0] dram_access,
	output [31:0] dram_read,
	output reg  [31:0] access_in,
	output reg  [31:0] access_out,
	output reg  [31:0] scache_all,
	output reg  [31:0] scache_hit,
	input              axis_aclk      ,
	input              axis_resetn    ,
	input              cache_enable   ,

`ifdef SKIP_CALIB
	output            calib_tap_req,
	input             calib_tap_load,
	input [6:0]       calib_tap_addr,
	input [7:0]       calib_tap_val,
	input             calib_tap_load_done,
`endif
`ifndef REMOVE_DRAM_IMP
	/* DDR3 SDRAM pins*/
	inout  [63:0]  ddr3_dq,
	inout  [ 7:0]  ddr3_dqs_n,
	inout  [ 7:0]  ddr3_dqs_p,
	output [15:0]  ddr3_addr,
	output [ 2:0]  ddr3_ba,
	output         ddr3_ras_n,
	output         ddr3_cas_n,
	output         ddr3_we_n,
	output         ddr3_reset_n,
	output [ 0:0]  ddr3_ck_p,
	output [ 0:0]  ddr3_ck_n,
	output [ 0:0]  ddr3_cke,
	output [ 0:0]  ddr3_cs_n,
	output [ 7:0]  ddr3_dm,
	output [ 0:0]  ddr3_odt,

	input  wire dram_clk_p,
	input  wire dram_clk_n,
`ifdef TWO_DRAM
	input  wire dram_clk_i,
`endif /*TWO_DRAM*/
`endif /*REMOVE_DRAM_IMP*/
	// Master Stream Ports (interface to data path)
	output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
	output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
	output [C_M_AXIS_TDEST_WIDTH-1:0] m_axis_tdest,
	output             m_axis_tvalid,
	input              m_axis_tready,
	output             m_axis_tlast,
	
	// Slave Stream Ports (interface to RX queues)
	input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
	input [C_S_AXIS_TDEST_WIDTH-1:0] s_axis_tdest,
	input              s_axis_tvalid,
	output             s_axis_tready,
	input              s_axis_tlast

);

//
// AXIS Format 
//    tdata: 
//         a.  app_wdf_data[255:0]
//         b.  app_wdf_data[511:256]
//    tuser:
//         tuser[ 2: 0] : app_cmd
//         tuser[32: 3] : app_addr
//         tuser[34:33] : request type
//                            2'b00 -> read request
//                            2'b01 -> write request
//         tuser[36:35] : data type 
//                            2'b00 -> no data
//                            2'b01 -> a. app_wdf_data[255:0] 
//                            2'b10 -> b. app_wdf_data[511:256]
//                            2'b11 -> unused
//         tuser[44:37] : source core (PE)
//         tuser[45]    : likely cache bit
//    tkeep:
//
localparam REQ_TYPE_READ  = 2'b00;
localparam REQ_TYPE_WRITE = 2'b01;
localparam REQ_TYPE_HTABLE_READ  = 2'b10;
localparam REQ_TYPE_HTABLE_WRITE = 2'b11;

/*
 *  Functions and Parameters
 */

function integer clogb2 (input integer size);
begin
	size = size - 1;
	for (clogb2=1; size>1; clogb2=clogb2+1)
		size = size >> 1;
end
endfunction // clogb2

function integer STR_TO_INT;
input [7:0] in;
begin
	if(in == "8")
		STR_TO_INT = 8;
	else if(in == "4")
		STR_TO_INT = 4;
	else
		STR_TO_INT = 0;
end
endfunction

localparam MIG_CMD_READ  = 3'b001;
localparam MIG_CMD_WRITE = 3'b000;

localparam DATA_WIDTH     = 64;
localparam RANK_WIDTH     = clogb2(RANKS);
localparam PAYLOAD_WIDTH  = (ECC_TEST == "OFF") ? DATA_WIDTH : DQ_WIDTH;
localparam BURST_LENGTH   = STR_TO_INT(BURST_MODE);
localparam APP_DATA_WIDTH = 2 * nCK_PER_CLK * PAYLOAD_WIDTH;
localparam APP_MASK_WIDTH = APP_DATA_WIDTH / 8;

/*
 *  wire declartion
 */

wire [(2*nCK_PER_CLK)-1:0]     app_ecc_multiple_err;
wire [ADDR_WIDTH-1:0]          app_addr;
wire [2:0]                     app_cmd;
wire                           app_en;
wire                           app_rdy;
wire [APP_DATA_WIDTH-1:0]      app_rd_data;
wire                           app_rd_data_end;
wire                           app_rd_data_valid;
wire [APP_DATA_WIDTH-1:0]      app_wdf_data;
wire                           app_wdf_end;
wire [APP_MASK_WIDTH-1:0]      app_wdf_mask;
wire                           app_wdf_rdy;
wire                           app_sr_active;
wire                           app_ref_ack;
wire                           app_zq_ack;
wire                           app_wdf_wren;

wire [512+64+30+3+8+2+2+1+1+1-1:0] din_fifo_in, dout_fifo_in;
wire [512+8+30+2-1:0]          din_fifo_out, dout_fifo_out;
wire [8+30+2-1:0]              din_misc, dout_misc;
wire [264:0]                   din_sf, dout_sf;
wire                           full_fifo_in, empty_fifo_in;
wire                           almost_full_fifo_in, prog_full_fifo_in;
wire                           wr_en_fifo_in, rd_en_fifo_in;
wire                           full_misc, empty_misc;
wire                           wr_en_misc, rd_en_misc;
wire                           full_fifo_out, empty_fifo_out;
wire                           wr_en_fifo_out, rd_en_fifo_out;
wire                           empty_sf, full_sf;
wire                           wr_en_sf, rd_en_sf;
wire  init_calib_complete_wire;

`ifndef REMOVE_DRAM_IMP
wire ui_mem_clk;
wire ui_mem_rst;
reg dram_state;

always @ (posedge ui_mem_clk)
	if (ui_mem_rst) 
		init_calib_complete <= 0;
	else 
		init_calib_complete <= init_calib_complete_wire && dram_state;
`else
assign init_calib_complete = 1'b1;
`endif /*REMOVE_DRAM_IMP*/

/*
 * Cache :
 *    key: address, value: hashtable
 */
//reg  [1:0]   state;
reg          cache_bit_stage0, cache_bit_stage1, cache_bit_stage2;
reg          lookup0_stage0, lookup0_stage1, lookup0_stage2;
reg  [512+64+30+3+2+2+8+1+1-1:0] data0_stage0, data0_stage1, data0_stage2;
reg  [511:0] din_fifo_reg;
reg          din_valid, din_cacheb, din_hashb, return0;
reg  [7:0]   tag_stage3;
reg          cache_en;
reg          hash_bit_stage0, hash_bit_stage1;

wire [512+64+30+3+2+2+8+1+1-1:0] din_fifo_in_pipe;
wire         cache_bit_out;
wire [31:0]  cache_wr_addr;
wire [511:0] cache_data_wr, data_wr1;
wire [2:0]   din_cmd_cache;
wire [31:0]  din_addr_cache;

localparam C_CACHE_ADDR_WIDTH     = 10;
localparam C_HCACHE_ADDR_WIDTH    = 10;
localparam C_CACHE_MEM_ADDR_WIDTH = 32;
localparam BYTE_ADDR_TO_DPATH = clogb2(C_M_AXIS_DATA_WIDTH/8);
wire scache_rd0_en;
wire [C_CACHE_ADDR_WIDTH-1:0]scache_rd0_addr;
wire [C_CACHE_MEM_ADDR_WIDTH-C_CACHE_ADDR_WIDTH-1:0] scache_rd0_din;
wire scache_rd0_result;
wire [C_M_AXIS_DATA_WIDTH-1:0] scache_rd0_dout;
wire scache_rd0_valid;
wire scache_wr0_en, scache_wr1_en;
wire [C_CACHE_ADDR_WIDTH-1:0] scache_wr0_addr, scache_wr1_addr;
wire [C_M_AXIS_DATA_WIDTH+C_CACHE_MEM_ADDR_WIDTH-C_CACHE_ADDR_WIDTH-1:0] scache_wr0_data, scache_wr1_data;

// Hash
wire shcache_rd0_en;
wire [C_HCACHE_ADDR_WIDTH-1:0] shcache_rd0_addr;
wire [C_CACHE_MEM_ADDR_WIDTH-C_HCACHE_ADDR_WIDTH-1:0] shcache_rd0_din;
//wire [21:0] shcache_rd0_din;
wire shcache_rd0_result;
wire [64-1:0] shcache_rd0_dout;
wire shcache_rd0_valid;
wire shcache_wr0_en, shcache_wr1_en;
wire [C_HCACHE_ADDR_WIDTH-1:0] shcache_wr0_addr, shcache_wr1_addr;
wire [64+C_CACHE_MEM_ADDR_WIDTH-C_HCACHE_ADDR_WIDTH-1:0] shcache_wr0_data, shcache_wr1_data;


assign shcache_rd0_en   =  cache_en && din_valid && din_cacheb && din_hashb && din_cmd_cache == MIG_CMD_READ;
assign shcache_rd0_addr[C_HCACHE_ADDR_WIDTH-1:0] = din_addr_cache[C_HCACHE_ADDR_WIDTH-1:0];
assign shcache_rd0_din[C_CACHE_MEM_ADDR_WIDTH-C_HCACHE_ADDR_WIDTH-1:0] = din_addr_cache[C_CACHE_MEM_ADDR_WIDTH-1:C_HCACHE_ADDR_WIDTH];

assign shcache_wr0_en   = cache_en && din_valid && din_cacheb && din_hashb && din_cmd_cache == MIG_CMD_WRITE;
assign shcache_wr0_addr[C_HCACHE_ADDR_WIDTH-1:0] = din_addr_cache[C_HCACHE_ADDR_WIDTH-1:0];
assign shcache_wr0_data = {data_wr1[63:0], din_addr_cache[C_CACHE_MEM_ADDR_WIDTH-1:C_HCACHE_ADDR_WIDTH]};

assign shcache_wr1_en   = cache_en && rd_en_fifo_out && cache_bit_out; 
assign shcache_wr1_addr[C_HCACHE_ADDR_WIDTH-1:0] = cache_wr_addr[C_HCACHE_ADDR_WIDTH-1:0];
assign shcache_wr1_data = {cache_data_wr[63:0], cache_wr_addr[C_CACHE_MEM_ADDR_WIDTH-1:C_HCACHE_ADDR_WIDTH]}; 

// Data store wiring
assign scache_rd0_en   =  cache_en && din_valid && din_cacheb && !din_hashb && din_cmd_cache == MIG_CMD_READ;
assign scache_rd0_addr[C_CACHE_ADDR_WIDTH-1:0] = din_addr_cache[C_CACHE_ADDR_WIDTH+BYTE_ADDR_TO_DPATH-1:BYTE_ADDR_TO_DPATH];
assign scache_rd0_din[C_CACHE_MEM_ADDR_WIDTH-C_CACHE_ADDR_WIDTH-BYTE_ADDR_TO_DPATH-1:0] = din_addr_cache[C_CACHE_MEM_ADDR_WIDTH-1:C_CACHE_ADDR_WIDTH+BYTE_ADDR_TO_DPATH];
assign scache_rd0_din[C_CACHE_MEM_ADDR_WIDTH-C_CACHE_ADDR_WIDTH-1:C_CACHE_MEM_ADDR_WIDTH-C_CACHE_ADDR_WIDTH-BYTE_ADDR_TO_DPATH] = 0;

assign scache_wr0_en   = cache_en && din_valid && din_cacheb && !din_hashb && din_cmd_cache == MIG_CMD_WRITE;
assign scache_wr0_addr[C_CACHE_ADDR_WIDTH-1:0] = din_addr_cache[C_CACHE_ADDR_WIDTH+BYTE_ADDR_TO_DPATH-1:BYTE_ADDR_TO_DPATH];
assign scache_wr0_data = {data_wr1, 6'h0,din_addr_cache[C_CACHE_MEM_ADDR_WIDTH-1:C_CACHE_ADDR_WIDTH+BYTE_ADDR_TO_DPATH]};

assign scache_wr1_en   = cache_en && rd_en_fifo_out && cache_bit_out; 
assign scache_wr1_addr[C_CACHE_ADDR_WIDTH-1:0] = cache_wr_addr[C_CACHE_ADDR_WIDTH+BYTE_ADDR_TO_DPATH-1:BYTE_ADDR_TO_DPATH];
assign scache_wr1_data = {cache_data_wr, 6'h0, cache_wr_addr[C_CACHE_MEM_ADDR_WIDTH-1:C_CACHE_ADDR_WIDTH+BYTE_ADDR_TO_DPATH]}; 

//
// small_cache
//
small_cache #(
	.C_CACHE_MEM_ADDR_WIDTH   ( C_CACHE_MEM_ADDR_WIDTH ),
	.C_CACHE_ADDR_WIDTH       ( C_CACHE_ADDR_WIDTH     )
) u_small_cache (
	.clk        ( axis_aclk    ),
	.rst        ( !axis_resetn ), 
	// #0 Path
	.rd0_en     ( scache_rd0_en     ),
	.rd0_addr   ( scache_rd0_addr   ),
	.rd0_din    ( scache_rd0_din    ),
	.rd0_result ( scache_rd0_result ),
	.rd0_dout   ( scache_rd0_dout   ),
	.rd0_valid  ( scache_rd0_valid  ),
	.wr0_en     ( scache_wr0_en     ),
	.wr0_addr   ( scache_wr0_addr   ),
	.wr0_data   ( scache_wr0_data   ),
	// #1 Path
	.rd1_en     ( 1'b0     )
	//.wr1_en     ( scache_wr1_en   ),
	//.wr1_addr   ( scache_wr1_addr ),
	//.wr1_data   ( scache_wr1_data )
);

small_hcache #(
	.C_CACHE_MEM_ADDR_WIDTH   ( C_CACHE_MEM_ADDR_WIDTH ),
	.C_CACHE_ADDR_WIDTH       ( C_HCACHE_ADDR_WIDTH     )
) u_hsmall_cache (
	.clk        ( axis_aclk    ),
	.rst        ( !axis_resetn ), 
	// #0 Path
	.rd0_en     ( shcache_rd0_en     ),
	.rd0_addr   ( shcache_rd0_addr   ),
	.rd0_din    ( shcache_rd0_din    ),
	.rd0_result ( shcache_rd0_result ),
	.rd0_dout   ( shcache_rd0_dout   ),
	.rd0_valid  ( shcache_rd0_valid  ),
	.wr0_en     ( shcache_wr0_en     ),
	.wr0_addr   ( shcache_wr0_addr   ),
	.wr0_data   ( shcache_wr0_data   ),
	// #1 Path
	.rd1_en     ( 1'b0     )
	//:.wr1_en     ( shcache_wr1_en   ),
	//:.wr1_addr   ( shcache_wr1_addr ),
	//:.wr1_data   ( shcache_wr1_data )
);


always @ (posedge axis_aclk)
	if (!axis_resetn) begin
		cache_bit_stage0 <= 0;
		cache_bit_stage1 <= 0;
		cache_bit_stage2 <= 0;
		lookup0_stage0  <= 0;
		lookup0_stage1  <= 0;
		lookup0_stage2  <= 0;
		data0_stage0    <= 0;
		data0_stage1    <= 0;
		data0_stage2    <= 0;
		din_fifo_reg    <= 0;
		tag_stage3      <= 0;
		return0         <= 0;
		cache_en        <= 0;
	end else begin
		cache_en        <= cache_enable;
		hash_bit_stage0 <= din_hashb;
		hash_bit_stage1 <= hash_bit_stage0;
		cache_bit_stage0 <= cache_en && din_valid && din_cacheb && din_cmd_cache == MIG_CMD_READ;
		cache_bit_stage1 <= cache_bit_stage0;
		cache_bit_stage2 <= cache_bit_stage1;
		lookup0_stage0 <= din_valid;// && din_cmd_cache == MIG_CMD_READ;
		lookup0_stage1 <= lookup0_stage0;
		lookup0_stage2 <= lookup0_stage1;
		data0_stage0   <= din_fifo_in_pipe;
		data0_stage1   <= data0_stage0;
		data0_stage2   <= data0_stage1;
		if (lookup0_stage1) begin
			if (scache_rd0_result) begin
				return0 <= (cache_en) ? 1 : 0;
				din_fifo_reg <= scache_rd0_dout;
				tag_stage3   <= data0_stage1[8:1];
			end else if (shcache_rd0_result) begin
				return0 <= (cache_en) ? 1 : 0;
				din_fifo_reg <= {448'd0, shcache_rd0_dout};
				tag_stage3   <= data0_stage1[8:1];
			end else begin
				return0 <= 0;
`ifdef REMOVE_DRAM_IMP
				din_fifo_reg <= (!hash_bit_stage1) ? scache_rd0_dout : {448'd0, shcache_rd0_dout};
				tag_stage3   <= data0_stage1[8:1];
`endif
			end
		end else begin
			return0 <= 0;
		end
	end 

`ifndef REMOVE_DRAM_IMP
/*
 * Input Data FIFO :
 *       general : 512bit width x ?? depth
 *       type    : Fallthrough Read
 */
`ifdef TMP_DEBUG
wire wr_rst_busy, rd_rst_busy;
`endif /*SIMULATION_DEBUG*/
asfifo_624 u_fifo_in (
	.rst         ( !axis_resetn | ui_mem_rst ),  
`ifdef TMP_DEBUG
	.wr_rst_busy ( wr_rst_busy ),
	.rd_rst_busy ( rd_rst_busy ),
`endif /*TMP_DEBUG*/
	.wr_clk      ( axis_aclk     ),  
	.rd_clk      ( ui_mem_clk    ), 
	.din         ( din_fifo_in   ), 
	.wr_en       ( wr_en_fifo_in ),
	.rd_en       ( rd_en_fifo_in ),
	.dout        ( dout_fifo_in  ), 
	.full        ( full_fifo_in  ), 
	.almost_full ( almost_full_fifo_in ),
	.prog_full   ( prog_full_fifo_in ),
	.empty       ( empty_fifo_in ) 
);

`endif /*REMOVE_DRAM_IMP*/

/*
 * MISC FIFO :
 *     General : 8bit width x ?? depth
 *     Type    : Fallthrough Read
 *     MAP     : source[7:0]
 */ 
lake_fallthrough_small_fifo #(
	.WIDTH          (8+30+2),
	.MAX_DEPTH_BITS (5)
) u_fifo_misc (
	.din            ( din_misc   ),
	.wr_en          ( wr_en_misc ),
	.rd_en          ( rd_en_misc ),
	.dout           ( dout_misc  ),
	.full           ( full_misc  ),
	.nearly_full    ( ),
	.prog_full      ( ),
	.empty          ( empty_misc ),
	.reset          ( ui_mem_rst ),
	.clk            ( ui_mem_clk )
);

`ifndef REMOVE_DRAM_IMP
/*
 * Output FIFO :
 *       General : 256 bit width x ?? depth
 *       Type    : Fallthrough Read
 */
asfifo_552 u_fifo_out (
	.rst      ( !axis_resetn | ui_mem_rst  ),
	.wr_rst_busy ( ),
	.rd_rst_busy ( ),
	.wr_clk   ( ui_mem_clk     ),
	.rd_clk   ( axis_aclk      ),
	.din      ( din_fifo_out   ),
	.wr_en    ( wr_en_fifo_out ),
	.rd_en    ( rd_en_fifo_out ),
	.dout     ( dout_fifo_out  ),
	.full     ( full_fifo_out  ),
	.empty    ( empty_fifo_out )
);

`endif /*REMOVE_DRAM_IMP*/

localparam NO_DATA     = 2'b00;
localparam DATA_TYPE_0 = 2'b01;
localparam DATA_TYPE_1 = 2'b10;

reg [C_M_AXIS_DATA_WIDTH-1:0]       din_data;
reg [((C_M_AXIS_DATA_WIDTH/8))-1:0] din_strb;
reg [29:0]  din_addr;
reg [2:0]   din_cmd;
reg [1:0]   din_req;
reg [1:0]   din_type;
reg [7:0]   din_src;

// Convert 256 to 512
always @ (posedge axis_aclk)
	if (!axis_resetn) begin
		din_cmd   <= 0;
		din_addr  <= 0;
		din_data  <= 0;
		din_strb  <= 0;
		din_req   <= 0;
		din_type  <= 0;
		din_src   <= 0;
		din_valid <= 0;
		din_cacheb <= 0;
		din_hashb <= 0;
	end else begin
		if (s_axis_tvalid && s_axis_tready) begin
			din_valid <= 1;
			din_cmd   <= s_axis_tuser[2:0];
			//din_addr  <= s_axis_tuser[32:3]; // todo: addressing problem
			if (s_axis_tuser[34] == 1) begin // Hash Table
				din_addr  <= s_axis_tuser[32:3];//{s_axis_tuser[26:3], 6'd0}; // todo: addressing problem
			end else begin  // Data Store
				din_addr  <= s_axis_tuser[32:3]; // todo: addressing problem
			end
			din_req   <= s_axis_tuser[34:33];
			din_type  <= s_axis_tuser[36:35];
			din_src   <= s_axis_tuser[44:37];
			din_cacheb <= s_axis_tuser[45];
			//if (s_axis_tuser[36:35] == DATA_TYPE_0) begin
			din_hashb <= s_axis_tuser[46];
			din_data <= s_axis_tdata;
			din_strb <= s_axis_tkeep;
			//end
		end else begin
			din_valid <= 0;
		end
	end

reg [2:0]   out_cmd;
reg [29:0]  out_addr;
reg [511:0] out_data;
reg [63:0]  out_strb;
reg [1:0]   out_req;
reg [1:0]   out_type;
reg [7:0]   out_src;
reg         out_valid;

wire [511:0] dout_data;
wire [2:0]   dout_cmd;
wire [29:0]  dout_addr;
wire [63:0]  dout_strb;
wire [1:0]   dout_req;
wire [1:0]   dout_type;
wire [7:0]   dout_src;
wire         dout_cache;
wire         dout_hash;
wire         dout_return;

wire return_wr_en;

//**********************************************************************
// FIFO assignment
//**********************************************************************
assign din_fifo_in_pipe   = {din_data, din_cmd, din_addr, 
                        din_strb, din_req, din_type, din_src, din_cacheb, din_hashb};
assign din_fifo_in   = {data0_stage2, return0};
assign wr_en_fifo_in = lookup0_stage2;// && !return0;
assign rd_en_fifo_in = !empty_fifo_in && app_wdf_rdy && app_rdy;

assign din_misc   = {dout_return, dout_cache, dout_addr, dout_src};
assign wr_en_misc = rd_en_fifo_in && dout_cmd == MIG_CMD_READ;
assign rd_en_misc = app_rd_data_valid;

assign din_fifo_out   = {dout_misc, app_rd_data};
assign wr_en_fifo_out = init_calib_complete ? app_rd_data_valid : 1'b0;
assign rd_en_fifo_out = init_calib_complete ? !empty_fifo_out : 1'b0;

assign {dout_data, dout_cmd, dout_addr, dout_strb, dout_req, dout_type, dout_src, dout_cache, dout_hash, dout_return} = dout_fifo_in;
assign return_wr_en  = dout_fifo_out[551];
assign cache_bit_out = dout_fifo_out[550];
assign cache_wr_addr = {2'd0, dout_fifo_out[549:520]};
assign cache_data_wr = dout_fifo_out[511:0];
assign din_cmd_cache = din_cmd;
assign din_addr_cache = {2'd0, din_addr};
assign data_wr1  = din_data;

//**********************************************************************
// Assignment : AXIS Master Bus
//**********************************************************************
/*  16/11/2017
 *  Todo : The problem of timing is here.
 *         You need to add registers to absorb the latency.
 */

wire [C_M_AXIS_DATA_WIDTH-1:0] tdata_buf;
wire [7:0] tdest_buf;

wire empty_rcache, full_rcache;
wire wr_en_rcache, rd_en_rcache;
wire empty_buf, full_buf;
wire wr_en_buf, rd_en_buf;
wire empty_axis, full_axis;
wire wr_en_axis, rd_en_axis;
wire [C_M_AXIS_DATA_WIDTH+8-1:0] dout_rcache;
wire [C_M_AXIS_DATA_WIDTH+8-1:0] dout_buf;
wire [C_M_AXIS_DATA_WIDTH+8-1:0] din_axis;

wire [1:0] arb;

`ifdef REMOVE_DRAM_IMP
assign wr_en_rcache = cache_bit_stage2;
`else
assign wr_en_rcache = return0;
`endif /*REMOVE_DRAM_IMP*/

`ifndef REMOVE_DRAM_IMP
assign rd_en_rcache = !empty_rcache && arb[0];
`else
assign rd_en_rcache = !empty_rcache;
`endif
assign wr_en_buf    = !empty_fifo_out && !return_wr_en;
assign rd_en_buf    = !empty_buf && arb[1];
`ifndef REMOVE_DRAM_IMP
assign wr_en_axis   = !empty_rcache || !empty_buf;
`else
assign wr_en_axis   = !empty_rcache;
`endif
assign rd_en_axis   = !empty_axis && m_axis_tready;

`ifndef REMOVE_DRAM_IMP
assign arb = (!empty_rcache) ? 2'b01 :
             (!empty_buf)    ? 2'b10 : 0;
assign din_axis  = (arb == 2'b01) ? dout_rcache :
                   (arb == 2'b10) ? dout_buf    : 0;
`else
assign din_axis  = dout_rcache;
`endif

lake_fallthrough_small_fifo #(
	.WIDTH           ( C_M_AXIS_DATA_WIDTH+8 ),
	.MAX_DEPTH_BITS  ( 3 )
) u_cache_fifo (
	.din         ( {tag_stage3, din_fifo_reg} ),
	.wr_en       ( wr_en_rcache ),
	.rd_en       ( rd_en_rcache ),
	.dout        ( dout_rcache ),
	.full        ( full_rcache ),
	.nearly_full ( ),
	.prog_full   ( ),
	.empty       ( empty_rcache ),
	.reset       ( !axis_resetn ),
	.clk         ( axis_aclk    )
);

`ifndef REMOVE_DRAM_IMP
lake_fallthrough_small_fifo #(
	.WIDTH           ( C_M_AXIS_DATA_WIDTH+8 ),
	.MAX_DEPTH_BITS  ( 3 )
) u_buf_fifo (
	.din         ( dout_fifo_out[C_M_AXIS_DATA_WIDTH+8-1:0] ),
	.wr_en       ( wr_en_buf ),
	.rd_en       ( rd_en_buf ),
	.dout        ( dout_buf ),
	.full        ( full_buf               ),
	.nearly_full ( ),
	.prog_full   ( ),
	.empty       ( empty_buf              ),
	.reset       ( !axis_resetn           ),
	.clk         ( axis_aclk              )
);
`endif

lake_fallthrough_small_fifo #(
	.WIDTH           ( C_M_AXIS_DATA_WIDTH+8 ),
	.MAX_DEPTH_BITS  ( 3 )
) u_axis_fifo (
	.din         ( din_axis ),
	.wr_en       ( wr_en_axis ),
	.rd_en       ( rd_en_axis ),
	.dout        ( {tdest_buf, tdata_buf} ),
	.full        ( full_axis              ),
	.nearly_full ( ),
	.prog_full   ( ),
	.empty       ( empty_axis             ),
	.reset       ( !axis_resetn           ),
	.clk         ( axis_aclk              )
);

assign m_axis_tvalid = (init_calib_complete) ? !empty_axis : 1'b0;
assign m_axis_tdata  = tdata_buf;
assign m_axis_tuser  = {120'd0, config_dram_node};
assign m_axis_tdest  = tdest_buf[C_M_AXIS_TDEST_WIDTH-1:0];
assign m_axis_tkeep  = 64'hffff_ffff_ffff_ffff;  // todo: multiple flit
assign m_axis_tlast  = 1'b1; // todo: multiple flit

`ifdef REMOVE_DRAM_IMP
assign s_axis_tready = 1'b1;
`else
assign s_axis_tready = !prog_full_fifo_in;
`endif /*REMOVE_DRAM_IMP*/


`ifndef REMOVE_DRAM_IMP
/*
 * Clean up DRAM memory
 */

reg [23:0] clean_addr;
//reg clean_app_en;
always @ (posedge ui_mem_clk) 
	if (ui_mem_rst) begin
		dram_state <= 0;
		clean_addr <= 0;
	end else begin
		if (init_calib_complete_wire) begin
			case (dram_state)
				0: begin
					if (app_rdy && app_wdf_rdy) begin
`ifndef SIMULATION_DEBUG
						if (clean_addr == 24'hff_ffff)
`else
						if (clean_addr == 24'h00_000f)
`endif /* SIMULATION_DEBUG */ 
							dram_state <= 1;
						else
							clean_addr <= clean_addr + 1;
					end
				end
				1:;
			endcase
		end
	end

wire init_app_en = app_rdy && app_wdf_rdy && dram_state == 0;
/*
 *  Todo :
 *     app_wdf_mask and app_wdf_data come from different FIFO, 
 *     u_fifo_in and u_fifo_cmdin. so if full signal on one of 
 *     them is high, the data or strb signals disappears.
 *     Probably, it is needed to replace it into one fifo as 
 *     all signals are stored. 
 */

assign app_cmd      = (dram_state == 0) ?  MIG_CMD_WRITE      : dout_cmd;
assign app_addr     = (dram_state == 0) ?  {clean_addr, 6'd0} : dout_addr[29:0];
assign app_en       = (dram_state == 0) ?  init_app_en   : !empty_fifo_in && app_rdy && app_wdf_rdy;
assign app_wdf_data = (dram_state == 0) ?  512'h0 : (dout_req == REQ_TYPE_WRITE || dout_req == REQ_TYPE_HTABLE_WRITE) ? dout_data : 0;
assign app_wdf_mask = (dram_state == 0) ?  64'h0  : (dout_req == REQ_TYPE_WRITE || dout_req == REQ_TYPE_HTABLE_WRITE) ? ~dout_strb : 0;
assign app_wdf_end  = (dram_state == 0) ?  1'b1   : (dout_req == REQ_TYPE_WRITE || dout_req == REQ_TYPE_HTABLE_WRITE) && !empty_fifo_in && app_wdf_rdy && app_rdy; 
assign app_wdf_wren = (dram_state == 0) ?  init_app_en :(dout_req == REQ_TYPE_WRITE || dout_req == REQ_TYPE_HTABLE_WRITE) && app_rdy && 
                               !empty_fifo_in && app_wdf_rdy; 
`endif /*REMOVE_DRAM_IMP*/
/*
 *  DRAM DEBUG
 */
always @ (posedge axis_aclk) 
	if (!axis_resetn) begin
		debug     <= 0;
		access_in  <= 0;
		access_out <= 0;
		scache_all <= 0;
		scache_hit <= 0;
	end else begin
		debug <= {full_fifo_out, full_misc, full_fifo_in};
		if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
			access_in <= access_in + 1;
		end
		if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
			access_out <= access_out + 1;
		end
		if (scache_rd0_en) begin
			scache_all <= scache_all + 1;
		end
		if (return0) begin
			scache_hit <= scache_hit + 1;
		end
	end

`ifndef REMOVE_DRAM_IMP
reg [31:0] dram_access_reg;
reg [31:0] dram_read_reg;
always @ (posedge ui_mem_clk)
	if (ui_mem_rst) begin
		dram_access_reg <= 0;
		dram_read_reg   <= 0;
	end else begin
		if (dram_state == 1) begin
			if (app_rdy && app_en) begin
				dram_access_reg <= dram_access_reg + 1;
			end
			if (app_rd_data_valid) begin
				dram_read_reg <= dram_read_reg + 1;
			end
		end
	end

asfifo_64 u_debug_fifo (
	.rst      ( !axis_resetn | ui_mem_rst ),  
	.wr_rst_busy ( ),
	.rd_rst_busy ( ),
	.wr_clk   ( ui_mem_clk    ),  
	.rd_clk   ( axis_aclk     ), 
	.din      ( {dram_read_reg, dram_access_reg}   ), 
	.wr_en    ( 1'b1 ),
	.rd_en    ( 1'b1 ),
	.dout     ( {dram_read, dram_access} ), 
	.full     (  ), 
	.empty    (  ) 
);
`endif /*REMOVE_DRAM_IMP*/

`ifndef REMOVE_DRAM_IMP

sume_mig_drama u_sume_mig_dram (
	//.sys_clk_i              (mem_clk)          ,
	//.clk_ref_i              (ref_clk)          ,
`ifdef TWO_DRAM
	.sys_clk_i              (dram_clk_i),
    .clk_ref_i              (axis_aclk),
`else
	.sys_clk_p              (dram_clk_p),
	.sys_clk_n              (dram_clk_n),
`endif
	.sys_rst                (!sys_rst)         ,

	.ddr3_addr              (ddr3_addr)        ,
	.ddr3_ba                (ddr3_ba)          ,
	.ddr3_cas_n             (ddr3_cas_n)       ,
	.ddr3_ck_n              (ddr3_ck_n)        ,
	.ddr3_ck_p              (ddr3_ck_p)        ,
	.ddr3_cke               (ddr3_cke)         ,
	.ddr3_ras_n             (ddr3_ras_n)       ,
	.ddr3_we_n              (ddr3_we_n)        ,
	.ddr3_dq                (ddr3_dq)          ,
	.ddr3_dqs_n             (ddr3_dqs_n)       ,
	.ddr3_dqs_p             (ddr3_dqs_p)       ,
	.ddr3_reset_n           (ddr3_reset_n)     ,
	.ddr3_cs_n              (ddr3_cs_n)        ,
	.ddr3_dm                (ddr3_dm)          ,
	.ddr3_odt               (ddr3_odt)         ,
	
	.init_calib_complete    (init_calib_complete_wire),
	.app_addr               (app_addr)         ,
	.app_cmd                (app_cmd)          ,
	.app_en                 (app_en)           ,
	.app_wdf_data           (app_wdf_data)     ,
	.app_wdf_end            (app_wdf_end)      ,
	.app_wdf_wren           (app_wdf_wren)     ,
	.app_rd_data            (app_rd_data)      ,
	.app_rd_data_end        (app_rd_data_end)  ,
	.app_rd_data_valid      (app_rd_data_valid),
	.app_rdy                (app_rdy)          ,
	.app_wdf_rdy            (app_wdf_rdy)      ,
	.app_sr_req             (0)                ,
	.app_ref_req            (0)                ,
	.app_zq_req             (0)                ,
	.app_sr_active          ()                 ,
	.app_ref_ack            ()                 ,
	.app_zq_ack             ()                 ,
	.app_wdf_mask           (app_wdf_mask)     ,
	
	//.device_temp_i          ( )     ,
	//.device_temp            ( )     ,
`ifdef SKIP_CALIB
	.calib_tap_req          (calib_tap_req)    ,
	.calib_tap_load         (calib_tap_load)   ,
	.calib_tap_addr         (calib_tap_addr)   ,
	.calib_tap_val          (calib_tap_val)    ,
	.calib_tap_load_done    (calib_tap_load_done),
`endif
	.ui_clk                 (ui_mem_clk)       ,
	.ui_clk_sync_rst        (ui_mem_rst)
);
`endif /*REMOVE_DRAM_IMP*/


endmodule
