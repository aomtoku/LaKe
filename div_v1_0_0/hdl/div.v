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
`timescale 1ns/1ns
`define WRITE_THROUGH
`define XILINX_FIFO
`include "div_cpu_regs_defines.v"
module div #(
	//Master AXI Stream Data Width
	parameter C_BASEADDR             = 32'h00000000,
	parameter C_HIGHADDR             = 32'h0,
	parameter C_S_AXI_ADDR_WIDTH     = 12,
	parameter C_S_AXI_DATA_WIDTH     = 32,
	parameter C_MAX_LEN              = 512,
	parameter C_M_AXIS_DATA_WIDTH=256,
	parameter C_S_AXIS_DATA_WIDTH=256,
	parameter C_M_AXIS_TUSER_WIDTH=128,
	parameter C_S_AXIS_TUSER_WIDTH=128
) (
	// Global Ports
	input axis_aclk,
	input axis_resetn,
	//output [2:0] debug,
	
	// Master Stream Ports (interface to data path)
	output [C_M_AXIS_DATA_WIDTH - 1:0] m_axis_tdata,
	output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0] m_axis_tuser,
	output m_axis_tvalid,
	input  m_axis_tready,
	output m_axis_tlast,
	
	// Slave Stream Ports (interface to RX queues)
	input [C_S_AXIS_DATA_WIDTH - 1:0] s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH / 8)) - 1:0] s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser,
	input  s_axis_tvalid,
	output s_axis_tready,
	input  s_axis_tlast,
	
	//
	output [C_M_AXIS_DATA_WIDTH - 1:0] kvs_m_axis_tdata,
	output [((C_M_AXIS_DATA_WIDTH / 8)) - 1:0] kvs_m_axis_tkeep,
	output [C_M_AXIS_TUSER_WIDTH-1:0] kvs_m_axis_tuser,
	output kvs_m_axis_tlast,
	input  kvs_m_axis_tready,
	output kvs_m_axis_tvalid,

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
	output                                    S_AXI_AWREADY
);

//`include "filter.h"
localparam ETH_TYPE_POS = 96;
localparam IP_PROTO_POS = 184;
localparam SPORT_POS    = 16; 
localparam DPORT_POS    = 32; 

localparam IP_TYPE      = 16'h0008;
localparam UDP_PROTO    =  8'h11;

localparam SRC_PORT_POS=16;
localparam DST_PORT_POS=24;
localparam MEMC_MAGIC_POS   = 80;
localparam MEMC_OPCODE_POS  = 88;
localparam MEMC_RESRVD_POS  = 128;
localparam MEMC_TOTLEN_POS  = 144;


localparam PROTOCOL_BINARY_REQ            = 8'h80;
localparam PROTOCOL_BINARY_RES            = 8'h81;
// protocol_binary_command
localparam PROTOCOL_BINARY_CMD_GET        = 8'h00;
localparam PROTOCOL_BINARY_CMD_SET        = 8'h01;
localparam PROTOCOL_BINARY_CMD_DELETE     = 8'h04;
wire [15:0] cpu2ip_kvs_uport_reg;
reg  [15:0] ip2cpu_kvs_uport_reg;

wire empty_recv, full_recv;
wire empty_send0, full_send0;
wire empty_send1, full_send1;
wire nearly_full_recv, nearly_full_send0, nearly_full_send1;
wire rd_en_send0, rd_en_send1, rd_en_recv;
wire wr_en_send0, wr_en_send1, wr_en_recv;

wire [256+128+32:0] dout_fifo;
wire reset_registers;
wire diven;

localparam MODULE_HEADER = 0;
localparam IN_PACKET     = 1;
//------------- Wires -----------------
reg [C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8:0] data_reg_stage1;
reg [C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8:0] data_reg_stage2;
wire [C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8:0] fifo_data_out;
wire in_fifo_empty;
reg data_reg_stage1_empty = 1;
reg data_reg_stage2_empty = 1;
reg data_reg_stage2_stop;
reg [C_M_AXIS_DATA_WIDTH+C_M_AXIS_TUSER_WIDTH+C_M_AXIS_DATA_WIDTH/8:0] data_reg_stage2_input;
wire [47:0] target_mac;
wire  [C_M_AXIS_TUSER_WIDTH-1:0] tuser_reg;
wire  [C_M_AXIS_DATA_WIDTH-1:0] tdata_reg;
wire  [C_M_AXIS_DATA_WIDTH-1:0] tdata_reg_next;
reg state;
reg state_next;
reg kvs_data_en, kvs_data_en_next;
reg both_traffic_en, both_traffic_en_next;
wire kvs_period = kvs_data_en || kvs_data_en_next;
wire both_traffic = both_traffic_en || both_traffic_en_next;
wire full_send2, empty_send2, nearly_full_send2;

wire     [`REG_RESET_BITS]    reset_reg;
wire dummy_tlast;
wire [31:0] dummy1;
wire dummy_tvalid = !data_reg_stage2_empty && !data_reg_stage2_stop;
assign {dummy_tlast, tuser_reg, dummy1, tdata_reg} = data_reg_stage2;
assign tdata_reg_next = data_reg_stage1[C_S_AXIS_DATA_WIDTH-1:0];
wire [31:0] totlen_in = {tdata_reg_next[MEMC_TOTLEN_POS+7 :MEMC_TOTLEN_POS   ], 
                         tdata_reg_next[MEMC_TOTLEN_POS+15:MEMC_TOTLEN_POS+8 ], 
                         tdata_reg_next[MEMC_TOTLEN_POS+23:MEMC_TOTLEN_POS+16],
                         tdata_reg_next[MEMC_TOTLEN_POS+31:MEMC_TOTLEN_POS+24]};

always @(*) begin
	state_next            = state;
	kvs_data_en_next      = kvs_data_en;
	data_reg_stage2_stop  = 0;
	data_reg_stage2_input = data_reg_stage1;
	both_traffic_en_next  = both_traffic_en;

	case(state)
		MODULE_HEADER: begin
			if (!data_reg_stage2_empty) begin
				if(tdata_reg[ETH_TYPE_POS+15:ETH_TYPE_POS] == IP_TYPE && tdata_reg[IP_PROTO_POS+7:IP_PROTO_POS]  == UDP_PROTO ) begin
					$display("IP && UDP");
					if(data_reg_stage1_empty) begin
						data_reg_stage2_stop = 1;
					end else if({tdata_reg_next[DPORT_POS+7:DPORT_POS], tdata_reg_next[DPORT_POS+15:DPORT_POS+8]} == cpu2ip_kvs_uport_reg) begin
`ifdef WRITE_THROUGH
						if (tdata_reg_next[MEMC_MAGIC_POS+7:MEMC_MAGIC_POS] == PROTOCOL_BINARY_REQ && 
							  (tdata_reg_next[MEMC_OPCODE_POS+7:MEMC_OPCODE_POS] == PROTOCOL_BINARY_CMD_SET || 
							   tdata_reg_next[MEMC_OPCODE_POS+7:MEMC_OPCODE_POS] == PROTOCOL_BINARY_CMD_DELETE) && 
							totlen_in[31:9] == 23'h0 && diven) begin
							both_traffic_en_next = 1;
							$display("both traffic: Request SET or Delete");
						end else begin
							$display("KVS port: Request GET");
						end

`endif /* WRITE_THROUGH */
						$display("memcached");
						if (tdata_reg_next[MEMC_MAGIC_POS+7:MEMC_MAGIC_POS] == PROTOCOL_BINARY_REQ && 
							totlen_in[31:9] != 23'h0)
							kvs_data_en_next = 0;
						else if (nearly_full_send2) 
							kvs_data_en_next = 0;
						else if (diven)
							kvs_data_en_next = 1;
						else
							kvs_data_en_next = 0;
					end
`ifdef WRITE_THROUGH
						else if ({tdata_reg_next[SPORT_POS+7:SPORT_POS], tdata_reg_next[SPORT_POS+15:SPORT_POS+8]} == cpu2ip_kvs_uport_reg) begin
						if (tdata_reg_next[MEMC_MAGIC_POS+7:MEMC_MAGIC_POS] == PROTOCOL_BINARY_RES && 
							tdata_reg_next[MEMC_OPCODE_POS+7:MEMC_OPCODE_POS] == PROTOCOL_BINARY_CMD_GET && 
							tdata_reg_next[MEMC_RESRVD_POS+15:MEMC_RESRVD_POS] == 16'h0 &&
							totlen_in[31:9] == 23'h0 && diven) begin
							both_traffic_en_next = 1;
							$display("both traffic: Response GET");
						end else begin
							$display("Normal port: Response SET or Delete");
						end
					end 
`endif /* WRITE_THROUGH */
				end
				if((!full_send0 && !full_send1) && dummy_tvalid) begin
					state_next = IN_PACKET;
				end
			end
		end // case: MODULE_HEADER

		IN_PACKET: begin
			if(dummy_tlast && dummy_tvalid && (!full_send0 && !full_send1)) begin
				state_next = MODULE_HEADER;
				kvs_data_en_next = 0;
				both_traffic_en_next = 0;
			end
		end
	endcase // case (state)
end // always @ (*)

`ifdef SIMULATION_DEBUG
wire set_en = state == MODULE_HEADER && !data_reg_stage2_empty && 
              tdata_reg[ETH_TYPE_POS+15:ETH_TYPE_POS] == IP_TYPE && 
              tdata_reg[IP_PROTO_POS+7:IP_PROTO_POS]  == UDP_PROTO && 
              tdata_reg_next[MEMC_MAGIC_POS+7:MEMC_MAGIC_POS] == PROTOCOL_BINARY_REQ && 
              (tdata_reg_next[MEMC_OPCODE_POS+7:MEMC_OPCODE_POS] == PROTOCOL_BINARY_CMD_SET || 
              tdata_reg_next[MEMC_OPCODE_POS+7:MEMC_OPCODE_POS] == PROTOCOL_BINARY_CMD_DELETE) ;
`endif /*SIMULATION_DEBUG*/


always @(posedge axis_aclk) begin
	if(~axis_resetn) begin
		state <= MODULE_HEADER;
		data_reg_stage1 <= 0;
		data_reg_stage1_empty <= 1;
		data_reg_stage2 <= 0;
		data_reg_stage2_empty <= 1;
		kvs_data_en <= 0;
		both_traffic_en <= 0;
	end else begin
		kvs_data_en <= kvs_data_en_next;
		both_traffic_en <= both_traffic_en_next;
		state <= state_next;
		if ((!nearly_full_send0 || !nearly_full_send1 || data_reg_stage2_empty) && !data_reg_stage2_stop) begin
			data_reg_stage2 <= data_reg_stage2_input;
			data_reg_stage2_empty <= data_reg_stage1_empty;
		end 
		if (((!nearly_full_send0 || !nearly_full_send1 || data_reg_stage2_empty) && !data_reg_stage2_stop) || data_reg_stage1_empty) begin
			data_reg_stage1 <= dout_fifo;
			data_reg_stage1_empty <= empty_recv;
		end
	end
end

// Handle output
assign wr_en_recv = s_axis_tvalid && s_axis_tready && !nearly_full_recv;
assign wr_en_send0 = !data_reg_stage2_empty && !data_reg_stage2_stop && !nearly_full_send0 && (!kvs_period || both_traffic);
assign wr_en_send1 = !data_reg_stage2_empty && !data_reg_stage2_stop && !nearly_full_send1 && (kvs_period || both_traffic);

assign rd_en_recv =  ((((!full_send0 && !full_send1) || data_reg_stage2_empty) && !data_reg_stage2_stop) || data_reg_stage1_empty) && !empty_recv;
assign rd_en_send0 = !empty_send0 && m_axis_tready;
assign rd_en_send1 = !empty_send2 && kvs_m_axis_tready;
/*
 * FIFO Instance : 
 */
div_fallthrough_small_fifo #(
	.WIDTH(256+128+32+1),
	.MAX_DEPTH_BITS(4)
) inst_recv_fifo (
	.din        ({s_axis_tlast, s_axis_tuser, s_axis_tkeep, s_axis_tdata}),     // Data in
	.wr_en      (wr_en_recv),   // Write enable
	.rd_en      (rd_en_recv),   // Read the next word
	.dout       (dout_fifo),    // Data out
	.full       (full_recv),
	.nearly_full(nearly_full_recv),
	.prog_full  (),
	.empty      (empty_recv),
	.reset      (!axis_resetn ),
	.clk        (axis_aclk)
);

div_fallthrough_small_fifo #(
	.WIDTH(256+128+32+1),
	.MAX_DEPTH_BITS(4)
) inst_send0_fifo (
	.din        ( data_reg_stage2 ),
	.wr_en      ( wr_en_send0 ),
	.rd_en      ( rd_en_send0 ),
	.dout       ( {m_axis_tlast, m_axis_tuser, m_axis_tkeep, m_axis_tdata} ),
	.full       ( full_send0        ),
	.nearly_full( nearly_full_send0 ),
	.prog_full  (),
	.empty      ( empty_send0  ),
	.reset      ( !axis_resetn ),
	.clk        ( axis_aclk    )
);


wire [256+128+32+1-1:0] send1_dout;
div_fallthrough_small_fifo #(
	.WIDTH(256+128+32+1),
	.MAX_DEPTH_BITS(7)
) inst_send1_0_fifo (
	.din        ( data_reg_stage2 ),
	.wr_en      ( wr_en_send1 ),
	.rd_en      ( !empty_send1 /*&& !full_send2*/),
	.dout       ( send1_dout ),
	.full       ( full_send1        ),
	.nearly_full( nearly_full_send1 ),
	.prog_full  (),
	.empty      ( empty_send1  ),
	.reset      ( !axis_resetn ),
	.clk        ( axis_aclk    )
);

`ifdef XILINX_FIFO
wire [10:0] dcount;
wire room4dcount = (16'd32768 - {dcount, 5'd0}) < send1_dout[256+32+16-1:256+32-1];
`endif
reg [7:0]cnt;
reg [31:0] drop_cnt;
reg drop_en_reg;
`ifdef XILINX_FIFO
wire drop_en = (cnt == 0 && room4dcount && !empty_send1 /*&& !full_send2*/) ? 1'b1 : drop_en_reg;
`else
wire drop_en = (cnt == 0 && nearly_full_send2 && !empty_send1 /*&& !full_send2*/) ? 1'b1 : drop_en_reg;
`endif
always @ (posedge axis_aclk)
	if (!axis_resetn) begin
		drop_en_reg <= 0;
		drop_cnt    <= 0;
		cnt         <= 0;
	end else begin
		if (!empty_send1 /*&& !full_send2*/) begin
			if (send1_dout[256+128+32+1-1] == 1)
				cnt <= 0;
			else
				cnt <= cnt + 1;
		end
`ifdef XILINX_FIFO
		if (cnt == 0 && room4dcount && !empty_send1 /*&& !full_send2*/) begin
`else
		if (cnt == 0 && nearly_full_send2 && !empty_send1 /*&& !full_send2*/) begin
`endif
			drop_en_reg <= 1'b1;
			drop_cnt <= drop_cnt + 1;
		end else if (send1_dout[256+128+32+1-1] == 1 && !empty_send1 /*&& !full_send2*/) begin
			drop_en_reg <= 1'b0;
		end
	end

`ifdef XILINX_FIFO
sfifo417 inst_send1_1_fifo (
	.almost_full ( nearly_full_send2 ),  
	.data_count  ( dcount ), 
	.srst        ( !axis_resetn ),                
`else
div_fallthrough_small_fifo #(
	.WIDTH(256+128+32+1),
	.MAX_DEPTH_BITS(10) //63
) inst_send1_1_fifo (
	.reset      ( !axis_resetn),
	.nearly_full( nearly_full_send2 ),
	.prog_full  (),
`endif
	.din        ( send1_dout ),
	.wr_en      ( !empty_send1 && !full_send2 && drop_en == 0 ),
	.rd_en      ( rd_en_send1 ),
	.dout       ( {kvs_m_axis_tlast, kvs_m_axis_tuser, kvs_m_axis_tkeep, kvs_m_axis_tdata} ),
	.full       ( full_send2   ),
	.empty      ( empty_send2  ),
	.clk        ( axis_aclk    )
);

assign m_axis_tvalid = !empty_send0;
assign kvs_m_axis_tvalid = !empty_send2;
assign s_axis_tready = ~nearly_full_recv;

/*
 * Packet rate counter
 */
reg         lake_switch_ondemand; /* 1: NIC, 0: host */
reg  [31:0] time_counter;
reg  [31:0] rate_counter;
wire [31:0] resol_counter; /* From host */
wire [31:0] thrd_counter;  /* From host */ 

always @ (posedge axis_aclk) begin
	if (!axis_resetn) begin
		time_counter <= 0;
		rate_counter <= 0;
		lake_switch_ondemand <= 0;
	end else begin
		if (resol_counter - 1 != time_counter) begin
			time_counter  <= #1 time_counter + 1;
			rate_counter  <= #1 (s_axis_tvalid && s_axis_tlast && s_axis_tready) ? rate_counter + 1 : rate_counter;
		end else begin
			time_counter <= 0;
			if (rate_counter > thrd_counter) 
				lake_switch_ondemand <= 1;
			else
				lake_switch_ondemand <= 0;
			rate_counter <= 0;
		end
	end
end

reg  [`REG_ID_BITS]      id_reg;
reg  [`REG_VERSION_BITS] version_reg;
reg  [`REG_PKTIN_BITS]   pktin_reg;
reg  [31:0] queries_l1hit_reg, queries_l1miss_reg;
wire [31:0] cpu2ip_local_ipaddr_reg;
reg  [31:0] ip2cpu_local_ipaddr_reg;
wire [7:0] cpu2ip_diven_reg;
reg  [7:0] ip2cpu_diven_reg;
reg  [31:0] normal_outbound_pkts, kvs_outbound_pkts;
wire queries_clear;
wire queries_reg_clear;
wire resetn_sync;

div_cpu_regs #(
	.C_BASE_ADDRESS        ( C_BASEADDR     ),
	.C_S_AXI_DATA_WIDTH    ( C_S_AXI_DATA_WIDTH ),
	.C_S_AXI_ADDR_WIDTH    ( C_S_AXI_ADDR_WIDTH )
) u_cpu_regs (
	// General ports
	.clk                   ( axis_aclk   ),
	.resetn                ( axis_resetn ),
	// Global Registers
	.cpu_resetn_soft       (),
	.resetn_soft           (),
	.resetn_sync           ( resetn_sync ),

	// Register ports
	.id_reg                (id_reg),
	.version_reg           (version_reg),
	.reset_reg             (reset_reg),
	.ip2cpu_flip_reg       (),
	.cpu2ip_flip_reg       (),
	.ip2cpu_debug_reg      (),
	.cpu2ip_debug_reg      (),
	.pktin_reg             ( pktin_reg ),
	.pktin_reg_clear       (),
	.norm_pktout_reg       ( normal_outbound_pkts ),
	.norm_pktout_reg_clear ( ),
	.kvs_pktout_reg        ( kvs_outbound_pkts ),
	.kvs_pktout_reg_clear  ( ),
	.ip2cpu_local_ipaddr_reg  ( ip2cpu_local_ipaddr_reg ),
	.cpu2ip_local_ipaddr_reg  ( cpu2ip_local_ipaddr_reg ),
	.ip2cpu_kvs_uport_reg     ( ip2cpu_kvs_uport_reg ),
	.cpu2ip_kvs_uport_reg     ( cpu2ip_kvs_uport_reg ),
	.ip2cpu_diven_reg         ( ip2cpu_diven_reg ),
	.cpu2ip_diven_reg         ( cpu2ip_diven_reg ),
	.drop_cnt                 ( drop_cnt ),

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

assign reset_registers = reset_reg[4];

always @ (posedge axis_aclk)
	if (~resetn_sync) begin
		id_reg      <= #1 `REG_ID_DEFAULT;
		version_reg <= #1 `REG_VERSION_DEFAULT;
		pktin_reg   <= #1 `REG_PKTIN_DEFAULT;
		ip2cpu_local_ipaddr_reg <= #1 `REG_IPADDR_DEFAULT;
		ip2cpu_kvs_uport_reg <= #1 `REG_KVSPORT_DEFAULT;
		normal_outbound_pkts <= #1 0;
		kvs_outbound_pkts    <= #1 0;
		ip2cpu_diven_reg     <= #1 `REG_DIVEN_DEFAULT;
	end else begin
		id_reg      <= #1 `REG_ID_DEFAULT;
		version_reg <= #1 `REG_VERSION_DEFAULT;
		pktin_reg   <= #1 (s_axis_tvalid && s_axis_tlast && s_axis_tready) ? pktin_reg + 1 : pktin_reg;
		ip2cpu_local_ipaddr_reg <= #1 cpu2ip_local_ipaddr_reg;
		ip2cpu_kvs_uport_reg    <= #1 cpu2ip_kvs_uport_reg;
		ip2cpu_diven_reg        <= #1 cpu2ip_diven_reg;
		if (m_axis_tlast && m_axis_tready && m_axis_tvalid) begin
			normal_outbound_pkts <= #1 normal_outbound_pkts + 1;
		end
		if (kvs_m_axis_tlast && kvs_m_axis_tready && kvs_m_axis_tvalid) begin
			kvs_outbound_pkts <= #1 kvs_outbound_pkts + 1;
		end
	end

assign diven = cpu2ip_diven_reg[0];

endmodule 

