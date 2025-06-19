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
`timescale 1ns/1ps
module key_lookup #(
	parameter C_M_AXIS_DATA_WIDTH    = 512,
	parameter C_S_AXIS_DATA_WIDTH    = 512,
	parameter C_M_AXIS_TUSER_WIDTH   = 128,
	parameter C_S_AXIS_TUSER_WIDTH   = 128,
	parameter C_M_AXIS_TDEST_WIDTH   = 3,
	parameter C_S_AXIS_TDEST_WIDTH   = 3
)(
	output reg  [31:0] access_in,
	output reg  [31:0] access_out,
	input              axis_aclk      ,
	input              axis_resetn    ,
	input       [7:0]  config_lut_node,

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
// Function : nkeep
//
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

function [63:0] nkeep64 (input [7:0] i);
begin
	if (i <= 32) begin
		nkeep64 = {32'h0, nkeep(i)};
	end else begin
		nkeep64 = {nkeep(i-32), 32'hffff_ffff};
	end
end
endfunction

reg [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_tdata_buf;
reg [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep_buf;
reg [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_tuser_buf;
reg [C_S_AXIS_TDEST_WIDTH-1:0]          s_axis_tdest_buf;
reg                                     s_axis_tvalid_buf;
reg                                     s_axis_tready_buf;
reg                                     s_axis_tlast_buf;

always @ (posedge axis_aclk) 
	if (!axis_resetn) begin
		s_axis_tdata_buf  <= 0;
		s_axis_tkeep_buf  <= 0;
		s_axis_tuser_buf  <= 0;
		s_axis_tdest_buf  <= 0;
		s_axis_tvalid_buf <= 0;
		s_axis_tready_buf <= 0;
		s_axis_tlast_buf  <= 0;
	end else begin
		s_axis_tdata_buf  <= #5 s_axis_tdata ;
		s_axis_tkeep_buf  <= #5 s_axis_tkeep ;
		s_axis_tuser_buf  <= #5 s_axis_tuser ;
		s_axis_tdest_buf  <= #5 s_axis_tdest ;
		s_axis_tvalid_buf <= #5 s_axis_tvalid;
		s_axis_tready_buf <= #5 s_axis_tready;
		s_axis_tlast_buf  <= #5 s_axis_tlast ;
	end

reg [16+C_M_AXIS_DATA_WIDTH-1:0] KEY [63:0];

reg  [1:0]   state;
reg          lookup_stage0, lookup_stage1, lookup_stage2;
reg  [7:0]   src_node0, src_node1, src_node2, src_node3;
reg  [5:0]   addr_wr_reset, addr_wr_fifo;
reg          valid;
reg [16+C_M_AXIS_DATA_WIDTH-1:0] din_fifo_reg;
wire [5:0]   addr_wr;
wire [47:0]  cmp_din = s_axis_tuser_buf[47:0];
wire         opcode  = (state == 2) ? s_axis_tuser_buf[48] : 1'b0;
wire [47:0]  din_fifo     = (opcode) ? s_axis_tuser_buf[47:0] : 32'h0;
wire [15:0]  len_fifo     = (opcode) ? s_axis_tuser_buf[79:64] : 16'h0;
wire [511:0] key_fifo    = s_axis_tdata_buf;
wire [7:0]   src_node     = s_axis_tuser_buf[63:56];
wire         busy;
wire         match;
wire [5:0]   match_addr;
reg  [5:0]   match_addr_reg;
reg          match_reg;
wire         we_fifo      = state == 1 ? 1'b1 : opcode && s_axis_tvalid_buf && s_axis_tready_buf;
wire         empty_fifo, full_fifo;
wire [47:0]  din, din_out;
wire [5:0]   addr_wr_out;
wire         we = !empty_fifo && !busy;
wire [15:0]  length;
wire [511:0] key_out;

assign addr_wr = (state == 1) ? addr_wr_reset : 
                 (state == 2) ? addr_wr_out   : 0;
assign din     = (state == 1) ? 48'h0      : 
                 (state == 2) ? din_out    : 0;

lake_fallthrough_small_fifo #(
	.WIDTH           ( 48 + 6 + 16 + 512 ),
	.MAX_DEPTH_BITS  ( 3 )
) u_in_fifo (
	.din         ( {din_fifo, addr_wr_fifo, len_fifo, key_fifo} ),
	.wr_en       ( we_fifo ),
	.rd_en       ( !empty_fifo && !busy   ),
	.dout        ( {din_out, addr_wr_out, length, key_out} ),
	.full        ( full_fifo              ),
	.nearly_full ( ),
	.prog_full   ( ),
	.empty       ( empty_fifo             ),
	.reset       ( !axis_resetn           ),
	.clk         ( axis_aclk              )
);
reg return;
always @ (posedge axis_aclk) 
	if (!axis_resetn) begin
		lookup_stage0 <= 0;
		lookup_stage1 <= 0;
		lookup_stage2 <= 0;
		src_node0     <= 0;
		src_node1     <= 0;
		src_node2     <= 0;
		src_node3     <= 0;
		addr_wr_reset <= 0;
		state         <= 0;
		addr_wr_fifo  <= 0;
		valid         <= 0;
		din_fifo_reg  <= 0;
		return        <= 0;
		match_addr_reg <= 0;
		match_reg <= 0;
	end else begin
		lookup_stage0 <= !opcode && s_axis_tvalid_buf && s_axis_tready_buf;
		lookup_stage1 <= lookup_stage0;
		lookup_stage2 <= lookup_stage1;
		src_node0 <= src_node;
		src_node1 <= src_node0;
		src_node2 <= src_node1;
		src_node3 <= src_node2;
		match_reg <= match;
		if (opcode && s_axis_tvalid_buf && s_axis_tready_buf) begin
			if (addr_wr_fifo == 6'd63)
				addr_wr_fifo <= 0;
			else
				addr_wr_fifo <= addr_wr_fifo + 1;
		end
		if (lookup_stage1) begin
			valid <= 0;
			return <= 0;
			match_addr_reg <= match_addr;
		end else if (lookup_stage2) begin
			valid <= 1;
			if (match_reg) begin
				din_fifo_reg <= KEY[match_addr_reg];
				return <= 1;
			end
		end else begin
			valid <= 0;
			return <= 0;
		end
		if (we) begin 
			KEY[addr_wr] <= {length, key_out};
		end
		case (state) 
			0: state <= 1;
			1: begin
				if (!busy) begin
					if (addr_wr_reset == 6'd63) begin
						addr_wr_reset <= 0;
						state   <= 2;
					end else begin
						addr_wr_reset <= addr_wr_reset + 1;
					end
				end
			end
			2: begin
				
			end
			default: ;
		endcase
	end

ncams #(
	.MEM_TYPE              ( 1),
	.CAM_MODE              ( 0),
	.ID_BITS               ( 1),
	.TCAM_ADDR_WIDTH       ( 5),
	.TCAM_DATA_WIDTH       (48),
	.TCAM_ADDR_TYPE        ( 0),
	.TCAM_MATCH_ADDR_WIDTH ( 5)
) u_ncams (
	.clk        ( axis_aclk   ),
	.rst        ( axis_resetn ),
	.we         ( we          ),
	.addr_wr    ( addr_wr     ), //  [TCAM_ADDR_WIDTH+ID_BITS-1:0]
	.din        ( din         ),
	.busy       ( busy        ),
	.cmp_din    ( cmp_din     ),
	.match      ( match       ),
	.match_addr ( match_addr  )
);


wire empty_buf, full_buf;
wire [C_M_AXIS_DATA_WIDTH-1:0] tdata_buf;
wire [7:0] tdest_buf;
wire [15:0] len_buf;
wire        return_buf;

lake_fallthrough_small_fifo #(
	.WIDTH           ( 16+C_M_AXIS_DATA_WIDTH+8+1 ),
	.MAX_DEPTH_BITS  ( 3 )
) u_buf_fifo (
	.din         ( {din_fifo_reg, src_node2, return} ),
	.wr_en       ( valid ),
	.rd_en       ( !empty_buf && m_axis_tready ),
	.dout        ( {len_buf, tdata_buf, tdest_buf, return_buf} ),
	.full        ( full_buf               ),
	.nearly_full ( ),
	.prog_full   ( ),
	.empty       ( empty_buf              ),
	.reset       ( !axis_resetn           ),
	.clk         ( axis_aclk              )
);

assign m_axis_tvalid = !empty_buf;
assign m_axis_tdata  = tdata_buf;
assign m_axis_tuser  = {103'h0, return_buf, len_buf, config_lut_node};
assign m_axis_tdest  = tdest_buf[C_M_AXIS_TDEST_WIDTH-1:0];
assign m_axis_tkeep  = nkeep64(len_buf);
assign m_axis_tlast  = 1'b1;

assign s_axis_tready = state != 0 && state != 1; // todo
/*
 *  DRAM DEBUG
 */
always @ (posedge axis_aclk) 
	if (!axis_resetn) begin
		access_in  <= 0;
		access_out <= 0;
	end else begin
		if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
			access_in <= access_in + 1;
		end
		if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
			access_out <= access_out + 1;
		end
	end
endmodule
