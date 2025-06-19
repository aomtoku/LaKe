`timescale 1ns / 1ps
//-
// Copyright (c) 2019 Noa Zilberman
// Modified by Yuta Tokusashi
// All rights reserved.
//
// This software was developed by Stanford University and the University of Cambridge Computer Laboratory 
// under National Science Foundation under Grant No. CNS-0855268,
// the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
// by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
// as part of the DARPA MRC research programme.
//
//  File:
//        nf_datapath.v
//
//  Module:
//        nf_datapath
//
//  Author: Noa Zilberman
//
//  Description:
//        NetFPGA user data path wrapper, wrapping input arbiter, output port lookup and output queues
//
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


module nf_datapath #(
    //Slave AXI parameters
    parameter C_S_AXI_DATA_WIDTH    = 32,          
    parameter C_S_AXI_ADDR_WIDTH    = 32,          
     parameter C_BASEADDR            = 32'h00000000,

    // Master AXI Stream Data Width
    parameter C_M_AXIS_DATA_WIDTH=256,
    parameter C_S_AXIS_DATA_WIDTH=256,
    parameter C_M_AXIS_TUSER_WIDTH=128,
    parameter C_S_AXIS_TUSER_WIDTH=128,
    parameter NUM_QUEUES=5
)
(
    //Datapath clock
    input                                     axis_aclk,
    input                                     axis_resetn,
    //Registers clock
    input                                     axi_aclk,
    input                                     axi_resetn,
    input              c0_sys_clk_p   ,
    input              c0_sys_clk_n   ,
    input              c1_sys_clk_p   ,
    input              c1_sys_clk_n   ,    
	//input                                     qdra_clk,
	//input                                     qdrb_clk,
	input                                     mem_clk_p,
	input                                     mem_clk_n,
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
    // Slave AXI Ports
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S0_AXI_AWADDR,
    input                                     S0_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S0_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S0_AXI_WSTRB,
    input                                     S0_AXI_WVALID,
    input                                     S0_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S0_AXI_ARADDR,
    input                                     S0_AXI_ARVALID,
    input                                     S0_AXI_RREADY,
    output                                    S0_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S0_AXI_RDATA,
    output     [1 : 0]                        S0_AXI_RRESP,
    output                                    S0_AXI_RVALID,
    output                                    S0_AXI_WREADY,
    output     [1 :0]                         S0_AXI_BRESP,
    output                                    S0_AXI_BVALID,
    output                                    S0_AXI_AWREADY,
    
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S1_AXI_AWADDR,
    input                                     S1_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S1_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S1_AXI_WSTRB,
    input                                     S1_AXI_WVALID,
    input                                     S1_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S1_AXI_ARADDR,
    input                                     S1_AXI_ARVALID,
    input                                     S1_AXI_RREADY,
    output                                    S1_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S1_AXI_RDATA,
    output     [1 : 0]                        S1_AXI_RRESP,
    output                                    S1_AXI_RVALID,
    output                                    S1_AXI_WREADY,
    output     [1 :0]                         S1_AXI_BRESP,
    output                                    S1_AXI_BVALID,
    output                                    S1_AXI_AWREADY,

    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S2_AXI_AWADDR,
    input                                     S2_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S2_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S2_AXI_WSTRB,
    input                                     S2_AXI_WVALID,
    input                                     S2_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S2_AXI_ARADDR,
    input                                     S2_AXI_ARVALID,
    input                                     S2_AXI_RREADY,
    output                                    S2_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S2_AXI_RDATA,
    output     [1 : 0]                        S2_AXI_RRESP,
    output                                    S2_AXI_RVALID,
    output                                    S2_AXI_WREADY,
    output     [1 :0]                         S2_AXI_BRESP,
    output                                    S2_AXI_BVALID,
    output                                    S2_AXI_AWREADY,

    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S3_AXI_AWADDR,
    input                                     S3_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S3_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S3_AXI_WSTRB,
    input                                     S3_AXI_WVALID,
    input                                     S3_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S3_AXI_ARADDR,
    input                                     S3_AXI_ARVALID,
    input                                     S3_AXI_RREADY,
    output                                    S3_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S3_AXI_RDATA,
    output     [1 : 0]                        S3_AXI_RRESP,
    output                                    S3_AXI_RVALID,
    output                                    S3_AXI_WREADY,
    output     [1 :0]                         S3_AXI_BRESP,
    output                                    S3_AXI_BVALID,
    output                                    S3_AXI_AWREADY,

    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S4_AXI_AWADDR,
    input                                     S4_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S4_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S4_AXI_WSTRB,
    input                                     S4_AXI_WVALID,
    input                                     S4_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S4_AXI_ARADDR,
    input                                     S4_AXI_ARVALID,
    input                                     S4_AXI_RREADY,
    output                                    S4_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S4_AXI_RDATA,
    output     [1 : 0]                        S4_AXI_RRESP,
    output                                    S4_AXI_RVALID,
    output                                    S4_AXI_WREADY,
    output     [1 :0]                         S4_AXI_BRESP,
    output                                    S4_AXI_BVALID,
    output                                    S4_AXI_AWREADY,

    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S5_AXI_AWADDR,
    input                                     S5_AXI_AWVALID,
    input      [C_S_AXI_DATA_WIDTH-1 : 0]     S5_AXI_WDATA,
    input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S5_AXI_WSTRB,
    input                                     S5_AXI_WVALID,
    input                                     S5_AXI_BREADY,
    input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S5_AXI_ARADDR,
    input                                     S5_AXI_ARVALID,
    input                                     S5_AXI_RREADY,
    output                                    S5_AXI_ARREADY,
    output     [C_S_AXI_DATA_WIDTH-1 : 0]     S5_AXI_RDATA,
    output     [1 : 0]                        S5_AXI_RRESP,
    output                                    S5_AXI_RVALID,
    output                                    S5_AXI_WREADY,
    output     [1 :0]                         S5_AXI_BRESP,
    output                                    S5_AXI_BVALID,
    output                                    S5_AXI_AWREADY,
    
    // Slave Stream Ports (interface from Rx queues)
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_0_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_0_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_0_tuser,
    input                                     s_axis_0_tvalid,
    output                                    s_axis_0_tready,
    input                                     s_axis_0_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_1_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_1_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_1_tuser,
    input                                     s_axis_1_tvalid,
    output                                    s_axis_1_tready,
    input                                     s_axis_1_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_2_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_2_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_2_tuser,
    input                                     s_axis_2_tvalid,
    output                                    s_axis_2_tready,
    input                                     s_axis_2_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_3_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_3_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_3_tuser,
    input                                     s_axis_3_tvalid,
    output                                    s_axis_3_tready,
    input                                     s_axis_3_tlast,
    input [C_S_AXIS_DATA_WIDTH - 1:0]         s_axis_4_tdata,
    input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_4_tkeep,
    input [C_S_AXIS_TUSER_WIDTH-1:0]          s_axis_4_tuser,
    input                                     s_axis_4_tvalid,
    output                                    s_axis_4_tready,
    input                                     s_axis_4_tlast,


    // Master Stream Ports (interface to TX queues)
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_0_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_0_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_0_tuser,
    output                                     m_axis_0_tvalid,
    input                                      m_axis_0_tready,
    output                                     m_axis_0_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_1_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_1_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_1_tuser,
    output                                     m_axis_1_tvalid,
    input                                      m_axis_1_tready,
    output                                     m_axis_1_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_2_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_2_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_2_tuser,
    output                                     m_axis_2_tvalid,
    input                                      m_axis_2_tready,
    output                                     m_axis_2_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_3_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_3_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_3_tuser,
    output                                     m_axis_3_tvalid,
    input                                      m_axis_3_tready,
    output                                     m_axis_3_tlast,
    output [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_4_tdata,
    output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_4_tkeep,
    output [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_4_tuser,
    output                                     m_axis_4_tvalid,
    input                                      m_axis_4_tready,
    output                                     m_axis_4_tlast


    );
    
    //internal connectivity
  
    wire [C_M_AXIS_DATA_WIDTH - 1:0]         m_axis_opl_tdata;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_opl_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0]          m_axis_opl_tuser;
    wire                                     m_axis_opl_tvalid;
    wire                                     m_axis_opl_tready;
    wire                                     m_axis_opl_tlast;
     
    wire [C_M_AXIS_DATA_WIDTH - 1:0]         s_axis_opl_tdata;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_opl_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0]          s_axis_opl_tuser;
    wire                                     s_axis_opl_tvalid;
    wire                                     s_axis_opl_tready;
    wire                                     s_axis_opl_tlast;
   
    wire [C_M_AXIS_DATA_WIDTH - 1:0]         s_axis_inp0_tdata;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_inp0_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0]          s_axis_inp0_tuser;
    wire                                     s_axis_inp0_tvalid;
    wire                                     s_axis_inp0_tready;
    wire                                     s_axis_inp0_tlast;

    wire [C_M_AXIS_DATA_WIDTH - 1:0]         s_axis_inp1_tdata;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_inp1_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0]          s_axis_inp1_tuser;
    wire                                     s_axis_inp1_tvalid;
    wire                                     s_axis_inp1_tready;
    wire                                     s_axis_inp1_tlast;

    wire [C_M_AXIS_DATA_WIDTH - 1:0]         s_axis_norm_tdata;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_norm_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0]          s_axis_norm_tuser;
    wire                                     s_axis_norm_tvalid;
    wire                                     s_axis_norm_tready;
    wire                                     s_axis_norm_tlast;

    wire [C_M_AXIS_DATA_WIDTH - 1:0]         s_axis_memc_tdata;
    wire [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_memc_tkeep;
    wire [C_M_AXIS_TUSER_WIDTH-1:0]          s_axis_memc_tuser;
    wire                                     s_axis_memc_tvalid;
    wire                                     s_axis_memc_tready;
    wire                                     s_axis_memc_tlast;

  //Input Arbiter
  input_arbiter_ip 
 input_arbiter_v1_0 (
      .axis_aclk(axis_aclk), 
      .axis_resetn(axis_resetn), 
      .m_axis_tdata (s_axis_inp0_tdata), 
      .m_axis_tkeep (s_axis_inp0_tkeep), 
      .m_axis_tuser (s_axis_inp0_tuser), 
      .m_axis_tvalid(s_axis_inp0_tvalid), 
      .m_axis_tready(s_axis_inp0_tready), 
      .m_axis_tlast (s_axis_inp0_tlast), 
      .s_axis_0_tdata (s_axis_0_tdata), 
      .s_axis_0_tkeep (s_axis_0_tkeep), 
      .s_axis_0_tuser (s_axis_0_tuser), 
      .s_axis_0_tvalid(s_axis_0_tvalid), 
      .s_axis_0_tready(s_axis_0_tready), 
      .s_axis_0_tlast (s_axis_0_tlast), 
      .s_axis_1_tdata (s_axis_1_tdata), 
      .s_axis_1_tkeep (s_axis_1_tkeep), 
      .s_axis_1_tuser (s_axis_1_tuser), 
      .s_axis_1_tvalid(s_axis_1_tvalid), 
      .s_axis_1_tready(s_axis_1_tready), 
      .s_axis_1_tlast (s_axis_1_tlast), 
      .s_axis_2_tdata (s_axis_2_tdata), 
      .s_axis_2_tkeep (s_axis_2_tkeep), 
      .s_axis_2_tuser (s_axis_2_tuser), 
      .s_axis_2_tvalid(s_axis_2_tvalid), 
      .s_axis_2_tready(s_axis_2_tready), 
      .s_axis_2_tlast (s_axis_2_tlast), 
      .s_axis_3_tdata (s_axis_3_tdata), 
      .s_axis_3_tkeep (s_axis_3_tkeep), 
      .s_axis_3_tuser (s_axis_3_tuser), 
      .s_axis_3_tvalid(s_axis_3_tvalid), 
      .s_axis_3_tready(s_axis_3_tready), 
      .s_axis_3_tlast (s_axis_3_tlast), 
      .s_axis_4_tdata (s_axis_4_tdata), 
      .s_axis_4_tkeep (s_axis_4_tkeep), 
      .s_axis_4_tuser (s_axis_4_tuser), 
      .s_axis_4_tvalid(s_axis_4_tvalid), 
      .s_axis_4_tready(s_axis_4_tready), 
      .s_axis_4_tlast (s_axis_4_tlast), 
      .S_AXI_AWADDR(S0_AXI_AWADDR), 
      .S_AXI_AWVALID(S0_AXI_AWVALID),
      .S_AXI_WDATA(S0_AXI_WDATA),  
      .S_AXI_WSTRB(S0_AXI_WSTRB),  
      .S_AXI_WVALID(S0_AXI_WVALID), 
      .S_AXI_BREADY(S0_AXI_BREADY), 
      .S_AXI_ARADDR(S0_AXI_ARADDR), 
      .S_AXI_ARVALID(S0_AXI_ARVALID),
      .S_AXI_RREADY(S0_AXI_RREADY), 
      .S_AXI_ARREADY(S0_AXI_ARREADY),
      .S_AXI_RDATA(S0_AXI_RDATA),  
      .S_AXI_RRESP(S0_AXI_RRESP),  
      .S_AXI_RVALID(S0_AXI_RVALID), 
      .S_AXI_WREADY(S0_AXI_WREADY), 
      .S_AXI_BRESP(S0_AXI_BRESP),  
      .S_AXI_BVALID(S0_AXI_BVALID), 
      .S_AXI_AWREADY(S0_AXI_AWREADY),
      .S_AXI_ACLK (axi_aclk), 
      .S_AXI_ARESETN(axi_resetn),
      .pkt_fwd() 
    );
    

div_ip u_div_ip (
	// Global Ports
	.axis_aclk    ( axis_aclk   ),
	.axis_resetn  ( axis_resetn ),
	//.debug        ( ),
	
	// Master Stream Ports (interface to data path)
	.m_axis_tdata      ( s_axis_norm_tdata  ),
	.m_axis_tkeep      ( s_axis_norm_tkeep  ),
	.m_axis_tuser      ( s_axis_norm_tuser  ),
	.m_axis_tvalid     ( s_axis_norm_tvalid ),
	.m_axis_tready     ( s_axis_norm_tready ),
	.m_axis_tlast      ( s_axis_norm_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata       ( s_axis_inp0_tdata  ),
	.s_axis_tkeep       ( s_axis_inp0_tkeep  ),
	.s_axis_tuser       ( s_axis_inp0_tuser  ),
	.s_axis_tvalid      ( s_axis_inp0_tvalid ),
	.s_axis_tready      ( s_axis_inp0_tready ),
	.s_axis_tlast       ( s_axis_inp0_tlast  ),
	
	//
	.kvs_m_axis_tdata  ( s_axis_memc_tdata  ),
	.kvs_m_axis_tkeep  ( s_axis_memc_tkeep  ),
	.kvs_m_axis_tuser  ( s_axis_memc_tuser  ),
	.kvs_m_axis_tlast  ( s_axis_memc_tlast  ),
	.kvs_m_axis_tready ( s_axis_memc_tready ),
	.kvs_m_axis_tvalid ( s_axis_memc_tvalid ),

	// Slave AXI Ports
	.S_AXI_AWADDR          ( S4_AXI_AWADDR  ), 
	.S_AXI_AWVALID         ( S4_AXI_AWVALID ),
	.S_AXI_WDATA           ( S4_AXI_WDATA   ),  
	.S_AXI_WSTRB           ( S4_AXI_WSTRB   ),  
	.S_AXI_WVALID          ( S4_AXI_WVALID  ), 
	.S_AXI_BREADY          ( S4_AXI_BREADY  ), 
	.S_AXI_ARADDR          ( S4_AXI_ARADDR  ), 
	.S_AXI_ARVALID         ( S4_AXI_ARVALID ),
	.S_AXI_RREADY          ( S4_AXI_RREADY  ), 
	.S_AXI_ARREADY         ( S4_AXI_ARREADY ),
	.S_AXI_RDATA           ( S4_AXI_RDATA   ),  
	.S_AXI_RRESP           ( S4_AXI_RRESP   ),  
	.S_AXI_RVALID          ( S4_AXI_RVALID  ), 
	.S_AXI_WREADY          ( S4_AXI_WREADY  ), 
	.S_AXI_BRESP           ( S4_AXI_BRESP   ),  
	.S_AXI_BVALID          ( S4_AXI_BVALID  ), 
	.S_AXI_AWREADY         ( S4_AXI_AWREADY ),
	.S_AXI_ACLK            ( axi_aclk       ), 
	.S_AXI_ARESETN         ( axi_resetn     )
);

    
memcached 
 u_db (
	/* DDR3 DRAM IO pins */
	.ddr3_dq               ( ddr3_dq      ),
	.ddr3_dqs_n            ( ddr3_dqs_n   ),
	.ddr3_dqs_p            ( ddr3_dqs_p   ),
	.ddr3_addr             ( ddr3_addr    ),
	.ddr3_ba               ( ddr3_ba      ),
	.ddr3_ras_n            ( ddr3_ras_n   ),
	.ddr3_cas_n            ( ddr3_cas_n   ),
	.ddr3_we_n             ( ddr3_we_n    ),
	.ddr3_reset_n          ( ddr3_reset_n ),
	.ddr3_ck_p             ( ddr3_ck_p    ),
	.ddr3_ck_n             ( ddr3_ck_n    ),
	.ddr3_cke              ( ddr3_cke     ),
	.ddr3_cs_n             ( ddr3_cs_n    ),
	.ddr3_dm               ( ddr3_dm      ),
	.ddr3_odt              ( ddr3_odt     ),
    /* SRAM A IO pins */
	.c0_qdriip_cq_p        ( c0_qdriip_cq_p      ),
	.c0_qdriip_cq_n        ( c0_qdriip_cq_n      ),
	.c0_qdriip_q           ( c0_qdriip_q         ),
	.c0_qdriip_k_p         ( c0_qdriip_k_p       ),
	.c0_qdriip_k_n         ( c0_qdriip_k_n       ),
	.c0_qdriip_d           ( c0_qdriip_d         ),
	.c0_qdriip_sa          ( c0_qdriip_sa        ),
	.c0_qdriip_w_n         ( c0_qdriip_w_n       ),
	.c0_qdriip_r_n         ( c0_qdriip_r_n       ),
	.c0_qdriip_bw_n        ( c0_qdriip_bw_n      ),
	.c0_qdriip_dll_off_n   ( c0_qdriip_dll_off_n ),
    /* SRAM B IO pins */
	.c1_qdriip_cq_p        ( c1_qdriip_cq_p      ),
	.c1_qdriip_cq_n        ( c1_qdriip_cq_n      ),
	.c1_qdriip_q           ( c1_qdriip_q         ),
	.c1_qdriip_k_p         ( c1_qdriip_k_p       ),
	.c1_qdriip_k_n         ( c1_qdriip_k_n       ),
	.c1_qdriip_d           ( c1_qdriip_d         ),
	.c1_qdriip_sa          ( c1_qdriip_sa        ),
	.c1_qdriip_w_n         ( c1_qdriip_w_n       ),
	.c1_qdriip_r_n         ( c1_qdriip_r_n       ),
	.c1_qdriip_bw_n        ( c1_qdriip_bw_n      ),
	.c1_qdriip_dll_off_n   ( c1_qdriip_dll_off_n ),
	// Global Ports
	.axis_aclk             ( axis_aclk   ), 
	.axis_resetn           ( axis_resetn ), 
    .c0_sys_clk_p          ( c0_sys_clk_p ),
    .c0_sys_clk_n          ( c0_sys_clk_n ),
    .c1_sys_clk_p          ( c1_sys_clk_p ),
    .c1_sys_clk_n          ( c1_sys_clk_n ),    
	//.qdra_clk              ( qdra_clk    ),
	//.qdrb_clk              ( qdrb_clk    ),
	.dram_clk_p            ( mem_clk_p   ),
	.dram_clk_n            ( mem_clk_n   ),
	.debug                 (),
	.LED                   (),
	// axi lite control/status interface
	// Slave AXI Ports
	.S_AXI_AWADDR          ( S3_AXI_AWADDR  ), 
	.S_AXI_AWVALID         ( S3_AXI_AWVALID ),
	.S_AXI_WDATA           ( S3_AXI_WDATA   ),  
	.S_AXI_WSTRB           ( S3_AXI_WSTRB   ),  
	.S_AXI_WVALID          ( S3_AXI_WVALID  ), 
	.S_AXI_BREADY          ( S3_AXI_BREADY  ), 
	.S_AXI_ARADDR          ( S3_AXI_ARADDR  ), 
	.S_AXI_ARVALID         ( S3_AXI_ARVALID ),
	.S_AXI_RREADY          ( S3_AXI_RREADY  ), 
	.S_AXI_ARREADY         ( S3_AXI_ARREADY ),
	.S_AXI_RDATA           ( S3_AXI_RDATA   ),  
	.S_AXI_RRESP           ( S3_AXI_RRESP   ),  
	.S_AXI_RVALID          ( S3_AXI_RVALID  ), 
	.S_AXI_WREADY          ( S3_AXI_WREADY  ), 
	.S_AXI_BRESP           ( S3_AXI_BRESP   ),  
	.S_AXI_BVALID          ( S3_AXI_BVALID  ), 
	.S_AXI_AWREADY         ( S3_AXI_AWREADY ),
	.S_AXI_ACLK            ( axi_aclk       ), 
	.S_AXI_ARESETN         ( axi_resetn     ),
	
	// Master Stream Ports (interface to data path)
	.m_axis_tdata          ( s_axis_inp1_tdata  ),
	.m_axis_tkeep          ( s_axis_inp1_tkeep  ),
	.m_axis_tuser          ( s_axis_inp1_tuser  ),
	.m_axis_tvalid         ( s_axis_inp1_tvalid ),
	.m_axis_tready         ( s_axis_inp1_tready ),
	.m_axis_tlast          ( s_axis_inp1_tlast  ),
	
	// Slave Stream Ports (interface to RX queues)
	.s_axis_tdata          ( s_axis_memc_tdata  ),
	.s_axis_tkeep          ( s_axis_memc_tkeep  ),
	.s_axis_tuser          ( s_axis_memc_tuser  ),
	.s_axis_tvalid         ( s_axis_memc_tvalid ),
	.s_axis_tready         ( s_axis_memc_tready ),
	.s_axis_tlast          ( s_axis_memc_tlast  ) 
);

  input_arbiter_ip 
 input_arbiter2_v1_0 (
      .axis_aclk   (axis_aclk), 
      .axis_resetn (axis_resetn), 
      .m_axis_tdata (s_axis_opl_tdata), 
      .m_axis_tkeep (s_axis_opl_tkeep), 
      .m_axis_tuser (s_axis_opl_tuser), 
      .m_axis_tvalid(s_axis_opl_tvalid), 
      .m_axis_tready(s_axis_opl_tready), 
      .m_axis_tlast (s_axis_opl_tlast), 
      .s_axis_0_tdata (s_axis_norm_tdata), 
      .s_axis_0_tkeep (s_axis_norm_tkeep), 
      .s_axis_0_tuser (s_axis_norm_tuser), 
      .s_axis_0_tvalid(s_axis_norm_tvalid), 
      .s_axis_0_tready(s_axis_norm_tready), 
      .s_axis_0_tlast (s_axis_norm_tlast), 
      .s_axis_1_tdata (s_axis_inp1_tdata), 
      .s_axis_1_tkeep (s_axis_inp1_tkeep), 
      .s_axis_1_tuser (s_axis_inp1_tuser), 
      .s_axis_1_tvalid(s_axis_inp1_tvalid), 
      .s_axis_1_tready(s_axis_inp1_tready), 
      .s_axis_1_tlast (s_axis_inp1_tlast), 
      .S_AXI_AWADDR   (S5_AXI_AWADDR), 
      .S_AXI_AWVALID  (S5_AXI_AWVALID),
      .S_AXI_WDATA    (S5_AXI_WDATA),  
      .S_AXI_WSTRB    (S5_AXI_WSTRB),  
      .S_AXI_WVALID   (S5_AXI_WVALID), 
      .S_AXI_BREADY   (S5_AXI_BREADY), 
      .S_AXI_ARADDR   (S5_AXI_ARADDR), 
      .S_AXI_ARVALID  (S5_AXI_ARVALID),
      .S_AXI_RREADY   (S5_AXI_RREADY), 
      .S_AXI_ARREADY  (S5_AXI_ARREADY),
      .S_AXI_RDATA    (S5_AXI_RDATA),  
      .S_AXI_RRESP    (S5_AXI_RRESP),  
      .S_AXI_RVALID   (S5_AXI_RVALID), 
      .S_AXI_WREADY   (S5_AXI_WREADY), 
      .S_AXI_BRESP    (S5_AXI_BRESP),  
      .S_AXI_BVALID   (S5_AXI_BVALID), 
      .S_AXI_AWREADY  (S5_AXI_AWREADY),
      .S_AXI_ACLK     (axi_aclk), 
      .S_AXI_ARESETN  (axi_resetn),
      .pkt_fwd() 
    );
    
     //Output Port Lookup  
       output_port_lookup_ip 
     output_port_lookup_1  (
      .axis_aclk(axis_aclk), 
      .axis_resetn(axis_resetn), 
      .m_axis_tdata (m_axis_opl_tdata), 
      .m_axis_tkeep (m_axis_opl_tkeep), 
      .m_axis_tuser (m_axis_opl_tuser), 
      .m_axis_tvalid(m_axis_opl_tvalid), 
      .m_axis_tready(m_axis_opl_tready), 
      .m_axis_tlast (m_axis_opl_tlast), 
      .s_axis_tdata (s_axis_opl_tdata), 
      .s_axis_tkeep (s_axis_opl_tkeep), 
      .s_axis_tuser (s_axis_opl_tuser), 
      .s_axis_tvalid(s_axis_opl_tvalid), 
      .s_axis_tready(s_axis_opl_tready), 
      .s_axis_tlast (s_axis_opl_tlast), 

      .S_AXI_AWADDR(S1_AXI_AWADDR), 
      .S_AXI_AWVALID(S1_AXI_AWVALID),
      .S_AXI_WDATA(S1_AXI_WDATA),  
      .S_AXI_WSTRB(S1_AXI_WSTRB),  
      .S_AXI_WVALID(S1_AXI_WVALID), 
      .S_AXI_BREADY(S1_AXI_BREADY), 
      .S_AXI_ARADDR(S1_AXI_ARADDR), 
      .S_AXI_ARVALID(S1_AXI_ARVALID),
      .S_AXI_RREADY(S1_AXI_RREADY), 
      .S_AXI_ARREADY(S1_AXI_ARREADY),
      .S_AXI_RDATA(S1_AXI_RDATA),  
      .S_AXI_RRESP(S1_AXI_RRESP),  
      .S_AXI_RVALID(S1_AXI_RVALID), 
      .S_AXI_WREADY(S1_AXI_WREADY), 
      .S_AXI_BRESP(S1_AXI_BRESP),  
      .S_AXI_BVALID(S1_AXI_BVALID), 
      .S_AXI_AWREADY(S1_AXI_AWREADY),
      .S_AXI_ACLK (axi_aclk), 
      .S_AXI_ARESETN(axi_resetn)


    );
    
       
      //Output queues
       output_queues_ip  
     bram_output_queues_1 (
      .axis_aclk(axis_aclk), 
      .axis_resetn(axis_resetn), 
      .s_axis_tdata   (m_axis_opl_tdata), 
      .s_axis_tkeep   (m_axis_opl_tkeep), 
      .s_axis_tuser   (m_axis_opl_tuser), 
      .s_axis_tvalid  (m_axis_opl_tvalid), 
      .s_axis_tready  (m_axis_opl_tready), 
      .s_axis_tlast   (m_axis_opl_tlast), 
      .m_axis_0_tdata (m_axis_0_tdata), 
      .m_axis_0_tkeep (m_axis_0_tkeep), 
      .m_axis_0_tuser (m_axis_0_tuser), 
      .m_axis_0_tvalid(m_axis_0_tvalid), 
      .m_axis_0_tready(m_axis_0_tready), 
      .m_axis_0_tlast (m_axis_0_tlast), 
      .m_axis_1_tdata (m_axis_1_tdata), 
      .m_axis_1_tkeep (m_axis_1_tkeep), 
      .m_axis_1_tuser (m_axis_1_tuser), 
      .m_axis_1_tvalid(m_axis_1_tvalid), 
      .m_axis_1_tready(m_axis_1_tready), 
      .m_axis_1_tlast (m_axis_1_tlast), 
      .m_axis_2_tdata (m_axis_2_tdata), 
      .m_axis_2_tkeep (m_axis_2_tkeep), 
      .m_axis_2_tuser (m_axis_2_tuser), 
      .m_axis_2_tvalid(m_axis_2_tvalid), 
      .m_axis_2_tready(m_axis_2_tready), 
      .m_axis_2_tlast (m_axis_2_tlast), 
      .m_axis_3_tdata (m_axis_3_tdata), 
      .m_axis_3_tkeep (m_axis_3_tkeep), 
      .m_axis_3_tuser (m_axis_3_tuser), 
      .m_axis_3_tvalid(m_axis_3_tvalid), 
      .m_axis_3_tready(m_axis_3_tready), 
      .m_axis_3_tlast (m_axis_3_tlast), 
      .m_axis_4_tdata (m_axis_4_tdata), 
      .m_axis_4_tkeep (m_axis_4_tkeep), 
      .m_axis_4_tuser (m_axis_4_tuser), 
      .m_axis_4_tvalid(m_axis_4_tvalid), 
      .m_axis_4_tready(m_axis_4_tready), 
      .m_axis_4_tlast (m_axis_4_tlast), 
      .bytes_stored(), 
      .pkt_stored(), 
      .bytes_removed_0(), 
      .bytes_removed_1(), 
      .bytes_removed_2(), 
      .bytes_removed_3(), 
      .bytes_removed_4(), 
      .pkt_removed_0(), 
      .pkt_removed_1(), 
      .pkt_removed_2(), 
      .pkt_removed_3(), 
      .pkt_removed_4(), 
      .bytes_dropped(), 
      .pkt_dropped(), 

      .S_AXI_AWADDR(S2_AXI_AWADDR), 
      .S_AXI_AWVALID(S2_AXI_AWVALID),
      .S_AXI_WDATA(S2_AXI_WDATA),  
      .S_AXI_WSTRB(S2_AXI_WSTRB),  
      .S_AXI_WVALID(S2_AXI_WVALID), 
      .S_AXI_BREADY(S2_AXI_BREADY), 
      .S_AXI_ARADDR(S2_AXI_ARADDR), 
      .S_AXI_ARVALID(S2_AXI_ARVALID),
      .S_AXI_RREADY(S2_AXI_RREADY), 
      .S_AXI_ARREADY(S2_AXI_ARREADY),
      .S_AXI_RDATA(S2_AXI_RDATA),  
      .S_AXI_RRESP(S2_AXI_RRESP),  
      .S_AXI_RVALID(S2_AXI_RVALID), 
      .S_AXI_WREADY(S2_AXI_WREADY), 
      .S_AXI_BRESP(S2_AXI_BRESP),  
      .S_AXI_BVALID(S2_AXI_BVALID), 
      .S_AXI_AWREADY(S2_AXI_AWREADY),
      .S_AXI_ACLK (axi_aclk), 
      .S_AXI_ARESETN(axi_resetn)
    ); 
    
    
    
    
endmodule

