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

`timescale 1 ps/100 fs

module sram_cont #(
//***********************************************************
// SUPPORT CHUNK
//***********************************************************
	parameter MAX_CHUNK_SIZE_BYTE     = 1024,
	parameter CHUNK0_SIZE             = 64,
	parameter CHUNK1_SIZE             = 128,
	parameter CHUNK2_SIZE             = 256,
	parameter CHUNK3_SIZE             = 512,
//***********************************************************
// AXI Stream Bus
//***********************************************************
	parameter C_M_AXIS_DATA_WIDTH     = 512,
	parameter C_S_AXIS_DATA_WIDTH     = 512,
	parameter C_M_AXIS_TUSER_WIDTH    = 128,
	parameter C_S_AXIS_TUSER_WIDTH    = 128,
	parameter AXIS_DEST_BITS          = 3,
//***********************************************************
// The following parameters are mode register settings
//***********************************************************
	parameter C0_MEM_TYPE              = "QDR2PLUS", 
	parameter C1_MEM_TYPE              = "QDR2PLUS",
	parameter C0_DATA_WIDTH            = 36, // # of DQ (data)
	parameter C1_DATA_WIDTH            = 36,
	parameter C0_BW_WIDTH              = 4, // # of byte writes
	parameter C1_BW_WIDTH              = 4,
	parameter C0_ADDR_WIDTH            = 19, // Address Width
	parameter C1_ADDR_WIDTH            = 19,
	parameter C0_NUM_DEVICES           = 1,
	parameter C1_NUM_DEVICES           = 1,
	parameter C0_CLKIN_PERIOD          = 4999,
	parameter C1_CLKIN_PERIOD          = 4999,
	parameter C0_CLK_PERIOD            = 2000,
	parameter C1_CLK_PERIOD            = 2000,

//***********************************************************
// The following parameters are mode register settings
//***********************************************************
	parameter C0_BURST_LEN             = 4, 
	parameter C1_BURST_LEN             = 4,
//***********************************************************
// Simulation parameters
//***********************************************************
	parameter C0_SIMULATION            = "FALSE", // "TRUE" or "FALSE"
	parameter C1_SIMULATION            = "FALSE",
	parameter C0_SIM_BYPASS_INIT_CAL   = "FAST",
	parameter C1_SIM_BYPASS_INIT_CAL   = "FAST",
//***********************************************************
// IODELAY and PHY related parameters
//***********************************************************
	parameter C0_TCQ                   = 100,
	parameter C1_TCQ                   = 100,
	parameter integer DEVICE_TAPS      = 32,
//***********************************************************
// System clock frequency parameters
//***********************************************************
	parameter C0_nCK_PER_CLK           = 2, // # of memory CKs per fabric CLK
	parameter C1_nCK_PER_CLK           = 2,
//***********************************************************
// Wait period for the read strobe (CQ) to become stable
//***********************************************************
//parameter C0_CLK_STABLE            = (20*1000*1000/(C0_CLK_PERIOD*2)),
                                  // Cycles till CQ/CQ# is stable
                                  // Should be TRUE during design simulations and
                                  // FALSE during implementations
                                  // # of memory CKs per fabric CLK
	parameter RST_ACT_LOW           = 0
                                  // =1 for active low reset,
                                  // =0 for active high.
)(
	input                                      axis_aclk  ,
	input                                      axis_resetn,
	// Master Stream Ports (interface to data path)
	output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_tdata,
	output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_tuser,
	output [AXIS_DEST_BITS-1:0]                m_axis_tdest,
	output                                     m_axis_tvalid,
	input                                      m_axis_tready,
	output                                     m_axis_tlast,
	// Slave Stream Ports (interface to RX queues)
	input [C_S_AXIS_DATA_WIDTH - 1:0]          s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0]  s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser,
	input [AXIS_DEST_BITS-1:0]                 s_axis_tdest,
	input                                      s_axis_tvalid,
	output                                     s_axis_tready,
	input                                      s_axis_tlast,
	// Debug Port
	output [31:0] sram0_wrcmd,
	output [31:0] sram0_rdcmd,
	output [31:0] sram1_wrcmd,
	output [31:0] sram1_rdcmd,
	output reg [31:0] sram_incnt,
	output reg [31:0] sram_outcnt,
`ifndef REMOVE_SRAM_IMP
//Memory Interface
	input       [0:0]     c0_qdriip_cq_p,
	input       [0:0]     c0_qdriip_cq_n,
	input       [35:0]    c0_qdriip_q,
	inout  wire [0:0]     c0_qdriip_k_p,
	inout  wire [0:0]     c0_qdriip_k_n,
	output wire [35:0]    c0_qdriip_d,
	output wire [18:0]    c0_qdriip_sa,
	output wire           c0_qdriip_w_n,
	output wire           c0_qdriip_r_n,
	output wire [3:0]     c0_qdriip_bw_n,
	output wire           c0_qdriip_dll_off_n,
//Memory Interface
	input       [0:0]     c1_qdriip_cq_p, 
	input       [0:0]     c1_qdriip_cq_n,
	input       [35:0]    c1_qdriip_q,
	inout wire  [0:0]     c1_qdriip_k_p,
	inout wire  [0:0]     c1_qdriip_k_n,
	output wire [35:0]    c1_qdriip_d,
	output wire [18:0]    c1_qdriip_sa,
	output wire           c1_qdriip_w_n,
	output wire           c1_qdriip_r_n,
	output wire [3:0]     c1_qdriip_bw_n,
	output wire           c1_qdriip_dll_off_n,
// Single-ended system clock
	output                init_calib_complete,
	//input                 c0_sys_clk_i,
	//input                 c1_sys_clk_i,
	input                 c0_sys_clk_p,
	input                 c0_sys_clk_n,
	input                 c1_sys_clk_p,
	input                 c1_sys_clk_n,
`endif /*REMOVE_SRAM_IMP*/
	//input                 clk_ref_i,
// System reset - Default polarity of sys_rst pin is Active Low.
// System reset polarity will change based on the option 
// selected in GUI.
	input                 sys_rst
); 
/*************************************************************
 * AXIS format
 *************************************************************/

// s_axis_tuser[1:0]   : GET REQUEST(2'b01) / Delete REQ(2'b10)
// s_axis_tuser[11:2]  : SLAB SIZE
//

// m_axis_tuser[1:0]    : REPLY(1'b0)
// m_axis_tuser[11:2] : ALLOCATED CHUNK SIZE
// m_axis_tdata[31:0] : CHUNK ADDRESS

/*************************************************************
 * Functions
 *************************************************************/
// clogb2 function - ceiling of log base 2
function integer clogb2 (input integer size);
begin
	size = size - 1;
	for (clogb2=1; size>1; clogb2=clogb2+1)
		size = size >> 1;
end
endfunction

/*************************************************************
 * Parameters
 *************************************************************/
localparam integer C0_TAP_BITS = clogb2(DEVICE_TAPS - 1);
localparam integer C0_CQ_BITS  = clogb2(C0_DATA_WIDTH/9 - 1);
localparam integer C0_Q_BITS   = clogb2(C0_DATA_WIDTH - 1);   
localparam integer C1_TAP_BITS = clogb2(DEVICE_TAPS - 1);
localparam integer C1_CQ_BITS  = clogb2(C1_DATA_WIDTH/9 - 1);
localparam integer C1_Q_BITS   = clogb2(C1_DATA_WIDTH - 1);

localparam C0_APP_DATA_WIDTH   = C0_BURST_LEN*C0_DATA_WIDTH;
localparam C0_APP_MASK_WIDTH   = C0_APP_DATA_WIDTH / 9;
localparam C1_APP_DATA_WIDTH   = C1_BURST_LEN*C1_DATA_WIDTH;
localparam C1_APP_MASK_WIDTH   = C1_APP_DATA_WIDTH / 9;
   

localparam MAX_CHUNK_SIZE      = clogb2(MAX_CHUNK_SIZE_BYTE);

localparam SRAM_CMD_WR         = 1;
localparam SRAM_CMD_RD         = 0;

localparam SLAB0_SIZE             = 64;
localparam SLAB1_SIZE             = 128;
localparam SLAB2_SIZE             = 256;
localparam SLAB3_SIZE             = 512;
`ifdef SIZE_SIMULATION_DEBUG
localparam SLAB0_START_ADDR       = 32'h1000_0000;
localparam SLAB1_START_ADDR       = 32'h1000_1000;
localparam SLAB2_START_ADDR       = 32'h1000_2000;
localparam SLAB3_START_ADDR       = 32'h1000_3000;
localparam SLAB0_FINISH_ADDR      = 32'h1000_1000 - SLAB0_SIZE;
localparam SLAB1_FINISH_ADDR      = 32'h1000_2000 - SLAB1_SIZE;
localparam SLAB2_FINISH_ADDR      = 32'h1000_3000 - SLAB2_SIZE;
localparam SLAB3_FINISH_ADDR      = 32'h1000_4000 - SLAB3_SIZE;
localparam SLAB0_SRAM_START_ADDR  = 20'h0_1000;
localparam SLAB0_SRAM_FINISH_ADDR = 20'h0_2000;
localparam SLAB1_SRAM_START_ADDR  = 20'h0_3000;
localparam SLAB1_SRAM_FINISH_ADDR = 20'h0_4000;
localparam SLAB2_SRAM_START_ADDR  = 20'h0_5000;
localparam SLAB2_SRAM_FINISH_ADDR = 20'h0_6000;
localparam SLAB3_SRAM_START_ADDR  = 20'h0_7000;
localparam SLAB3_SRAM_FINISH_ADDR = 20'h0_8000;
`else
localparam SLAB0_START_ADDR       = 32'h1000_0000;
localparam SLAB0_FINISH_ADDR      = 32'h1400_0000 - SLAB0_SIZE;
localparam SLAB1_START_ADDR       = 32'h1400_0000;
localparam SLAB1_FINISH_ADDR      = 32'h1800_0000 - SLAB0_SIZE;
localparam SLAB2_START_ADDR       = 32'h1800_0000;
localparam SLAB2_FINISH_ADDR      = 32'h1C00_0000 - SLAB0_SIZE;
localparam SLAB3_START_ADDR       = 32'h1C00_0000;
localparam SLAB3_FINISH_ADDR      = 32'h2000_0000 - SLAB0_SIZE;
localparam SLAB0_SRAM_START_ADDR  = 20'h0_0000;
localparam SLAB0_SRAM_FINISH_ADDR = 20'h3_ffff;
localparam SLAB1_SRAM_START_ADDR  = 20'h4_0000;
localparam SLAB1_SRAM_FINISH_ADDR = 20'h7_ffff;
localparam SLAB2_SRAM_START_ADDR  = 20'h8_0000;
localparam SLAB2_SRAM_FINISH_ADDR = 20'hb_ffff;
localparam SLAB3_SRAM_START_ADDR  = 20'hc_0000;
localparam SLAB3_SRAM_FINISH_ADDR = 20'hf_ffff;
`endif
/*************************************************************
 * Wire declarations
 *************************************************************/
wire                                    c0_clk;
wire                                    c0_rst_clk;
wire                                    c0_app_wr_cmd0;
wire                                    c0_app_wr_cmd1;
wire [C0_ADDR_WIDTH-1:0]                c0_app_wr_addr0;
wire [C0_ADDR_WIDTH-1:0]                c0_app_wr_addr1;
wire                                    c0_app_rd_cmd0;
wire                                    c0_app_rd_cmd1;
wire [C0_ADDR_WIDTH-1:0]                c0_app_rd_addr0;
wire [C0_ADDR_WIDTH-1:0]                c0_app_rd_addr1;
wire [(C0_BURST_LEN*C0_DATA_WIDTH)-1:0] c0_app_wr_data0;
wire [(C0_DATA_WIDTH*2)-1:0]            c0_app_wr_data1;
wire [(C0_BURST_LEN*C0_BW_WIDTH)-1:0]   c0_app_wr_bw_n0;
wire [(C0_BW_WIDTH*2)-1:0]              c0_app_wr_bw_n1;
wire                                    c0_app_cal_done;
wire                                    c0_app_rd_valid0;
wire                                    c0_app_rd_valid1;
wire [(C0_BURST_LEN*C0_DATA_WIDTH)-1:0] c0_app_rd_data0;
wire [(C0_DATA_WIDTH*2)-1:0]            c0_app_rd_data1;

wire                                    c1_clk;
wire                                    c1_rst_clk;
wire                                    c1_app_wr_cmd0;
wire                                    c1_app_wr_cmd1;
wire [C1_ADDR_WIDTH-1:0]                c1_app_wr_addr0;
wire [C1_ADDR_WIDTH-1:0]                c1_app_wr_addr1;
wire                                    c1_app_rd_cmd0;
wire                                    c1_app_rd_cmd1;
wire [C1_ADDR_WIDTH-1:0]                c1_app_rd_addr0;
wire [C1_ADDR_WIDTH-1:0]                c1_app_rd_addr1;
wire [(C1_BURST_LEN*C1_DATA_WIDTH)-1:0] c1_app_wr_data0;
wire [(C1_DATA_WIDTH*2)-1:0]            c1_app_wr_data1;
wire [(C1_BURST_LEN*C1_BW_WIDTH)-1:0]   c1_app_wr_bw_n0;
wire [(C1_BW_WIDTH*2)-1:0]              c1_app_wr_bw_n1;
wire                                    c1_app_cal_done;
wire                                    c1_app_rd_valid0;
wire                                    c1_app_rd_valid1;
wire [(C1_BURST_LEN*C1_DATA_WIDTH)-1:0] c1_app_rd_data0;
wire [(C1_DATA_WIDTH*2)-1:0]            c1_app_rd_data1;

wire                                    c0_init_calib_complete;
wire                                    c1_init_calib_complete;

assign init_calib_complete = c0_init_calib_complete & 
                                   c1_init_calib_complete;

/*************************************************************
 * AXIS LOGIC
 *************************************************************/
wire empty_axis_mig_asfifo0, full_axis_mig_asfifo0;
wire empty_axis_mig_asfifo1, full_axis_mig_asfifo1;
wire [AXIS_DEST_BITS-1:0]  dest_pe;
wire full_node, empty_node;
wire dout_en;
wire empty_axis_mig_asfifo2;
wire full_axis_mig_asfifo2;
wire [31:0] alloc_chunk_addr_fifo;
wire [11:0] alloc_chunk_size_fifo;

wire [1:0]  request   = s_axis_tuser[1:0];
wire [9:0]  max_chunk = s_axis_tuser[11:2];
wire [7:0]  src_node  = s_axis_tuser[19:12];
wire [7:0]  src_node_out;
wire [9:0]  max_chunk_fifo;
wire [31:0] del_chunk = s_axis_tdata[31:0];
wire [1:0]  sel;

wire        mem_request;
wire [9:0]  mem_max_chunk;
wire [31:0] mem_del_chunk;
wire [7:0] s_axis_tdest_wire, dest_pe_wire;
assign s_axis_tdest_wire[AXIS_DEST_BITS-1:0] = s_axis_tdest;
assign s_axis_tdest_wire[7:AXIS_DEST_BITS] = 0;

assign dest_pe = dest_pe_wire[AXIS_DEST_BITS-1:0];

`ifndef REMOVE_SRAM_IMP
lake_fallthrough_small_fifo #(
	.WIDTH               ( 18 ),
	.MAX_DEPTH_BITS      ( 3 )
) u_axis_mig_sfifo0 (
	.dout            ( {dest_pe_wire, max_chunk_fifo}   ),
	.empty           ( empty_axis_mig_asfifo0  ),
	.rd_en           ( !empty_axis_mig_asfifo0 ),
	
	.din             ( {s_axis_tdest_wire, s_axis_tuser[MAX_CHUNK_SIZE+2-1:2]} ),
	.full            ( full_axis_mig_asfifo0   ),
	.wr_en           ( s_axis_tvalid && s_axis_tready && request[0] ),
	.clk             ( axis_aclk              ),
	
	.reset           ( !axis_resetn )
);

lake_fallthrough_small_fifo #(
	.WIDTH               ( 43 ),
	.MAX_DEPTH_BITS      ( 3 )
) u_axis_mig_sfifo1 (
	.dout            ( {mem_del_chunk, mem_max_chunk, mem_request} ),
	.empty           ( empty_axis_mig_asfifo1                      ),
	.rd_en           ( !empty_axis_mig_asfifo1                     ),
	
	.din             ( {del_chunk , max_chunk, request[1]}         ),
	.full            ( full_axis_mig_asfifo1                       ),
	.wr_en           ( s_axis_tvalid && s_axis_tready),
	.clk             ( axis_aclk                                   ),
	
	.reset           ( !axis_resetn  )
);
`endif /*REMOVE_SRAM_IMP*/

lake_fallthrough_small_fifo #(
	.WIDTH               ( 8 ),
	.MAX_DEPTH_BITS      ( 5 )
) u_node_info (
	.din             ( src_node  ),
	.wr_en           ( s_axis_tvalid && s_axis_tready && s_axis_tuser[0] ),
	.rd_en           ( !empty_axis_mig_asfifo2 && m_axis_tready && !empty_node ),  
	.dout            ( src_node_out   ),  
	.full            ( full_node        ),
	.nearly_full     (  ),
	.prog_full       (  ),
	.empty           ( empty_node       ),
	.reset           ( !axis_resetn     ),
	.clk             ( axis_aclk        ) 
);
/*************************************************************
 * Determinition of CHUNK SIZE
 *************************************************************/
reg sel_valid_reg;
reg [1:0] sel_reg;
reg req_reg;
reg [31:0] mem_max_chunk_p0;
reg [31:0] mem_del_chunk_p0;
`ifndef REMOVE_SRAM_IMP

always @ (posedge axis_aclk)
	if (!axis_resetn) begin
		sel_reg          <= 0;
		req_reg          <= 0;
		sel_valid_reg    <= 0; 
		mem_max_chunk_p0 <= 0;
		mem_del_chunk_p0 <= 0;
	end else begin	
		sel_valid_reg <= !empty_axis_mig_asfifo1;
		req_reg       <= (!empty_axis_mig_asfifo1) ? mem_request : 0;
		sel_reg       <= (mem_max_chunk <= CHUNK0_SIZE) ? 2'b00 :
                         (mem_max_chunk <= CHUNK1_SIZE) ? 2'b01 :
                         (mem_max_chunk <= CHUNK2_SIZE) ? 2'b10 :
                         (mem_max_chunk <= CHUNK3_SIZE) ? 2'b11 : 0;
		mem_max_chunk_p0 <= mem_max_chunk;
		mem_del_chunk_p0 <= mem_del_chunk;
	end

assign sel = sel_reg;

wire        fl0_get_valid, fl0_del_valid; 
wire [31:0] fl0_din, fl0_dout;
wire        fl0_dout_en;
wire        fl1_get_valid, fl1_del_valid; 
wire [31:0] fl1_din, fl1_dout;
wire        fl1_dout_en;
wire        fl2_get_valid, fl2_del_valid; 
wire [31:0] fl2_din, fl2_dout;
wire        fl2_dout_en;
wire        fl3_get_valid, fl3_del_valid; 
wire [31:0] fl3_din, fl3_dout;
wire        fl3_dout_en;
wire [ 9:0] chunk_size_fl0;
wire [ 9:0] chunk_size_fl1;
wire [ 9:0] chunk_size_fl2;
wire [ 9:0] chunk_size_fl3;

assign fl0_din   = (fl0_get_valid) ? {22'd0, mem_max_chunk_p0} : 
                   (fl0_del_valid) ? mem_del_chunk_p0          : 0;
assign fl0_get_valid = (sel == 2'b00) && sel_valid_reg && req_reg == 1'b0;
assign fl0_del_valid = (sel == 2'b00) && sel_valid_reg && req_reg == 1'b1;
assign fl1_din   = (fl1_get_valid) ? {22'd0, mem_max_chunk_p0} : 
                   (fl1_del_valid) ? mem_del_chunk_p0          : 0;
assign fl1_get_valid = (sel == 2'b01) && sel_valid_reg && req_reg == 1'b0;
assign fl1_del_valid = (sel == 2'b01) && sel_valid_reg && req_reg == 1'b1;
assign fl2_din   = (fl2_get_valid) ? {22'd0, mem_max_chunk_p0} : 
                   (fl2_del_valid) ? mem_del_chunk_p0          : 0;
assign fl2_get_valid = (sel == 2'b10) && sel_valid_reg && req_reg == 1'b0;
assign fl2_del_valid = (sel == 2'b10) && sel_valid_reg && req_reg == 1'b1;
assign fl3_din   = (fl3_get_valid) ? {22'd0, mem_max_chunk_p0} : 
                   (fl3_del_valid) ? mem_del_chunk_p0          : 0;
assign fl3_get_valid = (sel == 2'b11) && sel_valid_reg && req_reg == 1'b0;
assign fl3_del_valid = (sel == 2'b11) && sel_valid_reg && req_reg == 1'b1;
`endif /*REMOVE_SRAM_IMP*/
/*************************************************************
 * MEM LOGIC
 *************************************************************/
wire [31:0] alloc_chunk_addr;
wire [11:0] alloc_chunk_size;
wire [11:0] fl0_chunk_size;
wire [11:0] fl1_chunk_size;
wire [11:0] fl2_chunk_size;
wire [11:0] fl3_chunk_size;

`ifndef REMOVE_SRAM_IMP
prio_enc #(
	.DATA_WIDTH   ( 44 )
) u_prio_enc (
	.clk     ( axis_aclk   ),
	.rst_n   ( axis_resetn ),
	.en      ( fl0_dout_en || fl1_dout_en || fl2_dout_en || fl3_dout_en ), // todo : add other port en signal

	.en_0    ( fl0_dout_en ),
	.din_0   ( {fl0_chunk_size, fl0_dout} ),
	.en_1    ( fl1_dout_en ),
	.din_1   ( {fl1_chunk_size, fl1_dout} ),
	.en_2    ( fl2_dout_en ),
	.din_2   ( {fl2_chunk_size, fl2_dout} ),
	.en_3    ( fl3_dout_en ),
	.din_3   ( {fl3_chunk_size, fl3_dout} ),

	.dout_en ( dout_en ),
	.dout    ( {alloc_chunk_size, alloc_chunk_addr} )
);

lake_fallthrough_small_fifo #(
	.WIDTH               ( 44 ),
	.MAX_DEPTH_BITS      ( 3 )
) u_axis_mig_afifo2 (
	.dout            ( {alloc_chunk_size_fifo, alloc_chunk_addr_fifo} ), 
	.empty           ( empty_axis_mig_asfifo2                      ),
	.rd_en           ( !empty_axis_mig_asfifo2 && m_axis_tready    ),
	.clk             ( axis_aclk                                   ), 
	
	.din             ( {alloc_chunk_size, alloc_chunk_addr}        ),  
	.full            ( full_axis_mig_asfifo2                       ),
	.wr_en           ( dout_en ),
	
	.reset           ( !axis_resetn                 )
);
// Todo: Replacing registers for init.
reg axis_resetn_reg;
always @ (posedge c0_clk)
	axis_resetn_reg <= c0_rst_clk;

/*************************************************************
 * Instance #0: MIG2WORD 
 *************************************************************/
wire [143:0] fl0_sram_din, fl0_sram_dout;
wire         fl0_sram_din_en;
wire         fl0_sram_cmd, fl0_sram_cmd_en;
wire [19:0]  fl0_sram_addr;
wire         fl0_ready;
reg          fl0_rd_en;

wire [143:0] fl1_sram_din, fl1_sram_dout;
wire         fl1_sram_din_en;
wire         fl1_sram_cmd, fl1_sram_cmd_en;
wire [19:0]  fl1_sram_addr;
wire         fl1_ready;
reg          fl1_rd_en;

wire [143:0] fl2_sram_din, fl2_sram_dout;
wire         fl2_sram_din_en;
wire         fl2_sram_cmd, fl2_sram_cmd_en;
wire [19:0]  fl2_sram_addr;
wire         fl2_ready;
reg          fl2_rd_en;

wire [143:0] fl3_sram_din, fl3_sram_dout;
wire         fl3_sram_din_en;
wire         fl3_sram_cmd, fl3_sram_cmd_en;
wire [19:0]  fl3_sram_addr;
wire         fl3_ready;
reg          fl3_rd_en;

mig2word u_mig2word0 (
	.clk                   ( axis_aclk       ),
	.rst                   ( !axis_resetn    ),

	.get_valid             ( fl0_get_valid   ),
	.del_valid             ( fl0_del_valid   ),
	.din                   ( fl0_din         ),
	//.dout_en               (  ),
	.dout                  ( fl0_dout        ),
	.ovalid                ( fl0_dout_en     ),
	.chunk_size            ( fl0_chunk_size  ),
	// SRAM interfaces
	.sram_din              ( fl0_sram_din    ),
	.sram_din_en           ( fl0_sram_din_en ),
	.sram_addr             ( fl0_sram_addr   ),
	.sram_cmd              ( fl0_sram_cmd    ),
//	.sram_cmd_en           ( fl0_sram_cmd_en ),
	.sram_dout             ( fl0_sram_dout   ),
	.cb_ready              ( fl0_ready       ),
	.cb_rd_en              ( fl0_rd_en       ),
	// Configuration Registers
	//    Todo init_en : Registers reset
	.init_en               ( axis_resetn_reg   ),
	.conf_start_addr       ( SLAB0_START_ADDR  ),
	.conf_finish_addr      ( SLAB0_FINISH_ADDR ),
	.conf_sram_start_addr  ( SLAB0_SRAM_START_ADDR  ),
	.conf_sram_finish_addr ( SLAB0_SRAM_FINISH_ADDR ),
	.conf_chunk_size       ( SLAB0_SIZE        )
);

mig2word u_mig2word1 (
	.clk                   ( axis_aclk       ),
	.rst                   ( !axis_resetn    ),

	.get_valid             ( fl1_get_valid   ),
	.del_valid             ( fl1_del_valid   ),
	.din                   ( fl1_din         ),
	//.dout_en               (  ),
	.dout                  ( fl1_dout        ),
	.ovalid                ( fl1_dout_en     ),
	.chunk_size            ( fl1_chunk_size  ),
	// SRAM interfaces
	.sram_din              ( fl1_sram_din    ),
	.sram_din_en           ( fl1_sram_din_en ),
	.sram_addr             ( fl1_sram_addr   ),
	.sram_cmd              ( fl1_sram_cmd    ),
//	.sram_cmd_en           ( fl0_sram_cmd_en ),
	.sram_dout             ( fl1_sram_dout   ),
	.cb_ready              ( fl1_ready       ),
	.cb_rd_en              ( fl1_rd_en       ),
	// Configuration Registers
	//    Todo init_en : Registers reset
	.init_en               ( axis_resetn_reg  ),
	.conf_start_addr       ( SLAB1_START_ADDR  ),
	.conf_finish_addr      ( SLAB1_FINISH_ADDR ),
	.conf_sram_start_addr  ( SLAB1_SRAM_START_ADDR  ),
	.conf_sram_finish_addr ( SLAB1_SRAM_FINISH_ADDR ),
	.conf_chunk_size       ( SLAB1_SIZE        )
);

mig2word u_mig2word2 (
	.clk                   ( axis_aclk       ),
	.rst                   ( !axis_resetn    ),

	.get_valid             ( fl2_get_valid   ),
	.del_valid             ( fl2_del_valid   ),
	.din                   ( fl2_din         ),
	//.dout_en               (  ),
	.dout                  ( fl2_dout        ),
	.ovalid                ( fl2_dout_en     ),
	.chunk_size            ( fl2_chunk_size  ),
	// SRAM interfaces
	.sram_din              ( fl2_sram_din    ),
	.sram_din_en           ( fl2_sram_din_en ),
	.sram_addr             ( fl2_sram_addr   ),
	.sram_cmd              ( fl2_sram_cmd    ),
//	.sram_cmd_en           ( fl0_sram_cmd_en ),
	.sram_dout             ( fl2_sram_dout   ),
	.cb_ready              ( fl2_ready       ),
	.cb_rd_en              ( fl2_rd_en       ),
	// Configuration Registers
	//    Todo init_en : Registers reset
	.init_en               ( axis_resetn_reg  ),
	.conf_start_addr       ( SLAB2_START_ADDR  ),
	.conf_finish_addr      ( SLAB2_FINISH_ADDR ),
	.conf_sram_start_addr  ( SLAB2_SRAM_START_ADDR  ),
	.conf_sram_finish_addr ( SLAB2_SRAM_FINISH_ADDR ),
	.conf_chunk_size       ( SLAB2_SIZE        )
);

mig2word u_mig2word3 (
	.clk                   ( axis_aclk       ),
	.rst                   ( !axis_resetn    ),

	.get_valid             ( fl3_get_valid   ),
	.del_valid             ( fl3_del_valid   ),
	.din                   ( fl3_din         ),
	//.dout_en               (  ),
	.dout                  ( fl3_dout        ),
	.ovalid                ( fl3_dout_en     ),
	.chunk_size            ( fl3_chunk_size  ),
	// SRAM interfaces
	.sram_din              ( fl3_sram_din    ),
	.sram_din_en           ( fl3_sram_din_en ),
	.sram_addr             ( fl3_sram_addr   ),
	.sram_cmd              ( fl3_sram_cmd    ),
//	.sram_cmd_en           ( fl3_sram_cmd_en ),
	.sram_dout             ( fl3_sram_dout   ),
	.cb_ready              ( fl3_ready       ),
	.cb_rd_en              ( fl3_rd_en       ),
	// Configuration Registers
	//    Todo init_en : Registers reset
	.init_en               ( axis_resetn_reg  ),
	.conf_start_addr       ( SLAB3_START_ADDR  ),
	.conf_finish_addr      ( SLAB3_FINISH_ADDR ),
	.conf_sram_start_addr  ( SLAB3_SRAM_START_ADDR  ),
	.conf_sram_finish_addr ( SLAB3_SRAM_FINISH_ADDR ),
	.conf_chunk_size       ( SLAB3_SIZE        )
);
/*************************************************************
 * Crossbar Switch
 *************************************************************/

wire cb_empty0, cb_full0;
wire cb_empty1, cb_full1;
wire [143:0] sram_data0, sram_data1;
reg          sram_rd_en0, sram_rd_en1;

wire [143:0] sram_din0, sram_din1;
wire [143:0] sram_dout;
wire         sram_cmd0, sram_cmd_en0;
wire         sram_cmd1, sram_cmd_en1;
wire [19:0]  sram_addr0, sram_addr1;

wire [1:0] dummy2, dummy3;
wire [5:0] grt_0, grt_1, grt_2, grt_3, grt_4, grt_5;
reg  [2:0] port_0, port_1, port_2, port_3, port_4, port_5;

cb u_cb ( 
	.idata_0   ( {2'b00, fl0_sram_dout, fl0_sram_addr, fl0_sram_cmd} ),  
	.ivalid_0  ( fl0_rd_en && fl0_ready), 
	.ivch_0    ( 0 ),
	.port_0    ( port_0 ),
	.req_0     ( fl0_ready ), 
	.grt_0     ( grt_0 ), 
	 
	.odata_0   ( fl0_sram_din    ),  
	.ovalid_0  ( fl0_sram_din_en ), 
	.ovch_0    (),    
	
	.idata_1   ( {2'b01, fl1_sram_dout, fl1_sram_addr, fl1_sram_cmd} ), 
	.ivalid_1  ( fl1_rd_en && fl1_ready ), 
	.ivch_1    ( 0 ), 
	.port_1    ( port_1 ), 
	.req_1     ( fl1_ready ), 
	.grt_1     ( grt_1 ),    
	 
	.odata_1   ( fl1_sram_din    ),  
	.ovalid_1  ( fl1_sram_din_en ), 
	.ovch_1    (),   
	

	.idata_2   ( {2'b10, fl2_sram_dout, fl2_sram_addr, fl2_sram_cmd} ), 
	.ivalid_2  ( fl2_rd_en && fl2_ready ), 
	.ivch_2    ( 0 ), 
	.port_2    ( port_2 ), 
	.req_2     ( fl2_ready ), 
	.grt_2     ( grt_2 ),    
	 
	.odata_2   ( fl2_sram_din    ),  
	.ovalid_2  ( fl2_sram_din_en ), 
	.ovch_2    (),   
	
	.idata_3   ( {2'b11, fl3_sram_dout, fl3_sram_addr, fl3_sram_cmd} ), 
	.ivalid_3  ( fl3_rd_en && fl3_ready ), 
	.ivch_3    ( 0 ), 
	.port_3    ( port_3 ), 
	.req_3     ( fl3_ready ), 
	.grt_3     ( grt_3 ),    
	 
	.odata_3   ( fl3_sram_din    ),  
	.ovalid_3  ( fl3_sram_din_en ), 
	.ovch_3    (),   

	// SRAM Interface0
	.idata_4   ( sram_data0 ),  
	.ivalid_4  ( sram_rd_en0 && !cb_empty0), 
	.ivch_4    ( 0 ),   
	.port_4    ( port_4 ),   
	.req_4     ( !cb_empty0 ),    
	.grt_4     ( grt_4 ),    
	 
	.odata_4   ( {dummy2, sram_din0, sram_addr0, sram_cmd0} ),  
	.ovalid_4  ( sram_cmd_en0 ), 
	.ovch_4    (),

	// SRAM Interface1
	.idata_5   ( sram_data1 ),  
	.ivalid_5  ( sram_rd_en1 && !cb_empty1), 
	.ivch_5    ( 0 ),   
	.port_5    ( port_5 ),   
	.req_5     ( !cb_empty1 ),    
	.grt_5     ( grt_5 ),    
	 
	.odata_5   ( {dummy3, sram_din1, sram_addr1, sram_cmd1} ),  
	.ovalid_5  ( sram_cmd_en1 ), 
	.ovch_5    (),

	.clk       ( axis_aclk    ),
	.rst       ( !axis_resetn )
);

always @ (*) begin
	if (fl0_sram_addr[19])
		port_0 = 5;
	else 
		port_0 = 4;

	if (fl1_sram_addr[19])
		port_1 = 5;
	else 
		port_1 = 4;

	if (fl2_sram_addr[19])
		port_2 = 5;
	else 
		port_2 = 4;

	if (fl3_sram_addr[19])
		port_3 = 5;
	else 
		port_3 = 4;
end

always @ (posedge axis_aclk) begin
	if (!axis_resetn) begin
		fl0_rd_en  = 0;
		fl1_rd_en  = 0;
		fl2_rd_en  = 0;
		fl3_rd_en  = 0;
		sram_rd_en0 = 0;
		sram_rd_en1 = 0;
	end else begin
		if (grt_0 == 6'h10 && fl0_ready)
			fl0_rd_en = 1;
		else 
			fl0_rd_en = 0;
	
		if (grt_1 == 6'h10 && fl1_ready)
			fl1_rd_en = 1;
		else 
			fl1_rd_en = 0;
	
		if (grt_2 == 6'h10 && fl2_ready)
			fl2_rd_en = 1;
		else 
			fl2_rd_en = 0;
	
		if (grt_3 == 6'h10 && fl3_ready)
			fl3_rd_en = 1;
		else 
			fl3_rd_en = 0;
	
		if ((grt_4 == 6'h01 || grt_4 == 6'h02 || grt_4 == 6'h04 || grt_4 == 6'h08) && !cb_empty0)
			sram_rd_en0 = 1;
		else 
			sram_rd_en0 = 0;
	
		if ((grt_5 == 6'h01 || grt_5 == 6'h02 || grt_5 == 6'h04 || grt_5 == 6'h08) && !cb_empty1)
			sram_rd_en1 = 1;
		else 
			sram_rd_en1 = 0;
	end
end
`endif /*REMOVE_SRAM_IMP*/
/*************************************************************
 * Assignment : AXIS BUS
 *************************************************************/
assign m_axis_tvalid = !empty_axis_mig_asfifo2;
assign m_axis_tdata  = {480'h0, alloc_chunk_addr_fifo};
assign m_axis_tkeep  = 64'h0000_0000_0000_000f;
assign m_axis_tuser  = {114'h0, alloc_chunk_size_fifo, 2'h0};
assign m_axis_tdest  = src_node_out[AXIS_DEST_BITS-1:0];
assign m_axis_tlast  = 1'b1;

assign s_axis_tready = 1; // todo: 

wire         glue0_empty, glue1_empty;
wire         glue0_full, glue1_full;
wire [1:0]   sram0_port, sram1_port;
wire [143:0] sram0_din, sram1_din;
wire [19:0]  sram0_addr, sram1_addr;
wire         sram0_cmd, sram1_cmd;
reg [2*20-1:0] port_sel0, port_sel1;
wire [1:0]   port0_cb, port1_cb;
/*************************************************************
 * Assignment : SRAM Interfaces
 *************************************************************/
`ifndef REMOVE_SRAM_IMP
assign c0_app_wr_cmd0  = (!sram0_addr[19]) ? sram0_cmd == SRAM_CMD_WR 
                                             && !glue0_empty : 0;
assign c0_app_wr_addr0 = (!sram0_addr[19]) ? sram0_addr[18:0] : 0;
assign c0_app_rd_cmd0  = (!sram0_addr[19]) ? sram0_cmd == SRAM_CMD_RD
                                             && !glue0_empty : 0;
assign c0_app_rd_addr0 = (!sram0_addr[19]) ? sram0_addr[18:0] : 0;
assign c0_app_wr_data0 = (!sram0_addr[19]) ? sram0_din : 0;

assign c1_app_wr_cmd0  = (sram1_addr[19])  ? sram1_cmd == SRAM_CMD_WR 
                                              && !glue1_empty : 0;
assign c1_app_wr_addr0 = (sram1_addr[19])  ? sram1_addr[18:0] : 0;
assign c1_app_rd_cmd0  = (sram1_addr[19])  ? sram1_cmd == SRAM_CMD_RD
                                              && !glue1_empty : 0;
assign c1_app_rd_addr0 = (sram1_addr[19])  ? sram1_addr[18:0] : 0;
assign c1_app_wr_data0 = (sram1_addr[19])  ? sram1_din : 0;

/*************************************************************
 * SRAM Instances
 *************************************************************/
always @ (posedge c0_clk) begin
	port_sel0 <= {port_sel0[2*19-1:0], sram0_port};
end
always @ (posedge c1_clk) begin
	port_sel1 <= {port_sel1[2*19-1:0], sram1_port};
end

asfifo_167 u_asfifo_cb2sram0 (
	.rst            ( !axis_resetn | c0_rst_clk ),
	.wr_clk         ( axis_aclk                 ),
	.rd_clk         ( c0_clk                    ),
	.din            ( {dummy2, sram_din0, sram_addr0, sram_cmd0}  ), //2, 144, 20, 1 = 167
	.wr_en          ( sram_cmd_en0     ),
	.rd_en          ( !glue0_empty     ),
	.dout           ( {sram0_port, sram0_din, sram0_addr, sram0_cmd} ),
	.full           ( glue0_full       ),
	.empty          ( glue0_empty      ),
	.wr_rst_busy    (),
	.rd_rst_busy    () 
);

asfifo_167 u_asfifo_cb2sram1 (
	.rst            ( !axis_resetn | c1_rst_clk ),
	.wr_clk         ( axis_aclk                 ),
	.rd_clk         ( c1_clk                    ),
	.din            ( {dummy3, sram_din1, sram_addr1, sram_cmd1}  ), //2, 144, 20, 1 = 167
	.wr_en          ( sram_cmd_en1     ),
	.rd_en          ( !glue1_empty     ),
	.dout           ( {sram1_port, sram1_din, sram1_addr, sram1_cmd} ),
	.full           ( glue1_full       ),
	.empty          ( glue1_empty      ),
	.wr_rst_busy    (),
	.rd_rst_busy    () 
);

always @ (*) begin
	port_4 = {1'b0, port0_cb}; // todo
	port_5 = {1'b0, port1_cb}; // todo
end

asfifo_146 u_asfifo_sram02cb (
	.rst            ( !axis_resetn | c0_rst_clk ),
	.wr_clk         ( c0_clk           ),
	.rd_clk         ( axis_aclk        ),
	.din            ( {c0_app_rd_data0, port_sel0[2*20-1:2*19]} ),
	.wr_en          ( c0_app_rd_valid0 ),
	.rd_en          ( sram_rd_en0      ),
	.dout           ( {sram_data0, port0_cb} ),
	.full           ( cb_full0         ),
	.empty          ( cb_empty0        ),
	.wr_rst_busy    (),
	.rd_rst_busy    () 
);

asfifo_146 u_asfifo_sram12cb (
	.rst            ( !axis_resetn | c1_rst_clk ),
	.wr_clk         ( c1_clk           ),
	.rd_clk         ( axis_aclk        ),
	.din            ( {c1_app_rd_data0, port_sel1[2*20-1:2*19]} ),
	.wr_en          ( c1_app_rd_valid0 ),
	.rd_en          ( sram_rd_en1      ),
	.dout           ( {sram_data1, port1_cb} ),
	.full           ( cb_full1         ),
	.empty          ( cb_empty1        ),
	.wr_rst_busy    (),
	.rd_rst_busy    () 
);

sume_mig_sram u_sume_mig_sram (
	// Memory interface ports
	.c0_qdriip_cq_p                     ( c0_qdriip_cq_p         ),
	.c0_qdriip_cq_n                     ( c0_qdriip_cq_n         ),
	.c0_qdriip_q                        ( c0_qdriip_q            ),
	.c0_qdriip_k_p                      ( c0_qdriip_k_p          ),
	.c0_qdriip_k_n                      ( c0_qdriip_k_n          ),
	.c0_qdriip_d                        ( c0_qdriip_d            ),
	.c0_qdriip_sa                       ( c0_qdriip_sa           ),
	.c0_qdriip_w_n                      ( c0_qdriip_w_n          ),
	.c0_qdriip_r_n                      ( c0_qdriip_r_n          ),
	.c0_qdriip_bw_n                     ( c0_qdriip_bw_n         ), 
	.c0_qdriip_dll_off_n                ( c0_qdriip_dll_off_n    ),
	.c0_init_calib_complete             ( c0_init_calib_complete ),
	// Application interface ports
	.c0_app_wr_cmd0                     ( c0_app_wr_cmd0         ),
	.c0_app_wr_addr0                    ( c0_app_wr_addr0        ),
	.c0_app_rd_cmd0                     ( c0_app_rd_cmd0         ),
	.c0_app_rd_addr0                    ( c0_app_rd_addr0        ),
	.c0_app_wr_data0                    ( c0_app_wr_data0        ),
	.c0_app_wr_bw_n0                    ( {C0_BURST_LEN*C0_BW_WIDTH{1'b0}}),
	.c0_app_rd_valid0                   ( c0_app_rd_valid0       ),
	.c0_app_rd_data0                    ( c0_app_rd_data0        ),

	.c0_app_wr_cmd1                     ( 1'd0                   ),
	.c0_app_wr_addr1                    ( 19'd0                  ),
	.c0_app_wr_data1                    ( 144'd0                 ),
	.c0_app_wr_bw_n1                    ( 18'd0                  ),
	.c0_app_rd_cmd1                     ( 1'd0                   ),
	.c0_app_rd_addr1                    ( 19'd0                  ),
	.c0_app_rd_valid1                   (),
	.c0_app_rd_data1                    (),
	// Memory interface ports
	.c1_qdriip_cq_p                     ( c1_qdriip_cq_p         ),
	.c1_qdriip_cq_n                     ( c1_qdriip_cq_n         ),
	.c1_qdriip_q                        ( c1_qdriip_q            ),
	.c1_qdriip_k_p                      ( c1_qdriip_k_p          ),
	.c1_qdriip_k_n                      ( c1_qdriip_k_n          ),
	.c1_qdriip_d                        ( c1_qdriip_d            ),
	.c1_qdriip_sa                       ( c1_qdriip_sa           ),
	.c1_qdriip_w_n                      ( c1_qdriip_w_n          ),
	.c1_qdriip_r_n                      ( c1_qdriip_r_n          ),
	.c1_qdriip_bw_n                     ( c1_qdriip_bw_n         ),
	.c1_qdriip_dll_off_n                ( c1_qdriip_dll_off_n    ),
	.c1_init_calib_complete             ( c1_init_calib_complete ),
	// Application interface ports
	.c1_app_wr_cmd0                     ( c1_app_wr_cmd0         ),
	.c1_app_wr_addr0                    ( c1_app_wr_addr0        ),
	.c1_app_rd_cmd0                     ( c1_app_rd_cmd0         ),
	.c1_app_rd_addr0                    ( c1_app_rd_addr0        ),
	.c1_app_wr_data0                    ( c1_app_wr_data0        ),
	.c1_app_wr_bw_n0                    ( {C1_BURST_LEN*C1_BW_WIDTH{1'b0}}),
	.c1_app_rd_valid0                   ( c1_app_rd_valid0       ),
	.c1_app_rd_data0                    ( c1_app_rd_data0        ),

	.c1_app_wr_cmd1                     ( 1'd0                   ),
	.c1_app_wr_addr1                    ( 19'd0                  ),
	.c1_app_wr_data1                    ( 144'd0                 ),
	.c1_app_wr_bw_n1                    ( 18'd0                  ),
	.c1_app_rd_cmd1                     ( 1'd0                   ),
	.c1_app_rd_addr1                    ( 19'd0                  ),
	.c1_app_rd_valid1                   (),
	.c1_app_rd_data1                    (),

	.c0_clk                             ( c0_clk                 ),
	.c0_rst_clk                         ( c0_rst_clk             ),
	.c1_clk                             ( c1_clk                 ),
	.c1_rst_clk                         ( c1_rst_clk             ),
	// System Clock Ports
	.c0_sys_clk_p                       (c0_sys_clk_p),  // input                                        c1_sys_clk_p
	.c0_sys_clk_n                       (c0_sys_clk_n),  // input                                        c1_sys_clk_n
	.c1_sys_clk_p                       (c1_sys_clk_p),  // input                                        c1_sys_clk_p
	.c1_sys_clk_n                       (c1_sys_clk_n),  // input                                        c1_sys_clk_n
	//.c0_sys_clk_i                       ( c0_sys_clk_i           ),
	//.c1_sys_clk_i                       ( c1_sys_clk_i           ),
	// Reference Clock Ports
	//.clk_ref_i                          ( clk_ref_i              ),
	.sys_rst                            ( sys_rst                )
);

`endif /*REMOVE_SRAM_IMP*/
/*************************************************************
 * DEBUG
 *************************************************************/
reg [31:0] sram0_wrcnt, sram0_rdcnt;
reg [31:0] sram1_wrcnt, sram1_rdcnt;

always @ (posedge axis_aclk) begin
	if (!axis_resetn) begin
		sram_incnt <= 0;
		sram_outcnt <= 0;
	end else begin
		if (s_axis_tvalid && s_axis_tready && s_axis_tlast)
			sram_incnt <= sram_incnt + 1;
		if (m_axis_tvalid && m_axis_tready && m_axis_tlast)
			sram_outcnt <= sram_outcnt + 1;
	end
end

always @ (posedge c0_clk) begin
	if (c0_rst_clk) begin
		sram0_wrcnt <= 0;
		sram0_rdcnt <= 0;
	end else begin
		if (c0_app_wr_cmd0)
			sram0_wrcnt <= sram0_wrcnt + 1;
		if (c0_app_rd_cmd0)
			sram0_rdcnt <= sram0_rdcnt + 1;
	end
end

always @ (posedge c1_clk) begin
	if (c1_rst_clk) begin
		sram1_wrcnt <= 0;
		sram1_rdcnt <= 0;
	end else begin
		if (c1_app_wr_cmd0 )
			sram1_wrcnt <= sram1_wrcnt + 1;
		if (c1_app_rd_cmd0 )
			sram1_rdcnt <= sram1_rdcnt + 1;
	end
end

asfifo_64 u_debug0_fifo (
	.wr_rst_busy ( ),
	.rd_rst_busy ( ),
	.rst      ( !axis_resetn | c0_rst_clk ),
	.wr_clk   ( c0_clk    ),
	.rd_clk   ( axis_aclk     ), 
	.din      ( {sram0_wrcnt, sram0_rdcnt}   ), 
	.wr_en    ( 1'b1 ),
	.rd_en    ( 1'b1 ),
	.dout     ( {sram0_wrcmd, sram0_rdcmd} ), 
	.full     (  ), 
	.empty    (  ) 
);

asfifo_64 u_debug1_fifo (
	.wr_rst_busy ( ),
	.rd_rst_busy ( ),
	.rst      ( !axis_resetn | c1_rst_clk ),
	.wr_clk   ( c1_clk    ),
	.rd_clk   ( axis_aclk     ), 
	.din      ( {sram1_wrcnt, sram1_rdcnt}   ), 
	.wr_en    ( 1'b1 ),
	.rd_en    ( 1'b1 ),
	.dout     ( {sram1_wrcmd, sram1_rdcmd} ), 
	.full     (  ), 
	.empty    (  ) 
);

endmodule

module mig2word (
	input         clk,
	input         rst,
	// 
	input         get_valid,
	input         del_valid,
	input  [31:0] din,
	input         init_en,
	output [31:0] dout,
	output        ovalid,
	output [11:0] chunk_size,
	// Config
	input [31:0]  conf_chunk_size,
	input [31:0]  conf_start_addr,
	input [31:0]  conf_finish_addr,
	input [19:0]  conf_sram_start_addr,
	input [19:0]  conf_sram_finish_addr,
	// SRAM Interface
	input  [143:0] sram_din,
	input          sram_din_en,
	output [ 19:0] sram_addr,
	output         sram_cmd,
//	output         sram_cmd_en,
	output [143:0] sram_dout,
	// Flow controll
	output         cb_ready,
	input          cb_rd_en
);

localparam SRAM_CMD_WR = 1;
localparam SRAM_CMD_RD = 0;

/*************************************************************
 * User Logic
 *************************************************************/
wire empty, full;
wire [143:0] do;

reg [31:0] init_finish_addr;
reg        sram_en;
reg [31:0] start_addr_reg;
reg        init_state;

always @ (posedge clk)
	if (rst) begin
		init_finish_addr <= 32'h0;
		start_addr_reg   <= 32'h0;
		sram_en          <=  1'b0;
		init_state       <=  1'b0;
	end else begin
		if (init_en) begin
			init_finish_addr <= conf_finish_addr;
			start_addr_reg   <= conf_start_addr;
			sram_en          <= 1'b0;
			init_state       <= 1'b1;
		end 
		if (init_state) begin
			if (start_addr_reg == init_finish_addr) begin
				sram_en          <= 1'b1;
			end
		end
		// Stage1 : incremental address for Chunk
		if (get_valid && !sram_en) begin
			start_addr_reg <= start_addr_reg + conf_chunk_size;
		end 	
	end
/*************************************************************
 * FIFO and FIFO cntr
 *************************************************************/
wire sram_valid;
wire ready;
wire wr_en = sram_en && sram_din_en;
wire rd_en = sram_en && !empty && ready;
wire prog_full;

lake_fallthrough_small_fifo #(
	.WIDTH               ( 144 ),
	.MAX_DEPTH_BITS      (   5 ),
	.PROG_FULL_THRESHOLD (  32-24 )
) fifo_chunk0 (
	.din             ( sram_din    ),
	.wr_en           ( wr_en       ),
	.rd_en           ( rd_en       ),  
	.dout            ( do          ),  
	.full            ( full        ),
	.nearly_full     ( ),
	.prog_full       ( prog_full   ),
	.empty           ( empty       ),
	.reset           ( rst         ),
	.clk             ( clk         ) 
);

reg [4:0]   cnt;
reg [143:0] data, next_data;
reg         init_value;
reg         odata_en;
reg         wpol;
reg [15:0]  wtmp;
reg  [31:0] fcnt0, fcnt1, dout_reg;
wire [31:0] dout_wire; 
wire load = fcnt0 != fcnt1 || rd_en;

always @ (posedge clk) 
	if (rst) begin
		cnt  <= 0;
		data <= 0;
		init_value <= 0;
		odata_en   <= 0;
		wpol       <= 0;
		wtmp       <= 0;
		fcnt0      <= 0;
		fcnt1      <= 0;
		dout_reg   <= 0;
	end else begin
		next_data <= do;
		dout_reg  <= dout_wire;
		if (!init_value && !empty) begin
			data       <= do;
			init_value <= 1;
		end
		if (rd_en) begin
			fcnt0 <= fcnt0 + 1;
		end
		if (sram_en && get_valid && load) begin
			if (wpol == 0 && cnt == 4) begin
				fcnt1 <= fcnt1 + 1;
				cnt <= 0;
				data <= {16'h0, next_data[143:16]};
				odata_en <= 1;
				wpol <= 1;
				wtmp <= data[15:0];
			end else if (wpol == 1 && cnt == 3) begin
				fcnt1 <= fcnt1 + 1;
				cnt <= 0;
				data <= next_data;
				wpol <= 0;
				odata_en <= 1;
			end else begin
				odata_en <= 1;
				cnt <= cnt + 1;
				data <= {32'h0, data[143:32]};
			end
		end	else begin
			odata_en <= 0;
		end
	end

assign ready      = cnt == 0 && sram_en && get_valid;
assign dout_wire  = (wpol == 0 && cnt == 4) ? {next_data[15:0], data[15:0]}: data[31:0];
assign dout       = (sram_en) ? (empty ? 32'hffff_ffff : dout_reg) : start_addr_reg;
assign ovalid     = (sram_en) ? (empty ? get_valid : odata_en    ) : get_valid; 
assign chunk_size = conf_chunk_size[11:0];

/*************************************************************
 * GET operation
 *************************************************************/
reg [19:0]  get_sram_addr;
reg         get_cmd_issue;

always @ (posedge clk)
	if (rst) begin
		get_sram_addr    <= 0;
		get_cmd_issue    <= 0;
	end else begin
		if (init_en) begin
			get_sram_addr <= conf_sram_start_addr;
		end
		if (!prog_full && sram_valid && !del_valid && sram_en) begin
			get_cmd_issue <= 1;
			if (get_sram_addr == conf_sram_finish_addr) begin
				get_sram_addr <= conf_sram_start_addr;
			end else begin
				get_sram_addr <= get_sram_addr + 1;
			end
		end else begin
			get_cmd_issue <= 0;
		end
	end

/*************************************************************
 * Delete operation
 *************************************************************/
//
// del_sram_pol : 0: sram[143:128] + sram[127:0]
//                1: sram[143: 16] + sram[ 15:0]
//
reg [31:0]  din_reg;
reg [143:0] del_sram_reg, del_sram_reg_reg;
reg [15 :0] del_sram_tmp_reg;
reg [2  :0] del_sram_cnt;
reg         del_sram_pol;
reg [19:0]  del_sram_addr;
reg         del_cmd_issue;

always @ (posedge clk)
	if (rst) begin
		del_sram_reg     <= 0;
		del_sram_reg_reg <= 0;
		del_sram_tmp_reg <= 0;
		del_sram_cnt     <= 0;
		del_sram_pol     <= 0;
		del_sram_addr    <= 0;
		del_cmd_issue    <= 0;
		din_reg <= 0;
	end else begin
		din_reg <= din;
		del_sram_reg_reg <= del_sram_reg;
		if (init_en) begin
			del_sram_addr <= conf_sram_start_addr;
		end
		if (del_valid) begin
			if (del_sram_cnt == 4) begin
				if (del_sram_pol == 0) begin
					del_sram_reg[143:128] <= din[15: 0];
					del_sram_tmp_reg      <= din[31:16];
				end else begin // del_sram_pol == 1
					del_sram_reg[143:95] <= {16'h0, din};
				end
				del_sram_cnt  <= 0;
				del_cmd_issue <= 1'b1;
				del_sram_pol  <= ~del_sram_pol;
				if (del_sram_addr == conf_sram_finish_addr) begin
					del_sram_addr <= conf_sram_start_addr;
				end else begin
					del_sram_addr <= del_sram_addr + 1;
				end
			end else if (del_sram_cnt == 3 && del_sram_pol) begin
				del_sram_reg <= {din, del_sram_reg[143:48], 
					                               del_sram_tmp_reg};
				del_sram_cnt  <= 0;
				del_cmd_issue <= 1'b1;
				del_sram_pol  <= ~del_sram_pol;
				if (del_sram_addr == conf_sram_finish_addr) begin
					del_sram_addr <= conf_sram_start_addr;
				end else begin
					del_sram_addr <= del_sram_addr + 1;
				end
			end else begin
				del_cmd_issue <= 1'b0;
				del_sram_cnt <= del_sram_cnt + 1;
				if (del_sram_pol == 0) begin
					del_sram_reg <= {16'd0, din, del_sram_reg[127:32]};
				end else begin // del_sram_pol == 1
					del_sram_reg <= {din, del_sram_reg[143:48], 
					                               del_sram_tmp_reg};
				end
			end
		end else begin
				del_cmd_issue <= 1'b0;
		end
	end

/*************************************************************
 * Assignment : SRAM MIG User Interface 
 *************************************************************/
wire         cb_full, cb_empty;
wire [143:0] cb_sram_dout;
wire [19 :0] cb_sram_addr;
wire         cb_sram_cmd;
wire         cb_sram_cmd_en;

assign cb_sram_cmd_en = (del_cmd_issue) || (get_cmd_issue); 
assign cb_sram_cmd    = (del_cmd_issue) ? SRAM_CMD_WR   : 
                        (get_cmd_issue) ? SRAM_CMD_RD   : 0;
assign cb_sram_addr   = (del_cmd_issue) ? del_sram_addr :  
                        (get_cmd_issue) ? get_sram_addr : 0;

assign cb_sram_dout   = (del_cmd_issue && del_sram_pol)  ? del_sram_reg :
                        (del_cmd_issue && !del_sram_pol) ? {din_reg, del_sram_reg_reg[143:48], del_sram_tmp_reg} : 0; // only Delete

//assign sram_valid     = get_sram_addr != del_sram_addr;
assign sram_valid     = get_valid || del_valid;

assign cb_ready       = !cb_empty;


lake_fallthrough_small_fifo #(
	.WIDTH               ( 165 ), // 144 + 20 + 1
	.MAX_DEPTH_BITS      (   3 )
) u_fifo_cb (
	.din             ( {cb_sram_dout, cb_sram_addr, cb_sram_cmd} ),
	.wr_en           ( cb_sram_cmd_en                     ),
	.rd_en           ( cb_rd_en                        ),  
	.dout            ( {sram_dout, sram_addr, sram_cmd} ),  
	.full            ( cb_full                         ),
	.nearly_full     (  ),
	.prog_full       (  ),
	.empty           ( cb_empty                        ),
	.reset           ( rst                             ),
	.clk             ( clk                             ) 
);

endmodule

