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

`timescale 1 ns / 1 ns
module axis2convert #(
	parameter C_M_AXIS_DATA_WIDTH    = 256,
	parameter C_S_AXIS_DATA_WIDTH    = 512,
	parameter C_M_AXIS_TUSER_WIDTH   = 128,
	parameter C_S_AXIS_TUSER_WIDTH   = 128,
	parameter C_M_AXIS_TDEST_WIDTH   = 3,
	parameter C_S_AXIS_TDEST_WIDTH   = 3
)(
	input axis_aclk,
	input axis_resetn,

	// Master Stream Ports (interface to data path)
	output [C_M_AXIS_DATA_WIDTH-1:0]           m_axis_tdata,
	output [((C_M_AXIS_DATA_WIDTH/8))-1:0]     m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_tuser,
	//output [C_M_AXIS_TDEST_WIDTH-1:0]          m_axis_tdest,
	output                                     m_axis_tvalid,
	input                                      m_axis_tready,
	output                                     m_axis_tlast,
	
	// Slave Stream Ports (interface to RX queues)
	input [C_S_AXIS_DATA_WIDTH-1:0]           s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH/8))-1:0]     s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_tuser,
	//input [C_S_AXIS_TDEST_WIDTH-1:0]          s_axis_tdest,
	input                                     s_axis_tvalid,
	output                                    s_axis_tready,
	input                                     s_axis_tlast
);


/***********************************************************
 * FIFO instances for dividing data into two block;
 ***********************************************************/
//reg rd_en0_reg, rd_en1_reg;

wire wr_en_fifo0, rd_en_fifo0;
wire empty0;
wire full0;
wire nearly_full0;

wire [C_M_AXIS_DATA_WIDTH*2-1:0]       m_axis_tdata_wire0;
wire [((C_M_AXIS_DATA_WIDTH*2/8))-1:0] m_axis_tkeep_wire0;
wire [C_M_AXIS_TUSER_WIDTH-1:0]      m_axis_tuser_wire;
//wire [C_M_AXIS_TDEST_WIDTH-1:0]      m_axis_tdest_wire;
wire                                 m_axis_tlast_wire;

lake_fallthrough_small_fifo #(
	.WIDTH           ((C_M_AXIS_DATA_WIDTH*2)+C_M_AXIS_TUSER_WIDTH+(C_M_AXIS_DATA_WIDTH*2/8)+1),
	.MAX_DEPTH_BITS  (2)
) u_input0_fifo (
	.din           ({s_axis_tlast, s_axis_tuser, s_axis_tkeep, s_axis_tdata}),
	.wr_en         ( wr_en_fifo0 ),
	.rd_en         ( rd_en_fifo0 ),

	.dout          ({m_axis_tlast_wire, m_axis_tuser_wire,
	                         m_axis_tkeep_wire0, m_axis_tdata_wire0}),
	.full          ( full0        ),
	.nearly_full   ( nearly_full0 ),
	.prog_full     (),
	.empty         ( empty0  ),

    .reset         ( !axis_resetn ),
    .clk           ( axis_aclk     )
);

reg [255:0] tdata_tmp;
reg [127:0] tuser_tmp;
reg [31:0]  tkeep_tmp;
reg         tlast_tmp;
reg         tmp_en;

always @ (posedge axis_aclk) begin
	if (!axis_resetn) begin
		tdata_tmp <= 0;
		tuser_tmp <= 0;
		tkeep_tmp <= 0;
		tlast_tmp <= 0;
		tmp_en    <= 0;
	end else begin
		tdata_tmp <= m_axis_tdata_wire0[511:256];
		tuser_tmp <= m_axis_tuser_wire;
		tkeep_tmp <= m_axis_tkeep_wire0[63:32];
		tlast_tmp <= (rd_en_fifo0) ? m_axis_tlast_wire : 1'b0;
		tmp_en    <= rd_en_fifo0;
	end
end

assign rd_en_fifo0 = !empty0 && !tmp_en;
assign wr_en_fifo0 = s_axis_tvalid && s_axis_tready && ~nearly_full0;

/***********************************************************
 * wire assignment
 ***********************************************************/
assign m_axis_tdata  = (tmp_en == 0) ? m_axis_tdata_wire0[255:0] : tdata_tmp;
assign m_axis_tkeep  = (tmp_en == 0) ? m_axis_tkeep_wire0[31:0]  : tkeep_tmp;
assign m_axis_tuser  = (tmp_en == 0) ? m_axis_tuser_wire         : tuser_tmp;
assign m_axis_tlast  = (m_axis_tkeep_wire0[63:32] == 0) ? 1'b1   : tlast_tmp;
assign m_axis_tvalid = (m_axis_tkeep != 0) ? rd_en_fifo0 || tmp_en : 1'b0;

assign s_axis_tready = ~nearly_full0;

endmodule
