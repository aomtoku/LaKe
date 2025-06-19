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

module small_cache #(
	parameter C_CACHE_MEM_ADDR_WIDTH = 32,
	parameter C_CACHE_ADDR_WIDTH     = 10,
	parameter C_CACHE_DATA_WIDTH     = 512,
	parameter C_CACHE_RDATA_WIDTH    = C_CACHE_MEM_ADDR_WIDTH - C_CACHE_ADDR_WIDTH,
	parameter C_CACHE_WIDTH = C_CACHE_DATA_WIDTH + C_CACHE_MEM_ADDR_WIDTH - C_CACHE_ADDR_WIDTH,
	parameter C_CACHE_DEPTH = 2**C_CACHE_ADDR_WIDTH,
	parameter C_CACHE_NWAY  = 1
)(
	input clk,
	input rst, 
	// #0 Path
	input                          rd0_en,
	input [C_CACHE_ADDR_WIDTH-1:0] rd0_addr,
	input [C_CACHE_RDATA_WIDTH-1:0]rd0_din,
	output                         rd0_result,
	output [C_CACHE_DATA_WIDTH-1:0]rd0_dout,
	output reg                     rd0_valid,
	input                          wr0_en,
	input [C_CACHE_ADDR_WIDTH-1:0] wr0_addr,
	input [C_CACHE_WIDTH-1:0]      wr0_data,
	// #1 Path
	input                          rd1_en,
	input [C_CACHE_ADDR_WIDTH-1:0] rd1_addr,
	input [C_CACHE_RDATA_WIDTH-1:0]rd1_din,
	output                         rd1_result,
	output [C_CACHE_DATA_WIDTH-1:0]rd1_dout,
	output reg                     rd1_valid,
	input                          wr1_en,
	input [C_CACHE_ADDR_WIDTH-1:0] wr1_addr,
	input [C_CACHE_WIDTH-1:0]      wr1_data
);

/*
 *  wire declaration
 */
wire port0_en, port1_en;
wire we0, we1;
wire [C_CACHE_ADDR_WIDTH-1:0] addr0 = (rd0_en) ? rd0_addr : wr0_addr;
wire [C_CACHE_ADDR_WIDTH-1:0] addr1 = (rd1_en) ? rd1_addr : wr1_addr;
wire [C_CACHE_WIDTH:0] din0, din1, dout0, dout1;
wire valid0_bit;
wire valid1_bit;
/*
 *  reg declaration
 */
reg lookup0_stage0, lookup0_stage1;
reg lookup1_stage0, lookup1_stage1;
reg [C_CACHE_RDATA_WIDTH-1:0] data0_stage0, data0_stage1;
reg [C_CACHE_RDATA_WIDTH-1:0] data1_stage0, data1_stage1;
/*
 *  assignment :
 */
assign port0_en = 1'b1; //
assign port1_en = 1'b1; //
assign we0 = wr0_en;
assign we1 = wr1_en;

assign rd0_result = lookup0_stage1 && valid0_bit && data0_stage1 == dout0[C_CACHE_RDATA_WIDTH-1:0];
assign rd0_dout   = dout0[C_CACHE_WIDTH-1:C_CACHE_RDATA_WIDTH];
assign rd1_result = lookup1_stage1 && valid1_bit && data1_stage1 == dout1[C_CACHE_RDATA_WIDTH-1:0];
assign rd1_dout   = dout1[C_CACHE_WIDTH-1:C_CACHE_RDATA_WIDTH];

assign din0 = {1'b1, wr0_data};
assign din1 = {1'b1, wr1_data};

assign valid0_bit = dout0[C_CACHE_WIDTH];
assign valid1_bit = dout1[C_CACHE_WIDTH];

always @ (posedge clk) 
	if (rst) begin
		lookup0_stage0 <= 0;
		lookup0_stage1 <= 0;
		lookup1_stage0 <= 0;
		lookup1_stage1 <= 0;
		data0_stage0   <= 0;
		data0_stage1   <= 0;
		data1_stage0   <= 0;
		data1_stage1   <= 0;
		rd0_valid <= 0;
		rd1_valid <= 0;
	end else begin
		lookup0_stage0 <= rd0_en && !we0;
		lookup0_stage1 <= lookup0_stage0;
		lookup1_stage0 <= rd1_en && !we1;
		lookup1_stage1 <= lookup1_stage0;
		data0_stage0   <= rd0_din;
		data0_stage1   <= data0_stage0;
		data1_stage0   <= rd1_din;
		data1_stage1   <= data1_stage0;
		if (lookup0_stage0) begin
			rd0_valid <= 1;
		end else begin
			rd0_valid <= 0;
		end
		if (lookup1_stage0) begin
			rd1_valid <= 1;
		end else begin
			rd1_valid <= 0;
		end
	end


// True Dual-Port RAM: 2 clock cycles for read access
cache_1k u_cache (
	.clka   ( clk      ),
	.ena    ( port0_en ),
	.wea    ( we0      ),
	.addra  ( addr0    ),
	.dina   ( din0     ),
	.douta  ( dout0    ),
	.clkb   ( clk      ),
	.enb    ( port1_en ),
	.web    ( we1      ),
	.addrb  ( addr1    ),
	.dinb   ( din1     ),
	.doutb  ( dout1    ) 
);

endmodule
