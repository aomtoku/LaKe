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

module string_pe #(
	parameter HASH_VALUE_WIDTH    = 32,
	parameter PE_DATA_PATH_WIDTH  = 256,
	parameter PE_USER_PATH_WIDTH  = 100,
	parameter PE_DEST_BITS        = 3,
	parameter MEM_DATA_PATH_WIDTH = 512,
	parameter MEM_USER_PATH_WIDTH = 128,
	parameter DATA_PATH_WIDTH     = 64,    // bit
	parameter MAX_KEY_SUPPORT     = 64,    // Max Bytes
	parameter MAX_VAL_SUPPORT     = 64,    // Max Bytes
	parameter MAX_FLIT_SIZE       = 4,    // Max Bytes
	parameter ASSOCIATIVE         = "1way" // 1way, 2way, 4way, 8way
)(
	input  wire         clk,
	input  wire         rst,
	input  wire  [7:0]  pe_id,
	input  wire  [PE_DEST_BITS-1:0]  config_dram_node,
	input  wire  [PE_DEST_BITS-1:0]  config_sram_node,
	input  wire  [PE_DEST_BITS-1:0]  config_lut_node,
	output wire  [31:0] debug_table,
	output wire  [31:0] debug_chunk,
	output reg   [31:0] htable_acc_all,
	output reg   [31:0] htable_acc_hit,
	
	/* From Ethernet */
	input  wire [PE_DATA_PATH_WIDTH-1:0]    s_pe_axis_tdata,
	input  wire [PE_DATA_PATH_WIDTH/8-1:0]  s_pe_axis_tkeep,
	input  wire [PE_USER_PATH_WIDTH-1:0]    s_pe_axis_tuser,
	input  wire                             s_pe_axis_tlast,
	output wire                             s_pe_axis_tready,
	input  wire                             s_pe_axis_tvalid,
	
	/* To Ethernet */
	output reg  [PE_DATA_PATH_WIDTH-1:0]    m_pe_axis_tdata,
	output reg  [PE_DATA_PATH_WIDTH/8-1:0]  m_pe_axis_tkeep,
	output reg  [PE_USER_PATH_WIDTH-1:0]    m_pe_axis_tuser,
	input                                   m_pe_axis_tready,
	output reg                              m_pe_axis_tvalid,
	output reg                              m_pe_axis_tlast,

	/* From Ethernet */
	input  wire [MEM_DATA_PATH_WIDTH-1:0]   s_mem_axis_tdata,
	input  wire [MEM_DATA_PATH_WIDTH/8-1:0] s_mem_axis_tkeep,
	input  wire [MEM_USER_PATH_WIDTH-1:0]   s_mem_axis_tuser,
	input  wire [PE_DEST_BITS-1:0]          s_mem_axis_tdest,
	input  wire                             s_mem_axis_tlast,
	output wire                             s_mem_axis_tready,
	input  wire                             s_mem_axis_tvalid,
	
	/* To Ethernet */
	output      [MEM_DATA_PATH_WIDTH-1:0]   m_mem_axis_tdata,
	output      [MEM_DATA_PATH_WIDTH/8-1:0] m_mem_axis_tkeep,
	output      [MEM_USER_PATH_WIDTH-1:0]   m_mem_axis_tuser,
	output      [PE_DEST_BITS-1:0]          m_mem_axis_tdest,
	input                                   m_mem_axis_tready,
	output                                  m_mem_axis_tvalid,
	output                                  m_mem_axis_tlast
); 

/*************************************************************
 * Functions
 *************************************************************/
function integer log2;
	input integer value;
	begin
		value = value - 1;
		for(log2=0;value >0;log2=log2+1)
			value = value >> 1;
	end
endfunction

function [31:0] int2bit;
input [7:0] size;
reg [63:0] tmp;
begin
	tmp = 64'h0000_0000_FFFF_FFFF;
	tmp = tmp << size;
	int2bit = tmp[63:32];
end
endfunction

function [9:0] mal32;
input [15:0] input_t;
begin
	mal32 = input_t[14:5];
end
endfunction

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

function [255:0] mask (input [31:0]j);
begin
	case(j)
		32'h0000_0000 : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
		32'h0000_0001 : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff;
		32'h0000_0003 : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff;
		32'h0000_000c : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff;
		32'h0000_000f : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff;
		32'h0000_001f : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff;
		32'h0000_003f : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff;
		32'h0000_00cf : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff;
		32'h0000_00ff : mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff;
		32'h0000_01ff : mask = 256'h00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff;
		32'h0000_03ff : mask = 256'h00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff;
		32'h0000_0cff : mask = 256'h00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff;
		32'h0000_0fff : mask = 256'h00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff;
		32'h0000_1fff : mask = 256'h00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff;
		32'h0000_3fff : mask = 256'h00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff;
		32'h0000_cfff : mask = 256'h00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff;
		32'h0000_ffff : mask = 256'h00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h0001_ffff : mask = 256'h00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h0003_ffff : mask = 256'h00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h000c_ffff : mask = 256'h00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h000f_ffff : mask = 256'h00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h001f_ffff : mask = 256'h00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h003f_ffff : mask = 256'h00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h00cf_ffff : mask = 256'h00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h00ff_ffff : mask = 256'h00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h01ff_ffff : mask = 256'h00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h03ff_ffff : mask = 256'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h0cff_ffff : mask = 256'h00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h0fff_ffff : mask = 256'h00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h1fff_ffff : mask = 256'h000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'h3fff_ffff : mask = 256'h0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'hcfff_ffff : mask = 256'h00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		32'hffff_ffff : mask = 256'hffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		default : mask = 256'h0;
	endcase
end
endfunction

function [511:0] mask512 (input [63:0]j);
begin
	case(j)
		64'h0000_0000_0000_0000 : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
		64'h0000_0000_0000_0001 : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff;
		64'h0000_0000_0000_0003 : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff;
		64'h0000_0000_0000_000c : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff;
		64'h0000_0000_0000_000f : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff;
		64'h0000_0000_0000_001f : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff;
		64'h0000_0000_0000_003f : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff;
		64'h0000_0000_0000_00cf : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff;
		64'h0000_0000_0000_00ff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff;
		64'h0000_0000_0000_01ff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff;
		64'h0000_0000_0000_03ff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff;
		64'h0000_0000_0000_0cff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff;
		64'h0000_0000_0000_0fff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0000_1fff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0000_3fff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0000_cfff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0000_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0001_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0003_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_000c_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_000f_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_001f_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_003f_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_00cf_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_00ff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_01ff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_03ff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0cff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_0fff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_1fff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_3fff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_cfff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0000_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0001_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0003_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_000c_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_000f_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_001f_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_003f_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_00cf_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_00ff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_01ff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_03ff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0cff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_0fff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_1fff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_3fff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_cfff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0000_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0001_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0003_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h000c_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h000f_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h001f_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h003f_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h00cf_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h00ff_ffff_ffff_ffff : mask512 = 512'h00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h01ff_ffff_ffff_ffff : mask512 = 512'h00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h03ff_ffff_ffff_ffff : mask512 = 512'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0cff_ffff_ffff_ffff : mask512 = 512'h00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h0fff_ffff_ffff_ffff : mask512 = 512'h00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h1fff_ffff_ffff_ffff : mask512 = 512'h000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'h3fff_ffff_ffff_ffff : mask512 = 512'h0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'hcfff_ffff_ffff_ffff : mask512 = 512'h00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		64'hffff_ffff_ffff_ffff : mask512 = 512'hffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		default : mask512 = 512'h0;
	endcase
end
endfunction

function [255:0] keep2mask (input [5:0] k);
begin
	case(k)
		6'd0  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
		6'd1  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff;
		6'd2  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff;
		6'd3  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff;
		6'd4  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff;
		6'd5  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff;
		6'd6  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff;
		6'd7  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff;
		6'd8  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff;
		6'd9  : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff;
		6'd10 : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff;
		6'd11 : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff;
		6'd12 : keep2mask = 256'h00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff;
		6'd13 : keep2mask = 256'h00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff;
		6'd14 : keep2mask = 256'h00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff;
		6'd15 : keep2mask = 256'h00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff;
		6'd16 : keep2mask = 256'h00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd17 : keep2mask = 256'h00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd18 : keep2mask = 256'h00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd19 : keep2mask = 256'h00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd20 : keep2mask = 256'h00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd21 : keep2mask = 256'h00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd22 : keep2mask = 256'h00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd23 : keep2mask = 256'h00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd24 : keep2mask = 256'h00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd25 : keep2mask = 256'h00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd26 : keep2mask = 256'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd27 : keep2mask = 256'h00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd28 : keep2mask = 256'h00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd29 : keep2mask = 256'h000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd30 : keep2mask = 256'h0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd31 : keep2mask = 256'h00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		6'd32 : keep2mask = 256'hffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		default : keep2mask = 256'h0;
	endcase
end
endfunction

function [511:0] keep2mask512 (input [7:0] k);
begin
	case(k)
		8'd0  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000;
		8'd1  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff;
		8'd2  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff;
		8'd3  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff;
		8'd4  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff;
		8'd5  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff;
		8'd6  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff;
		8'd7  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff;
		8'd8  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff;
		8'd9  : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff;
		8'd10 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff;
		8'd11 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff;
		8'd12 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff;
		8'd13 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff;
		8'd14 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff;
		8'd15 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff;
		8'd16 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd17 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd18 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd19 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd20 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd21 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd22 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd23 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd24 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd25 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd26 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd27 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd28 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd29 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd30 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd31 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd32 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd33 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd34 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd35 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd36 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd37 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd38 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd39 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd40 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd41 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd42 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd43 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd44 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd45 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd46 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd47 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd48 : keep2mask512 = 512'h00000000_00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd49 : keep2mask512 = 512'h00000000_00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd50 : keep2mask512 = 512'h00000000_00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd51 : keep2mask512 = 512'h00000000_00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd52 : keep2mask512 = 512'h00000000_00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd53 : keep2mask512 = 512'h00000000_00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd54 : keep2mask512 = 512'h00000000_00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd55 : keep2mask512 = 512'h00000000_00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd56 : keep2mask512 = 512'h00000000_00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd57 : keep2mask512 = 512'h00000000_000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd58 : keep2mask512 = 512'h00000000_0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd59 : keep2mask512 = 512'h00000000_00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd60 : keep2mask512 = 512'h00000000_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd61 : keep2mask512 = 512'h000000ff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd62 : keep2mask512 = 512'h0000ffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd63 : keep2mask512 = 512'h00ffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		8'd64 : keep2mask512 = 512'hffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff;
		default : keep2mask512 = 512'h0;
	endcase
end
endfunction

function [63:0] nkeep64 (input [7:0] i);
begin
	if (i <= 32) begin
		nkeep64 = {32'h0, nkeep(i)};
	end else begin
		nkeep64 = {nkeep(i-32), 32'hffff_ffff};
	end
end
endfunction

function [9:0] slab_size (input [9:0] size);
begin
	if (size <= 64) begin
		slab_size = 64;
	end else if (size <= 128) begin
		slab_size = 128;
	end else if (size <= 256) begin
		slab_size = 256;
	end else if (size <= 512) begin
		slab_size = 512;
	end else if (size <= 1024) begin
		slab_size = 1024;
	end else begin
		$display("Error: slab size over 1024B.");
	end
end
endfunction


localparam HEAD_SIZE          = 8;
localparam ARRAY_BYTES        = PE_DATA_PATH_WIDTH / 8; // ==> 8 Bytes
// If Key size is 64Bytes()
//   MAX_KEY_CNT_SIZE is 3bit (2^3 = 8bytes)
localparam MAX_KEY_CNT_SIZE   = log2(MAX_KEY_SUPPORT/ARRAY_BYTES);  
localparam MAX_KEY_ARRAY_SIZE = MAX_KEY_SUPPORT / ARRAY_BYTES;
localparam MAX_KEY_CNT = MAX_KEY_SUPPORT / ARRAY_BYTES;
localparam MAX_VAL_CNT = MAX_VAL_SUPPORT / ARRAY_BYTES;

/*************************************************************
 * Parameters 
 *************************************************************/
localparam STRPE_OP_GET    = 8'd0;
localparam STRPE_OP_SET    = 8'd1;
localparam STRPE_OP_DEL    = 8'd2;

localparam MIG_CMD_READ    = 3'b001;
localparam MIG_CMD_WRITE   = 3'b000;

localparam REQ_TYPE_READ          = 2'b00;
localparam REQ_TYPE_WRITE         = 2'b01;
localparam REQ_TYPE_HTABLE_READ   = 2'b10;
localparam REQ_TYPE_HTABLE_WRITE  = 2'b11;

localparam NO_DATA         = 2'b00;
localparam DATA_TYPE_0     = 2'b01;
localparam DATA_TYPE_1     = 2'b10;

localparam NUM_SOURCE_DRAM = 8'h00;
localparam NUM_SOURCE_SRAM = 8'h01;

localparam NWAY            = (ASSOCIATIVE == "1way") ? 1 :
                             (ASSOCIATIVE == "2way") ? 2 :
                             (ASSOCIATIVE == "4way") ? 4 :
                             (ASSOCIATIVE == "8way") ? 8 : 0;

localparam HTABLE_IDLE       = 3'd0;
localparam HTABLE_REP        = 3'd1;
localparam HTABLE_CHUNK_REQ  = 3'd2;
localparam HTABLE_CHUNK_WAIT = 3'd3;
localparam HTABLE_HTABLE_WR  = 3'd4;
localparam HTABLE_KVUPDATE   = 3'd5;
localparam HTABLE_LUT_WAIT   = 3'd6;
localparam HTABLE_LUT_REQ    = 3'd7;
/***********************************************************
 * Reset
 ***********************************************************/
(* dont_touch = "true" *)reg [15:0] rst_reg = 16'hffff;

always @ (posedge clk) begin
	rst_reg <= (rst) ? 16'hffff : 16'h0000;
end
/*************************************************************
 *  Common Porpose Registers
 *************************************************************/
reg [7:0]   opcode;
reg [15:0]  key_len;
reg [15:0]  val_len;
reg [255:0] tmp_key;
reg [255:0] tmp_val;
(* RAM_STYLE="BLOCK" *) reg [511:0] KEY [MAX_FLIT_SIZE-1:0];
(* RAM_STYLE="BLOCK" *) reg [511:0] VAL [MAX_FLIT_SIZE-1:0];
//reg [511:0] KEY [MAX_FLIT_SIZE-1:0];
//reg [511:0] VAL [MAX_FLIT_SIZE-1:0];

(* dont_touch = "true" *)reg [MEM_DATA_PATH_WIDTH-1:0]   s_mem_axis_tdata_bufbuf;
(* dont_touch = "true" *)reg [MEM_DATA_PATH_WIDTH/8-1:0] s_mem_axis_tkeep_bufbuf;
(* dont_touch = "true" *)reg [MEM_USER_PATH_WIDTH-1:0]   s_mem_axis_tuser_bufbuf;
(* dont_touch = "true" *)reg [PE_DEST_BITS-1:0]          s_mem_axis_tdest_bufbuf;
(* dont_touch = "true" *)reg                             s_mem_axis_tlast_bufbuf;
(* dont_touch = "true" *)reg                             s_mem_axis_tready_bufbuf;
(* dont_touch = "true" *)reg                             s_mem_axis_tvalid_bufbuf;
(* dont_touch = "true" *)reg [MEM_DATA_PATH_WIDTH-1:0]   s_mem_axis_tdata_buf;
(* dont_touch = "true" *)reg [MEM_DATA_PATH_WIDTH/8-1:0] s_mem_axis_tkeep_buf;
(* dont_touch = "true" *)reg [MEM_USER_PATH_WIDTH-1:0]   s_mem_axis_tuser_buf;
(* dont_touch = "true" *)reg [PE_DEST_BITS-1:0]          s_mem_axis_tdest_buf;
(* dont_touch = "true" *)reg                             s_mem_axis_tlast_buf;
(* dont_touch = "true" *)reg                             s_mem_axis_tready_buf;
(* dont_touch = "true" *)reg                             s_mem_axis_tvalid_buf;
always @ (posedge clk) begin
	if (rst_reg[0]) begin
		s_mem_axis_tdata_buf  <= 0;
		s_mem_axis_tkeep_buf  <= 0;
		s_mem_axis_tuser_buf  <= 0;
		s_mem_axis_tdest_buf  <= 0;
		s_mem_axis_tlast_buf  <= 0;
		s_mem_axis_tready_buf <= 0;
		s_mem_axis_tvalid_buf <= 0;
		s_mem_axis_tdata_bufbuf  <= 0;
		s_mem_axis_tkeep_bufbuf  <= 0;
		s_mem_axis_tuser_bufbuf  <= 0;
		s_mem_axis_tdest_bufbuf  <= 0;
		s_mem_axis_tlast_bufbuf  <= 0;
		s_mem_axis_tready_bufbuf <= 0;
		s_mem_axis_tvalid_bufbuf <= 0;
	end else begin
		s_mem_axis_tdata_buf  <= s_mem_axis_tdata;
		s_mem_axis_tkeep_buf  <= s_mem_axis_tkeep;
		s_mem_axis_tuser_buf  <= s_mem_axis_tuser;
		s_mem_axis_tdest_buf  <= s_mem_axis_tdest;
		s_mem_axis_tlast_buf  <= s_mem_axis_tlast;
		s_mem_axis_tready_buf <= s_mem_axis_tready;
		s_mem_axis_tvalid_buf <= s_mem_axis_tvalid;
		s_mem_axis_tdata_bufbuf  <= s_mem_axis_tdata;
		s_mem_axis_tkeep_bufbuf  <= s_mem_axis_tkeep;
		s_mem_axis_tuser_bufbuf  <= s_mem_axis_tuser;
		s_mem_axis_tdest_bufbuf  <= s_mem_axis_tdest;
		s_mem_axis_tlast_bufbuf  <= s_mem_axis_tlast;
		s_mem_axis_tready_bufbuf <= s_mem_axis_tready;
		s_mem_axis_tvalid_bufbuf <= s_mem_axis_tvalid;
	end
end
/*************************************************************
 * Fetch Key and Value 
 *************************************************************/
integer i;
reg [9:0] rcnt_key, rcnt_key_reg;
wire [8:0] rcnt_key_index = rcnt_key[9:1];
reg [9:0] rcnt_val;
reg  [2:0]   htable_state;

wire [7:0]  source_core_input = s_pe_axis_tuser[51:44];
wire        key_en_input  = (source_core_input == pe_id) ? s_pe_axis_tuser[0]    : 0;
wire        key_last      = (source_core_input == pe_id) ? s_pe_axis_tuser[1]    : 0;
wire        val_en_input  = (source_core_input == pe_id) ? s_pe_axis_tuser[2]    : 0;
wire        val_last      = (source_core_input == pe_id) ? s_pe_axis_tuser[3]    : 0;
wire [7:0]  opcode_input  = (source_core_input == pe_id) ? s_pe_axis_tuser[11:4] : 0;
wire [15:0] key_len_input = (source_core_input == pe_id) ? s_pe_axis_tuser[27:12]: 0;
wire [15:0] val_len_input = (source_core_input == pe_id) ? s_pe_axis_tuser[43:28]: 0;
`ifdef CACHE_MODE
reg  [31:0] opaque;
reg  [15:0] src_uport;
wire [31:0] opaque_input   = (source_core_input == pe_id) ? s_pe_axis_tuser[83:52] : 0;
wire [15:0] src_uport_input = (source_core_input == pe_id) ? s_pe_axis_tuser[99:84] : 0;
wire lut_req_en = s_mem_axis_tready_buf && s_mem_axis_tvalid_buf && s_mem_axis_tuser_buf[PE_DEST_BITS-1:0]== config_lut_node[PE_DEST_BITS-1:0];
`endif /*CACHE_MODE */

always @ (posedge clk) begin
	if (rst_reg[1]) begin
		for (i = 0; i < MAX_FLIT_SIZE; i = i + 1) begin
			KEY[i] <= 0;
			VAL[i] <= 0;
		end
		opcode    <= 0;
		key_len   <= 0;
		val_len   <= 0;
		rcnt_key  <= 0;
		rcnt_key_reg  <= 0;
		rcnt_val  <= 0;
		tmp_key <= 0;
		tmp_val <= 0;
`ifdef CACHE_MODE
		opaque   <= 0;
		src_uport <= 0;
`endif /*CACHE_MODE */
	end else begin
`ifdef CACHE_MODE
		if (lut_req_en) begin
			rcnt_key <= rcnt_key + 1;
			KEY[rcnt_key] <= s_mem_axis_tdata_buf;
		end
`endif /*CACHE_MODE */
		if (s_pe_axis_tvalid && s_pe_axis_tready && (key_en_input || val_en_input)) begin
			rcnt_key <= rcnt_key + 1;
			//if (rcnt_key == 0 && !key_last)
			if (rcnt_key[0] == 0 /* && !val_last*/) begin
				$display("DEBUG: tmp_key <= %x", s_pe_axis_tdata);
				tmp_key <= s_pe_axis_tdata;
			//else if (rcnt_key[0] == 0 && key_last)
			end 
			if (rcnt_key[0] == 0 && val_last) begin
				$display("DEBUG: KEY[%d] <= {256'd0, %x}", rcnt_key_index, s_pe_axis_tdata);
				KEY[rcnt_key_index] <= {256'h0, s_pe_axis_tdata};
			end else if (rcnt_key[0] == 1) begin
				$display("DEBUG: KEY[%d] <= {%x, %x}", rcnt_key_index, s_pe_axis_tdata, tmp_key);
				KEY[rcnt_key_index] <= {s_pe_axis_tdata, tmp_key};
			end
		end
		if (s_pe_axis_tvalid && s_pe_axis_tready && val_en_input) begin
			rcnt_val <= rcnt_val + 1;
			if (rcnt_val[0] == 0 && !val_last)
				tmp_val <= s_pe_axis_tdata;
			else if (rcnt_val[0] == 0 && val_last)
				VAL[rcnt_val] <= {256'h0, s_pe_axis_tdata};
			else if (rcnt_val[0] == 1)
				VAL[rcnt_val] <= {s_pe_axis_tdata, tmp_val};
		end
		if (s_pe_axis_tvalid && s_pe_axis_tready && rcnt_key == 0) begin
			opcode  <= opcode_input;
			key_len <= key_len_input;
			val_len <= val_len_input;
`ifdef CACHE_MODE
			opaque  <= opaque_input;
			src_uport <= src_uport_input;
`endif /*CACHE_MODE */
		end

`ifdef CACHE_MODE
		if (s_mem_axis_tvalid_buf && s_mem_axis_tready_buf && htable_state == HTABLE_LUT_WAIT && s_mem_axis_tuser_buf[24] == 1) begin
			opcode <= STRPE_OP_SET;
			key_len <= s_mem_axis_tuser_buf[23:8];
		end
		if ((s_pe_axis_tlast && s_pe_axis_tready && s_pe_axis_tvalid) || lut_req_en) begin
`else
		if (s_pe_axis_tlast && s_pe_axis_tready && s_pe_axis_tvalid) begin
`endif /*CACHE_MODE */
			rcnt_key_reg <= rcnt_key;
			rcnt_key     <= 0;
			rcnt_val     <= 0;
		end
	end
end

/*************************************************************
 * Hash Function
 *************************************************************/
// Todo : multiple flits in Key
`ifdef CRC_DISABLE
reg [HASH_VALUE_WIDTH-1:0] hash_value;
`else
wire [HASH_VALUE_WIDTH-1:0] hash_value;
`endif /*CRC_DISABLE*/
reg  [HASH_VALUE_WIDTH-1:0] hash_value_buf;
`ifdef CACHE_MODE
wire hash_crc_en = (key_en_input && s_pe_axis_tvalid && s_pe_axis_tready) || lut_req_en;
`else
wire hash_crc_en = (key_en_input && s_pe_axis_tvalid && s_pe_axis_tready);
`endif /*CACHE_MODE */
reg hash_valid;
reg hash_valid_reg;
`ifdef CACHE_MODE
wire [255:0] input_data_cache = (lut_req_en) ? s_mem_axis_tdata_buf[255:0] & keep2mask(s_mem_axis_tuser_buf[12:8]) : 
                                                 s_pe_axis_tdata & keep2mask(key_len_input[5:0]);
`else
wire [255:0] input_data_cache = s_pe_axis_tdata & keep2mask(key_len_input[5:0]);
`endif /*CACHE_MODE */

`ifdef CRC_DISABLE
always @ (posedge clk)
	hash_value <= input_data_cache;
`else
crc u_hashfunc (
	.data_in      ( input_data_cache ), //input 256bit
	.crc_en       ( hash_crc_en     ),
	.crc_out      ( hash_value      ), //output 32bit
	.rst          ( rst_reg[2] || hash_valid_reg  ),
	.clk          ( clk             )
);
`endif /*CRC_DISABLE*/

`ifdef CRC_DEBUG
integer F_HANDLE;
initial F_HANDLE = $fopen("dump2.log");
always @ (*) begin
	if (hash_crc_en) begin
  		$fdisplay(F_HANDLE, "time(%t) : key(%dB): %x", $time, key_len_input[5:0], input_data_cache);
		$fflush(F_HANDLE);
	end
	if (hash_valid) begin
  		$fdisplay(F_HANDLE, "time(%t) : hash:%x", $time, hash_value);
		$fflush(F_HANDLE);
	end
end

`endif


always @ (posedge clk)
	if (rst_reg[3]) begin
		hash_valid     <= 1'b0;
		hash_valid_reg <= 1'b0;
	end else begin
		hash_valid_reg <= hash_valid;
`ifdef CACHE_MODE
		if ((key_last && key_en_input && s_pe_axis_tvalid && s_pe_axis_tready) || lut_req_en) begin
`else
		if (key_last && key_en_input && s_pe_axis_tvalid && s_pe_axis_tready) begin
`endif /*CACHE_MODE */
			hash_valid <= 1'b1;
		end else begin
			hash_valid <= 1'b0;
		end
		if (hash_valid)
			hash_value_buf <= hash_value;
	end


/*************************************************************
 * Hash Table Access (DRAM)
 *************************************************************/

localparam FLIST_GET_REQ = 2'b01;
localparam FLIST_DEL_REQ = 2'b01;


reg  [MEM_DATA_PATH_WIDTH-1:0]   tdata_htable;
reg  [MEM_USER_PATH_WIDTH-1-48:0]   tuser_htable;
reg  [MEM_DATA_PATH_WIDTH/8-1:0] tkeep_htable;
reg  [PE_DEST_BITS-1:0]          tdest_htable;
reg                              tvalid_htable;
reg                              tlast_htable;
reg  [MEM_DATA_PATH_WIDTH-1:0]   tdata_flst;
reg  [MEM_USER_PATH_WIDTH-1-48:0]   tuser_flst;
reg  [MEM_DATA_PATH_WIDTH/8-1:0] tkeep_flst;
reg                              tvalid_flst;
reg                              tlast_flst;
reg  [7:0]   htable_check_cnt;

reg  [29:0]  chunk_addr;
reg  [9:0]   chunk_addr_cnt;
reg          htable_miss, htable_hit;
wire [29:0]  htable_addr;
localparam HTABLE_ENTRY_BITS  = 64;
localparam HTABLE_ENTRY_BYTES = HTABLE_ENTRY_BITS / 8;
localparam HTABLE_ENTRY_SIZE  = log2(HTABLE_ENTRY_BYTES);
reg [3:0] way_cnt;
wire [HTABLE_ENTRY_BITS*NWAY-1:0] htable_bucket; 
reg [HTABLE_ENTRY_BITS*NWAY-1:0] htable_bucket_reg;
wire [31:0] htable_chunk_addr;
wire flist_req;
reg flist_req_reg;

reg        htable0_valid;
reg [14:0] htable0_keylen, htable0_vallen;
reg [31:0] htable0_chunkaddr;
reg htable0_en;

assign htable_addr = (hash_valid) ? hash_value[29:0] : hash_value_buf[29:0];
assign htable_bucket = s_mem_axis_tdata_buf[HTABLE_ENTRY_BITS*NWAY-1:0];
assign flist_req = ((s_mem_axis_tready_buf && s_mem_axis_tvalid_buf && htable_state == HTABLE_REP) && (htable_bucket[46:32] != key_len[14:0] || htable_bucket[62] == 0)) ? 1'b1 : flist_req_reg;
assign	htable_chunk_addr = htable0_chunkaddr;//htable_bucket_reg[31:0];

always @ (posedge clk) begin
	if (rst_reg[4]) begin
		htable0_chunkaddr <= 0;
		htable0_keylen    <= 0;
		htable0_vallen    <= 0;
		htable0_en        <= 0;
		htable0_valid     <= 0;
	end else begin
		if (s_mem_axis_tready_buf && s_mem_axis_tvalid_buf 
			&& htable_state == HTABLE_REP) begin
			$display("Htable chunk:%x keylen:%d vallen:%d", 
				htable_bucket[31:0], htable_bucket[46:32], htable_bucket[61:47] );
			htable0_chunkaddr <= htable_bucket[31:0];
			htable0_keylen <= htable_bucket[46:32];
			htable0_vallen <= htable_bucket[61:47];
			htable0_valid  <= htable_bucket[62];
			htable0_en <= 1'b1;
		end else begin
			htable0_en <= 1'b0;
		end
	end
end


reg return_miss;
reg return_hit;
reg return;
reg [9:0] htable_data_cnt;
wire [9:0] slab_req_size = key_len[9:0] + val_len[9:0];
reg [31:0] new_chunk_addr;
reg [9:0] req_slab_size;
reg [15:0] chck_req_keylen, chck_req_vallen;
reg [15:0] chck_rep_keylen, chck_rep_vallen;
reg [15:0] dram_cnt;
reg htable0_en_reg;
reg htable_valid;
reg [511:0] ready_kvdata;
reg lut_en;
reg lut_wr_en;
reg update_reg;
reg slab_error;
reg kvupdate_done;
// --debug--
wire [15:0] chck_rep_totlen = {1'b0, htable0_keylen} + {1'b0, htable0_vallen};
wire [2:0] debug_req_slab_size = req_slab_size[9:7] + 1;
wire [31:0] dstore_addr = (new_chunk_addr != 0) ? new_chunk_addr    + {10'd0, dram_cnt, 6'd0} :
                                                  htable_chunk_addr + {10'd0, dram_cnt, 6'd0};

always @ (posedge clk) begin
	if (rst_reg[5]) begin
		tdata_htable     <= 0;
		tuser_htable     <= 0;
		tkeep_htable     <= 0;
		tdest_htable     <= 0;
		tlast_htable     <= 0;
		tvalid_htable    <= 0;
		tdata_flst       <= 0;
		tuser_flst       <= 0;
		tkeep_flst       <= 0;
		tlast_flst       <= 0;
		tvalid_flst      <= 0;

		htable_state     <= HTABLE_IDLE;
		htable_check_cnt <= 0;
		htable_miss      <= 0;
		htable_hit       <= 0;
		chunk_addr       <= 0;
		chunk_addr_cnt   <= 0;
		htable_bucket_reg<= 0;
		way_cnt          <= 0;
		htable_data_cnt  <= 0;
		flist_req_reg    <= 0;
		new_chunk_addr   <= 0;
		req_slab_size    <= 0;
		ready_kvdata     <= 0;
		lut_en           <= 0;
		lut_wr_en        <= 0;
		update_reg       <= 0;
		dram_cnt         <= 0;
		slab_error       <= 0;
		kvupdate_done    <= 0;
	end else begin
		if (htable_state == HTABLE_KVUPDATE) 
			flist_req_reg <= 0;
		else 
			flist_req_reg <= flist_req;
		case (htable_state)
			HTABLE_IDLE: begin
				slab_error    <= 0;
				kvupdate_done <= 0;
				if (lut_en) begin
					lut_wr_en <= 1;
					lut_en    <= 0;
				end 
				if (hash_valid) begin
					req_slab_size <= slab_size(key_len + val_len);
					htable_state  <= HTABLE_REP;
					tdata_htable  <= 0;
					tkeep_htable  <= 0;
					tdest_htable  <= config_dram_node;
					tuser_htable  <= {33'd0, 1'b1, 1'b1, pe_id[7:0], NO_DATA, 
							REQ_TYPE_HTABLE_READ, htable_addr, MIG_CMD_READ};
					tvalid_htable <= 1;
					tlast_htable  <= 1;
`ifdef CACHE_MODE
					ready_kvdata <= (VAL[0] & keep2mask512(val_len)) << {key_len,3'd0};
`endif
				end 
`ifdef CACHE_MODE
					else if (opcode == 8'hf0) begin
					htable_state  <= HTABLE_LUT_WAIT;
					tdata_htable  <= 0;
					tkeep_htable  <= 0;
					tdest_htable  <= config_lut_node;
					tuser_htable  <= {16'h0, pe_id[7:0], 8'h0, src_uport, opaque}; /*8, 8 , 16, 32*/
					tvalid_htable <= 1;
					tlast_htable  <= 1;
				end else if (opcode == STRPE_OP_GET && return_miss && return) begin
					htable_state <= HTABLE_LUT_REQ;
				end else if (opcode == STRPE_OP_DEL && return_hit && return) begin
					htable_state <= HTABLE_CHUNK_REQ;
					update_reg <= 1;
				end else if (opcode == STRPE_OP_SET && return_hit && return) begin
					htable_state <= HTABLE_KVUPDATE;
					update_reg <= 1;
				end else begin
					if (s_mem_axis_tready_buf && s_mem_axis_tvalid_buf 
						&& s_mem_axis_tdest_buf == pe_id[PE_DEST_BITS-1:0]) begin
						
					end
`else
					else begin // RESET all registers
`endif /*CACHE_MODE*/
					tdata_htable  <= 0;
					tkeep_htable  <= 0;
					tuser_htable  <= 0;
					tdest_htable  <= 0;
					tvalid_htable <= 0;
					tlast_htable  <= 0;
					new_chunk_addr <= 0;
				end
			end
			HTABLE_REP: begin
				tuser_htable  <= 0;
				tdest_htable  <= 0;
				tvalid_htable <= 0;
				tlast_htable  <= 0;
				if (s_mem_axis_tready_buf && s_mem_axis_tvalid_buf 
					&& s_mem_axis_tdest_buf == pe_id[PE_DEST_BITS-1:0]) begin
`ifdef CACHE_MODE
					ready_kvdata <= ready_kvdata | (KEY[0] & keep2mask512(key_len));
`endif
					htable_bucket_reg <= htable_bucket; 
					if (opcode == STRPE_OP_SET && flist_req) begin
						
						htable_state      <= HTABLE_CHUNK_REQ;
					end else if (opcode == STRPE_OP_GET || 
						(opcode == STRPE_OP_SET && !flist_req) ||
						opcode == STRPE_OP_DEL) begin
						htable_state      <= HTABLE_KVUPDATE;
					end
				end
			end
			HTABLE_CHUNK_REQ: begin
				if (opcode == STRPE_OP_DEL) begin
					tdata_flst   <= {480'd0, new_chunk_addr};
					tkeep_flst   <= 0;
					tuser_flst   <= {60'd0, pe_id[7:0], slab_req_size, FLIST_DEL_REQ};
					tvalid_flst  <= 1;
					tlast_flst   <= 1;
					htable_state <= HTABLE_HTABLE_WR;
				end else begin
					tdata_flst   <= 0;
					tkeep_flst   <= 0;
					tuser_flst   <= {60'd0, pe_id[7:0], slab_req_size, FLIST_GET_REQ};
					tvalid_flst  <= 1;
					tlast_flst   <= 1;
					htable_state <= HTABLE_CHUNK_WAIT;
				end
			end
			HTABLE_CHUNK_WAIT: begin
				if (s_mem_axis_tvalid_buf && s_mem_axis_tready_buf 
					&& s_mem_axis_tuser_buf[1:0] == 2'b00) begin
					if (s_mem_axis_tdata_buf[31:0] == 32'hffff_ffff) begin
						// Failure for SRAM request
						slab_error <= 1;
						htable_state <= HTABLE_IDLE;
					end else begin
						new_chunk_addr[31:0] <= s_mem_axis_tdata_buf[31:0];
						htable_state <= HTABLE_HTABLE_WR;
					end
				end
				tdata_flst   <= 0;
				tkeep_flst   <= 0;
				tuser_flst   <= 0;
				tvalid_flst  <= 0;
				tlast_flst   <= 0;
			end
			HTABLE_HTABLE_WR: begin
				if (opcode == STRPE_OP_DEL) begin
					tdata_htable  <= 0;
					tkeep_htable  <= 64'h0000_00ff;
					tdest_htable  <= config_dram_node;
					tuser_htable  <= {33'd0, 1'b1, 1'b1, pe_id[7:0], NO_DATA, 
							REQ_TYPE_HTABLE_WRITE, htable_addr, MIG_CMD_WRITE};
					tvalid_htable <= 1;
					tlast_htable  <= 1;
					htable_state <= HTABLE_KVUPDATE;
				end else begin
					tdata_htable  <= {448'd0, 2'b01, val_len[14:0], 
					                  key_len[14:0], new_chunk_addr[31:0]};
					tkeep_htable  <= 64'h0000_00ff;
					tdest_htable  <= config_dram_node;
					tuser_htable  <= {33'd0, 1'b1, 1'b1, pe_id[7:0], NO_DATA, 
							REQ_TYPE_HTABLE_WRITE, htable_addr, MIG_CMD_WRITE};
					tvalid_htable <= 1;
					tlast_htable  <= 1;
					htable_state <= HTABLE_KVUPDATE;
				end
			end
			HTABLE_KVUPDATE:begin
				$display("req_slab_size[9:6]:%d, ready %d, opcode %d", 
					req_slab_size[9:6], m_mem_axis_tready, opcode);
				if (opcode == STRPE_OP_DEL && update_reg && htable_valid) begin
					update_reg     <= 0;
					tdata_htable   <= 0;
					tuser_htable <= {34'd0, 1'b1, pe_id[7:0], DATA_TYPE_0, 
								REQ_TYPE_WRITE, new_chunk_addr[29:0], MIG_CMD_WRITE};
					tkeep_htable     <= nkeep64(key_len + val_len); //todo
					tdest_htable     <= config_dram_node;
					tlast_htable     <= 1; // todo : more length
					htable_state     <= HTABLE_IDLE;
				end else if (opcode == STRPE_OP_SET && update_reg && htable_valid) begin
					update_reg <= 0;
					if (lut_wr_en)
						tdata_htable     <= ready_kvdata;
					else 
						tdata_htable     <= KEY[htable_check_cnt];
					tuser_htable <= {34'd0, 1'b1, pe_id[7:0], DATA_TYPE_0, 
								REQ_TYPE_WRITE, new_chunk_addr[29:0], MIG_CMD_WRITE};
					tkeep_htable     <= nkeep64(key_len + val_len); //todo
					tdest_htable     <= config_dram_node;
					tlast_htable     <= 1; // todo : more length
					htable_state     <= HTABLE_IDLE;
				end else if (htable_valid) begin
					if (opcode == STRPE_OP_SET) begin
`ifdef CACHE_MODE
						if (lut_wr_en)
							tdata_htable     <= ready_kvdata;
						else 
							tdata_htable     <= KEY[htable_check_cnt];
`else
						tdata_htable     <= KEY[htable_check_cnt];
`endif
						tdest_htable     <= config_dram_node;
						tvalid_htable    <= 1;
						lut_wr_en        <= 0;
		
						// to suport more than 32B.
						//if (htable_check_cnt == req_slab_size[9:7] + 1) begin
						if ((slab_req_size[9:6] == dram_cnt + 1 && slab_req_size[5:0] == 0) || (slab_req_size[9:6] == dram_cnt && slab_req_size[5:0] != 0) ) begin
							tlast_htable     <= 1;
							kvupdate_done    <= 1;
							htable_state     <= HTABLE_IDLE;
							tkeep_htable     <= nkeep64(key_len + val_len); //todo
							htable_check_cnt <= 0;
							dram_cnt <= 0;
						end else begin
							tlast_htable     <= 0; 
							htable_check_cnt <= htable_check_cnt + 1;
							dram_cnt <= dram_cnt + 1;
							tkeep_htable     <= 64'hffffffff_ffffffff; //todo
						end
						if (new_chunk_addr != 0) begin
							tuser_htable <= {34'd0, 1'b1, pe_id[7:0], DATA_TYPE_0, 
									REQ_TYPE_WRITE, dstore_addr[29:0], MIG_CMD_WRITE};
						end else begin
							tuser_htable <= {34'd0, 1'b1, pe_id[7:0], DATA_TYPE_1, 
									REQ_TYPE_WRITE, dstore_addr[29:0], MIG_CMD_WRITE};
						end
					end else if (opcode == STRPE_OP_GET||opcode == STRPE_OP_DEL) begin
						//if (chck_req_keylen == chck_rep_keylen) begin
						if (key_len == chck_rep_keylen) begin
							tdata_htable     <= 0;
							tkeep_htable     <= 0; 
							tdest_htable     <= config_dram_node;
							tlast_htable     <= 1;
							tvalid_htable    <= 1;
							tuser_htable <= {34'd0, 1'b1,  pe_id[7:0], DATA_TYPE_1, 
									REQ_TYPE_READ, dstore_addr[29:0], MIG_CMD_READ};
							dram_cnt <= dram_cnt + 1;
							if ((dram_cnt[9:0] + 1 == chck_rep_totlen[15:6] && chck_rep_totlen[5:0] == 0) || 
								(dram_cnt[9:0] == chck_rep_totlen[15:6] && chck_rep_totlen[5:0] != 0)) begin
								htable_state     <= HTABLE_IDLE;
								dram_cnt <= 0;
							end
						end else begin
							htable_state     <= HTABLE_IDLE;
						end
					end
				end else begin
					tvalid_htable    <= 0;
				end
			end
`ifdef CACHE_MODE
			// GET reply including Values
			HTABLE_LUT_WAIT: begin
				if (s_mem_axis_tready_buf && s_mem_axis_tvalid_buf 
					&& s_mem_axis_tdest_buf == pe_id[PE_DEST_BITS-1:0]) begin
					htable_state <= HTABLE_IDLE;
					lut_en <= 1;
				end
				tdata_htable  <= 0;
				tkeep_htable  <= 0;
				tdest_htable  <= 0;
				tuser_htable  <= 0;
				tvalid_htable <= 0;
				tlast_htable  <= 0;
			end
			// GET Request with cache miss
			HTABLE_LUT_REQ: begin
				htable_state  <= HTABLE_IDLE;
				tdata_htable  <= KEY[htable_check_cnt];
				tdest_htable  <= config_lut_node;
				tkeep_htable  <= nkeep64(key_len);
				tuser_htable  <= {chck_req_keylen, pe_id[7:0], 8'h1, src_uport, opaque};
				tvalid_htable <= 1;
				tlast_htable  <= 1;
			end
`endif /* CACHE_MODE */
			default: ;
		endcase
	end
end

/*************************************************************
 * key check & Memory Data
 *************************************************************/
reg [  7:0] reg_cnt;
reg [  7:0] val_cnt;
reg [ 15:0] cnt_keylen, cnt_vallen;
reg [511:0] val_reg;
reg         compare_en;
reg         return_value_en;
reg [511:0] mem_tdata_reg, comp_tdata_reg;
wire [19:0] shift = {1'b0, chck_rep_keylen, 3'b000};
reg [6:0]   remain_keylen;
reg [6:0]   remain_keylen_neg;

reg [511:0] mask512_remain_keylen;
reg [511:0] mask512_remain_keylen_neg;

always @ (posedge clk) begin
	if (rst_reg[6]) begin
		reg_cnt         <= 0;
		chck_req_keylen <= 0;
		chck_req_vallen <= 0;
		chck_rep_keylen <= 0;
		chck_rep_vallen <= 0;
		cnt_keylen      <= 0; // todo: mutilple key and values 
		cnt_vallen      <= 0; // todo: mutilple key and values 
		val_reg         <= 0;
		return_miss     <= 0;
		return_hit      <= 0;
		return          <= 0;
		return_value_en <= 0;
		val_cnt         <= 0;
		compare_en      <= 0;
		comp_tdata_reg  <= 0;
		mem_tdata_reg   <= 0;
		htable0_en_reg  <= 0;
		htable_valid    <= 0;
		remain_keylen   <= 0;
		remain_keylen_neg<= 0;
		mask512_remain_keylen <= 0;
		mask512_remain_keylen_neg <= 0;
		htable_acc_all <= 0; 
		htable_acc_hit <= 0; 
	end else begin
		htable0_en_reg  <= htable0_en;
		if (htable0_en) begin
			chck_req_keylen <= key_len;
			chck_req_vallen <= val_len;
			chck_rep_keylen <= {1'b0, htable0_keylen};
			chck_rep_vallen <= {1'b0, htable0_vallen};
			htable_valid    <= 1'b1;
		end
		if (m_pe_axis_tvalid && m_pe_axis_tready && m_pe_axis_tlast) begin
			htable_valid      <= 1'b0;
			remain_keylen     <= 0;
			remain_keylen_neg <= 0;
			mask512_remain_keylen <= 0;
			mask512_remain_keylen_neg <= 0;
		end
		//if (s_mem_axis_tvalid_buf && s_mem_axis_tready_buf && s_mem_axis_tlast_buf) begin
		//	reg_cnt <= 0;
		//end else if (s_mem_axis_tvalid_buf && s_mem_axis_tready_buf) begin
		//	reg_cnt <= reg_cnt + 1;
		//end
		if (s_mem_axis_tvalid_buf && s_mem_axis_tready_buf && htable_state != HTABLE_REP && htable_state != HTABLE_LUT_WAIT) begin
			if (htable_state == HTABLE_IDLE)
				reg_cnt <= reg_cnt + 1;
			if (chck_req_keylen == chck_rep_keylen) begin
				compare_en     <= 1;
			end
			comp_tdata_reg <= KEY[reg_cnt] & keep2mask512(chck_rep_keylen);
			mem_tdata_reg  <= s_mem_axis_tdata_buf & keep2mask512(chck_rep_keylen);
		end else begin
			//compare_en <= 0;
		end

		remain_keylen     <= {1'd0, chck_rep_keylen[5:0]};
		mask512_remain_keylen <= keep2mask512({2'd0, chck_rep_vallen[5:0]});
		remain_keylen_neg <= 7'd64 - {1'd0, chck_rep_keylen[5:0]};
		mask512_remain_keylen_neg <= mask512(~nkeep64({2'd0, chck_rep_vallen[5:0]}));

		if (compare_en) begin
			if (mem_tdata_reg != comp_tdata_reg || chck_rep_keylen == 0) begin
				$display("miss:");
				return      <= 1'b1;
				return_miss <= 1'b1;
				return_hit  <= 1'b0;
				reg_cnt     <= 0;
				//compare_en  <= 1;
				compare_en  <= 0;
			end else begin
				$display("hit :");
				if ((chck_rep_keylen[13:6] == val_cnt && chck_rep_keylen[5:0] != 0) || 
					(chck_rep_keylen[13:6] == val_cnt + 1 && chck_rep_keylen[5:0] == 0)) begin
					if (chck_rep_keylen[5:0] != 0) begin
						return_value_en  <= 1;
					end
					if (!return) begin
						htable_acc_all <= htable_acc_all + 1;
						htable_acc_hit <= htable_acc_hit + 1;
					end
					return      <= 1'b1;
					return_miss <= 1'b0;
					return_hit  <= 1'b1;
					val_cnt     <= 0;
					reg_cnt     <= 0;
					compare_en  <= 0;
				end else begin
					val_cnt     <= val_cnt + 1;
				end
			end
		end else if (htable0_en_reg && opcode == STRPE_OP_SET && chck_req_keylen != chck_rep_keylen)begin
				return      <= 1'b1;
				return_miss <= 1'b1;
				return_hit  <= 1'b0;
				reg_cnt     <= 0;
				if (!return) begin
					htable_acc_all <= htable_acc_all + 1;
				end
		end else if (htable0_en_reg && opcode == STRPE_OP_GET && chck_req_keylen != chck_rep_keylen)begin
				return      <= 1'b1;
				return_miss <= 1'b1;
				return_hit  <= 1'b0;
				reg_cnt     <= 0;
				if (!return) begin
					htable_acc_all <= htable_acc_all + 1;
				end
		end else begin
			return      <= 1'b0;
			return_miss <= 1'b0;
			return_hit  <= 1'b0;
		end
		if (m_pe_axis_tready && m_pe_axis_tvalid && m_pe_axis_tlast) begin
			return_value_en <= 0;
			val_cnt         <= 0;
		end
	end
end

/*************************************************************
 * Valid Period
 *************************************************************/
wire [PE_DATA_PATH_WIDTH-1:0]   tdata_pe_wire;
wire [PE_USER_PATH_WIDTH-1:0]   tuser_pe_wire;
wire [PE_DATA_PATH_WIDTH/8-1:0] tkeep_pe_wire;
wire                            tlast_pe_wire;
wire                            tvalid_pe_wire;
reg valid_mem_next, valid_mem_reg;

always @ (*) begin
	valid_mem_next = valid_mem_reg;
	if (return_value_en) begin
		valid_mem_next = 1;
	end
	if (tlast_pe_wire) begin
		valid_mem_next = 0;
	end
end

always @ (posedge clk) begin
	if (rst_reg[7]) begin
		valid_mem_reg <= 0;
	end else begin
		valid_mem_reg <= valid_mem_next;
	end
end

/*************************************************************
 * PIPELINE Processing
 *************************************************************/
(* dont_touch = "true" *) reg [511:0] mem_axis_tdata_p0 , mem_axis_tdata_p1 , mem_axis_tdata_p2;
(* dont_touch = "true" *) reg [127:0] mem_axis_tuser_p0 , mem_axis_tuser_p1 , mem_axis_tuser_p2;
(* dont_touch = "true" *) reg [ 63:0] mem_axis_tkeep_p0 , mem_axis_tkeep_p1 , mem_axis_tkeep_p2;
(* dont_touch = "true" *) reg         mem_axis_tlast_p0 , mem_axis_tlast_p1 , mem_axis_tlast_p2 ;
(* dont_touch = "true" *) reg         mem_axis_tvalid_p0, mem_axis_tvalid_p1, mem_axis_tvalid_p2;
reg finish_valid;

reg  [15:0] vallen_cnt_reg, vallen_cnt_next;
wire [511:0] align_tdata_p1 = ((mem_axis_tdata_p1>>{remain_keylen[5:0], 3'd0}) & mask512_remain_keylen) | ((mem_axis_tdata_p0<<{remain_keylen_neg[5:0], 3'd0}) & mask512_remain_keylen_neg);
`ifdef SIMULATION_DEBUG
wire [511:0] align_tdata_p1_debug0 = ((mem_axis_tdata_p1>>{remain_keylen[5:0], 3'd0}) & mask512_remain_keylen);
wire [511:0] align_tdata_p1_debug1 = ((mem_axis_tdata_p0<<{remain_keylen_neg[5:0], 3'd0}) & mask512_remain_keylen_neg);
`endif /*SIMULATION_DEBUG*/


always @ (*) begin
	vallen_cnt_next = vallen_cnt_reg;
	if (mem_axis_tvalid_p1 && valid_mem_next)
		vallen_cnt_next = vallen_cnt_next - 64;
end

always @ (posedge clk) begin
	if (rst_reg[8]) begin
		mem_axis_tdata_p0  <= 0;
		mem_axis_tuser_p0  <= 0;
		mem_axis_tkeep_p0  <= 0;
		mem_axis_tlast_p0  <= 0;
		mem_axis_tvalid_p0 <= 0;
		mem_axis_tdata_p1  <= 0;
		mem_axis_tuser_p1  <= 0;
		mem_axis_tkeep_p1  <= 0;
		mem_axis_tlast_p1  <= 0;
		mem_axis_tvalid_p1 <= 0;
		mem_axis_tdata_p2  <= 0;
		mem_axis_tuser_p2  <= 0;
		mem_axis_tkeep_p2  <= 0;
		mem_axis_tlast_p2  <= 0;
		mem_axis_tvalid_p2 <= 0;
		vallen_cnt_reg     <= 0;
		finish_valid       <= 0;
	end else begin
		mem_axis_tdata_p0  <= s_mem_axis_tdata_bufbuf;
		mem_axis_tuser_p0  <= s_mem_axis_tuser_bufbuf;
		mem_axis_tlast_p0  <= s_mem_axis_tlast_bufbuf;
		mem_axis_tkeep_p0  <= s_mem_axis_tkeep_bufbuf;
		mem_axis_tvalid_p0 <= s_mem_axis_tvalid_bufbuf;
		mem_axis_tdata_p1  <= mem_axis_tdata_p0;
		mem_axis_tuser_p1  <= mem_axis_tuser_p0;
		mem_axis_tlast_p1  <= mem_axis_tlast_p0;
		mem_axis_tvalid_p1 <= mem_axis_tvalid_p0;
		mem_axis_tdata_p2  <= align_tdata_p1;
		//mem_axis_tdata_p2  <= mem_axis_tdata_p1;
		mem_axis_tkeep_p1  <= mem_axis_tkeep_p0;
		mem_axis_tuser_p2  <= mem_axis_tuser_p1;
		if (mem_axis_tvalid_p0 && !return_value_en) begin
			vallen_cnt_reg <= chck_rep_vallen;
			finish_valid <= 0;
		end else begin
			vallen_cnt_reg <= vallen_cnt_next;
		end
		if (mem_axis_tvalid_p1 && ((opcode == STRPE_OP_GET && return_value_en) || (valid_mem_next))) begin
			// Todo : more logic is needed for more than 64 Byte
			if (opcode == STRPE_OP_GET && return_value_en) begin
				if (vallen_cnt_reg[15:6] != 0) begin
					mem_axis_tlast_p2  <= 0;
					mem_axis_tkeep_p2  <= 64'hffffffff_ffffffff;
				end else begin
					mem_axis_tlast_p2  <= 1;
					mem_axis_tkeep_p2  <= nkeep64(vallen_cnt_reg[5:0]);
					finish_valid <= 1;
				end
			end else begin 
				mem_axis_tlast_p2  <= mem_axis_tlast_p1;
				mem_axis_tkeep_p2  <= mem_axis_tkeep_p1;
			end
			if (!finish_valid) 
				mem_axis_tvalid_p2 <= 1'b1;
		end else begin
			mem_axis_tlast_p2  <= mem_axis_tlast_p1;
			mem_axis_tkeep_p2  <= mem_axis_tkeep_p1;
			mem_axis_tvalid_p2 <= 1'b0;
		end
	end
end

/*************************************************************
 * Memory DATA for PE returning (512bit to 256bit)
 *************************************************************/
axis2convert #(
	.C_M_AXIS_DATA_WIDTH    (256),
	.C_S_AXIS_DATA_WIDTH    (512),
	.C_M_AXIS_TUSER_WIDTH   (64),
	.C_S_AXIS_TUSER_WIDTH   (64),
	.C_M_AXIS_TDEST_WIDTH   (3),
	.C_S_AXIS_TDEST_WIDTH   (3)
) u_axis2conv (
	.axis_aclk              ( clk  ),
	.axis_resetn            ( !rst_reg[9] ),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata           ( tdata_pe_wire  ),
	.m_axis_tkeep           ( tkeep_pe_wire  ),
	.m_axis_tuser           (  ),
	//.m_axis_tdest           (  ),
	.m_axis_tvalid          ( tvalid_pe_wire ),
	.m_axis_tready          ( 1'b1/*tready_pe_wire*/ ), // todo : which signal is good?
	.m_axis_tlast           ( tlast_pe_wire  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata           ( mem_axis_tdata_p2  ),
	.s_axis_tkeep           ( mem_axis_tkeep_p2  ),
	.s_axis_tuser           ( mem_axis_tuser_p2[63:0]  ),
	//.s_axis_tdest           ( /*mem_axis_tdest_p2*/0  ),
	.s_axis_tvalid          ( mem_axis_tvalid_p2 ),
	.s_axis_tready          ( /*s_mem_axis_tready*/ ),
	.s_axis_tlast           ( mem_axis_tlast_p2  )
);


/*************************************************************
 * Returning DATA 
 *************************************************************/
localparam TUSER_CACHE_MISS = 2'b01;
localparam TUSER_CACHE_HIT  = 2'b10;
localparam TUSER_CACHE_THROUGH = 2'b11;
localparam TUSER_CACHE_DISCARD = 2'b00;

reg  [PE_DATA_PATH_WIDTH-1:0]   tdata_reg , tdata_next;
reg  [PE_DATA_PATH_WIDTH/8-1:0] tkeep_reg , tkeep_next;
//reg  [PE_USER_PATH_WIDTH-1:0]   tuser_reg , tuser_next;
reg  [PE_USER_PATH_WIDTH-1-74:0]   tuser_reg , tuser_next;
reg                             tlast_reg , tlast_next;
reg                             tvalid_reg, tvalid_next;
wire [PE_DATA_PATH_WIDTH-1:0]   tdata_upper;
wire [PE_DATA_PATH_WIDTH/8-1:0] tkeep_upper;
wire [PE_USER_PATH_WIDTH-1-74:0]   tuser_upper;
wire                            tlast_upper;
wire                            tvalid_upper;

reg  [15:0] value_len_tmp;
reg  [7:0]  opcode_reg;
reg  [7:0]  val_cnt_rtn;

wire rd_en_tx = tvalid_upper && m_pe_axis_tready;
wire empty_tx, full_tx;
wire wr_en_tx = tvalid_next;

always @ (*) begin
	tdata_next = tdata_reg;
	tkeep_next = tkeep_reg;
	tuser_next = tuser_reg;
	tlast_next = tlast_reg;
	tvalid_next = tvalid_reg;

	if (opcode == STRPE_OP_SET && htable_state == HTABLE_IDLE && kvupdate_done) begin
		tdata_next  = 0;
		tuser_next  = {16'h0, STRPE_OP_SET, TUSER_CACHE_DISCARD}; 
		tkeep_next  = 7;
		tlast_next  = 1;
		tvalid_next = 1;
	end else if (opcode == STRPE_OP_SET && htable_state == HTABLE_IDLE && slab_error) begin
		tdata_next  = 0;
		tuser_next  = {16'h0, STRPE_OP_SET, TUSER_CACHE_DISCARD}; 
		tkeep_next  = 7;
		tlast_next  = 1;
		tvalid_next = 1;
	end else if (opcode == STRPE_OP_DEL && (return_miss || (htable_state == HTABLE_KVUPDATE && update_reg))) begin
		tdata_next  = 0;
		tuser_next  = {16'h0, STRPE_OP_DEL, TUSER_CACHE_DISCARD}; 
		tkeep_next  = 7;
		tlast_next  = 1;
		tvalid_next = 1;
	end else if (opcode_reg == STRPE_OP_GET && return_value_en/*&& valid_mem_reg*/) begin
		tdata_next  = tdata_pe_wire;//(tdata_pe_wire >> {chck_rep_keylen, 3'b000}) & keep2mask(chck_rep_vallen); // this probabaly must be pipelined.
		tuser_next  = {chck_rep_vallen, STRPE_OP_GET, TUSER_CACHE_HIT}; 
		tkeep_next  = tkeep_pe_wire;//nkeep(chck_rep_vallen);
		tlast_next  = tlast_pe_wire;
		tvalid_next = tvalid_pe_wire;
	end else if (htable_state == HTABLE_LUT_REQ) begin
		tdata_next  <= 0;
		tuser_next  <= {16'h0, STRPE_OP_GET, TUSER_CACHE_THROUGH}; 
		tkeep_next  <= 0;
		tlast_next  <= 1;
		tvalid_next <= 1;
	end else if (lut_en) begin
		tdata_next  <= 0;
		tuser_next  <= {16'h0, STRPE_OP_GET, TUSER_CACHE_DISCARD}; 
		tkeep_next  <= 0;
		tlast_next  <= 1;
		tvalid_next <= 1;
	end else begin
		tdata_next  <= 0;
		tuser_next  <= 0; 
		tkeep_next  <= 0;
		tlast_next  <= 0;
		tvalid_next <= 0;
	end
end

always @ (posedge clk) begin
	if (rst_reg[10]) begin
		tdata_reg  <= 0;
		tuser_reg  <= 0; 
		tkeep_reg  <= 0;
		tlast_reg  <= 0;
		tvalid_reg <= 0;
		opcode_reg <= 0;
		val_cnt_rtn <= 0;
		value_len_tmp <= 0;
	end else begin
		if (htable_state == HTABLE_KVUPDATE) begin
			opcode_reg <= opcode;
		end
		if (s_pe_axis_tvalid && s_pe_axis_tready) begin
			value_len_tmp <= value_len_tmp + 16'd32;
		end
		tdata_reg  <= tdata_next ;
		tuser_reg  <= tuser_next ; 
		tkeep_reg  <= tkeep_next ;
		tlast_reg  <= tlast_next ;
		tvalid_reg <= tvalid_next;
	end
end

assign tvalid_upper = !empty_tx;

lake_fallthrough_small_fifo #(
	.WIDTH          ( PE_DATA_PATH_WIDTH+PE_DATA_PATH_WIDTH/8+PE_USER_PATH_WIDTH+1-74 ),
	.MAX_DEPTH_BITS ( 3 )
) u_fifo_tx (
	.din            ({tlast_next, tuser_next, tkeep_next, tdata_next}),
	.wr_en          ( wr_en_tx ),
	.rd_en          ( rd_en_tx ),
	.dout           ({tlast_upper, tuser_upper, tkeep_upper, tdata_upper}),
	.full           ( full_tx ),
	.nearly_full    (),
	.prog_full      (),
	.empty          ( empty_tx ),
	.reset          ( rst_reg[11] ),
	.clk            ( clk )
);

/*************************************************************
 * Arbitor for TDATA : 1. upper core, 2. DRAM,  3. freelist  
 *************************************************************/

(* dont_touch = "true" *)reg  [MEM_DATA_PATH_WIDTH-1:0]   m_mem_axis_tdata_fifo;
(* dont_touch = "true" *)reg  [MEM_DATA_PATH_WIDTH/8-1:0] m_mem_axis_tkeep_fifo;
(* dont_touch = "true" *)reg  [MEM_USER_PATH_WIDTH-1-48:0]   m_mem_axis_tuser_fifo;
(* dont_touch = "true" *)reg  [PE_DEST_BITS-1:0]          m_mem_axis_tdest_fifo;
(* dont_touch = "true" *)reg                              m_mem_axis_tvalid_fifo;
(* dont_touch = "true" *)reg                              m_mem_axis_tlast_fifo;
always @ (*) begin
	m_pe_axis_tdata  = tdata_upper;
	m_pe_axis_tuser[25:0]  = tuser_upper;
	m_pe_axis_tuser[99:26] = 0;
	m_pe_axis_tkeep  = tkeep_upper;
	m_pe_axis_tlast  = tlast_upper;
	m_pe_axis_tvalid = tvalid_upper;
end

always @ (posedge clk)
	if (rst_reg[12]) begin
		m_mem_axis_tdata_fifo  <= 0;
		m_mem_axis_tuser_fifo  <= 0;
		m_mem_axis_tkeep_fifo  <= 0;
		m_mem_axis_tlast_fifo  <= 0;
		m_mem_axis_tvalid_fifo <= 0;
		m_mem_axis_tdest_fifo  <= 0;
	end else begin
		if (htable_state == HTABLE_IDLE      || 
			htable_state == HTABLE_REP       || 
			htable_state == HTABLE_HTABLE_WR || 
			htable_state == HTABLE_KVUPDATE  || 
			htable_state == HTABLE_LUT_WAIT) begin// 2. DRAM
			m_mem_axis_tdata_fifo  <= tdata_htable;
			m_mem_axis_tuser_fifo  <= tuser_htable;
			m_mem_axis_tkeep_fifo  <= tkeep_htable;
			m_mem_axis_tlast_fifo  <= tlast_htable;
			m_mem_axis_tvalid_fifo <= tvalid_htable;
			m_mem_axis_tdest_fifo  <= tdest_htable;
		end else if (htable_state == HTABLE_CHUNK_REQ || htable_state == HTABLE_CHUNK_WAIT) begin // 3. freelist
			m_mem_axis_tdata_fifo  <= tdata_flst;
			m_mem_axis_tuser_fifo  <= tuser_flst;
			m_mem_axis_tkeep_fifo  <= tkeep_flst;
			m_mem_axis_tlast_fifo  <= tlast_flst;
			m_mem_axis_tvalid_fifo <= tvalid_flst;
			m_mem_axis_tdest_fifo  <= config_sram_node;
		end
	end

wire full_mem, empty_mem;

lake_fallthrough_small_fifo #(
	.WIDTH          ( 512+128+64+3+1-48 ),
	.MAX_DEPTH_BITS ( 3 )
) u_mem_tx (
	.din            ({m_mem_axis_tlast_fifo, m_mem_axis_tdest_fifo, 
	                  m_mem_axis_tuser_fifo, m_mem_axis_tkeep_fifo,
	                  m_mem_axis_tdata_fifo}),
	.wr_en          ( m_mem_axis_tvalid_fifo ),
	.rd_en          ( !empty_mem && m_mem_axis_tready ),
	.dout           ({m_mem_axis_tlast, m_mem_axis_tdest, 
	                  m_mem_axis_tuser[79:0], m_mem_axis_tkeep, 
	                  m_mem_axis_tdata}),
	.full           ( full_mem ),
	.nearly_full    (),
	.prog_full      (),
	.empty          ( empty_mem ),
	.reset          ( rst_reg[13] ),
	.clk            ( clk )
);
assign m_mem_axis_tuser[127:80] = 48'd0;
assign m_mem_axis_tvalid = !empty_mem;

// Todo:
assign s_pe_axis_tready  = 1;
assign s_mem_axis_tready = 1;
/*************************************************************
 * Statics Information
 *************************************************************/

(* dont_touch = "true" *)reg [2:0]  htable_state_reg;
(* dont_touch = "true" *)reg [1:0]  opcoded_reg;
(* dont_touch = "true" *)reg [2:0]  config_dram_node_reg;
(* dont_touch = "true" *)reg [31:0] new_chunk_addr_reg;
(* dont_touch = "true" *)reg [2:0]  return_reg;
(* dont_touch = "true" *)reg [2:0]  tdest_debug_reg;
always @ (posedge clk) begin
	if (rst_reg[14]) begin
		htable_state_reg <= 0;
		opcoded_reg <= 0;
		config_dram_node_reg <= 0;
		new_chunk_addr_reg <= 0;
		return_reg <= 0;
	end else begin
		htable_state_reg <= htable_state;
		opcoded_reg <= opcode[1:0];

		config_dram_node_reg  <= config_dram_node;
		new_chunk_addr_reg    <= new_chunk_addr;
		return_reg <= {return, return_hit, return_miss};
		if (s_mem_axis_tready && s_mem_axis_tvalid)
			tdest_debug_reg <= s_mem_axis_tdest;
	end
end

assign debug_chunk = new_chunk_addr_reg;
assign debug_table = {18'd0,
                      tdest_debug_reg,
                      return_reg,
                      config_dram_node_reg,
                      opcoded_reg,
                      htable_state_reg
                     };

endmodule

