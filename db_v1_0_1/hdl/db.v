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
`define INPUT_ARB
`define CLOCK_GATE_ALL

`timescale 1 ps / 100 fs
`include "db_cpu_regs_defines.v"

module db #(
	parameter C_M_AXIS_DATA_WIDTH    = 256,
	parameter C_S_AXIS_DATA_WIDTH    = 256,
	parameter C_M_AXIS_TUSER_WIDTH   = 128,
	parameter C_S_AXIS_TUSER_WIDTH   = 128,
	parameter C_S_AXI_ADDR_WIDTH     = 12,
	parameter C_S_AXI_DATA_WIDTH     = 32,
	parameter C_BASEADDR             = 32'h00000000,
	parameter C_HIGHADDR             = 32'h0,
	parameter SRC_PORT_POS           = 16 ,
	parameter DST_PORT_POS           = 24,
	/* Parameters for DDR3 SDRAM module */
	parameter SIMULATION            = "FALSE",
	parameter TCQ                   = 100,
	parameter DRAM_TYPE             = "DDR3",
	parameter nCK_PER_CLK           = 4,
	parameter RST_ACT_LOW           = 1
) (
`ifndef REMOVE_DRAM_IMP
	/* DDR3 DRAM IO pins */
	inout  [63:0]      ddr3_dq        ,
	inout  [ 7:0]      ddr3_dqs_n     ,
	inout  [ 7:0]      ddr3_dqs_p     ,
	output [15:0]      ddr3_addr      ,
	output [ 2:0]      ddr3_ba        ,
	output             ddr3_ras_n     ,
	output             ddr3_cas_n     ,
	output             ddr3_we_n      ,
	output             ddr3_reset_n   ,
	output [0:0]       ddr3_ck_p      ,
	output [0:0]       ddr3_ck_n      ,
	output [0:0]       ddr3_cke       ,   
	output [0:0]       ddr3_cs_n      ,
	output [7:0]       ddr3_dm        ,
	output [0:0]       ddr3_odt       ,

	input              dram_clk_p     ,
	input              dram_clk_n     ,
`endif /* REMOVE_DRAM_IMP */
`ifndef REMOVE_SRAM_IMP
    /* SRAM A IO pins */
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
    /* SRAM B IO pins */
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

	input              c0_sys_clk_p   ,
	input              c0_sys_clk_n   ,
	input              c1_sys_clk_p   ,
	input              c1_sys_clk_n   ,
`endif /* REMOVE_DRAM_IMP */
	// Global Ports
	input              axis_aclk      ,
	input              axis_resetn    ,
	output [8:0]       debug          ,
	output [1:0]       LED            ,
	// axi lite control/status interface
	// Slave AXI Ports
	input                                     S_AXI_ACLK,
	input                                     S_AXI_ARESETN,
	input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
	input                                     S_AXI_AWVALID,
	input      [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
	input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S_AXI_WSTRB,
	input                                     S_AXI_WVALID,
	input                                     S_AXI_BREADY,
	input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
	input                                     S_AXI_ARVALID,
	input                                     S_AXI_RREADY,
	output                                    S_AXI_ARREADY,
	output     [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
	output     [1 : 0]                        S_AXI_RRESP,
	output                                    S_AXI_RVALID,
	output                                    S_AXI_WREADY,
	output     [1 :0]                         S_AXI_BRESP,
	output                                    S_AXI_BVALID,
	output                                    S_AXI_AWREADY,
	
	// Master Stream Ports (interface to data path)
	output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
	output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
	output             m_axis_tvalid,
	input              m_axis_tready,
	output             m_axis_tlast,
	
	// Slave Stream Ports (interface to RX queues)
	input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
	input              s_axis_tvalid,
	output             s_axis_tready,
	input              s_axis_tlast
);

parameter DEBUG_PORT = "OFF";
parameter STANBY_CNTR = 255;

//
// Reset
//
wire        resetn_sync;
wire [7:0]  reset_soft_wire, reset_soft;
reg [7:0] stanby_cnt;
(* dont_touch = "true" *)reg [7:0] stanby = 0;
(* dont_touch = "true" *)reg [15:0] axis_resetn_reg = 16'hffff;
(* dont_touch = "true" *)reg [15:0] reset_soft_reg  = 16'h0000;
(* dont_touch = "true" *)reg [15:0] resetn_sync_reg  = 16'hffff;

always @ (posedge axis_aclk) begin
	axis_resetn_reg <= (axis_resetn) ? 16'hffff : 16'h0000;
	resetn_sync_reg <= (resetn_sync) ? 16'hffff : 16'h0000;
	reset_soft_reg  <= (reset_soft[0]) ? 16'hffff : 16'h0000;
	stanby          <= (stanby_cnt == STANBY_CNTR) ? 8'h00 : 8'hff;
end

wire axis_aclk_buf;
wire clk_en;
wire dram_en;
wire sram_en;
`ifdef CLOCK_GATE_ALL
BUFGCE BUFGCE_inst (
	.O  ( axis_aclk_buf ),
	.CE ( clk_en        ),
	.I  ( axis_aclk     )
);

`else
assign axis_aclk_buf = axis_aclk;
`endif /*CLOCK_GATE*/



`ifdef TWO_DRAM
wire dram_clk_i;
IBUFDS #(
	.DIFF_TERM    ( "FALSE"  ), 
	.IBUF_LOW_PWR ( "TRUE"   ), // Low power="TRUE", Highest perforrmance="FALSE"
	.IOSTANDARD   ( "DEFAULT") // Specify the input I/O standard
) IBUFDS_inst (
	.O            ( dram_clk_i ), 
	.I            ( dram_clk_p ),  
	.IB           ( dram_clk_n ) 
);
`endif

//
// Wire Declation for registers
//
wire [7:0] cpu2ip_scache_enable_wire;
(* dont_touch = "true" *)reg  [7:0] ip2cpu_scache_enable_reg;
wire [7:0] cpu2ip_clockgate_enable_wire;
(* dont_touch = "true" *)reg  [7:0] ip2cpu_clockgate_enable_reg;
wire [7:0]  cpu2ip_mode_reg;
(* dont_touch = "true" *)reg  [7:0]  ip2cpu_mode_reg;
wire [31:0] cpu2ip_local_ipaddr_reg;
(* dont_touch = "true" *)reg  [31:0] ip2cpu_local_ipaddr_reg;
wire [15:0] cpu2ip_kvs_uport_reg;
(* dont_touch = "true" *) reg  [15:0] ip2cpu_kvs_uport_reg;
wire [7:0] cpu2ip_lakeon_wire;
wire [31:0] queries_l1hit_pe0, queries_l1miss_pe0;
wire [31:0] queries_l1hit_pe1, queries_l1miss_pe1;
wire [31:0] queries_l1hit_pe2, queries_l1miss_pe2;
wire [31:0] queries_l1hit_pe3, queries_l1miss_pe3;
wire [31:0] queries_l1hit_pe4, queries_l1miss_pe4;
wire [31:0] sram0_wrcmd, sram0_rdcmd;
wire [31:0] sram1_wrcmd, sram1_rdcmd;
(* dont_touch = "true" *)reg  [`REG_PEEN_BITS]    pes_enable_reg;

assign clk_en = cpu2ip_lakeon_wire[0];
assign dram_en = cpu2ip_lakeon_wire[1];
assign sram_en = cpu2ip_lakeon_wire[2];


/*
 *  Wire Declation
 */
wire [C_M_AXIS_DATA_WIDTH - 1:0]         pe0_m_axis_tdata;
wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] pe0_m_axis_tkeep;
wire [C_M_AXIS_TUSER_WIDTH-1:0]          pe0_m_axis_tuser;
wire [2:0]                               pe0_m_axis_tdest;
wire                                     pe0_m_axis_tvalid;
wire                                     pe0_m_axis_tready;
wire                                     pe0_m_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH - 1:0]         pe0_s_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] pe0_s_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]          pe0_s_axis_tuser;
wire [2:0]                               pe0_s_axis_tdest;
wire                                     pe0_s_axis_tvalid;
wire                                     pe0_s_axis_tready;
wire                                     pe0_s_axis_tlast;

wire [C_M_AXIS_DATA_WIDTH - 1:0]         pe1_m_axis_tdata;
wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] pe1_m_axis_tkeep;
wire [C_M_AXIS_TUSER_WIDTH-1:0]          pe1_m_axis_tuser;
wire [2:0]                               pe1_m_axis_tdest;
wire                                     pe1_m_axis_tvalid;
wire                                     pe1_m_axis_tready;
wire                                     pe1_m_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH - 1:0]         pe1_s_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] pe1_s_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]          pe1_s_axis_tuser;
wire [2:0]                               pe1_s_axis_tdest;
wire                                     pe1_s_axis_tvalid;
wire                                     pe1_s_axis_tready;
wire                                     pe1_s_axis_tlast;

wire [C_M_AXIS_DATA_WIDTH - 1:0]         pe2_m_axis_tdata;
wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] pe2_m_axis_tkeep;
wire [C_M_AXIS_TUSER_WIDTH-1:0]          pe2_m_axis_tuser;
wire [2:0]                               pe2_m_axis_tdest;
wire                                     pe2_m_axis_tvalid;
wire                                     pe2_m_axis_tready;
wire                                     pe2_m_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH - 1:0]         pe2_s_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] pe2_s_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]          pe2_s_axis_tuser;
wire [2:0]                               pe2_s_axis_tdest;
wire                                     pe2_s_axis_tvalid;
wire                                     pe2_s_axis_tready;
wire                                     pe2_s_axis_tlast;

wire [C_M_AXIS_DATA_WIDTH - 1:0]         pe3_m_axis_tdata;
wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] pe3_m_axis_tkeep;
wire [C_M_AXIS_TUSER_WIDTH-1:0]          pe3_m_axis_tuser;
wire [2:0]                               pe3_m_axis_tdest;
wire                                     pe3_m_axis_tvalid;
wire                                     pe3_m_axis_tready;
wire                                     pe3_m_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH - 1:0]         pe3_s_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] pe3_s_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]          pe3_s_axis_tuser;
wire [2:0]                               pe3_s_axis_tdest;
wire                                     pe3_s_axis_tvalid;
wire                                     pe3_s_axis_tready;
wire                                     pe3_s_axis_tlast;

wire [C_M_AXIS_DATA_WIDTH - 1:0]         pe4_m_axis_tdata;
wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] pe4_m_axis_tkeep;
wire [C_M_AXIS_TUSER_WIDTH-1:0]          pe4_m_axis_tuser;
wire [2:0]                               pe4_m_axis_tdest;
wire                                     pe4_m_axis_tvalid;
wire                                     pe4_m_axis_tready;
wire                                     pe4_m_axis_tlast;

wire [C_S_AXIS_DATA_WIDTH - 1:0]         pe4_s_axis_tdata;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] pe4_s_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]          pe4_s_axis_tuser;
wire [2:0]                               pe4_s_axis_tdest;
wire                                     pe4_s_axis_tvalid;
wire                                     pe4_s_axis_tready;
wire                                     pe4_s_axis_tlast;


wire [511:0]                             dram_m_axis_tdata;
wire [((512 / 8)) - 1:0]                 dram_m_axis_tkeep;
wire [C_M_AXIS_TUSER_WIDTH-1:0]          dram_m_axis_tuser;
wire [2:0]                               dram_m_axis_tdest;
wire                                     dram_m_axis_tvalid;
wire                                     dram_m_axis_tready;
wire                                     dram_m_axis_tlast;

wire [511:0]                             dram_s_axis_tdata;
wire [((512 / 8)) - 1:0]                 dram_s_axis_tkeep;
wire [C_S_AXIS_TUSER_WIDTH-1:0]          dram_s_axis_tuser;
wire [2:0]                               dram_s_axis_tdest;
wire                                     dram_s_axis_tvalid;
wire                                     dram_s_axis_tready;
wire                                     dram_s_axis_tlast;

wire [511:0] pe0mem_m_axis_tdata,  pe0mem_s_axis_tdata;
wire [127:0] pe0mem_m_axis_tuser,  pe0mem_s_axis_tuser;
wire [ 63:0] pe0mem_m_axis_tkeep,  pe0mem_s_axis_tkeep;
wire [  2:0] pe0mem_m_axis_tdest,  pe0mem_s_axis_tdest;
wire         pe0mem_m_axis_tlast,  pe0mem_s_axis_tlast;
wire         pe0mem_m_axis_tvalid, pe0mem_s_axis_tvalid;
wire         pe0mem_m_axis_tready, pe0mem_s_axis_tready;

wire [511:0] pe1mem_m_axis_tdata,  pe1mem_s_axis_tdata;
wire [127:0] pe1mem_m_axis_tuser,  pe1mem_s_axis_tuser;
wire [ 63:0] pe1mem_m_axis_tkeep,  pe1mem_s_axis_tkeep;
wire [  2:0] pe1mem_m_axis_tdest,  pe1mem_s_axis_tdest;
wire         pe1mem_m_axis_tlast,  pe1mem_s_axis_tlast;
wire         pe1mem_m_axis_tvalid, pe1mem_s_axis_tvalid;
wire         pe1mem_m_axis_tready, pe1mem_s_axis_tready;

wire [511:0] pe2mem_m_axis_tdata,  pe2mem_s_axis_tdata;
wire [127:0] pe2mem_m_axis_tuser,  pe2mem_s_axis_tuser;
wire [ 63:0] pe2mem_m_axis_tkeep,  pe2mem_s_axis_tkeep;
wire [  2:0] pe2mem_m_axis_tdest,  pe2mem_s_axis_tdest;
wire         pe2mem_m_axis_tlast,  pe2mem_s_axis_tlast;
wire         pe2mem_m_axis_tvalid, pe2mem_s_axis_tvalid;
wire         pe2mem_m_axis_tready, pe2mem_s_axis_tready;

wire [511:0] pe3mem_m_axis_tdata,  pe3mem_s_axis_tdata;
wire [127:0] pe3mem_m_axis_tuser,  pe3mem_s_axis_tuser;
wire [ 63:0] pe3mem_m_axis_tkeep,  pe3mem_s_axis_tkeep;
wire [  2:0] pe3mem_m_axis_tdest,  pe3mem_s_axis_tdest;
wire         pe3mem_m_axis_tlast,  pe3mem_s_axis_tlast;
wire         pe3mem_m_axis_tvalid, pe3mem_s_axis_tvalid;
wire         pe3mem_m_axis_tready, pe3mem_s_axis_tready;

wire [511:0] pe4mem_m_axis_tdata,  pe4mem_s_axis_tdata;
wire [127:0] pe4mem_m_axis_tuser,  pe4mem_s_axis_tuser;
wire [ 63:0] pe4mem_m_axis_tkeep,  pe4mem_s_axis_tkeep;
wire [  2:0] pe4mem_m_axis_tdest,  pe4mem_s_axis_tdest;
wire         pe4mem_m_axis_tlast,  pe4mem_s_axis_tlast;
wire         pe4mem_m_axis_tvalid, pe4mem_s_axis_tvalid;
wire         pe4mem_m_axis_tready, pe4mem_s_axis_tready;

wire [31:0]  sram_incnt, sram_outcnt;
wire [31:0]  dramA_access, dramA_access_in, dramA_access_out, dramA_read;
wire [31:0]  dramA_scache_all, dramA_scache_hit;
wire [31:0]  dramB_access, dramB_access_in, dramB_access_out, dramB_read;
wire [31:0]  dramB_scache_all, dramB_scache_hit;
wire [31:0]  pe0_pktin , pe1_pktin , pe2_pktin , pe3_pktin , pe4_pktin;
wire [31:0]  pe0_pktout, pe1_pktout, pe2_pktout, pe3_pktout, pe4_pktout;
wire [31:0]  pe0_debug , pe1_debug , pe2_debug , pe3_debug , pe4_debug;
wire [31:0]  pe0_chunk , pe1_chunk , pe2_chunk , pe3_chunk , pe4_chunk;
wire [31:0]  pe0_errpkt, pe1_errpkt, pe2_errpkt, pe3_errpkt, pe4_errpkt;
wire [31:0]  pe0_stat_set_cnt, pe0_stat_get_cnt, pe0_stat_del_cnt;
wire [31:0]  pe1_stat_set_cnt, pe1_stat_get_cnt, pe1_stat_del_cnt;
wire [31:0]  pe2_stat_set_cnt, pe2_stat_get_cnt, pe2_stat_del_cnt;
wire [31:0]  pe3_stat_set_cnt, pe3_stat_get_cnt, pe3_stat_del_cnt;
wire [31:0]  pe4_stat_set_cnt, pe4_stat_get_cnt, pe4_stat_del_cnt;
wire         pe0_enable, pe1_enable, pe2_enable, pe3_enable, pe4_enable;
wire         clk0_en, clk1_en, clk2_en, clk3_en, clk4_en;
wire         active0_ready, active1_ready, active2_ready, active3_ready, active4_ready;
assign       pe0_enable = pes_enable_reg[0];
assign       pe1_enable = pes_enable_reg[1];
assign       pe2_enable = pes_enable_reg[2];
assign       pe3_enable = pes_enable_reg[3];
assign       pe4_enable = pes_enable_reg[4];
// Clock Gating
assign       clk0_en = cpu2ip_clockgate_enable_wire && (stanby[0] || (active0_ready || pe0_s_axis_tdest == 1));
assign       clk1_en = cpu2ip_clockgate_enable_wire && (stanby[1] || (active1_ready || pe1_s_axis_tdest == 2));
assign       clk2_en = cpu2ip_clockgate_enable_wire && (stanby[2] || (active2_ready || pe2_s_axis_tdest == 3));
assign       clk3_en = cpu2ip_clockgate_enable_wire && (stanby[3] || (active3_ready || pe3_s_axis_tdest == 4));
assign       clk4_en = cpu2ip_clockgate_enable_wire && (stanby[4] || (active4_ready || pe4_s_axis_tdest == 5));

/*
 *  DB Processor Element #0
 *     
 */
PE #(
	.C_M_AXIS_TDEST_WIDTH    ( 3 ),
	.C_S_AXIS_TDEST_WIDTH    ( 3 )
) u_pe_0 (
	.axis_aclk        ( axis_aclk_buf   ),
	.axis_resetn      ( axis_resetn_reg[0] && resetn_sync_reg[0] && !reset_soft_reg[0] ),
	// AXI registers
	.config_local_ip_addr ( cpu2ip_local_ipaddr_reg ),
	.config_kvs_uport     ( cpu2ip_kvs_uport_reg    ),
`ifdef CACHE_MODE
	.config_pe_id         ( 8'h3         ),
	.config_mode          ( 8'h0  ),
`else
	.config_pe_id         ( 8'h2         ),
	.config_mode          ( cpu2ip_mode_reg  ),
`endif
	.clk_en               ( clk0_en),
	.active_ready         ( active0_ready ),
	.queries_l1hit        ( queries_l1hit_pe0  ),
	.queries_l1miss       ( queries_l1miss_pe0 ),
	.pktin                ( pe0_pktin  ),
	.pktout               ( pe0_pktout ),
	.error_pkt            ( pe0_errpkt ),
	.debug_table          ( pe0_debug  ),
	.debug_chunk          ( pe0_chunk  ),
	.stat_set_cnt         ( pe0_stat_set_cnt ),
	.stat_get_cnt         ( pe0_stat_get_cnt ),
	.stat_del_cnt         ( pe0_stat_del_cnt ),

	// Master Stream Ports (memory network)
	.mem_m_axis_tdata     ( pe0mem_m_axis_tdata  ),
	.mem_m_axis_tkeep     ( pe0mem_m_axis_tkeep  ),
	.mem_m_axis_tuser     ( pe0mem_m_axis_tuser  ),
	.mem_m_axis_tdest     ( pe0mem_m_axis_tdest  ),
	.mem_m_axis_tvalid    ( pe0mem_m_axis_tvalid ),
	.mem_m_axis_tready    ( pe0mem_m_axis_tready ),
	.mem_m_axis_tlast     ( pe0mem_m_axis_tlast  ),
	
	// Slave Stream Ports (memory network)
	.mem_s_axis_tdata     ( pe0mem_s_axis_tdata  ),
	.mem_s_axis_tkeep     ( pe0mem_s_axis_tkeep  ),
	.mem_s_axis_tuser     ( pe0mem_s_axis_tuser  ),
	.mem_s_axis_tdest     ( pe0mem_s_axis_tdest  ),
	.mem_s_axis_tvalid    ( pe0mem_s_axis_tvalid ),
	.mem_s_axis_tready    ( pe0mem_s_axis_tready ),
	.mem_s_axis_tlast     ( pe0mem_s_axis_tlast  ),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata     ( pe0_m_axis_tdata  ),
	.m_axis_tkeep     ( pe0_m_axis_tkeep  ),
	.m_axis_tuser     ( pe0_m_axis_tuser  ),
	.m_axis_tdest     ( pe0_m_axis_tdest  ),
	.m_axis_tvalid    ( pe0_m_axis_tvalid ),
	.m_axis_tready    ( pe0_m_axis_tready ),
	.m_axis_tlast     ( pe0_m_axis_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata     ( pe0_s_axis_tdata  ),
	.s_axis_tkeep     ( pe0_s_axis_tkeep  ),
	.s_axis_tuser     ( pe0_s_axis_tuser  ),
	.s_axis_tdest     ( pe0_s_axis_tdest  ),
	.s_axis_tvalid    ( pe0_s_axis_tvalid ),
	.s_axis_tready    ( pe0_s_axis_tready ),
	.s_axis_tlast     ( pe0_s_axis_tlast  ) 
);

/*
 *  DB Processor Element #1
 *     
 */
PE #(
	.C_M_AXIS_TDEST_WIDTH    ( 3 ),
	.C_S_AXIS_TDEST_WIDTH    ( 3 )
) u_pe_1 (
	.axis_aclk        ( axis_aclk_buf   ),
	.axis_resetn      ( axis_resetn_reg[1] && resetn_sync_reg[1] && !reset_soft_reg[1] ),
	// AXI registers
	.config_local_ip_addr ( cpu2ip_local_ipaddr_reg ),
	.config_kvs_uport     ( cpu2ip_kvs_uport_reg    ),
`ifdef CACHE_MODE
	.config_pe_id         ( 8'h4         ),
	.config_mode          ( 8'h0  ),
`else
	.config_pe_id         ( 8'h3         ),
	.config_mode          ( cpu2ip_mode_reg  ),
`endif
	.clk_en               ( clk1_en),
	.active_ready         ( active1_ready ),
	.queries_l1hit        ( queries_l1hit_pe1  ),
	.queries_l1miss       ( queries_l1miss_pe1 ),
	.pktin                ( pe1_pktin  ),
	.pktout               ( pe1_pktout ),
	.error_pkt            ( pe1_errpkt ),
	.debug_table          ( pe1_debug  ),
	.debug_chunk          ( pe1_chunk  ),
	.stat_set_cnt         ( pe1_stat_set_cnt ),
	.stat_get_cnt         ( pe1_stat_get_cnt ),
	.stat_del_cnt         ( pe1_stat_del_cnt ),

	// Master Stream Ports (memory network)
	.mem_m_axis_tdata     ( pe1mem_m_axis_tdata  ),
	.mem_m_axis_tkeep     ( pe1mem_m_axis_tkeep  ),
	.mem_m_axis_tuser     ( pe1mem_m_axis_tuser  ),
	.mem_m_axis_tdest     ( pe1mem_m_axis_tdest  ),
	.mem_m_axis_tvalid    ( pe1mem_m_axis_tvalid ),
	.mem_m_axis_tready    ( pe1mem_m_axis_tready ),
	.mem_m_axis_tlast     ( pe1mem_m_axis_tlast  ),
	
	// Slave Stream Ports (memory network)
	.mem_s_axis_tdata     ( pe1mem_s_axis_tdata  ),
	.mem_s_axis_tkeep     ( pe1mem_s_axis_tkeep  ),
	.mem_s_axis_tuser     ( pe1mem_s_axis_tuser  ),
	.mem_s_axis_tdest     ( pe1mem_s_axis_tdest  ),
	.mem_s_axis_tvalid    ( pe1mem_s_axis_tvalid ),
	.mem_s_axis_tready    ( pe1mem_s_axis_tready ),
	.mem_s_axis_tlast     ( pe1mem_s_axis_tlast  ),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata     ( pe1_m_axis_tdata  ),
	.m_axis_tkeep     ( pe1_m_axis_tkeep  ),
	.m_axis_tuser     ( pe1_m_axis_tuser  ),
	.m_axis_tdest     ( pe1_m_axis_tdest  ),
	.m_axis_tvalid    ( pe1_m_axis_tvalid ),
	.m_axis_tready    ( pe1_m_axis_tready ),
	.m_axis_tlast     ( pe1_m_axis_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata     ( pe1_s_axis_tdata  ),
	.s_axis_tkeep     ( pe1_s_axis_tkeep  ),
	.s_axis_tuser     ( pe1_s_axis_tuser  ),
	.s_axis_tdest     ( pe1_s_axis_tdest  ),
	.s_axis_tvalid    ( pe1_s_axis_tvalid ),
	.s_axis_tready    ( pe1_s_axis_tready ),
	.s_axis_tlast     ( pe1_s_axis_tlast  ) 
);

/*
 *  DB Processor Element #2
 *     
 */
PE #(
	.C_M_AXIS_TDEST_WIDTH    ( 3 ),
	.C_S_AXIS_TDEST_WIDTH    ( 3 )
) u_pe_2 (
	.axis_aclk        ( axis_aclk_buf   ),
	.axis_resetn      ( axis_resetn_reg[2] && resetn_sync_reg[2] && !reset_soft_reg[2] ),
	// AXI registers
	.config_local_ip_addr ( cpu2ip_local_ipaddr_reg ),
	.config_kvs_uport     ( cpu2ip_kvs_uport_reg    ),
`ifdef CACHE_MODE
	.config_pe_id         ( 8'h5         ),
	.config_mode          ( 8'h0  ),
`else
	.config_pe_id         ( 8'h4         ),
	.config_mode          ( cpu2ip_mode_reg ),
`endif
	.clk_en               ( clk2_en),
	.active_ready         ( active2_ready ),
	.queries_l1hit        ( queries_l1hit_pe2  ),
	.queries_l1miss       ( queries_l1miss_pe2 ),
	.pktin                ( pe2_pktin  ),
	.pktout               ( pe2_pktout ),
	.error_pkt            ( pe2_errpkt ),
	.debug_table          ( pe2_debug  ),
	.debug_chunk          ( pe2_chunk  ),
	.stat_set_cnt         ( pe2_stat_set_cnt ),
	.stat_get_cnt         ( pe2_stat_get_cnt ),
	.stat_del_cnt         ( pe2_stat_del_cnt ),

	// Master Stream Ports (memory network)
	.mem_m_axis_tdata     ( pe2mem_m_axis_tdata  ),
	.mem_m_axis_tkeep     ( pe2mem_m_axis_tkeep  ),
	.mem_m_axis_tuser     ( pe2mem_m_axis_tuser  ),
	.mem_m_axis_tdest     ( pe2mem_m_axis_tdest  ),
	.mem_m_axis_tvalid    ( pe2mem_m_axis_tvalid ),
	.mem_m_axis_tready    ( pe2mem_m_axis_tready ),
	.mem_m_axis_tlast     ( pe2mem_m_axis_tlast  ),
	
	// Slave Stream Ports (memory network)
	.mem_s_axis_tdata     ( pe2mem_s_axis_tdata  ),
	.mem_s_axis_tkeep     ( pe2mem_s_axis_tkeep  ),
	.mem_s_axis_tuser     ( pe2mem_s_axis_tuser  ),
	.mem_s_axis_tdest     ( pe2mem_s_axis_tdest  ),
	.mem_s_axis_tvalid    ( pe2mem_s_axis_tvalid ),
	.mem_s_axis_tready    ( pe2mem_s_axis_tready ),
	.mem_s_axis_tlast     ( pe2mem_s_axis_tlast  ),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata     ( pe2_m_axis_tdata  ),
	.m_axis_tkeep     ( pe2_m_axis_tkeep  ),
	.m_axis_tuser     ( pe2_m_axis_tuser  ),
	.m_axis_tdest     ( pe2_m_axis_tdest  ),
	.m_axis_tvalid    ( pe2_m_axis_tvalid ),
	.m_axis_tready    ( pe2_m_axis_tready ),
	.m_axis_tlast     ( pe2_m_axis_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata     ( pe2_s_axis_tdata  ),
	.s_axis_tkeep     ( pe2_s_axis_tkeep  ),
	.s_axis_tuser     ( pe2_s_axis_tuser  ),
	.s_axis_tdest     ( pe2_s_axis_tdest  ),
	.s_axis_tvalid    ( pe2_s_axis_tvalid ),
	.s_axis_tready    ( pe2_s_axis_tready ),
	.s_axis_tlast     ( pe2_s_axis_tlast  ) 
);

PE #(
	.C_M_AXIS_TDEST_WIDTH    ( 3 ),
	.C_S_AXIS_TDEST_WIDTH    ( 3 )
) u_pe_3 (
	.axis_aclk        ( axis_aclk_buf   ),
	.axis_resetn      ( axis_resetn_reg[3] && resetn_sync_reg[3] && !reset_soft_reg[3] ),
	// AXI registers
	.config_local_ip_addr ( cpu2ip_local_ipaddr_reg ),
	.config_kvs_uport     ( cpu2ip_kvs_uport_reg    ),
`ifdef CACHE_MODE
	.config_pe_id         ( 8'h6         ),
	.config_mode          ( 8'h0  ),
`else
	.config_pe_id         ( 8'h5         ),
	.config_mode          ( cpu2ip_mode_reg ),
`endif
	.clk_en               ( clk3_en),
	.active_ready         ( active3_ready ),
	.queries_l1hit        ( queries_l1hit_pe3  ),
	.queries_l1miss       ( queries_l1miss_pe3 ),
	.pktin                ( pe3_pktin  ),
	.pktout               ( pe3_pktout ),
	.error_pkt            ( pe3_errpkt ),
	.debug_table          ( pe3_debug  ),
	.debug_chunk          ( pe3_chunk  ),
	.stat_set_cnt         ( pe3_stat_set_cnt ),
	.stat_get_cnt         ( pe3_stat_get_cnt ),
	.stat_del_cnt         ( pe3_stat_del_cnt ),

	// Master Stream Ports (memory network)
	.mem_m_axis_tdata     ( pe3mem_m_axis_tdata  ),
	.mem_m_axis_tkeep     ( pe3mem_m_axis_tkeep  ),
	.mem_m_axis_tuser     ( pe3mem_m_axis_tuser  ),
	.mem_m_axis_tdest     ( pe3mem_m_axis_tdest  ),
	.mem_m_axis_tvalid    ( pe3mem_m_axis_tvalid ),
	.mem_m_axis_tready    ( pe3mem_m_axis_tready ),
	.mem_m_axis_tlast     ( pe3mem_m_axis_tlast  ),
	
	// Slave Stream Ports (memory network)
	.mem_s_axis_tdata     ( pe3mem_s_axis_tdata  ),
	.mem_s_axis_tkeep     ( pe3mem_s_axis_tkeep  ),
	.mem_s_axis_tuser     ( pe3mem_s_axis_tuser  ),
	.mem_s_axis_tdest     ( pe3mem_s_axis_tdest  ),
	.mem_s_axis_tvalid    ( pe3mem_s_axis_tvalid ),
	.mem_s_axis_tready    ( pe3mem_s_axis_tready ),
	.mem_s_axis_tlast     ( pe3mem_s_axis_tlast  ),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata     ( pe3_m_axis_tdata  ),
	.m_axis_tkeep     ( pe3_m_axis_tkeep  ),
	.m_axis_tuser     ( pe3_m_axis_tuser  ),
	.m_axis_tdest     ( pe3_m_axis_tdest  ),
	.m_axis_tvalid    ( pe3_m_axis_tvalid ),
	.m_axis_tready    ( pe3_m_axis_tready ),
	.m_axis_tlast     ( pe3_m_axis_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata     ( pe3_s_axis_tdata  ),
	.s_axis_tkeep     ( pe3_s_axis_tkeep  ),
	.s_axis_tuser     ( pe3_s_axis_tuser  ),
	.s_axis_tdest     ( pe3_s_axis_tdest  ),
	.s_axis_tvalid    ( pe3_s_axis_tvalid ),
	.s_axis_tready    ( pe3_s_axis_tready ),
	.s_axis_tlast     ( pe3_s_axis_tlast  ) 
);

PE #(
	.C_M_AXIS_TDEST_WIDTH    ( 3 ),
	.C_S_AXIS_TDEST_WIDTH    ( 3 )
) u_pe_4 (
	.axis_aclk        ( axis_aclk_buf   ),
	.axis_resetn      ( axis_resetn_reg[4] && resetn_sync_reg[4] && !reset_soft_reg[4] ),
	// AXI registers
	.config_local_ip_addr ( cpu2ip_local_ipaddr_reg ),
	.config_kvs_uport     ( cpu2ip_kvs_uport_reg    ),
`ifdef CACHE_MODE
	.config_pe_id         ( 8'h7         ),
	.config_mode          ( 8'h0  ),
`else
	.config_pe_id         ( 8'h6         ),
	.config_mode          ( cpu2ip_mode_reg ),
`endif
	.clk_en               ( clk4_en),
	.active_ready         ( active4_ready ),
	.queries_l1hit        ( queries_l1hit_pe4  ),
	.queries_l1miss       ( queries_l1miss_pe4 ),
	.pktin                ( pe4_pktin  ),
	.pktout               ( pe4_pktout ),
	.error_pkt            ( pe4_errpkt ),
	.debug_table          ( pe4_debug  ),
	.debug_chunk          ( pe4_chunk  ),
	.stat_set_cnt         ( pe4_stat_set_cnt ),
	.stat_get_cnt         ( pe4_stat_get_cnt ),
	.stat_del_cnt         ( pe4_stat_del_cnt ),

	// Master Stream Ports (memory network)
	.mem_m_axis_tdata     ( pe4mem_m_axis_tdata  ),
	.mem_m_axis_tkeep     ( pe4mem_m_axis_tkeep  ),
	.mem_m_axis_tuser     ( pe4mem_m_axis_tuser  ),
	.mem_m_axis_tdest     ( pe4mem_m_axis_tdest  ),
	.mem_m_axis_tvalid    ( pe4mem_m_axis_tvalid ),
	.mem_m_axis_tready    ( pe4mem_m_axis_tready ),
	.mem_m_axis_tlast     ( pe4mem_m_axis_tlast  ),
	
	// Slave Stream Ports (memory network)
	.mem_s_axis_tdata     ( pe4mem_s_axis_tdata  ),
	.mem_s_axis_tkeep     ( pe4mem_s_axis_tkeep  ),
	.mem_s_axis_tuser     ( pe4mem_s_axis_tuser  ),
	.mem_s_axis_tdest     ( pe4mem_s_axis_tdest  ),
	.mem_s_axis_tvalid    ( pe4mem_s_axis_tvalid ),
	.mem_s_axis_tready    ( pe4mem_s_axis_tready ),
	.mem_s_axis_tlast     ( pe4mem_s_axis_tlast  ),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata     ( pe4_m_axis_tdata  ),
	.m_axis_tkeep     ( pe4_m_axis_tkeep  ),
	.m_axis_tuser     ( pe4_m_axis_tuser  ),
	.m_axis_tdest     ( pe4_m_axis_tdest  ),
	.m_axis_tvalid    ( pe4_m_axis_tvalid ),
	.m_axis_tready    ( pe4_m_axis_tready ),
	.m_axis_tlast     ( pe4_m_axis_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata     ( pe4_s_axis_tdata  ),
	.s_axis_tkeep     ( pe4_s_axis_tkeep  ),
	.s_axis_tuser     ( pe4_s_axis_tuser  ),
	.s_axis_tdest     ( pe4_s_axis_tdest  ),
	.s_axis_tvalid    ( pe4_s_axis_tvalid ),
	.s_axis_tready    ( pe4_s_axis_tready ),
	.s_axis_tlast     ( pe4_s_axis_tlast  ) 
);
/*
 *  Memory Controller
 *     MIG (DDR3 SDRAM 4GB) + Glue Logic
 */

wire dramA_init_calib, dramB_init_calib, sram_init_calib;
//wire dram_resetn = (axis_resetn_reg[6] && resetn_sync_reg[5] && !reset_soft_reg[5] 
dram_cont #(
	.C_M_AXIS_DATA_WIDTH    ( 512 ),
	.C_S_AXIS_DATA_WIDTH    ( 512 ),
	.C_M_AXIS_TUSER_WIDTH   ( 128 ),
	.C_S_AXIS_TUSER_WIDTH   ( 128 ),
	.C_M_AXIS_TDEST_WIDTH   ( 3 ),
	.C_S_AXIS_TDEST_WIDTH   ( 3 )
) u_dram_cont (
`ifndef REMOVE_DRAM_IMP
	/* DDR3 SDRAM pins*/
	.ddr3_dq                ( ddr3_dq      ),
	.ddr3_dqs_n             ( ddr3_dqs_n   ),
	.ddr3_dqs_p             ( ddr3_dqs_p   ),
	.ddr3_addr              ( ddr3_addr    ),
	.ddr3_ba                ( ddr3_ba      ),
	.ddr3_ras_n             ( ddr3_ras_n   ),
	.ddr3_cas_n             ( ddr3_cas_n   ),
	.ddr3_we_n              ( ddr3_we_n    ),
	.ddr3_reset_n           ( ddr3_reset_n ),
	.ddr3_ck_p              ( ddr3_ck_p    ),
	.ddr3_ck_n              ( ddr3_ck_n    ),
	.ddr3_cke               ( ddr3_cke     ),
	.ddr3_cs_n              ( ddr3_cs_n    ),
	.ddr3_dm                ( ddr3_dm      ),
	.ddr3_odt               ( ddr3_odt     ),

`ifdef TWO_DRAM
	.dram_clk_i             ( dram_clk_i ),
`else
	.dram_clk_p             ( dram_clk_p ),
	.dram_clk_n             ( dram_clk_n ),
`endif
`endif /*REMOVE_DRAM_IMP*/
	/* General pins */
	.sys_rst                ( axis_resetn_reg[5] && dram_en ),
	.config_dram_node       ( 8'd0 ),
	.init_calib_complete    ( dramA_init_calib ),
	.dram_access            ( dramA_access ),
	.dram_read              ( dramA_read ),
	.access_in              ( dramA_access_in ),
	.access_out             ( dramA_access_out ),
	.scache_all             ( dramA_scache_all ),
	.scache_hit             ( dramA_scache_hit ),
	.cache_enable           ( cpu2ip_scache_enable_wire[0] ),
	.axis_aclk              ( axis_aclk_buf   ),
	.axis_resetn            ( axis_resetn_reg[6] && resetn_sync_reg[5] && !reset_soft_reg[5]),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata           ( dram_m_axis_tdata ),
	.m_axis_tkeep           ( dram_m_axis_tkeep ),
	.m_axis_tuser           ( dram_m_axis_tuser ),
	.m_axis_tdest           ( dram_m_axis_tdest ),
	.m_axis_tvalid          ( dram_m_axis_tvalid),
	.m_axis_tready          ( dram_m_axis_tready),
	.m_axis_tlast           ( dram_m_axis_tlast ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata           ( dram_s_axis_tdata ),
	.s_axis_tkeep           ( dram_s_axis_tkeep ),
	.s_axis_tuser           ( dram_s_axis_tuser ),
	.s_axis_tdest           ( dram_s_axis_tdest ),
	.s_axis_tvalid          ( dram_s_axis_tvalid),
	.s_axis_tready          ( dram_s_axis_tready),
	.s_axis_tlast           ( dram_s_axis_tlast )
);

`ifdef TWO_DRAM_ADD
dram_cont #(
	.C_M_AXIS_DATA_WIDTH    ( 512 ),
	.C_S_AXIS_DATA_WIDTH    ( 512 ),
	.C_M_AXIS_TUSER_WIDTH   ( 128 ),
	.C_S_AXIS_TUSER_WIDTH   ( 128 ),
	.C_M_AXIS_TDEST_WIDTH   ( 3 ),
	.C_S_AXIS_TDEST_WIDTH   ( 3 )
) u_dramB_cont (
`ifndef REMOVE_DRAM_IMP
	/* DDR3 SDRAM pins*/
	.ddr3_dq                ( ddr3B_dq      ),
	.ddr3_dqs_n             ( ddr3B_dqs_n   ),
	.ddr3_dqs_p             ( ddr3B_dqs_p   ),
	.ddr3_addr              ( ddr3B_addr    ),
	.ddr3_ba                ( ddr3B_ba      ),
	.ddr3_ras_n             ( ddr3B_ras_n   ),
	.ddr3_cas_n             ( ddr3B_cas_n   ),
	.ddr3_we_n              ( ddr3B_we_n    ),
	.ddr3_reset_n           ( ddr3B_reset_n ),
	.ddr3_ck_p              ( ddr3B_ck_p    ),
	.ddr3_ck_n              ( ddr3B_ck_n    ),
	.ddr3_cke               ( ddr3B_cke     ),
	.ddr3_cs_n              ( ddr3B_cs_n    ),
	.ddr3_dm                ( ddr3B_dm      ),
	.ddr3_odt               ( ddr3B_odt     ),

`ifdef TWO_DRAM
	.dram_clk_i             ( dram_clk_i ),
`else
	.dram_clk_p             ( dram_clk_p ),
	.dram_clk_n             ( dram_clk_n ),
`endif
`endif /*REMOVE_DRAM_IMP*/
	/* General pins */
	.sys_rst                ( axis_resetn_reg[5] ),
	.config_dram_node       ( 8'd0 ),
	.init_calib_complete    ( dramB_init_calib ),
	.dram_access            ( dramB_access ),
	.dram_read              ( dramB_read ),
	.access_in              ( dramB_access_in ),
	.access_out             ( dramB_access_out ),
	.scache_all             ( dramB_scache_all ),
	.scache_hit             ( dramB_scache_hit ),
	.cache_enable           ( cpu2ip_scache_enable_wire[0] ),
	.axis_aclk              ( axis_aclk_buf   ),
	.axis_resetn            ( axis_resetn_reg[6] && resetn_sync_reg[5] && !reset_soft_reg[5] ),

	// Master Stream Ports (interface to data path)
	.m_axis_tdata           ( dram_m_axis_tdata ),
	.m_axis_tkeep           ( dram_m_axis_tkeep ),
	.m_axis_tuser           ( dram_m_axis_tuser ),
	.m_axis_tdest           ( dram_m_axis_tdest ),
	.m_axis_tvalid          ( dram_m_axis_tvalid),
	.m_axis_tready          ( dram_m_axis_tready),
	.m_axis_tlast           ( dram_m_axis_tlast ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata           ( dram_s_axis_tdata ),
	.s_axis_tkeep           ( dram_s_axis_tkeep ),
	.s_axis_tuser           ( dram_s_axis_tuser ),
	.s_axis_tdest           ( dram_s_axis_tdest ),
	.s_axis_tvalid          ( dram_s_axis_tvalid),
	.s_axis_tready          ( dram_s_axis_tready),
	.s_axis_tlast           ( dram_s_axis_tlast )
);
`endif /*TWO_DRAM_ADD*/

wire [511:0] sram_m_axis_tdata, sram_s_axis_tdata;
wire [127:0] sram_m_axis_tuser, sram_s_axis_tuser;
wire [ 63:0] sram_m_axis_tkeep, sram_s_axis_tkeep;
wire [  2:0] sram_m_axis_tdest, sram_s_axis_tdest;
wire         sram_m_axis_tlast, sram_s_axis_tlast;
wire         sram_m_axis_tvalid, sram_s_axis_tvalid;
wire         sram_m_axis_tready, sram_s_axis_tready;

sram_cont #(
//***********************************************************
// Simulation parameters
//***********************************************************
`ifndef REMOVE_SRAM_IMP
	.C0_SIMULATION            (SIMULATION), // "TRUE" or "FALSE"
	.C1_SIMULATION            (SIMULATION)
`endif
) u_sram_cont (
	.axis_aclk                ( axis_aclk_buf   ),
	.axis_resetn              ( axis_resetn_reg[7] && resetn_sync_reg[6] && !reset_soft_reg[6]),
	// Master Stream Ports (interface to data path)
	.m_axis_tdata             ( sram_m_axis_tdata  ),
	.m_axis_tkeep             ( sram_m_axis_tkeep  ),
	.m_axis_tuser             ( sram_m_axis_tuser  ),
	.m_axis_tdest             ( sram_m_axis_tdest  ),
	.m_axis_tvalid            ( sram_m_axis_tvalid ),
	.m_axis_tready            ( sram_m_axis_tready ),
	.m_axis_tlast             ( sram_m_axis_tlast  ),
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata             ( sram_s_axis_tdata  ),
	.s_axis_tkeep             ( sram_s_axis_tkeep  ),
	.s_axis_tuser             ( sram_s_axis_tuser  ),
	.s_axis_tdest             ( sram_s_axis_tdest  ),
	.s_axis_tvalid            ( sram_s_axis_tvalid ),
	.s_axis_tready            ( sram_s_axis_tready ),
	.s_axis_tlast             ( sram_s_axis_tlast  ),
	// Debug Port
	.sram0_wrcmd              ( sram0_wrcmd ),
	.sram0_rdcmd              ( sram0_rdcmd ),
	.sram1_wrcmd              ( sram1_wrcmd ),
	.sram1_rdcmd              ( sram1_rdcmd ),
	.sram_incnt               ( sram_incnt  ),
	.sram_outcnt              ( sram_outcnt ),
//Memory Interface
`ifndef REMOVE_SRAM_IMP
	.c0_qdriip_cq_p           ( c0_qdriip_cq_p      ),    
	.c0_qdriip_cq_n           ( c0_qdriip_cq_n      ),
	.c0_qdriip_q              ( c0_qdriip_q         ),
	.c0_qdriip_k_p            ( c0_qdriip_k_p       ),
	.c0_qdriip_k_n            ( c0_qdriip_k_n       ),
	.c0_qdriip_d              ( c0_qdriip_d         ),
	.c0_qdriip_sa             ( c0_qdriip_sa        ),
	.c0_qdriip_w_n            ( c0_qdriip_w_n       ),
	.c0_qdriip_r_n            ( c0_qdriip_r_n       ),
	.c0_qdriip_bw_n           ( c0_qdriip_bw_n      ),
	.c0_qdriip_dll_off_n      ( c0_qdriip_dll_off_n ),
//Memory Interface
	.c1_qdriip_cq_p           ( c1_qdriip_cq_p      ), 
	.c1_qdriip_cq_n           ( c1_qdriip_cq_n      ),
	.c1_qdriip_q              ( c1_qdriip_q         ),
	.c1_qdriip_k_p            ( c1_qdriip_k_p       ),
	.c1_qdriip_k_n            ( c1_qdriip_k_n       ),
	.c1_qdriip_d              ( c1_qdriip_d         ),
	.c1_qdriip_sa             ( c1_qdriip_sa        ),
	.c1_qdriip_w_n            ( c1_qdriip_w_n       ),
	.c1_qdriip_r_n            ( c1_qdriip_r_n       ),
	.c1_qdriip_bw_n           ( c1_qdriip_bw_n      ),
	.c1_qdriip_dll_off_n      ( c1_qdriip_dll_off_n ),
// Single-ended system clock
	.init_calib_complete      ( sram_init_calib ),
	.c0_sys_clk_p             (c0_sys_clk_p), 
	.c0_sys_clk_n             (c0_sys_clk_n), 
	.c1_sys_clk_p             (c1_sys_clk_p), 
	.c1_sys_clk_n             (c1_sys_clk_n), 
`endif /*REMOVE_SRAM_IMP*/
// System reset - Default polarity of sys_rst pin is Active Low.
// System reset polarity will change based on the option 
// selected in GUI.
	.sys_rst                  ( !axis_resetn_reg[8] || !sram_en )
); 

wire [ 31:0] lut_access_in,    lut_access_out;
wire [511:0] lut_m_axis_tdata, lut_s_axis_tdata;
wire [127:0] lut_m_axis_tuser, lut_s_axis_tuser;
wire [ 63:0] lut_m_axis_tkeep, lut_s_axis_tkeep;
wire [  2:0] lut_m_axis_tdest, lut_s_axis_tdest;
wire         lut_m_axis_tlast, lut_s_axis_tlast;
wire         lut_m_axis_tvalid, lut_s_axis_tvalid;
wire         lut_m_axis_tready, lut_s_axis_tready;

key_lookup u_key_lookup (
	.config_lut_node( 8'h02 ),
	.access_in      ( lut_access_in  ),
	.access_out     ( lut_access_out ),
	.axis_aclk      ( axis_aclk_buf ),
	.axis_resetn    ( axis_resetn_reg[9] && resetn_sync_reg[6] && !reset_soft_reg[6] ),
	// Master Stream Ports (interface to data path)
	.m_axis_tdata   ( lut_m_axis_tdata  ),
	.m_axis_tkeep   ( lut_m_axis_tkeep  ),
	.m_axis_tuser   ( lut_m_axis_tuser  ),
	.m_axis_tdest   ( lut_m_axis_tdest  ),
	.m_axis_tvalid  ( lut_m_axis_tvalid ),
	.m_axis_tready  ( lut_m_axis_tready ),
	.m_axis_tlast   ( lut_m_axis_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata   ( lut_s_axis_tdata  ),
	.s_axis_tkeep   ( lut_s_axis_tkeep  ),
	.s_axis_tuser   ( lut_s_axis_tuser  ),
	.s_axis_tdest   ( lut_s_axis_tdest  ),
	.s_axis_tvalid  ( lut_s_axis_tvalid ),
	.s_axis_tready  ( lut_s_axis_tready ),
	.s_axis_tlast   ( lut_s_axis_tlast  ) 
);

/*
 *  PE-Network AXI Stream-based Switch
 *    Port0 : Network Data Path 
 *    Port1 : PE0
 *    Port2 : PE1
 *    Port3 : PE2
 */
	// Slave Stream Ports (interface to RX queues)
wire [2:0] s_axis_tdest, m_axis_tdest; // not used;
reg  [2:0] s_axis_tdest_next, s_axis_tdest_reg, roundrobin_arb, prev_tdest, prev_tdest_next;
wire [4:0] axis_s_decode_err;
reg  stop_next, stop_reg;
reg  s_axis_tlast_buf_reg;
wire [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_tdata_buf;
wire [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep_buf;
wire [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_tuser_buf;
wire                                     s_axis_tvalid_buf;
wire                                     s_axis_tready_buf;
wire                                     s_axis_tlast_buf;
wire in_fifo_empty, in_fifo_full, in_fifo_nearly_full;
wire stop;
wire in_fifo_rd_en = !in_fifo_empty && s_axis_tready_buf && ((pe0_s_axis_tready && pe0_enable) || (pe1_s_axis_tready && pe1_enable) || (pe2_s_axis_tready && pe2_enable) || (pe3_s_axis_tready && pe3_enable) || (pe4_s_axis_tready && pe4_enable)) && !stop;
assign s_axis_tready = !in_fifo_nearly_full;
assign s_axis_tvalid_buf = !in_fifo_empty && s_axis_tready_buf && ((pe0_s_axis_tready && pe0_enable) || (pe1_s_axis_tready && pe1_enable) || (pe2_s_axis_tready && pe2_enable) || (pe3_s_axis_tready && pe3_enable) || (pe4_s_axis_tready && pe4_enable)) && !stop;
assign stop = (s_axis_tlast_buf_reg && (pe0_s_axis_tready && pe0_enable) && prev_tdest != 1) ? 1'b0 :
              (s_axis_tlast_buf_reg && (pe1_s_axis_tready && pe1_enable) && prev_tdest != 2) ? 1'b0 :
              (s_axis_tlast_buf_reg && (pe2_s_axis_tready && pe2_enable) && prev_tdest != 3) ? 1'b0 :
              (s_axis_tlast_buf_reg && (pe3_s_axis_tready && pe3_enable) && prev_tdest != 4) ? 1'b0 :
              (s_axis_tlast_buf_reg && (pe4_s_axis_tready && pe4_enable) && prev_tdest != 5) ? 1'b0 :
              (s_axis_tlast_buf_reg) ? 1'b1 : stop_reg;

lake_fallthrough_small_fifo #(
	.WIDTH           (C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8+1),
	.MAX_DEPTH_BITS  (2)
) u_input_fifo (
	.din           ({s_axis_tlast, s_axis_tuser, 
	                         s_axis_tkeep, s_axis_tdata}),
	.wr_en         ( s_axis_tready && s_axis_tvalid && ~in_fifo_nearly_full ),
	.rd_en         ( in_fifo_rd_en  ),

	.dout          ({s_axis_tlast_buf, s_axis_tuser_buf, 
	                         s_axis_tkeep_buf, s_axis_tdata_buf}),
	.full          ( in_fifo_full        ),
	.nearly_full   ( in_fifo_nearly_full ),
	.prog_full     (),
	.empty         ( in_fifo_empty  ),

	.reset         ( !axis_resetn ),
	.clk           ( axis_aclk_buf     )
);

always @ (*) begin
	s_axis_tdest_next = s_axis_tdest_reg;
	stop_next = stop_reg;
	prev_tdest_next = s_axis_tdest;
	if (s_axis_tready_buf && s_axis_tlast_buf && s_axis_tvalid_buf) begin
			s_axis_tdest_next = 0;
	end
	if (s_axis_tvalid_buf && !s_axis_tlast_buf && (s_axis_tdest_reg == 0 || s_axis_tlast_buf_reg)) begin
		if (pe0_s_axis_tready && pe0_enable && prev_tdest != 1) begin
			s_axis_tdest_next = 1;
			stop_next = 0;
		end else if (pe1_s_axis_tready && pe1_enable && prev_tdest != 2) begin
			s_axis_tdest_next = 2;
			stop_next = 0;
		end else if (pe2_s_axis_tready && pe2_enable && prev_tdest != 3) begin
			s_axis_tdest_next = 3;
			stop_next = 0;
		end else if (pe3_s_axis_tready && pe3_enable && prev_tdest != 4) begin
			s_axis_tdest_next = 4;
			stop_next = 0;
		end else if (pe4_s_axis_tready && pe4_enable && prev_tdest != 5) begin
			s_axis_tdest_next = 5;
			stop_next = 0;
		end else begin
			stop_next = 1;
			//s_axis_tdest_next = roundrobin_arb;
		end
	end
end


always @ (posedge axis_aclk_buf)
	if (!axis_resetn_reg[10] | !resetn_sync_reg[7] | reset_soft_reg[7]) begin
		s_axis_tdest_reg <= 0;
		//roundrobin_arb   <= 1;
		stop_reg <= 0;
		s_axis_tlast_buf_reg <= 0;
		prev_tdest <= 0;
	end else begin
		prev_tdest <= s_axis_tdest;
		s_axis_tdest_reg <= s_axis_tdest_next;
		stop_reg <= stop_next;
		s_axis_tlast_buf_reg <= s_axis_tlast_buf && s_axis_tvalid_buf && s_axis_tready_buf;
		//if (s_axis_tvalid_buf && !s_axis_tlast_buf && s_axis_tdest_reg == 2'b00 && 
		//	!pe0_s_axis_tready && !pe1_s_axis_tready && !pe2_s_axis_tready) begin
		//	if (roundrobin_arb == 3)
		//		roundrobin_arb   <= 0;
		//	else 
		//		roundrobin_arb   <= roundrobin_arb + 1;
		//end
	end
assign s_axis_tdest = (s_axis_tready_buf && s_axis_tlast_buf && s_axis_tvalid_buf) ? s_axis_tdest_reg : s_axis_tdest_next;


wire dummy_m_tvalid, dummy_m_tlast;
wire [2:0] dummy_m_tdest;
wire [255:0] dummy_m_tdata;
wire [127:0] dummy_m_tuser;
wire [31:0] dummy_m_tkeep;
wire         dummy_s0_tvalid;
wire         dummy_s0_tlast;
wire [2:0]   dummy_s0_tdest;
wire [255:0] dummy_s0_tdata;
wire [127:0] dummy_s0_tuser;
wire [31:0]  dummy_s0_tkeep;
wire         dummy_s1_tvalid;
wire         dummy_s1_tlast;
wire [2:0]   dummy_s1_tdest;
wire [255:0] dummy_s1_tdata;
wire [127:0] dummy_s1_tuser;
wire [31:0]  dummy_s1_tkeep;
wire         dummy_s2_tvalid;
wire         dummy_s2_tlast;
wire [2:0]   dummy_s2_tdest;
wire [255:0] dummy_s2_tdata;
wire [127:0] dummy_s2_tuser;
wire [31:0]  dummy_s2_tkeep;
wire         dummy_s3_tvalid;
wire         dummy_s3_tlast;
wire [2:0]   dummy_s3_tdest;
wire [255:0] dummy_s3_tdata;
wire [127:0] dummy_s3_tuser;
wire [31:0]  dummy_s3_tkeep;
wire         dummy_s4_tvalid;
wire         dummy_s4_tlast;
wire [2:0]   dummy_s4_tdest;
wire [255:0] dummy_s4_tdata;
wire [127:0] dummy_s4_tuser;
wire [31:0]  dummy_s4_tkeep;
wire dummy_s_axis_readya;
wire [4:0] dummy_s_axis_readyb;

axis_switch_0 u_tx_axis_switch (
	.aclk              ( axis_aclk_buf ),
	.aresetn           ( axis_resetn_reg[8] && resetn_sync_reg[6] && !reset_soft_reg[6] ),
	.s_axis_tready     ({ dummy_s_axis_readyb, s_axis_tready_buf }),
	.m_axis_tready     ({ pe4_s_axis_tready, pe3_s_axis_tready,pe2_s_axis_tready, pe1_s_axis_tready, pe0_s_axis_tready, 1'b0 }),
	.s_axis_tvalid     ({ 1'b0  , 1'b0  , 1'b0  , 1'b0  , 1'b0   , s_axis_tvalid_buf }),
	.s_axis_tdata      ({ 256'd0, 256'd0, 256'd0, 256'd0, 256'd0 , s_axis_tdata_buf  }),
	.s_axis_tkeep      ({ 32'd0 , 32'd0 , 32'd0 , 32'd0 , 32'd0  , s_axis_tkeep_buf  }),
	.s_axis_tlast      ({ 1'b0  , 1'b0  , 1'b0  , 1'b0  , 1'b0   , s_axis_tlast_buf  }),
	.s_axis_tdest      ({ 3'd0  , 3'd0  , 3'd0  , 3'd0  , 3'd0   , s_axis_tdest  }),
	.s_axis_tuser      ({ 128'd0, 128'd0, 128'd0, 128'd0, 128'd0 , s_axis_tuser_buf  }),
	.m_axis_tvalid     ({ pe4_s_axis_tvalid, pe3_s_axis_tvalid, pe2_s_axis_tvalid, pe1_s_axis_tvalid, pe0_s_axis_tvalid, dummy_m_tvalid }),
	.m_axis_tdata      ({ pe4_s_axis_tdata , pe3_s_axis_tdata , pe2_s_axis_tdata , pe1_s_axis_tdata , pe0_s_axis_tdata , dummy_m_tdata  }),
	.m_axis_tkeep      ({ pe4_s_axis_tkeep , pe3_s_axis_tkeep , pe2_s_axis_tkeep , pe1_s_axis_tkeep , pe0_s_axis_tkeep , dummy_m_tkeep  }),
	.m_axis_tlast      ({ pe4_s_axis_tlast , pe3_s_axis_tlast , pe2_s_axis_tlast , pe1_s_axis_tlast , pe0_s_axis_tlast , dummy_m_tlast  }),
	.m_axis_tdest      ({ pe4_s_axis_tdest , pe3_s_axis_tdest , pe2_s_axis_tdest , pe1_s_axis_tdest , pe0_s_axis_tdest , dummy_m_tdest  }),
	.m_axis_tuser      ({ pe4_s_axis_tuser , pe3_s_axis_tuser , pe2_s_axis_tuser , pe1_s_axis_tuser , pe0_s_axis_tuser , dummy_m_tuser  }),
	.s_decode_err      (  )
);

input_arbiter_mod #(
    // Master AXI Stream Data Width
    .NUM_QUEUES (5)
) u_rx_sw (
    .axis_aclk   (axis_aclk_buf),
    .axis_resetn (axis_resetn_reg[15] && resetn_sync_reg[15] && !reset_soft_reg[15] ),

    // Master Stream Ports (interface to data path)
    .m_axis_tdata  (m_axis_tdata ),
    .m_axis_tkeep  (m_axis_tkeep ),
    .m_axis_tuser  (m_axis_tuser ),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tready (m_axis_tready),
    .m_axis_tlast  (m_axis_tlast ),
                    
    .s_axis_0_tdata  (pe0_m_axis_tdata),
    .s_axis_0_tkeep  (pe0_m_axis_tkeep),
    .s_axis_0_tuser  (pe0_m_axis_tuser),
    .s_axis_0_tvalid (pe0_m_axis_tvalid),
    .s_axis_0_tready (pe0_m_axis_tready),
    .s_axis_0_tlast  (pe0_m_axis_tlast),

    .s_axis_1_tdata  (pe1_m_axis_tdata),
    .s_axis_1_tkeep  (pe1_m_axis_tkeep),
    .s_axis_1_tuser  (pe1_m_axis_tuser),
    .s_axis_1_tvalid (pe1_m_axis_tvalid),
    .s_axis_1_tready (pe1_m_axis_tready),
    .s_axis_1_tlast  (pe1_m_axis_tlast),

    .s_axis_2_tdata  (pe2_m_axis_tdata),
    .s_axis_2_tkeep  (pe2_m_axis_tkeep),
    .s_axis_2_tuser  (pe2_m_axis_tuser),
    .s_axis_2_tvalid (pe2_m_axis_tvalid),
    .s_axis_2_tready (pe2_m_axis_tready),
    .s_axis_2_tlast  (pe2_m_axis_tlast),

    .s_axis_3_tdata  (pe3_m_axis_tdata),
    .s_axis_3_tkeep  (pe3_m_axis_tkeep),
    .s_axis_3_tuser  (pe3_m_axis_tuser),
    .s_axis_3_tvalid (pe3_m_axis_tvalid),
    .s_axis_3_tready (pe3_m_axis_tready),
    .s_axis_3_tlast  (pe3_m_axis_tlast),

    .s_axis_4_tdata  (pe4_m_axis_tdata),
    .s_axis_4_tkeep  (pe4_m_axis_tkeep),
    .s_axis_4_tuser  (pe4_m_axis_tuser),
    .s_axis_4_tvalid (pe4_m_axis_tvalid),
    .s_axis_4_tready (pe4_m_axis_tready),
    .s_axis_4_tlast  (pe4_m_axis_tlast),

    // Slave AXI Ports
    .S_AXI_ACLK    (0),
    .S_AXI_ARESETN (0),
    .S_AXI_AWADDR  (0),
    .S_AXI_AWVALID (0),
    .S_AXI_WDATA   (0),
    .S_AXI_WSTRB   (0),
    .S_AXI_WVALID  (0),
    .S_AXI_BREADY  (0),
    .S_AXI_ARADDR  (0),
    .S_AXI_ARVALID (0),
    .S_AXI_RREADY  (0)
);

/*
 *  Memory Network using AXI Stream-based Switch
 *    Port0 : DRAM cont
 *    Port1 : SRAM cont
 *    Port2 : PE0
 *    Port3 : PE1
 *    Port4 : PE2
 */
wire [5:0] memsw_decode_err;
cache_switch_0 u_mem_switch (
	.aclk            ( axis_aclk_buf ),                    // input wire aclk
	.aresetn         ( axis_resetn_reg[12] && resetn_sync_reg[9] && !reset_soft_reg[9] ),              // input wire aresetn
	.s_axis_tvalid   ({ pe4mem_m_axis_tvalid, pe3mem_m_axis_tvalid, pe2mem_m_axis_tvalid, pe1mem_m_axis_tvalid, pe0mem_m_axis_tvalid, lut_m_axis_tvalid, sram_m_axis_tvalid, dram_m_axis_tvalid }),  // input wire [4 : 0] s_axis_tvalid
	.s_axis_tready   ({ pe4mem_m_axis_tready, pe3mem_m_axis_tready, pe2mem_m_axis_tready, pe1mem_m_axis_tready, pe0mem_m_axis_tready, lut_m_axis_tready, sram_m_axis_tready, dram_m_axis_tready }),  // output wire [4 : 0] s_axis_tready
	.s_axis_tdata    ({ pe4mem_m_axis_tdata , pe3mem_m_axis_tdata , pe2mem_m_axis_tdata , pe1mem_m_axis_tdata , pe0mem_m_axis_tdata , lut_m_axis_tdata,  sram_m_axis_tdata,  dram_m_axis_tdata  }),  // input wire [2559 : 0] s_axis_tdata
	.s_axis_tkeep    ({ pe4mem_m_axis_tkeep , pe3mem_m_axis_tkeep , pe2mem_m_axis_tkeep , pe1mem_m_axis_tkeep , pe0mem_m_axis_tkeep , lut_m_axis_tkeep,  sram_m_axis_tkeep,  dram_m_axis_tkeep  }),  // input wire [319 : 0] s_axis_tkeep
	.s_axis_tlast    ({ pe4mem_m_axis_tlast , pe3mem_m_axis_tlast , pe2mem_m_axis_tlast , pe1mem_m_axis_tlast , pe0mem_m_axis_tlast , lut_m_axis_tlast,  sram_m_axis_tlast,  dram_m_axis_tlast  }),  // input wire [4 : 0] s_axis_tlast
	.s_axis_tuser    ({ pe4mem_m_axis_tuser , pe3mem_m_axis_tuser , pe2mem_m_axis_tuser , pe1mem_m_axis_tuser , pe0mem_m_axis_tuser , lut_m_axis_tuser,  sram_m_axis_tuser,  dram_m_axis_tuser  }),  // input wire [639 : 0] s_axis_tlast
	.s_axis_tdest    ({ pe4mem_m_axis_tdest , pe3mem_m_axis_tdest , pe2mem_m_axis_tdest , pe1mem_m_axis_tdest , pe0mem_m_axis_tdest , lut_m_axis_tdest,  sram_m_axis_tdest,  dram_m_axis_tdest  }),  // input wire [14 : 0] s_axis_tdest
	.m_axis_tvalid   ({ pe4mem_s_axis_tvalid, pe3mem_s_axis_tvalid, pe2mem_s_axis_tvalid, pe1mem_s_axis_tvalid, pe0mem_s_axis_tvalid, lut_s_axis_tvalid, sram_s_axis_tvalid, dram_s_axis_tvalid }),  // output wire [4 : 0] m_axis_tvalid
	.m_axis_tready   ({ pe4mem_s_axis_tready, pe3mem_s_axis_tready, pe2mem_s_axis_tready, pe1mem_s_axis_tready, pe0mem_s_axis_tready, lut_s_axis_tready, sram_s_axis_tready, dram_s_axis_tready }),  // input wire [4 : 0] m_axis_tready
	.m_axis_tdata    ({ pe4mem_s_axis_tdata , pe3mem_s_axis_tdata , pe2mem_s_axis_tdata , pe1mem_s_axis_tdata , pe0mem_s_axis_tdata , lut_s_axis_tdata,  sram_s_axis_tdata,  dram_s_axis_tdata  }),  // output wire [2559 : 0] m_axis_tdata
	.m_axis_tkeep    ({ pe4mem_s_axis_tkeep , pe3mem_s_axis_tkeep , pe2mem_s_axis_tkeep , pe1mem_s_axis_tkeep , pe0mem_s_axis_tkeep , lut_s_axis_tkeep,  sram_s_axis_tkeep,  dram_s_axis_tkeep  }),  // output wire [319 : 0] m_axis_tkeep
	.m_axis_tuser    ({ pe4mem_s_axis_tuser , pe3mem_s_axis_tuser , pe2mem_s_axis_tuser , pe1mem_s_axis_tuser , pe0mem_s_axis_tuser , lut_s_axis_tuser,  sram_s_axis_tuser,  dram_s_axis_tuser  }),  // output wire [639 : 0] m_axis_tkeep
	.m_axis_tlast    ({ pe4mem_s_axis_tlast , pe3mem_s_axis_tlast , pe2mem_s_axis_tlast , pe1mem_s_axis_tlast , pe0mem_s_axis_tlast , lut_s_axis_tlast,  sram_s_axis_tlast,  dram_s_axis_tlast  }),  // output wire [4 : 0] m_axis_tlast
	.m_axis_tdest    ({ pe4mem_s_axis_tdest , pe3mem_s_axis_tdest , pe2mem_s_axis_tdest , pe1mem_s_axis_tdest , pe0mem_s_axis_tdest , lut_s_axis_tdest,  sram_s_axis_tdest,  dram_s_axis_tdest  }),  // output wire [14 : 0] m_axis_tdest
	.s_decode_err    ( memsw_decode_err )    // output wire [4 : 0] s_decode_err
);

reg  [`REG_ID_BITS]      id_reg;
reg  [`REG_VERSION_BITS] version_reg;
reg  [`REG_RESET_BITS]   reset_soft_reg_reg;
reg  [`REG_RESET_BITS]   debug_reg;
reg  [31:0] queries_l1hit_reg, queries_l1miss_reg;
reg  [31:0] stat_set_cnt, stat_get_cnt, stat_del_cnt;
reg  [7:0] ip2cpu_lakeon_reg;
wire queries_clear;
wire querieshit_reg_clear, queriesmiss_reg_clear;
reg  [31:0] pktin_reg, pktout_reg;
wire [`REG_PEEN_BITS] cpu2ip_pes_enable_wire;
(* dont_touch = "true" *)reg  [`REG_PEEN_BITS] ip2cpu_pes_enable_reg;
wire pktin_reg_clear, pktout_reg_clear;
wire clear_counters = reset_soft_wire[0];

db_cpu_regs #(
	.C_S_AXI_DATA_WIDTH    ( C_S_AXI_DATA_WIDTH ),
	.C_S_AXI_ADDR_WIDTH    ( C_S_AXI_ADDR_WIDTH ),
	.C_BASE_ADDRESS        ( C_BASEADDR         )
) u_cpu_regs (
	// General ports
	.clk                   ( axis_aclk   ),
	.resetn                ( axis_resetn_reg[13] ),
	// Global Registers
	.cpu_resetn_soft         (),
	.resetn_soft             (),
	.resetn_sync             ( resetn_sync ),

	// Register ports
	.id_reg                  ( id_reg         ),
	.version_reg             ( version_reg    ),
	.reset_reg               ( reset_soft_wire ),
	.cpu2ip_pes_enable_reg   ( cpu2ip_pes_enable_wire ),
	.ip2cpu_pes_enable_reg   ( ip2cpu_pes_enable_reg ),
	.cpu2ip_scache_enable_reg   ( cpu2ip_scache_enable_wire ),
	.ip2cpu_scache_enable_reg   ( ip2cpu_scache_enable_reg ),
	.cpu2ip_clockgate_enable_reg   ( cpu2ip_clockgate_enable_wire ),
	.ip2cpu_clockgate_enable_reg   ( ip2cpu_clockgate_enable_reg ),
	.ip2cpu_flip_reg         (),
	.cpu2ip_flip_reg         (),
	.ip2cpu_debug_reg        ( debug_reg ),
	.cpu2ip_debug_reg        (),
	.pktin_reg               ( pktin_reg ),
	.pktin_reg_clear         ( pktin_reg_clear ),
	.pktout_reg              ( pktout_reg ),
	.pktout_reg_clear        ( pktout_reg_clear ),
	.ip2cpu_local_ipaddr_reg ( ip2cpu_local_ipaddr_reg   ),
	.cpu2ip_local_ipaddr_reg ( cpu2ip_local_ipaddr_reg   ),
	.ip2cpu_kvs_uport_reg    ( ip2cpu_kvs_uport_reg      ),
	.cpu2ip_kvs_uport_reg    ( cpu2ip_kvs_uport_reg      ),
	.ip2cpu_mode_reg         ( ip2cpu_mode_reg    ),
	.cpu2ip_mode_reg         ( cpu2ip_mode_reg    ),
	.ip2cpu_lakeon_reg       ( ip2cpu_lakeon_reg  ),
	.cpu2ip_lakeon_reg       ( cpu2ip_lakeon_wire  ),
	.queries_l1hit_reg       ( queries_l1hit_reg  ),
	.queries_l1miss_reg      ( queries_l1miss_reg ),
	.querieshit_reg_clear    ( querieshit_reg_clear ),
	.queriesmiss_reg_clear   ( queriesmiss_reg_clear),
	.stat_set_cnt            ( stat_set_cnt ),
	.stat_get_cnt            ( stat_get_cnt ),
	.stat_del_cnt            ( stat_del_cnt ),
	.p0_pktin                ( pe0_pktin  ),
	.p0_pktout               ( pe0_pktout ),
	.p1_pktin                ( pe1_pktin  ),
	.p1_pktout               ( pe1_pktout ),
	.p2_pktin                ( pe2_pktin  ),
	.p2_pktout               ( pe2_pktout ),
	.p3_pktin                ( pe3_pktin  ),
	.p3_pktout               ( pe3_pktout ),
	.p4_pktin                ( pe4_pktin  ),
	.p4_pktout               ( pe4_pktout ),
	.dram_access             ( dramA_access ),
	.dram_read               ( dramA_read ),
	.dram_access_in          ( dramA_access_in ),
	.dram_access_out         ( dramA_access_out ),
	.dramA_scache_all        ( dramA_scache_all ),
	.dramA_scache_hit        ( dramA_scache_hit ),
	.lut_access_in           ( lut_access_in ),
	.lut_access_out          ( lut_access_out ),
	.p0_debug                ( pe0_debug  ),
	.p1_debug                ( pe1_debug  ),
	.p2_debug                ( pe2_debug  ),
	.p0_chunk                ( pe0_chunk  ),
	.p1_chunk                ( pe1_chunk  ),
	.p2_chunk                ( pe2_chunk  ),
	.sram0_wrcmd             ( sram0_wrcmd ),
	.sram0_rdcmd             ( sram0_rdcmd ),
	.sram1_wrcmd             ( sram1_wrcmd ),
	.sram1_rdcmd             ( sram1_rdcmd ),
	.sram_incnt              ( sram_incnt  ),
	.sram_outcnt             ( sram_outcnt ),
	.pe0_errpkt              ( pe0_errpkt ),
	.pe1_errpkt              ( pe1_errpkt ),
	.pe2_errpkt              ( pe2_errpkt ),

	// AXI Lite ports
	.S_AXI_ACLK            ( S_AXI_ACLK    ),
	.S_AXI_ARESETN         ( S_AXI_ARESETN ),
	.S_AXI_AWADDR          ( S_AXI_AWADDR  ),
	.S_AXI_AWVALID         ( S_AXI_AWVALID ),
	.S_AXI_WDATA           ( S_AXI_WDATA   ),
	.S_AXI_WSTRB           ( S_AXI_WSTRB   ),
	.S_AXI_WVALID          ( S_AXI_WVALID  ),
	.S_AXI_BREADY          ( S_AXI_BREADY  ),
	.S_AXI_ARADDR          ( S_AXI_ARADDR  ),
	.S_AXI_ARVALID         ( S_AXI_ARVALID ),
	.S_AXI_RREADY          ( S_AXI_RREADY  ),
	.S_AXI_ARREADY         ( S_AXI_ARREADY ),
	.S_AXI_RDATA           ( S_AXI_RDATA   ),
	.S_AXI_RRESP           ( S_AXI_RRESP   ),
	.S_AXI_RVALID          ( S_AXI_RVALID  ),
	.S_AXI_WREADY          ( S_AXI_WREADY  ),
	.S_AXI_BRESP           ( S_AXI_BRESP   ),
	.S_AXI_BVALID          ( S_AXI_BVALID  ),
	.S_AXI_AWREADY         ( S_AXI_AWREADY ) 
);

always @ (posedge axis_aclk)
	if (!axis_resetn_reg[14] | !resetn_sync | reset_soft[8]) begin
		id_reg                  <= #1 `REG_ID_DEFAULT;
		version_reg             <= #1 `REG_VERSION_DEFAULT;
		debug_reg               <= #1 `REG_DEBUG_DEFAULT;
		queries_l1hit_reg       <= #1 `REG_L1HIT_DEFAULT;
		queries_l1miss_reg      <= #1 `REG_L1MISS_DEFAULT;
		ip2cpu_local_ipaddr_reg <= #1 `REG_IPADDR_DEFAULT;
		ip2cpu_kvs_uport_reg    <= #1 `REG_KVSPORT_DEFAULT;
		ip2cpu_mode_reg         <= #1 `REG_MODE_DEFAULT;
		pktin_reg               <= #1 `REG_PKTIN_DEFAULT;
		pktout_reg              <= #1 `REG_PKTOUT_DEFAULT;
		reset_soft_reg_reg      <= #1 `REG_RESET_DEFAULT;
		ip2cpu_pes_enable_reg   <= #1 `REG_PEEN_DEFAULT;
		pes_enable_reg          <= #1 `REG_PEEN_DEFAULT;  
		ip2cpu_scache_enable_reg   <= #1 `REG_SCACHEEN_DEFAULT;
		ip2cpu_clockgate_enable_reg <= #1 `REG_CLOCKGATE_DEFAULT;
		ip2cpu_lakeon_reg <= #1 `REG_LAKEON_DEFAULT;
		stat_set_cnt <= #1 0;
		stat_get_cnt <= #1 0;
		stat_del_cnt <= #1 0;
	end else begin
		debug_reg               <= #1 {29'd0, dramB_init_calib, sram_init_calib, dramA_init_calib};
		reset_soft_reg_reg      <= #1 reset_soft_wire;
		id_reg                  <= #1 `REG_ID_DEFAULT;
		version_reg             <= #1 `REG_VERSION_DEFAULT;
		ip2cpu_local_ipaddr_reg <= #1 cpu2ip_local_ipaddr_reg;
		ip2cpu_kvs_uport_reg    <= #1 cpu2ip_kvs_uport_reg;
		ip2cpu_mode_reg         <= #1 cpu2ip_mode_reg;
		ip2cpu_pes_enable_reg   <= #1 cpu2ip_pes_enable_wire;
		ip2cpu_scache_enable_reg <= #1 cpu2ip_scache_enable_wire;
		ip2cpu_clockgate_enable_reg <= #1 cpu2ip_clockgate_enable_wire;
		ip2cpu_lakeon_reg       <= #1 cpu2ip_lakeon_wire;
		pes_enable_reg          <= #1 ip2cpu_pes_enable_reg;

		pktin_reg <= #1 clear_counters | pktin_reg_clear ? 'h0 : pktin_reg + (s_axis_tvalid && s_axis_tlast && s_axis_tready);
		pktout_reg <= #1 clear_counters | pktout_reg_clear ? 'h0 : pktout_reg + (m_axis_tvalid && m_axis_tlast && m_axis_tready);
		if (queries_clear) begin
			queries_l1hit_reg <= #1 `REG_L1HIT_DEFAULT;
			queries_l1miss_reg <= #1 `REG_L1MISS_DEFAULT;
			stat_set_cnt <= #1 0;
			stat_get_cnt <= #1 0;
			stat_del_cnt <= #1 0;
		end else begin
			queries_l1hit_reg <= #1 queries_l1hit_pe0 + queries_l1hit_pe1 + queries_l1hit_pe2 + queries_l1hit_pe3 + queries_l1hit_pe4;
			queries_l1miss_reg <= #1 queries_l1miss_pe0 + queries_l1miss_pe1 + queries_l1miss_pe2 + queries_l1miss_pe3 + queries_l1miss_pe4;
			stat_set_cnt <= #1 pe0_stat_set_cnt + pe1_stat_set_cnt + pe2_stat_set_cnt + pe3_stat_set_cnt + pe4_stat_set_cnt;
			stat_get_cnt <= #1 pe0_stat_get_cnt + pe1_stat_get_cnt + pe2_stat_get_cnt + pe3_stat_get_cnt + pe4_stat_get_cnt;
			stat_del_cnt <= #1 pe0_stat_del_cnt + pe1_stat_del_cnt + pe2_stat_del_cnt + pe3_stat_del_cnt + pe4_stat_del_cnt;
		end
		if (stanby_cnt != 255) begin
			stanby_cnt <= stanby_cnt + 1;
		end
	end

assign reset_soft = reset_soft_reg_reg;

endmodule
