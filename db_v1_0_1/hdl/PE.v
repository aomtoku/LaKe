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

`define CACHE_MODE
`timescale 1 ns / 1 ns

module PE #(
	parameter C_M_AXIS_DATA_WIDTH    = 256,
	parameter C_S_AXIS_DATA_WIDTH    = 256,
	parameter C_M_AXIS_TUSER_WIDTH   = 128,
	parameter C_S_AXIS_TUSER_WIDTH   = 128,
	parameter C_M_AXIS_TDEST_WIDTH   = 2,
	parameter C_S_AXIS_TDEST_WIDTH   = 2,
	parameter PE_TUSER_WIDTH         = 100,
	parameter MEM_DATA_PATH_WIDTH    = 512,
	parameter MEM_USER_PATH_WIDTH    = 128,
	parameter MEM_TDEST_WIDTH        = 3,
	parameter MODE_REG_WIDTH         = 8,
	parameter C_BASEADDR             = 32'hffffffff,
	parameter C_HIGHADDR             = 32'h0
) (
	input axis_aclk,
	input axis_resetn,
	input clk_en,

	// AXI registers
	input  [31:0]                    config_local_ip_addr,
	input  [15:0]                    config_kvs_uport,
	input  [7:0]                     config_pe_id,
	input  [MODE_REG_WIDTH-1:0]      config_mode,
	output [31:0]                    queries_l1hit,
	output [31:0]                    queries_l1miss,
	output reg [31:0]                pktin,
	output reg [31:0]                pktout,
	output reg [31:0]                error_pkt,
	output reg [31:0]                stat_set_cnt,
	output reg [31:0]                stat_get_cnt,
	output reg [31:0]                stat_del_cnt,
	output     [31:0]                debug_table,
	output     [31:0]                debug_chunk,
	output                           active_ready,

	// Master Stream Ports (memory network)
	output [MEM_DATA_PATH_WIDTH - 1:0]         mem_m_axis_tdata,
	output [((MEM_DATA_PATH_WIDTH / 8)) - 1:0] mem_m_axis_tkeep,
	output [MEM_USER_PATH_WIDTH-1:0]           mem_m_axis_tuser,
	output [MEM_TDEST_WIDTH-1:0]               mem_m_axis_tdest,
	output                                     mem_m_axis_tvalid,
	input                                      mem_m_axis_tready,
	output                                     mem_m_axis_tlast,
	
	// Slave Stream Ports (memory network)
	input [MEM_DATA_PATH_WIDTH - 1:0]         mem_s_axis_tdata,
	input [((MEM_DATA_PATH_WIDTH / 8)) - 1:0] mem_s_axis_tkeep,
	input [MEM_USER_PATH_WIDTH-1:0]           mem_s_axis_tuser,
	input [MEM_TDEST_WIDTH-1:0]               mem_s_axis_tdest,
	input                                     mem_s_axis_tvalid,
	output                                    mem_s_axis_tready,
	input                                     mem_s_axis_tlast,

	// Master Stream Ports (interface to data path)
	output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_tdata,
	output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_tuser,
	output [C_M_AXIS_TDEST_WIDTH-1:0]          m_axis_tdest,
	output                                     m_axis_tvalid,
	input                                      m_axis_tready,
	output                                     m_axis_tlast,
	
	// Slave Stream Ports (interface to RX queues)
	input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_tuser,
	input [C_S_AXIS_TDEST_WIDTH-1:0]          s_axis_tdest,
	input                                     s_axis_tvalid,
	output reg                                s_axis_tready,
	input                                     s_axis_tlast
);
/***********************************************************
 * Parameter : Header Position and Length
 ***********************************************************/
// Ethernet Frame Header
localparam ETH_DST_MAC_POS   = 0;
localparam ETH_SRC_MAC_POS   = 48;
localparam ETH_TYPE_POS      = 96;

localparam ETH_DST_MAC_LEN   = 48;
localparam ETH_SRC_MAC_LEN   = 48;
localparam ETH_TYPE_LEN      = 16;
// IP Header
localparam IP_VER_POS        = 112;
localparam IP_IHL_POS        = 116;
localparam IP_TOS_POS        = 120;
localparam IP_LEN_POS        = 128;
localparam IP_IDENT_POS      = 144;
localparam IP_FRAG_POS       = 160;
localparam IP_TTL_POS        = 176;
localparam IP_PROTO_POS      = 184;
localparam IP_CSUM_POS       = 192;
localparam IP_SRC_ADDR_POS   = 208;
localparam IP_DST_ADDR_POS0  = 240;
localparam IP_DST_ADDR_POS1  = 0;

localparam IP_VER_LEN        = 4;
localparam IP_IHL_LEN        = 4;
localparam IP_TOS_LEN        = 8;
localparam IP_LEN_LEN        = 16;
localparam IP_IDENT_LEN      = 16;
localparam IP_FRAG_LEN       = 16;
localparam IP_TTL_LEN        = 8;
localparam IP_PROTO_LEN      = 8;
localparam IP_CSUM_LEN       = 16;
localparam IP_SRC_ADDR_LEN   = 32;
localparam IP_DST_ADDR_LEN0  = 16;
localparam IP_DST_ADDR_LEN1  = 16;
// UDP Header 
localparam UDP_SRC_UPORT_POS = 16;
localparam UDP_DST_UPORT_POS = 32;
localparam UDP_LEN_POS       = 48;
localparam UDP_CSUM_POS      = 64;

localparam UDP_SRC_UPORT_LEN = 16;
localparam UDP_DST_UPORT_LEN = 16;
localparam UDP_LEN_LEN       = 16;
localparam UDP_CSUM_LEN      = 16;
// Memcached Header
localparam MEMC_MAGIC_POS    = 80;
localparam MEMC_MAGIC_LEN    = 8;
localparam MEMC_OPCODE_POS   = 88;
localparam MEMC_OPCODE_LEN   = 8;
localparam MEMC_KEYLEN_POS   = 96;
localparam MEMC_KEYLEN_LEN   = 16;
localparam MEMC_EXTLEN_POS   = 112;
localparam MEMC_EXTLEN_LEN   = 8;
localparam MEMC_DATATYPE_POS = 120;
localparam MEMC_DATATYPE_LEN = 8;
localparam MEMC_RESRVD_POS   = 128;
localparam MEMC_RESRVD_LEN   = 16;
localparam MEMC_TOTLEN_POS   = 144;
localparam MEMC_TOTLEN_LEN   = 32;
localparam MEMC_OPAQUE_POS   = 176;
localparam MEMC_OPAQUE_LEN   = 32;
localparam MEMC_CAS_POS      = 208;
localparam MEMC_CAS_LEN      = 32;

localparam MEMC_EXT_FLAG_POS = 16;
localparam MEMC_EXT_FLAG_LEN = 32;
localparam MEMC_EXT_EXPR_POS = 48;
localparam MEMC_EXT_EXPR_LEN = 32;

localparam MEMC_GET_KEY_POS  = 16;
localparam MEMC_GET_KEY_TMP_LEN = C_S_AXIS_DATA_WIDTH - MEMC_GET_KEY_POS;
localparam MEMC_SET_KEY_POS  = 80;
localparam MEMC_SET_KEY_TMP_LEN = C_S_AXIS_DATA_WIDTH - MEMC_SET_KEY_POS;

localparam MEMC_GET_VAL_POS  = 48;
localparam MEMC_GET_VAL_TMP_LEN = C_S_AXIS_DATA_WIDTH - MEMC_GET_VAL_POS;


/***********************************************************
 * Parameter : Header Value
 ***********************************************************/
// protocol_binary_magic
localparam PROTOCOL_BINARY_REQ            = 8'h80;
localparam PROTOCOL_BINARY_RES            = 8'h81;
// protocol_binary_command
localparam PROTOCOL_BINARY_CMD_GET        = 8'h00;
localparam PROTOCOL_BINARY_CMD_SET        = 8'h01;
localparam PROTOCOL_BINARY_CMD_ADD        = 8'h02;
localparam PROTOCOL_BINARY_CMD_REPLACE    = 8'h03;
localparam PROTOCOL_BINARY_CMD_DELETE     = 8'h04;
localparam PROTOCOL_BINARY_CMD_INCREMENT  = 8'h05;
localparam PROTOCOL_BINARY_CMD_DECREMENT  = 8'h06;
localparam PROTOCOL_BINARY_CMD_QUIT       = 8'h07;
localparam PROTOCOL_BINARY_CMD_FLUSH      = 8'h08;
localparam PROTOCOL_BINARY_CMD_GETQ       = 8'h09;
localparam PROTOCOL_BINARY_CMD_NOOP       = 8'h0a;
localparam PROTOCOL_BINARY_CMD_VERSION    = 8'h0b;
localparam PROTOCOL_BINARY_CMD_GETK       = 8'h0c;
localparam PROTOCOL_BINARY_CMD_GETKQ      = 8'h0d;
localparam PROTOCOL_BINARY_CMD_APPEND     = 8'h0e;
localparam PROTOCOL_BINARY_CMD_PREPEND    = 8'h0f;
localparam PROTOCOL_BINARY_CMD_STAT       = 8'h10;
localparam PROTOCOL_BINARY_CMD_SETQ       = 8'h11;
localparam PROTOCOL_BINARY_CMD_ADDQ       = 8'h12;
localparam PROTOCOL_BINARY_CMD_REPLACEQ   = 8'h13;
localparam PROTOCOL_BINARY_CMD_DELETEQ    = 8'h14;
localparam PROTOCOL_BINARY_CMD_INCREMENTQ = 8'h15;
localparam PROTOCOL_BINARY_CMD_DECREMENTQ = 8'h16;
localparam PROTOCOL_BINARY_CMD_QUITQ      = 8'h17;
localparam PROTOCOL_BINARY_CMD_FLUSHQ     = 8'h18;
localparam PROTOCOL_BINARY_CMD_APPENDQ    = 8'h19;
localparam PROTOCOL_BINARY_CMD_PREPENDQ   = 8'h1a;
localparam PROTOCOL_BINARY_CMD_TOUCH      = 8'h1c;
localparam PROTOCOL_BINARY_CMD_GAT        = 8'h1d;
localparam PROTOCOL_BINARY_CMD_GATQ       = 8'h1e;
localparam PROTOCOL_BINARY_CMD_GATK       = 8'h23;
localparam PROTOCOL_BINARY_CMD_GATKQ      = 8'h24;
localparam PROTOCOL_BINARY_CMD_SASL_LIST_MECHS = 8'h20;
localparam PROTOCOL_BINARY_CMD_SASL_AUTH = 8'h21;
localparam PROTOCOL_BINARY_CMD_SASL_STEP = 8'h22;

//protocol_binary_datatypes
localparam PROTOCOL_BINARY_RAW_BYTES     = 8'h00;

// IP UDP Header
localparam IP_TYPE                       = 16'h0008;
localparam UDP_PROTO                     =  8'h11;

localparam TTL_DEFAULT                   = 8'd64;

/***********************************************************
 * Functions
 ***********************************************************/
function [31:0] nkeep (input [5:0] i);
begin
	case(i)
		6'd0  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0000_0000;
		6'd1  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0000_0001;
		6'd2  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0000_0011;
		6'd3  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0000_0111;
		6'd4  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0000_1111;
		6'd5  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0001_1111;
		6'd6  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0011_1111;
		6'd7  : nkeep = 32'b0000_0000_0000_0000_0000_0000_0111_1111;
		6'd8  : nkeep = 32'b0000_0000_0000_0000_0000_0000_1111_1111;
		6'd9  : nkeep = 32'b0000_0000_0000_0000_0000_0001_1111_1111;
		6'd10 : nkeep = 32'b0000_0000_0000_0000_0000_0011_1111_1111;
		6'd11 : nkeep = 32'b0000_0000_0000_0000_0000_0111_1111_1111;
		6'd12 : nkeep = 32'b0000_0000_0000_0000_0000_1111_1111_1111;
		6'd13 : nkeep = 32'b0000_0000_0000_0000_0001_1111_1111_1111;
		6'd14 : nkeep = 32'b0000_0000_0000_0000_0011_1111_1111_1111;
		6'd15 : nkeep = 32'b0000_0000_0000_0000_0111_1111_1111_1111;
		6'd16 : nkeep = 32'b0000_0000_0000_0000_1111_1111_1111_1111;
		6'd17 : nkeep = 32'b0000_0000_0000_0001_1111_1111_1111_1111;
		6'd18 : nkeep = 32'b0000_0000_0000_0011_1111_1111_1111_1111;
		6'd19 : nkeep = 32'b0000_0000_0000_0111_1111_1111_1111_1111;
		6'd20 : nkeep = 32'b0000_0000_0000_1111_1111_1111_1111_1111;
		6'd21 : nkeep = 32'b0000_0000_0001_1111_1111_1111_1111_1111;
		6'd22 : nkeep = 32'b0000_0000_0011_1111_1111_1111_1111_1111;
		6'd23 : nkeep = 32'b0000_0000_0111_1111_1111_1111_1111_1111;
		6'd24 : nkeep = 32'b0000_0000_1111_1111_1111_1111_1111_1111;
		6'd25 : nkeep = 32'b0000_0001_1111_1111_1111_1111_1111_1111;
		6'd26 : nkeep = 32'b0000_0011_1111_1111_1111_1111_1111_1111;
		6'd27 : nkeep = 32'b0000_0111_1111_1111_1111_1111_1111_1111;
		6'd28 : nkeep = 32'b0000_1111_1111_1111_1111_1111_1111_1111;
		6'd29 : nkeep = 32'b0001_1111_1111_1111_1111_1111_1111_1111;
		6'd30 : nkeep = 32'b0011_1111_1111_1111_1111_1111_1111_1111;
		6'd31 : nkeep = 32'b0111_1111_1111_1111_1111_1111_1111_1111;
		6'd32 : nkeep = 32'b1111_1111_1111_1111_1111_1111_1111_1111;
		default : nkeep = 32'h0;
	endcase
end
endfunction

/***********************************************************
 * Clock Gating
 ***********************************************************/
wire axis_aclk_buf;
`ifdef CLOCK_GATE
BUFGCE BUFGCE_inst (
	.O  ( axis_aclk_buf ),
	.CE ( clk_en        ),
	.I  ( axis_aclk     )
);
`else
assign axis_aclk_buf = axis_aclk;
`endif /*CLOCK_GATE*/

/***********************************************************
 * Reset
 ***********************************************************/
(* dont_touch = "true" *)reg [15:0] axis_resetn_reg = 16'hffff;

always @ (posedge axis_aclk) begin
	axis_resetn_reg <= (axis_resetn) ? 16'hffff : 16'h0000;
end
/***********************************************************
 * Parameter : Status
 ***********************************************************/

localparam STATUS_IP     = 0,
           STATUS_UDP    = 1,
           STATUS_MEM    = 2,
		   STATUS_REQ    = 3,
           STATUS_MEMP   = 4,
           STATUS_REP    = 5;

reg [7:0]  s_axis_cnt;
reg [7:0]  status;

// Cache
reg [15:0] src_uport;
reg [3:0]  memcached_req_pkt;
reg        memcached_rep_pkt;
reg [7:0]  memcached_opcode;
reg [15:0] memcached_keylen;
reg [15:0] memcached_vallen;
reg [7:0]  memcached_extlen;
reg [31:0] memcached_bdylen;
reg [31:0] memcached_flag;
reg [31:0] memcached_expire;
reg [31:0] memcached_opaque;


reg tmp_valid;

	// Slave Stream Ports (interface to RX queues)
(* dont_touch = "true" *)reg [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_tdata_buf;
(* dont_touch = "true" *)reg [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep_buf;
(* dont_touch = "true" *)reg [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_tuser_buf;
(* dont_touch = "true" *)reg [C_S_AXIS_TDEST_WIDTH-1:0]          s_axis_tdest_buf;
(* dont_touch = "true" *)reg                                     s_axis_tvalid_buf;
(* dont_touch = "true" *)reg                                     s_axis_tready_buf;
(* dont_touch = "true" *)reg                                     s_axis_tlast_buf;
always @ (posedge axis_aclk_buf) begin
	if (!axis_resetn_reg[0]) begin
		s_axis_tdata_buf  <= 0;
		s_axis_tkeep_buf  <= 0;
		s_axis_tuser_buf  <= 0;
		s_axis_tdest_buf  <= 0;
		s_axis_tvalid_buf <= 0;
		s_axis_tready_buf <= 0;
		s_axis_tlast_buf  <= 0;
	end else begin
		s_axis_tdata_buf  <= s_axis_tdata;
		s_axis_tkeep_buf  <= s_axis_tkeep;
		s_axis_tuser_buf  <= s_axis_tuser;
		s_axis_tdest_buf  <= s_axis_tdest;
		s_axis_tvalid_buf <= s_axis_tvalid;
		s_axis_tready_buf <= s_axis_tready;
		s_axis_tlast_buf  <= s_axis_tlast;
	end
end

/***********************************************************
 * Parser for incoming packet 
 ***********************************************************/
wire extend_last = (memcached_opcode == PROTOCOL_BINARY_CMD_SET)    ?  s_axis_tlast_buf && s_axis_tkeep_buf[31:10] == 22'd0 : 
                   (memcached_opcode == PROTOCOL_BINARY_CMD_GET)    ?  s_axis_tlast_buf && s_axis_tkeep_buf[31:2] == 30'd0 : 
                   (memcached_opcode == PROTOCOL_BINARY_CMD_DELETE) ?  s_axis_tlast_buf && s_axis_tkeep_buf[31:2] == 30'd0 : 0;
reg [C_M_AXIS_DATA_WIDTH-1:0] tmp;
reg extend_last_reg;
reg [15:0] key_cnt, val_cnt;
always @ (posedge axis_aclk_buf) begin
	if (!axis_resetn_reg[1]) begin
		s_axis_cnt <= 0;
		status     <= 0;
		memcached_opcode <= 0;
		memcached_keylen <= 0;
		memcached_vallen <= 0;
		memcached_extlen <= 0;
		memcached_bdylen <= 0;
		memcached_flag   <= 0;
		memcached_expire <= 0;
		memcached_opaque <= 0;
		memcached_req_pkt <= 0;
		memcached_rep_pkt <= 0;
		src_uport <= 0;
		key_cnt <= 0;
		val_cnt <= 0;
		tmp <= 0;
		tmp_valid <= 0;
		extend_last_reg <= 0;
	end else begin
		if (s_axis_tvalid_buf && s_axis_tready_buf) begin
			case (s_axis_cnt)
				0: begin
					if (s_axis_tdata_buf[ETH_TYPE_POS+15:ETH_TYPE_POS] == IP_TYPE) 
						status[STATUS_IP] <= 1'b1;
					if (s_axis_tdata_buf[IP_PROTO_POS+7:IP_PROTO_POS] == UDP_PROTO)
						status[STATUS_UDP] <= 1'b1;
				end
				1: begin
					if ({s_axis_tdata_buf[UDP_DST_UPORT_POS+7:UDP_DST_UPORT_POS], 
						s_axis_tdata_buf[UDP_DST_UPORT_POS+15:UDP_DST_UPORT_POS+8]} == config_kvs_uport) 
						status[STATUS_MEM] <= 1'b1;
					if (s_axis_tdata_buf[MEMC_MAGIC_POS+MEMC_MAGIC_LEN-1:MEMC_MAGIC_POS] == PROTOCOL_BINARY_REQ) begin
						status[STATUS_REQ] <= 1'b1;
`ifdef CACHE_MODE
						src_uport <= {s_axis_tdata_buf[UDP_SRC_UPORT_POS+7:UDP_SRC_UPORT_POS], 
						              s_axis_tdata_buf[UDP_SRC_UPORT_POS+15:UDP_SRC_UPORT_POS+8]};
					end
					if ({s_axis_tdata_buf[UDP_SRC_UPORT_POS+7:UDP_SRC_UPORT_POS], 
						s_axis_tdata_buf[UDP_SRC_UPORT_POS+15:UDP_SRC_UPORT_POS+8]} == config_kvs_uport)
						status[STATUS_MEMP] <= 1'b1;
					if (s_axis_tdata_buf[MEMC_MAGIC_POS+MEMC_MAGIC_LEN-1:MEMC_MAGIC_POS] == PROTOCOL_BINARY_RES) begin
						status[STATUS_REP] <= 1'b1;
						src_uport <= {s_axis_tdata_buf[UDP_DST_UPORT_POS+7:UDP_DST_UPORT_POS], 
						              s_axis_tdata_buf[UDP_DST_UPORT_POS+15:UDP_DST_UPORT_POS+8]};
					end
`else
					end
`endif /* CACHE_MODE */
					memcached_opcode <= s_axis_tdata_buf[MEMC_OPCODE_POS+MEMC_OPCODE_LEN-1:MEMC_OPCODE_POS];
					memcached_keylen <= {s_axis_tdata_buf[MEMC_KEYLEN_POS+7:MEMC_KEYLEN_POS], 
					                     s_axis_tdata_buf[MEMC_KEYLEN_POS+MEMC_KEYLEN_LEN-1:MEMC_KEYLEN_POS+8]};
					memcached_extlen <= s_axis_tdata_buf[MEMC_EXTLEN_POS+MEMC_EXTLEN_LEN-1:MEMC_EXTLEN_POS];
					memcached_bdylen <= {s_axis_tdata_buf[MEMC_TOTLEN_POS+7:MEMC_TOTLEN_POS], 
					                     s_axis_tdata_buf[MEMC_TOTLEN_POS+15:MEMC_TOTLEN_POS+8],
					                     s_axis_tdata_buf[MEMC_TOTLEN_POS+23:MEMC_TOTLEN_POS+16],
					                     s_axis_tdata_buf[MEMC_TOTLEN_POS+MEMC_TOTLEN_LEN-1:MEMC_TOTLEN_POS+24]};
					memcached_opaque <= {s_axis_tdata_buf[MEMC_OPAQUE_POS+7:MEMC_OPAQUE_POS], 
					                     s_axis_tdata_buf[MEMC_OPAQUE_POS+15:MEMC_OPAQUE_POS+8],
					                     s_axis_tdata_buf[MEMC_OPAQUE_POS+23:MEMC_OPAQUE_POS+16],
					                     s_axis_tdata_buf[MEMC_OPAQUE_POS+MEMC_OPAQUE_LEN-1:MEMC_OPAQUE_POS+24]};
				end
				2: begin
					if (status[STATUS_IP] && status[STATUS_UDP] 
							&& status[STATUS_MEM] && status[STATUS_REQ] 
							&& (memcached_opcode == PROTOCOL_BINARY_CMD_SET 
							|| memcached_opcode == PROTOCOL_BINARY_CMD_ADD)) begin
						memcached_vallen <= memcached_bdylen[15:0] - memcached_keylen - {8'd0, memcached_extlen};
						memcached_req_pkt <= 1;
						memcached_flag   <= s_axis_tdata_buf[MEMC_EXT_FLAG_POS+MEMC_EXT_FLAG_LEN-1:MEMC_EXT_FLAG_POS];
						memcached_expire <= s_axis_tdata_buf[MEMC_EXT_EXPR_POS+MEMC_EXT_EXPR_LEN-1:MEMC_EXT_EXPR_POS];
						tmp[MEMC_SET_KEY_TMP_LEN-1:0] <= s_axis_tdata_buf[MEMC_SET_KEY_POS+MEMC_SET_KEY_TMP_LEN-1:MEMC_SET_KEY_POS];
					end else if (status[STATUS_IP] && status[STATUS_UDP] 
							&& status[STATUS_MEM] && status[STATUS_REQ] 
							&& (memcached_opcode == PROTOCOL_BINARY_CMD_GET 
							|| memcached_opcode == PROTOCOL_BINARY_CMD_DELETE)) begin
						memcached_vallen <= 0;
						memcached_req_pkt <= 1;
						tmp[MEMC_GET_KEY_TMP_LEN-1:0] <= s_axis_tdata_buf[MEMC_GET_KEY_POS+MEMC_GET_KEY_TMP_LEN-1:MEMC_GET_KEY_POS];
					end 
`ifdef CACHE_MODE
						else if (status[STATUS_IP] && status[STATUS_UDP] 
							&& status[STATUS_MEMP] && status[STATUS_REP] 
							&& memcached_opcode == PROTOCOL_BINARY_CMD_GET) begin
						memcached_rep_pkt <= 1;
						memcached_vallen <= memcached_bdylen[15:0] - {8'd0, memcached_extlen};
						tmp[MEMC_GET_VAL_TMP_LEN-1:0] <= s_axis_tdata_buf[MEMC_GET_VAL_TMP_LEN+MEMC_GET_VAL_POS-1:MEMC_GET_VAL_POS]; // GET Value
					end
`endif /* CACHE_MODE */
				end
				default: begin
					if (status[3:0] == 4'b1111 
							&& (memcached_opcode == PROTOCOL_BINARY_CMD_SET 
							|| memcached_opcode == PROTOCOL_BINARY_CMD_ADD)) begin
						tmp[MEMC_SET_KEY_TMP_LEN-1:0] <= s_axis_tdata_buf[MEMC_SET_KEY_POS+MEMC_SET_KEY_TMP_LEN-1:MEMC_SET_KEY_POS];
						memcached_req_pkt <= memcached_req_pkt + 1;
					end else if (status[3:0] == 4'b1111 
						&& (memcached_opcode == PROTOCOL_BINARY_CMD_GET 
						|| memcached_opcode == PROTOCOL_BINARY_CMD_DELETE)) begin
						tmp[MEMC_GET_KEY_TMP_LEN-1:0] <= s_axis_tdata_buf[MEMC_GET_KEY_POS+MEMC_GET_KEY_TMP_LEN-1:MEMC_GET_KEY_POS];
						memcached_req_pkt <= memcached_req_pkt + 1;
					end
`ifdef CACHE_MODE
						else if (status[5:0] == 6'b110011 && memcached_opcode == PROTOCOL_BINARY_CMD_GET) begin
						tmp[MEMC_GET_VAL_TMP_LEN-1:0] <= s_axis_tdata_buf[MEMC_GET_VAL_TMP_LEN+MEMC_GET_VAL_POS-1:MEMC_GET_VAL_POS]; // GET Value
						memcached_rep_pkt <= memcached_rep_pkt + 1;
					end
`endif /* CACHE_MODE */
				end
			endcase

			if (s_axis_tlast_buf) begin
				s_axis_cnt <= 0;
			end else begin
				s_axis_cnt <= s_axis_cnt + 1;
			end
		end
		// Last flit of outgoing Packet
		if (tmp_valid) begin
			status <= 0;
			tmp <= 0;
			memcached_opcode <= 0;
			memcached_keylen <= 0;
			memcached_extlen <= 0;
			memcached_bdylen <= 0;
			memcached_flag   <= 0;
			memcached_expire <= 0;
			memcached_req_pkt <= 0;
			memcached_rep_pkt <= 0;
			key_cnt <= 0;
			val_cnt <= 0;
		end
		if (s_axis_tvalid_buf && s_axis_tready_buf && s_axis_tlast_buf) begin
			if (!extend_last)
				extend_last_reg <= 1;
			tmp_valid <= 1;
		end else begin
			extend_last_reg <= 0;
			tmp_valid <= 0;
		end
	end
end

/***********************************************************
 * Prepairing Returning Packet
 ***********************************************************/
wire in_fifo_empty, in_fifo_full, in_fifo_nearly_full;
wire in_fifo_rd_en;

wire         infifo_axis_tlast;
wire [255:0] infifo_axis_tdata;
wire [ 31:0] infifo_axis_tkeep;
wire [127:0] infifo_axis_tuser;

lake_fallthrough_small_fifo #(
	.WIDTH           (C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
	.MAX_DEPTH_BITS  (6)
) u_input_fifo (
	.din           ({s_axis_tlast_buf, s_axis_tuser_buf, 
	                         s_axis_tkeep_buf, s_axis_tdata_buf}),
	.wr_en         ( s_axis_tready_buf && s_axis_tvalid_buf && ~in_fifo_nearly_full ),
	.rd_en         ( in_fifo_rd_en  ),

	.dout          ({infifo_axis_tlast, infifo_axis_tuser, 
	                         infifo_axis_tkeep, infifo_axis_tdata}),
	.full          ( in_fifo_full        ),
	.nearly_full   ( in_fifo_nearly_full ),
	.prog_full     (),
	.empty         ( in_fifo_empty  ),

	.reset         ( !axis_resetn_reg[2] ),
	.clk           ( axis_aclk_buf     )
);

reg data_reg_stage1_empty, data_reg_stage2_empty;
reg data_reg_stage1_stop, data_reg_stage2_stop;

assign in_fifo_rd_en = (((m_axis_tready || data_reg_stage2_empty) && 
                           !data_reg_stage2_stop) || data_reg_stage1_empty) 
                           && !in_fifo_empty;

reg         p0_axis_tlast, p1_axis_tlast, p2_axis_tlast;
reg [255:0] p0_axis_tdata, p1_axis_tdata, p2_axis_tdata;
reg [ 31:0] p0_axis_tkeep, p1_axis_tkeep, p2_axis_tkeep;
reg [127:0] p0_axis_tuser, p1_axis_tuser, p2_axis_tuser;

reg [C_M_AXIS_DATA_WIDTH-1:0] fifo_din;
reg [1:0] header_state;
always @ (posedge axis_aclk_buf) begin
	if (!axis_resetn_reg[3]) begin
		fifo_din      <= 0;
		header_state  <= 0;
		p0_axis_tlast <= 0;
		p0_axis_tdata <= 0;
		p0_axis_tkeep <= 0;
		p0_axis_tuser <= 0;
		p1_axis_tlast <= 0;
		p1_axis_tdata <= 0;
		p1_axis_tkeep <= 0;
		p1_axis_tuser <= 0;
		p2_axis_tlast <= 0;
		p2_axis_tdata <= 0;
		p2_axis_tkeep <= 0;
		p2_axis_tuser <= 0;
		data_reg_stage1_empty <= 0;
		data_reg_stage2_empty <= 0;
		data_reg_stage1_stop  <= 0;
		data_reg_stage2_stop  <= 0;
	end else begin
		data_reg_stage1_empty <= in_fifo_empty;	
		data_reg_stage2_empty <= data_reg_stage1_empty;
		data_reg_stage1_stop  <= 0;
		data_reg_stage2_stop  <= data_reg_stage1_stop;
		p0_axis_tlast <= infifo_axis_tlast;
		p0_axis_tdata <= infifo_axis_tdata;
		p0_axis_tkeep <= infifo_axis_tkeep;
		p0_axis_tuser <= infifo_axis_tuser;
		p1_axis_tlast <= p0_axis_tlast;
		p1_axis_tdata <= p0_axis_tdata;
		p1_axis_tkeep <= p0_axis_tkeep;
		p1_axis_tuser <= p0_axis_tuser;
		p2_axis_tlast <= p1_axis_tlast;
		p2_axis_tdata <= p1_axis_tdata;
		p2_axis_tkeep <= p1_axis_tkeep;
		p2_axis_tuser <= p1_axis_tuser;
		if (in_fifo_rd_en) begin
			case (header_state)
				0: begin
					fifo_din <= {
						p1_axis_tdata[IP_SRC_ADDR_POS+15:IP_SRC_ADDR_POS], // 16
						p1_axis_tdata[IP_DST_ADDR_POS0+IP_DST_ADDR_LEN0-1:IP_DST_ADDR_POS0],//16
						p0_axis_tdata[IP_DST_ADDR_POS1+IP_DST_ADDR_LEN1-1:IP_DST_ADDR_POS1],//16
						p1_axis_tdata[IP_CSUM_POS-1:IP_VER_POS],
						p1_axis_tdata[ETH_TYPE_POS+ETH_TYPE_LEN-1:ETH_TYPE_POS],   //8
						p1_axis_tdata[ETH_DST_MAC_POS+ETH_DST_MAC_LEN-1:ETH_DST_MAC_POS], //48
						p1_axis_tdata[ETH_SRC_MAC_POS+ETH_SRC_MAC_LEN-1:ETH_SRC_MAC_POS] //48
						};
				end 
				1: begin
					fifo_din <= {
						208'd0,
						p1_axis_tdata[UDP_SRC_UPORT_POS+UDP_SRC_UPORT_LEN-1:UDP_SRC_UPORT_POS],
						p1_axis_tdata[UDP_DST_UPORT_POS+UDP_DST_UPORT_LEN-1:UDP_DST_UPORT_POS],
						p2_axis_tdata[IP_SRC_ADDR_POS+31:IP_SRC_ADDR_POS+16]
						};
				end
				2: begin

				end
				default: ;
			endcase
			if (p2_axis_tlast) begin // Reset
				header_state <= 0;
			end else begin
				header_state <= header_state + 1;
			end
		end
	end
end

/************************************************
 * PE instance
 ************************************************/
localparam STRPE_OP_GET    = 8'd0;
localparam STRPE_OP_SET    = 8'd1;
localparam STRPE_OP_DEL    = 8'd2;

wire [C_S_AXIS_DATA_WIDTH - 1:0]         s_pe_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_pe_axis_tkeep;
wire [PE_TUSER_WIDTH-1:0]                s_pe_axis_tuser;
wire                                     s_pe_axis_tvalid;
wire                                     s_pe_axis_tready;
wire                                     s_pe_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH - 1:0]         m_pe_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] m_pe_axis_tkeep;
wire [PE_TUSER_WIDTH-1:0]                m_pe_axis_tuser;
wire                                     m_pe_axis_tvalid;
wire                                     m_pe_axis_tready;
wire                                     m_pe_axis_tlast;

wire [7:0] opcode = 
       (memcached_opcode == PROTOCOL_BINARY_CMD_SET ||
        memcached_opcode == PROTOCOL_BINARY_CMD_ADD) ? STRPE_OP_SET :
       (memcached_opcode == PROTOCOL_BINARY_CMD_DELETE) ? STRPE_OP_DEL :
       (memcached_opcode == PROTOCOL_BINARY_CMD_GET) ? STRPE_OP_GET : 0;

wire key_en;
wire key_last;
wire val_en;
wire val_last;
assign key_en   = memcached_keylen > {3'd0, memcached_req_pkt, 5'd0} - 32 && memcached_req_pkt != 0; 
assign key_last = memcached_keylen > {3'd0, memcached_req_pkt, 5'd0} - 32 && memcached_keylen <= {3'd0, memcached_req_pkt, 5'd0} && memcached_req_pkt != 0;
assign val_en   = (memcached_keylen[4:0] != 0) ? (key_last || val_last  || (!key_en && (memcached_keylen + memcached_vallen) >= {3'd0, memcached_req_pkt, 5'd0})) && memcached_req_pkt != 0 :
                  (memcached_keylen[4:0] == 0) ? !key_en && (val_last || (memcached_keylen + memcached_vallen) >= {3'd0, memcached_req_pkt, 5'd0}) && memcached_req_pkt != 0 : 0;
assign val_last = ((memcached_keylen + memcached_vallen) <= {3'd0, memcached_req_pkt, 5'd0}) && memcached_req_pkt != 0;

assign s_pe_axis_tuser = 
       ((memcached_opcode == PROTOCOL_BINARY_CMD_SET || 
        memcached_opcode == PROTOCOL_BINARY_CMD_ADD || 
        memcached_opcode == PROTOCOL_BINARY_CMD_DELETE) && memcached_req_pkt != 0) ? 
            {48'h0, config_pe_id, memcached_vallen[15:0], memcached_keylen[15:0], 
             opcode[7:0], val_last, val_en, key_last, key_en} : 
       (memcached_opcode == PROTOCOL_BINARY_CMD_GET && memcached_req_pkt != 0) ? 
            {src_uport, memcached_opaque, config_pe_id, memcached_vallen[15:0], memcached_keylen[15:0], 
             opcode[7:0], val_last, val_en, key_last, key_en} : 
       (memcached_opcode == PROTOCOL_BINARY_CMD_GET && memcached_rep_pkt != 0) ? 
           {src_uport, memcached_opaque, config_pe_id, memcached_vallen, 16'd0, 4'b1111, opcode[3:0], val_last, val_en, key_last, key_en} :
             0 ;

assign s_pe_axis_tdata = ((memcached_opcode == PROTOCOL_BINARY_CMD_SET ||
                          memcached_opcode == PROTOCOL_BINARY_CMD_ADD ) && memcached_req_pkt) ?
                             { s_axis_tdata_buf[MEMC_SET_KEY_POS-1:0],
                               tmp[MEMC_SET_KEY_TMP_LEN-1:0] }      :
                         (memcached_opcode == PROTOCOL_BINARY_CMD_GET ||
                          memcached_opcode == PROTOCOL_BINARY_CMD_DELETE && memcached_req_pkt) ?
                             { s_axis_tdata_buf[MEMC_GET_KEY_POS-1:0],
                               tmp[MEMC_GET_KEY_TMP_LEN-1:0] }      :
                         (memcached_opcode == PROTOCOL_BINARY_CMD_GET && memcached_rep_pkt) ?
                             { s_axis_tdata_buf[MEMC_GET_VAL_POS-1:0],
                               tmp[MEMC_GET_VAL_TMP_LEN-1:0] }      : 0;


assign s_pe_axis_tvalid = ((s_axis_cnt != 8'h0 && s_axis_cnt != 8'h1 && s_axis_cnt != 8'h2) && s_axis_tvalid_buf) || extend_last_reg;
assign s_pe_axis_tlast  = extend_last || extend_last_reg;
// Todo : keep signal
//      : ready signal
assign s_pe_axis_tkeep = nkeep(32);

always @ (posedge axis_aclk_buf) 
	if (!axis_resetn_reg[4]) begin
		stat_set_cnt <= 0;
		stat_get_cnt <= 0;
		stat_del_cnt <= 0;
	end else begin
		if (s_pe_axis_tlast && s_pe_axis_tvalid && s_pe_axis_tready) begin
			if (memcached_opcode == PROTOCOL_BINARY_CMD_SET || memcached_opcode == PROTOCOL_BINARY_CMD_ADD)
				stat_set_cnt <= stat_set_cnt + 1;
			else if (memcached_opcode == PROTOCOL_BINARY_CMD_GET)
				stat_get_cnt <= stat_get_cnt + 1;
			else if (memcached_opcode == PROTOCOL_BINARY_CMD_DELETE)
				stat_del_cnt <= stat_del_cnt + 1;
		end
	end


string_pe #(
	.HASH_VALUE_WIDTH      ( 32 ),
	.PE_DEST_BITS          ( C_M_AXIS_TDEST_WIDTH ),
	.PE_DATA_PATH_WIDTH    ( C_M_AXIS_DATA_WIDTH ),
	.PE_USER_PATH_WIDTH    ( PE_TUSER_WIDTH ),
	.MEM_DATA_PATH_WIDTH   ( MEM_DATA_PATH_WIDTH ),
	.MEM_USER_PATH_WIDTH   ( MEM_USER_PATH_WIDTH ),
	.DATA_PATH_WIDTH       ( 64 ),    // bit
	.MAX_KEY_SUPPORT       ( 64 ),    // Max Bytes
	.MAX_VAL_SUPPORT       ( 64 ),    // Max Bytes
	.ASSOCIATIVE           ( "1way" ) // 1way, 2way, 4way, 8way
) u_string_pe (
	.clk                   ( axis_aclk_buf    ),
	.rst                   ( !axis_resetn_reg[4] ),
	.pe_id                 ( config_pe_id ),
	.config_dram_node      ( 3'h0         ),
	.config_sram_node      ( 3'h1         ),
	.config_lut_node       ( 3'h2         ),
	.debug_table           ( debug_table  ),
	.debug_chunk           ( debug_chunk  ),
	
	/* From Ethernet */
	.s_pe_axis_tdata       ( s_pe_axis_tdata  ),
	.s_pe_axis_tkeep       ( s_pe_axis_tkeep  ),
	.s_pe_axis_tuser       ( s_pe_axis_tuser  ),
	.s_pe_axis_tlast       ( s_pe_axis_tlast  ),
	.s_pe_axis_tready      ( s_pe_axis_tready ),
	.s_pe_axis_tvalid      ( s_pe_axis_tvalid ),

	/* To Ethernet */
	.m_pe_axis_tdata       ( m_pe_axis_tdata  ),
	.m_pe_axis_tkeep       ( m_pe_axis_tkeep  ),
	.m_pe_axis_tuser       ( m_pe_axis_tuser  ),
	.m_pe_axis_tready      ( m_pe_axis_tready ),
	.m_pe_axis_tvalid      ( m_pe_axis_tvalid ),
	.m_pe_axis_tlast       ( m_pe_axis_tlast  ),

	/* From Memory */
	.s_mem_axis_tdata      ( mem_s_axis_tdata  ),
	.s_mem_axis_tkeep      ( mem_s_axis_tkeep  ),
	.s_mem_axis_tuser      ( mem_s_axis_tuser  ),
	.s_mem_axis_tdest      ( mem_s_axis_tdest  ),
	.s_mem_axis_tlast      ( mem_s_axis_tlast  ),
	.s_mem_axis_tready     ( mem_s_axis_tready ),
	.s_mem_axis_tvalid     ( mem_s_axis_tvalid ),

	/* To Memory */
	.m_mem_axis_tdata      ( mem_m_axis_tdata  ),
	.m_mem_axis_tkeep      ( mem_m_axis_tkeep  ),
	.m_mem_axis_tuser      ( mem_m_axis_tuser  ),
	.m_mem_axis_tdest      ( mem_m_axis_tdest  ),
	.m_mem_axis_tready     ( mem_m_axis_tready ),
	.m_mem_axis_tvalid     ( mem_m_axis_tvalid ),
	.m_mem_axis_tlast      ( mem_m_axis_tlast  ) 
);                      

/************************************************
 * Returning Query:
 *    [Cache Mode]
 *         Cache Miss ---> Server
 *         Cache Hit  ---> Client
 *    [Storage Mode]
 *         Cache Miss ---> Client
 *         Cache Hit  ---> Client
 ************************************************/
reg stop_next;

wire header_wr_en, header_rd_en;
wire header_empty, header_full;
wire full_return, empty_return;
wire nearly_full_return;
assign header_wr_en = s_axis_tvalid_buf && s_axis_tready_buf;// && (s_axis_cnt == 8'd0 || s_axis_cnt == 8'd1 || s_axis_cnt == 8'd2);
assign header_rd_en = stop_next && !nearly_full_return;

localparam MODE_CACHE = 0;
localparam MODE_STORAGE = 1;
wire [C_M_AXIS_DATA_WIDTH-1:0] fifo_axis_tdata;
wire [31:0] fifo_axis_tuser;
wire [31:0] fifo_axis_tkeep;
wire        fifo_axis_tlast;
wire [7:0] fifo_axis_cnt;

lake_fallthrough_small_fifo #(
	.WIDTH           (8 + C_M_AXIS_DATA_WIDTH + 32 + 32 + 1),
	.MAX_DEPTH_BITS  ( 6 )
) u_header_fifo (
	.din           ({s_axis_cnt, s_axis_tdata_buf, s_axis_tuser_buf[31:0], s_axis_tkeep_buf, s_axis_tlast_buf} ),
	.wr_en         ( header_wr_en  ),
	.rd_en         ( header_rd_en  ),

	.dout          ({fifo_axis_cnt, fifo_axis_tdata, fifo_axis_tuser, fifo_axis_tkeep, fifo_axis_tlast}),
	.full          ( header_full   ),
	.nearly_full   (),
	.prog_full     (),
	.empty         ( header_empty  ),

	.reset         ( !axis_resetn_reg[5] ),
	.clk           ( axis_aclk_buf     )
);

reg  [MODE_REG_WIDTH-1:0] mode_reg;
reg stop_reg;
reg s_axis_tready_reg;
reg  [C_M_AXIS_DATA_WIDTH-1:0]   m_axis_tdata_reg;
reg  [C_M_AXIS_TUSER_WIDTH-1:0]  m_axis_tuser_reg;
reg  [C_M_AXIS_DATA_WIDTH/8-1:0] m_axis_tkeep_reg;
reg                              m_axis_tlast_reg;
reg  [C_M_AXIS_DATA_WIDTH-1:0]   p0_m_axis_tdata_reg;
reg  [31:0]                      p0_m_axis_tuser_reg;
reg  [C_M_AXIS_DATA_WIDTH/8-1:0] p0_m_axis_tkeep_reg;
reg                              p0_m_axis_tlast_reg;
reg  [C_M_AXIS_DATA_WIDTH-1:0]   p1_m_axis_tdata_reg;
reg  [31:0]                      p1_m_axis_tuser_reg;
reg  [C_M_AXIS_DATA_WIDTH/8-1:0] p1_m_axis_tkeep_reg;
reg                              p1_m_axis_tlast_reg;
reg  [31:0]  tmp0;
reg  [255:0] tmp_data[15:0];
reg  [255:0] tmp_data_reg;
reg  [1:0]   result_reg;
reg  [15:0]  vallen_reg;
reg          wr_en_return;
reg  [23:0]  ipsum;
reg  [15:0]  ethlen;
localparam TUSER_CACHE_MISS     = 2'b01;
localparam TUSER_CACHE_HIT      = 2'b10;
localparam TUSER_CACHE_THROUGH  = 2'b11;
localparam TUSER_CACHE_DISCARD  = 2'b00;

// Todo : state machine
reg [2:0] state;
reg [15:0] iplen;
reg [15:0] udplen;
reg [15:0] udpsum;
reg [15:0] extlen;
reg [31:0] totlen;

reg tuser_result; // 1 == HIT, 0 == MISS
reg [15:0] tuser_length;
reg [2:0] m_pe_cnt;
reg [255:0] tmp_kv;
//wire [255:0] pe_data0 = tmp_data[0];
//wire [255:0] pe_data1 = tmp_data[1];
//wire [255:0] pe_data2 = tmp_data[2];
//wire [255:0] pe_data3 = tmp_data[3];
//wire [255:0] pe_data4 = tmp_data[4];
//wire [255:0] pe_data5 = tmp_data[5];
//wire [255:0] pe_data6 = tmp_data[6];
//wire [255:0] pe_data7 = tmp_data[7];
//wire [255:0] pe_data8 = tmp_data[8];
//wire [255:0] pe_data9 = tmp_data[9];
//wire [255:0] pe_dataa = tmp_data[10];
//wire [255:0] pe_datab = tmp_data[11];
//wire [255:0] pe_datac = tmp_data[12];
//wire [255:0] pe_datad = tmp_data[13];
//wire [255:0] pe_datae = tmp_data[14];
//wire [255:0] pe_dataf = tmp_data[15];
reg [15:0] vallen_cmp;
reg [15:0] memcached_state;
reg [31:0] cache_hit_pkts;
reg [31:0] cache_miss_pkts;

reg [7:0] opcode_reg;
reg [4:0] index;

always @ (posedge axis_aclk_buf)
	if (!axis_resetn_reg[6]) begin
		mode_reg            <= 0;
		stop_reg            <= 0;
		s_axis_tready_reg   <= 1;
		m_axis_tdata_reg    <= 0;
		m_axis_tuser_reg    <= 0;
		m_axis_tkeep_reg    <= 0;
		m_axis_tlast_reg    <= 0;
		p0_m_axis_tdata_reg <= 0;
		p0_m_axis_tuser_reg <= 0;
		p1_m_axis_tdata_reg <= 0;
		p1_m_axis_tuser_reg <= 0;
		ethlen              <= 0;
		iplen               <= 0;
		ipsum               <= 0;
		udplen              <= 0;
		udpsum              <= 0;
		extlen              <= 0;
		totlen              <= 0;
		tmp0                <= 0;
		tmp_data[0]         <= 0;
		tmp_data[1]         <= 0;
		tmp_data[2]         <= 0;
		tmp_data[3]         <= 0;
		tmp_data[4]         <= 0;
		tmp_data[5]         <= 0;
		tmp_data[6]         <= 0;
		tmp_data[7]         <= 0;
		tmp_data[8]         <= 0;
		tmp_data[9]         <= 0;
		tmp_data[10]        <= 0;
		tmp_data[11]        <= 0;
		tmp_data[12]        <= 0;
		tmp_data[13]        <= 0;
		tmp_data[14]        <= 0;
		tmp_data[15]        <= 0;
		tmp_data_reg        <= 0;
		m_pe_cnt            <= 0;
		result_reg          <= 0;
		wr_en_return        <= 0;
		vallen_reg          <= 0;
		tuser_result        <= 0;
		tuser_length        <= 0;
		state               <= 0;
		vallen_cmp          <= 0;
		opcode_reg          <= 0;
		memcached_state     <= 0;
		cache_hit_pkts      <= 0;
		cache_miss_pkts     <= 0;
		tmp_kv <= 0;
		index  <= 0;
	end else begin
		stop_reg <= stop_next;
		mode_reg <= config_mode;
		
		//if (s_axis_tlast_buf && s_axis_tvalid_buf && s_axis_tready_buf) begin
		if (s_axis_tlast && s_axis_tvalid && s_axis_tready) begin
			s_axis_tready_reg <= 1'b0;
		end else begin
			//s_axis_tready_reg <= s_axis_tready_buf;
			s_axis_tready_reg <= s_axis_tready;
		end
		if (m_pe_axis_tvalid && m_pe_axis_tready && m_pe_axis_tlast) begin
			m_pe_cnt <= 0;
			tmp_data[m_pe_cnt] <= m_pe_axis_tdata;
		end else if (m_pe_axis_tvalid && m_pe_axis_tready) begin
			m_pe_cnt <= m_pe_cnt + 1;
			tmp_data[m_pe_cnt] <= m_pe_axis_tdata;
		end 

		p0_m_axis_tdata_reg <= fifo_axis_tdata;
		p0_m_axis_tuser_reg <= fifo_axis_tuser;
		p0_m_axis_tkeep_reg <= fifo_axis_tkeep;
		p0_m_axis_tlast_reg <= fifo_axis_tlast;
		p1_m_axis_tdata_reg <= p0_m_axis_tdata_reg;
		p1_m_axis_tuser_reg <= p0_m_axis_tuser_reg;
		p1_m_axis_tkeep_reg <= p0_m_axis_tkeep_reg;
		p1_m_axis_tlast_reg <= p0_m_axis_tlast_reg;
		if (mode_reg[0] == MODE_CACHE) begin
`ifdef CACHE_MODE
			case (state)
				0: begin
					memcached_state <= 0;
					wr_en_return     <= 0;
					m_axis_tlast_reg <= 1'b0;
					if (!nearly_full_return && m_pe_axis_tvalid && m_pe_axis_tready && 
							m_pe_axis_tuser[9:2] == STRPE_OP_GET/* && m_pe_axis_tuser == TUSER_CACHE_HIT*/) begin
						$display("REPLY PACKET START : tdata %x", m_pe_axis_tdata);
						state <= 1;
						result_reg <= m_pe_axis_tuser[1:0];
						opcode_reg <= m_pe_axis_tuser[9:2];
						vallen_reg <= m_pe_axis_tuser[25:10];
						ipsum <= 16'h4500 + fifo_axis_tdata[IP_IDENT_POS+IP_IDENT_LEN-1:IP_IDENT_POS] 
						      + {TTL_DEFAULT, 8'h11} + fifo_axis_tdata[IP_SRC_ADDR_POS+15:IP_SRC_ADDR_POS] 
					 	      + fifo_axis_tdata[IP_SRC_ADDR_POS+31:IP_SRC_ADDR_POS+16]
							  + fifo_axis_tdata[IP_DST_ADDR_LEN0+IP_DST_ADDR_POS0-1:IP_DST_ADDR_POS0];
					end //else if (m_pe_axis_tvalid && m_pe_axis_tready && 
						//	m_pe_axis_tuser[9:2] == STRPE_OP_GET && m_pe_axis_tuser == TUSER_CACHE_THROUGH) begin
					//end
						else if (!nearly_full_return && m_pe_axis_tvalid && m_pe_axis_tready && 
							m_pe_axis_tuser[9:2] == STRPE_OP_SET/* && m_pe_axis_tuser == TUSER_CACHE_HIT*/) begin
						result_reg <= m_pe_axis_tuser[1:0];
						opcode_reg <= m_pe_axis_tuser[9:2];
						state <= 1;
					end
				end
				1: begin
					wr_en_return <= 0;
					if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_HIT) begin
						state <= 2;
						cache_hit_pkts      <= cache_hit_pkts + 1;
						$display("CACHE MODE: GET REQUEST HIT: value is returned.");
						ethlen <= 16'd14 + 16'd20 + 16'd8 + 16'd24 + 16'd4 + vallen_reg;
						iplen <= 16'd20 + 16'd8 + 16'd24 + 16'd4 + vallen_reg; 
						udplen <= 16'd8 + 16'd24 + 16'd4 + vallen_reg;
						ipsum <= ipsum + 16'd20 + 16'd8 + 16'd24 + 
					         + fifo_axis_tdata[IP_DST_ADDR_LEN1+IP_DST_ADDR_POS1-1:IP_DST_ADDR_POS1];
						udpsum <= 0;
					end else if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_MISS) begin
						state <= 2;
						$display("CACHE MODE: GET REQUEST MISS: LUT is ready");
						// Resend request packet to host.
					end else if (result_reg == TUSER_CACHE_THROUGH) begin
						cache_miss_pkts      <= cache_miss_pkts + 1;
						state <= 2;
					end else if (result_reg == TUSER_CACHE_DISCARD) begin
						state <= 0;
					end
				end
				2: begin
					if (!full_return) begin
						wr_en_return <= 1;
						if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_HIT) begin
							tmp0[31:0] <= p1_m_axis_tdata_reg[32+IP_SRC_ADDR_POS-1:IP_SRC_ADDR_POS];
							m_axis_tdata_reg <= { 
								p1_m_axis_tdata_reg[16+IP_SRC_ADDR_POS-1:IP_SRC_ADDR_POS],
								p0_m_axis_tdata_reg[IP_DST_ADDR_POS1+IP_DST_ADDR_LEN1-1:IP_DST_ADDR_POS1],
								p1_m_axis_tdata_reg[IP_DST_ADDR_LEN0+IP_DST_ADDR_POS0-1:IP_DST_ADDR_POS0],
								ipsum[7:0], ipsum[15:8], /*ipsum[23:16], ipsum[31:24],*/
								p1_m_axis_tdata_reg[IP_IDENT_POS+IP_IDENT_LEN+IP_FRAG_LEN+IP_TTL_LEN+IP_PROTO_LEN-1:IP_IDENT_POS],
								iplen[7:0], iplen[15:8],
								p1_m_axis_tdata_reg[IP_VER_POS+IP_VER_LEN+IP_IHL_LEN+IP_TOS_LEN-1:IP_VER_POS],
								p1_m_axis_tdata_reg[ETH_TYPE_POS+ETH_TYPE_LEN-1:ETH_TYPE_POS],
								p1_m_axis_tdata_reg[ETH_DST_MAC_POS+ETH_DST_MAC_LEN-1:ETH_DST_MAC_POS],
								p1_m_axis_tdata_reg[ETH_SRC_MAC_POS+ETH_SRC_MAC_LEN-1:ETH_SRC_MAC_POS]
							};
							m_axis_tuser_reg <= {96'h0, p1_m_axis_tuser_reg[31:24], p1_m_axis_tuser_reg[22], 
							                     p1_m_axis_tuser_reg[23], p1_m_axis_tuser_reg[20], p1_m_axis_tuser_reg[21],
							                     p1_m_axis_tuser_reg[18], p1_m_axis_tuser_reg[19], p1_m_axis_tuser_reg[16],
							                     p1_m_axis_tuser_reg[17], ethlen};
							m_axis_tkeep_reg <= 32'hffff_ffff;
							extlen <= 16'd4;
							totlen <= 32'd4 + {16'd0, vallen_reg};
							state <= 3;
						end else if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_THROUGH) begin
							// Resend request packet to host.
							if (p1_m_axis_tlast_reg)
								state <= 0;
							else
								state <= 2;
							m_axis_tdata_reg <= p1_m_axis_tdata_reg;
							m_axis_tuser_reg <= {96'd0, p1_m_axis_tuser_reg[31:0]};
							m_axis_tkeep_reg <= p1_m_axis_tkeep_reg;
							m_axis_tlast_reg <= p1_m_axis_tlast_reg;
						end 
					end
				end
				3: begin
					if (!full_return) begin
						state <= 4;
						wr_en_return <= 1;
						if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_HIT) begin
							m_axis_tkeep_reg <= 32'hffff_ffff;
							m_axis_tdata_reg <= {
								48'd0, // CAS
								p1_m_axis_tdata_reg[MEMC_OPAQUE_LEN+MEMC_OPAQUE_POS-1:MEMC_OPAQUE_POS],
								totlen[7:0], totlen[15:8], totlen[23:16], totlen[31:24],// value len // total len
								memcached_state[7:0], memcached_state[15:8],
								p1_m_axis_tdata_reg[MEMC_DATATYPE_LEN+MEMC_DATATYPE_POS-1:MEMC_DATATYPE_POS],
								extlen[7:0], // Extra length 
								16'd0, // key length
								p1_m_axis_tdata_reg[MEMC_OPCODE_LEN+MEMC_OPCODE_POS-1:MEMC_OPCODE_POS],
								PROTOCOL_BINARY_RES,
								udpsum[7:0], udpsum[15:8],
								udplen[7:0], udplen[15:8],
								p1_m_axis_tdata_reg[UDP_SRC_UPORT_LEN+UDP_SRC_UPORT_POS-1:UDP_SRC_UPORT_POS],
								p1_m_axis_tdata_reg[UDP_DST_UPORT_LEN+UDP_DST_UPORT_POS-1:UDP_DST_UPORT_POS],
								tmp0[31:16]
							};
						end 
					end else begin
						wr_en_return <= 0;
					end
					tmp_kv <= tmp_data[0] & 256'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
				end
				4: begin
					if (!full_return) begin
						state <= 5;
						wr_en_return <= 1;
						if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_HIT) begin
							$display("vallen_reg : %d", vallen_reg);
							if (vallen_reg <= 26) begin
								state <= 0;
								index <= 0;
								m_axis_tkeep_reg <= nkeep(6 + vallen_reg);
								m_axis_tlast_reg <= 1;
							end else begin
								vallen_cmp <= vallen_reg - 26;
								state <= 5;
								index <= 1;
								m_axis_tkeep_reg <= 32'hffffffff;
								m_axis_tlast_reg <= 0;
							end
							m_axis_tdata_reg <= {
								//m_pe_axis_tdata[255:48], // value
								//pe_data0[207:0],
								tmp_kv[207:0],
								32'd0, // Extra Flat
								16'd0 // left CAS. 
							};
						end
						tmp_kv <= (tmp_data[1] & 256'hffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffff0000_00000000) | (tmp_data[0] & 256'h00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff);
					end else begin
						wr_en_return <= 0;
					end
				end
				5: begin
					if (!full_return) begin
						if (vallen_cmp <= 32) begin
							state <= 0;
							index <= 0;
							wr_en_return <= 1;
							//m_axis_tdata_reg <= {pe_data1[255:192], pe_data0[63:0]};// todo: more much data 
							m_axis_tdata_reg <= tmp_kv;
							m_axis_tkeep_reg <= nkeep(vallen_cmp);
							m_axis_tlast_reg <= 1'b1;
						end else begin
							// todo : support for more than 56B.
							index <= index + 1;
							m_axis_tdata_reg <= tmp_kv;
							vallen_cmp <= vallen_cmp - 26;
							state <= 5;
							wr_en_return <= 1;
							tmp_kv <= (tmp_data[index+1] & 256'hffffffff_ffff0000_00000000_00000000_00000000_00000000_00000000_00000000) | (tmp_data[index] & 256'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff);
						end
					end else begin
							wr_en_return <= 0;
					end
				end
				default: ;
			endcase
`endif/* CACHE_MODE */
		end else begin // mode[0] == MODE_STORAGE
			case (state)
				0: begin
					wr_en_return <= 0;
					m_axis_tlast_reg <= 1'b0;
					memcached_state <= 0;
					if (m_pe_axis_tvalid && m_pe_axis_tready) begin
						$display("REPLY PACKET START : tdata %x", m_pe_axis_tdata);
						state <= 1;
						result_reg <= m_pe_axis_tuser[1:0];
						opcode_reg <= m_pe_axis_tuser[9:2];
						vallen_reg <= m_pe_axis_tuser[25:10];
						ipsum <= 16'h4500 + fifo_axis_tdata[IP_IDENT_POS+IP_IDENT_LEN-1:IP_IDENT_POS] 
						      + {TTL_DEFAULT, 8'h11} + fifo_axis_tdata[IP_SRC_ADDR_POS+15:IP_SRC_ADDR_POS] 
					 	      + fifo_axis_tdata[IP_SRC_ADDR_POS+31:IP_SRC_ADDR_POS+16]
							  + fifo_axis_tdata[IP_DST_ADDR_LEN0+IP_DST_ADDR_POS0-1:IP_DST_ADDR_POS0];
					end
				end
				1: begin
					state <= 2;
					wr_en_return <= 0;
					if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_HIT) begin
						memcached_state <= 0;
						ethlen <= 16'd14 + 16'd20 + 16'd8 + 16'd24 + 16'd4 + vallen_reg;
						iplen <= 16'd20 + 16'd8 + 16'd24 + 16'd4 + vallen_reg; 
						udplen <= 16'd8 + 16'd24 + 16'd4 + vallen_reg;
						ipsum <= ipsum + 16'd20 + 16'd8 + 16'd24 + 
					         + fifo_axis_tdata[IP_DST_ADDR_LEN1+IP_DST_ADDR_POS1-1:IP_DST_ADDR_POS1];
						udpsum <= 0;
					end else if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_MISS) begin
						memcached_state <= 1;
						ethlen <= 16'd14 + 16'd20 + 16'd8 + 16'd24;
						iplen <= 16'd20 + 16'd8 + 16'd24;
						udplen <= 16'd8 + 16'd24;
						ipsum <= ipsum + 16'd20 + 16'd8 + 16'd24 + 
					         + fifo_axis_tdata[IP_DST_ADDR_LEN1+IP_DST_ADDR_POS1-1:IP_DST_ADDR_POS1];
						udpsum <= 0;
					end else if (opcode_reg == STRPE_OP_SET && result_reg == TUSER_CACHE_HIT) begin
						ethlen <= 16'd14 + 16'd20 + 16'd8 + 16'd24;
						iplen <= 16'd20 + 16'd8 + 16'd24;
						udplen <= 16'd8 + 16'd24;
						ipsum <= ipsum + 16'd20 + 16'd8 + 16'd24 + 
					         + fifo_axis_tdata[IP_DST_ADDR_LEN1+IP_DST_ADDR_POS1-1:IP_DST_ADDR_POS1];
						udpsum <= 0;
					end else if (opcode_reg == STRPE_OP_SET && result_reg == TUSER_CACHE_MISS) begin
						ethlen <= 16'd14 + 16'd20 + 16'd8 + 16'd24;
						iplen <= 16'd20 + 16'd8 + 16'd24;
						udplen <= 16'd8 + 16'd24;
						ipsum <= ipsum + 16'd20 + 16'd8 + 16'd24 + 
					         + fifo_axis_tdata[IP_DST_ADDR_LEN1+IP_DST_ADDR_POS1-1:IP_DST_ADDR_POS1];
						udpsum <= 0;
					end
				end
				2: begin
					wr_en_return <= 1;
					tmp0[31:0] <= p1_m_axis_tdata_reg[32+IP_SRC_ADDR_POS-1:IP_SRC_ADDR_POS];
					m_axis_tdata_reg <= { 
						p1_m_axis_tdata_reg[16+IP_SRC_ADDR_POS-1:IP_SRC_ADDR_POS],
						p0_m_axis_tdata_reg[IP_DST_ADDR_LEN1+IP_DST_ADDR_POS1-1:IP_DST_ADDR_POS1],
						p1_m_axis_tdata_reg[IP_DST_ADDR_LEN0+IP_DST_ADDR_POS0-1:IP_DST_ADDR_POS0],
						ipsum[7:0], ipsum[15:8], /*ipsum[23:16], ipsum[31:24],*/
						p1_m_axis_tdata_reg[IP_IDENT_POS+IP_IDENT_LEN+IP_FRAG_LEN+IP_TTL_LEN+IP_PROTO_LEN-1:IP_IDENT_POS],
						iplen[7:0], iplen[15:8],
						p1_m_axis_tdata_reg[IP_VER_POS+IP_VER_LEN+IP_IHL_LEN+IP_TOS_LEN-1:IP_VER_POS],
						p1_m_axis_tdata_reg[ETH_TYPE_POS+ETH_TYPE_LEN-1:ETH_TYPE_POS],
						p1_m_axis_tdata_reg[ETH_DST_MAC_POS+ETH_DST_MAC_LEN-1:ETH_DST_MAC_POS],
						p1_m_axis_tdata_reg[ETH_SRC_MAC_POS+ETH_SRC_MAC_LEN-1:ETH_SRC_MAC_POS]
					};
					m_axis_tuser_reg <= {96'h0, {p1_m_axis_tuser_reg[31:24], p1_m_axis_tuser_reg[22], p1_m_axis_tuser_reg[23], p1_m_axis_tuser_reg[20], p1_m_axis_tuser_reg[21], p1_m_axis_tuser_reg[18], p1_m_axis_tuser_reg[19], p1_m_axis_tuser_reg[16], p1_m_axis_tuser_reg[17]}, ethlen};
					m_axis_tkeep_reg <= 32'hffff_ffff;
					if (opcode_reg == STRPE_OP_GET && result_reg ==  TUSER_CACHE_HIT) begin
						extlen <= 16'd4;
						totlen <= 32'd4 + {16'd0, vallen_reg};
					end else if (opcode_reg == STRPE_OP_GET && result_reg ==  TUSER_CACHE_MISS) begin
						extlen <= 16'd0;
						totlen <= 32'd0;// + {16'd0, vallen_reg};
					end else if (opcode_reg == STRPE_OP_SET && result_reg ==  TUSER_CACHE_MISS) begin
						extlen <= 16'd0;
						totlen <= 32'd0;// + {16'd0, vallen_reg};
					end else if (opcode_reg == STRPE_OP_SET && result_reg ==  TUSER_CACHE_MISS) begin
						extlen <= 16'd0;
						totlen <= 32'd0;// + {16'd0, vallen_reg};
					end else begin
					end
					state <= 3;
				end
				3: begin
					state <= 4;
					wr_en_return <= 1;
					m_axis_tkeep_reg <= 32'hffff_ffff;
					m_axis_tdata_reg <= {
						48'd0, // CAS
						p1_m_axis_tdata_reg[MEMC_OPAQUE_LEN+MEMC_OPAQUE_POS-1:MEMC_OPAQUE_POS],
						totlen[7:0], totlen[15:8], totlen[23:16], totlen[31:24],// value len // total len
						//p1_m_axis_tdata_reg[MEMC_RESRVD_LEN+MEMC_RESRVD_POS-1:MEMC_RESRVD_POS],
						memcached_state[7:0], memcached_state[15:8],
						p1_m_axis_tdata_reg[MEMC_DATATYPE_LEN+MEMC_DATATYPE_POS-1:MEMC_DATATYPE_POS],
						extlen[7:0], // Extra length 
						16'd0, // key length
						p1_m_axis_tdata_reg[MEMC_OPCODE_LEN+MEMC_OPCODE_POS-1:MEMC_OPCODE_POS],
						PROTOCOL_BINARY_RES,
						udpsum[7:0], udpsum[15:8],
						udplen[7:0], udplen[15:8],
						p1_m_axis_tdata_reg[UDP_SRC_UPORT_LEN+UDP_SRC_UPORT_POS-1:UDP_SRC_UPORT_POS],
						p1_m_axis_tdata_reg[UDP_DST_UPORT_LEN+UDP_DST_UPORT_POS-1:UDP_DST_UPORT_POS],
						tmp0[31:16]
					};
					tmp_kv <= tmp_data[0] | 256'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
				end
				4: begin
					state <= 5;
					wr_en_return <= 1;
					if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_HIT) begin
						$display("vallen_reg : %d", vallen_reg);
						if (vallen_reg <= 26) begin
							state <= 0;
							m_axis_tkeep_reg <= nkeep(6 + vallen_reg);
							m_axis_tlast_reg <= 1;
							index <= 0;
						end else begin
							vallen_cmp <= vallen_reg - 26;
							state <= 5;
							m_axis_tkeep_reg <= 32'hffffffff;
							m_axis_tlast_reg <= 0;
							index <= 1;
						end
						m_axis_tdata_reg <= {
							//m_pe_axis_tdata[255:48], // value
							//pe_data0[207:0],
							tmp_kv[207:0],
							32'd0, // Extra Flat
							16'd0 // left CAS. 
						};
						tmp_kv <= (tmp_data[1] | 256'hffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffff0000_00000000) | (tmp_data[0] | 256'h00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff);
					end else if (opcode_reg == STRPE_OP_GET && result_reg == TUSER_CACHE_MISS) begin
						state <= 0;
						m_axis_tdata_reg <= {
							240'd0, //
							16'd0 // left CAS. 
						};
						m_axis_tkeep_reg <= 32'h3; // 2B
						m_axis_tlast_reg <= 1'b1;
					end else if (opcode_reg == STRPE_OP_SET) begin
						state <= 0;
						m_axis_tdata_reg <= {
							240'd0,
							16'd0 // left CAS. // if set cmd is successful, CAS is 1.
						};
						m_axis_tkeep_reg <= 32'h3; // 2B
						m_axis_tlast_reg <= 1'b1;
					end
				end
				5: begin
					if (vallen_cmp <= 56) begin
						vallen_cmp <= 0;
						state <= 0;
						index <= 0;
						wr_en_return <= 1;
						//m_axis_tdata_reg <= {pe_data1[255:192], pe_data0[63:0]};// todo: more much data 
						m_axis_tdata_reg <= tmp_kv;
						m_axis_tkeep_reg <= nkeep(vallen_cmp);
						m_axis_tlast_reg <= 1'b1;
					end else begin
						// todo : support for more than 56B.
						index <= index + 1;
						vallen_cmp <= vallen_cmp - 26;
						//m_axis_tdata_reg <= {pe_data1[255:192], pe_data0[63:0]};// todo: more much data 
						m_axis_tdata_reg <= tmp_kv;
						tmp_kv <= (tmp_data[index+1] | 256'h11111111_11110000_00000000_00000000_00000000_00000000_00000000_00000000) | (tmp_data[index] | 256'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff);
						state <= 5;
					end
				end
				default: ;
			endcase
		end
	end

always @ (*) begin
	stop_next = stop_reg;
	s_axis_tready = s_axis_tready_reg;

	if (m_pe_axis_tvalid && m_pe_axis_tready)
		stop_next = 1;
`ifdef CACHE_MODE
	if (stop_reg == 1 && header_empty /*m_axis_tvalid && m_axis_tready && m_axis_tlast*/) begin
`else
	if (stop_reg == 1 && m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
`endif
		stop_next = 0;
		s_axis_tready = 1'b1;
	end
end

assign m_pe_axis_tready = 1;// todo
assign m_axis_tdest = 0;
/************************************************
 * Returning packet
 ************************************************/
assign m_axis_tvalid = !empty_return && m_axis_tready;
assign active_ready = (!empty_return && s_pe_axis_tready && header_empty && s_axis_tready);

lake_fallthrough_small_fifo #(
	.WIDTH           (C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
	.MAX_DEPTH_BITS  (6)
) u_return_fifo (
	.din           ({m_axis_tlast_reg, m_axis_tuser_reg,
	                      m_axis_tkeep_reg, m_axis_tdata_reg}),
	.wr_en         ( wr_en_return ),
	.rd_en         ( !empty_return && m_axis_tready  ),

	.dout          ({m_axis_tlast, m_axis_tuser, 
	                      m_axis_tkeep, m_axis_tdata}),
	.full          ( full_return  ),
	.nearly_full   ( nearly_full_return ),
	.prog_full     ( ),
	.empty         ( empty_return ),

	.reset         ( !axis_resetn_reg[7] ),
	.clk           ( axis_aclk_buf     )
);

/************************************************
 * Registers for Debug
 ************************************************/

always @ (posedge axis_aclk_buf) 
	if (!axis_resetn_reg[8]) begin
		pktin           <= 0;
		pktout          <= 0;
		error_pkt       <= 0;
	end else begin
		if (m_axis_tvalid && m_axis_tlast && m_axis_tready) begin
			pktout <= pktout + 1;
		end
		if (s_axis_tvalid_buf && s_axis_tlast_buf && s_axis_tready_buf) begin
			pktin <= pktin + 1;
		end
		if (status[3:0] != 4'b1111 && s_pe_axis_tready && 
				s_pe_axis_tvalid &&  s_pe_axis_tlast) begin
			error_pkt <= error_pkt + 1;
		end
	end

assign queries_l1miss = cache_miss_pkts; 
assign queries_l1hit  = cache_hit_pkts; 

endmodule

