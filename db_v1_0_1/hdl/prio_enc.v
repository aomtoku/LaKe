//
// Copyright (C) 2019 Hiroki Matsutani
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
 
 // This file is generated by ./gen.sh
`timescale 1 ns / 1 ns
module prio_enc #(
	parameter DATA_WIDTH = 48
)(
	input wire clk,
	input wire rst_n,
	input wire en,

	input wire en_0,
	input wire [DATA_WIDTH-1:0] din_0,

	input wire en_1,
	input wire [DATA_WIDTH-1:0] din_1,

	input wire en_2,
	input wire [DATA_WIDTH-1:0] din_2,

	input wire en_3,
	input wire [DATA_WIDTH-1:0] din_3,

	output wire                  dout_en,
	output wire [DATA_WIDTH-1:0] dout
);


 (* dont_touch="true" *) reg [DATA_WIDTH-1:0] reg_din_0;
 (* dont_touch="true" *) reg                  reg_en_0;
 
 //always @ (posedge clk or negedge rst_n)
 always @ (posedge clk)
	if (!rst_n) begin
		reg_din_0 <= 0;
		reg_en_0 <= 0;
	end else begin
		reg_din_0 <= din_0;
		reg_en_0 <= en_0;
	end

 (* dont_touch="true" *) reg [DATA_WIDTH-1:0] reg_din_1;
 (* dont_touch="true" *) reg                  reg_en_1;
 
 //always @ (posedge clk or negedge rst_n)
 always @ (posedge clk)
	if (!rst_n) begin
		reg_din_1 <= 0;
		reg_en_1 <= 0;
	end else begin
		reg_din_1 <= din_1;
		reg_en_1 <= en_1;
	end

 (* dont_touch="true" *) reg [DATA_WIDTH-1:0] reg_din_2;
 (* dont_touch="true" *) reg                  reg_en_2;
 
 //always @ (posedge clk or negedge rst_n)
 always @ (posedge clk)
	if (!rst_n) begin
		reg_din_2 <= 0;
		reg_en_2 <= 0;
	end else begin
		reg_din_2 <= din_2;
		reg_en_2 <= en_2;
	end

 (* dont_touch="true" *) reg [DATA_WIDTH-1:0] reg_din_3;
 (* dont_touch="true" *) reg                  reg_en_3;
 
 //always @ (posedge clk or negedge rst_n)
 always @ (posedge clk)
	if (!rst_n) begin
		reg_din_3 <= 0;
		reg_en_3 <= 0;
	end else begin
		reg_din_3 <= din_3;
		reg_en_3 <= en_3;
	end
 
 (* dont_touch="true" *) reg reg_en;

 //always @ (posedge clk or negedge rst_n)
 always @ (posedge clk)
	if (!rst_n) reg_en <= 0;
	else        reg_en <= en;

 assign dout = 	(!reg_en ) ? 0  : (
				(reg_en_0) ? reg_din_0 :
				(reg_en_1) ? reg_din_1 :
				(reg_en_2) ? reg_din_2 :
				(reg_en_3) ? reg_din_3 :
 				0);
 assign dout_en = reg_en;


endmodule

