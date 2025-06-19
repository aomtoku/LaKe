#
# Copyright (c) 2019 Yuta Tokusashi
# All rights reserved.
#
# This software was developed by
# Stanford University and the University of Cambridge Computer Laboratory
# under National Science Foundation under Grant No. CNS-0855268,
# the University of Cambridge Computer Laboratory under EPSRC INTERNET Project EP/H040536/1 and
# by the University of Cambridge Computer Laboratory under DARPA/AFRL contract FA8750-11-C-0249 ("MRC2"), 
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

# Vivado Launch Script
#### Change design settings here #######
set design db
set top db
set device xc7vx690t-3-ffg1761
set proj_dir ./ip_proj
set ip_version 1.01
set lib_name NetFPGA
#####################################
# set IP paths
#####################################
set   project_dir    project

#####################################
# set mode "storage" or "cache"
#####################################
set   db_mode "cache"
#set axi_lite_ipif_ip_path ../../../xilinx/cores/axi_lite_ipif/source/
#####################################
# Project Settings
#####################################
create_project -name ${design} -force -dir "./${project_dir}" -part ${device} -ip
set_property source_mgmt_mode All [current_project]
set_property top ${top} [current_fileset]
set_property ip_repo_paths $::env(SUME_FOLDER)/lib/hw/  [current_fileset]
if {[string match "cache" $db_mode]} {
	set_property verilog_define { {CACHE_MODE=1} } [current_fileset]
}
puts "Creating Database Cores IP (designed by aom)"
# Project Constraints
#####################################
# Project Structure & IP Build
#####################################
read_verilog "hdl/input_arbiter_mod.v"
read_verilog "hdl/cb.v"
read_verilog "hdl/muxcont.v"
read_verilog "hdl/mux.v"
read_verilog "hdl/arb.v"
read_verilog "hdl/prio_enc.v"
read_verilog "hdl/string_pe.v"
read_verilog "hdl/dram_cont.v"
read_verilog "hdl/sram_cont.v"
read_verilog "hdl/lake_fallthrough_small_fifo.v"
read_verilog "hdl/lake_small_fifo.v"
read_verilog "hdl/crc32.v"
read_verilog "hdl/axis2convert.v"
read_verilog "hdl/PE.v"
read_verilog "hdl/small_cache.v"
read_verilog "hdl/small_hcache.v"
read_verilog "hdl/db_cpu_regs_defines.v"
read_verilog "hdl/db_cpu_regs.v"
read_verilog "hdl/db.v"

if {[string match "cache" $db_mode]} {
	read_vhdl "hdl/cam_control.vhd"
	read_vhdl "hdl/cam_decoder.vhd"
	read_vhdl "hdl/cam_init_file_pack_xst.vhd"
	read_vhdl "hdl/cam_input_ternary_ternenc.vhd"
	read_vhdl "hdl/cam_input_ternary.vhd"
	read_vhdl "hdl/cam_input.vhd"
	read_vhdl "hdl/cam_match_enc.vhd"
	read_vhdl "hdl/cam_mem_blk_extdepth_prim.vhd"
	read_vhdl "hdl/cam_mem_blk_extdepth.vhd"
	read_vhdl "hdl/cam_mem_blk.vhd"
	read_vhdl "hdl/cam_mem_srl16_block.vhd"
	read_vhdl "hdl/cam_mem_srl16_block_word.vhd"
	read_vhdl "hdl/cam_mem_srl16_ternwrcomp.vhd"
	read_vhdl "hdl/cam_mem_srl16.vhd"
	read_vhdl "hdl/cam_mem_srl16_wrcomp.vhd"
	read_vhdl "hdl/cam_mem.vhd"
	read_vhdl "hdl/cam_pkg.vhd"
	read_vhdl "hdl/cam_regouts.vhd"
	read_vhdl "hdl/cam_rtl.vhd"
	read_vhdl "hdl/cam_top.vhd"
	read_vhdl "hdl/cam.vhd"
	read_vhdl "hdl/dmem.vhd"
	read_verilog "hdl/db_cam.v"
	read_verilog "hdl/db_cam_wrapper.v"
	read_verilog "hdl/db_ncams.v"
	read_verilog "hdl/db_prio_enc_ncams.v"
	read_verilog "hdl/key_lookup.v"
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
ipx::package_project

update_ip_catalog -rebuild 
ipx::infer_user_parameters [ipx::current_core]

create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.0 -module_name sume_mig_sram -dir ./${project_dir}
set_property -dict [list CONFIG.XML_INPUT_FILE {./../../mig_sram.prj}] [get_ips sume_mig_sram]
generate_target {instantiation_template} [get_files ./${project_dir}/sume_mig_sram/sume_mig_sram.xci]
generate_target all [get_files  ./${project_dir}/sume_mig_sram/sume_mig_sram.xci]
ipx::package_project -force -import_files ./${project_dir}/sume_mig_sram/sume_mig_sram.xci

create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.0 -module_name sume_mig_drama -dir ./${project_dir}
set_property -dict [list CONFIG.XML_INPUT_FILE {./../../mig_sume_ddr3A.prj}] [get_ips sume_mig_drama]
generate_target {instantiation_template} [get_files ./${project_dir}/sume_mig_drama/sume_mig_drama.xci]
generate_target all [get_files  ./${project_dir}/sume_mig_drama/sume_mig_drama.xci]
ipx::package_project -force -import_files ./${project_dir}/sume_mig_drama/sume_mig_drama.xci

create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.0 -module_name sume_mig_dramb -dir ./${project_dir}
set_property -dict [list CONFIG.XML_INPUT_FILE {./../../mig_sume_ddr3B.prj}] [get_ips sume_mig_dramb]
generate_target {instantiation_template} [get_files ./${project_dir}/sume_mig_dramb/sume_mig_dramb.xci]
generate_target all [get_files  ./${project_dir}/sume_mig_dramb/sume_mig_dramb.xci]
ipx::package_project -force -import_files ./${project_dir}/sume_mig_dramb/sume_mig_dramb.xci

create_ip -name axis_switch -vendor xilinx.com -library ip -version 1.1 -module_name axis_switch_0 -dir ./${project_dir}
set_property -dict [list CONFIG.NUM_SI {6} \
                         CONFIG.NUM_MI {6} \
                         CONFIG.TDATA_NUM_BYTES {32} \
                         CONFIG.HAS_TKEEP {1} \
                         CONFIG.HAS_TLAST {1} \
                         CONFIG.TUSER_WIDTH {128} \
                         CONFIG.ARB_ALGORITHM {1} \
                         CONFIG.ARB_ON_TLAST {1} \
                         CONFIG.ARB_ON_MAX_XFERS {16} \
                         CONFIG.TDEST_WIDTH {3} \
                         CONFIG.M00_S00_CONNECTIVITY {1} \
                         CONFIG.M01_S01_CONNECTIVITY {1} \
                         CONFIG.M01_S02_CONNECTIVITY {1} \
                         CONFIG.M01_S03_CONNECTIVITY {1} \
                         CONFIG.M01_S04_CONNECTIVITY {1} \
                         CONFIG.M01_S05_CONNECTIVITY {1} \
                         CONFIG.M02_S01_CONNECTIVITY {1} \
                         CONFIG.M02_S02_CONNECTIVITY {1} \
                         CONFIG.M02_S03_CONNECTIVITY {1} \
                         CONFIG.M02_S04_CONNECTIVITY {1} \
                         CONFIG.M02_S05_CONNECTIVITY {1} \
                         CONFIG.M03_S01_CONNECTIVITY {1} \
                         CONFIG.M03_S02_CONNECTIVITY {1} \
                         CONFIG.M03_S03_CONNECTIVITY {1} \
                         CONFIG.M03_S04_CONNECTIVITY {1} \
                         CONFIG.M03_S05_CONNECTIVITY {1} \
                         CONFIG.M04_S01_CONNECTIVITY {1} \
                         CONFIG.M04_S02_CONNECTIVITY {1} \
                         CONFIG.M04_S03_CONNECTIVITY {1} \
                         CONFIG.M04_S04_CONNECTIVITY {1} \
                         CONFIG.M04_S05_CONNECTIVITY {1} \
                         CONFIG.M05_S01_CONNECTIVITY {1} \
                         CONFIG.M05_S02_CONNECTIVITY {1} \
                         CONFIG.M05_S03_CONNECTIVITY {1} \
                         CONFIG.M05_S04_CONNECTIVITY {1} \
                         CONFIG.M05_S05_CONNECTIVITY {1} \
                         CONFIG.DECODER_REG {1} ] [get_ips axis_switch_0]
generate_target {instantiation_template} [get_files ./${project_dir}/axis_switch_0/axis_switch_0.xci]
generate_target all [get_files  ./${project_dir}/axis_switch_0/axis_switch_0.xci]
ipx::package_project -force -import_files ./${project_dir}/axis_switch_0/axis_switch_0.xci

create_ip -name axis_switch -vendor xilinx.com -library ip -version 1.1 -module_name axis_s_switch_0 -dir ./${project_dir}
set_property -dict [list CONFIG.NUM_SI {1} \
                         CONFIG.NUM_MI {5} \
                         CONFIG.TDATA_NUM_BYTES {32} \
                         CONFIG.HAS_TKEEP {1} \
                         CONFIG.HAS_TLAST {1} \
                         CONFIG.TUSER_WIDTH {128} \
                         CONFIG.ARB_ALGORITHM {1} \
                         CONFIG.ARB_ON_TLAST {1} \
                         CONFIG.ARB_ON_MAX_XFERS {10} \
                         CONFIG.TDEST_WIDTH {3} \
                         CONFIG.DECODER_REG {1} ] [get_ips axis_s_switch_0]
generate_target {instantiation_template} [get_files ./${project_dir}/axis_s_switch_0/axis_s_switch_0.xci]
generate_target all [get_files  ./${project_dir}/axis_s_switch_0/axis_s_switch_0.xci]
ipx::package_project -force -import_files ./${project_dir}/axis_s_switch_0/axis_s_switch_0.xci

create_ip -name axis_switch -vendor xilinx.com -library ip -version 1.1 -module_name axis_m_switch_0 -dir ./${project_dir}
set_property -dict [list CONFIG.NUM_SI {5} \
                         CONFIG.NUM_MI {1} \
                         CONFIG.TDATA_NUM_BYTES {32} \
                         CONFIG.HAS_TKEEP {1} \
                         CONFIG.HAS_TLAST {1} \
                         CONFIG.TUSER_WIDTH {128} \
                         CONFIG.ARB_ALGORITHM {1} \
                         CONFIG.ARB_ON_TLAST {1} \
                         CONFIG.ARB_ON_MAX_XFERS {3} \
                         CONFIG.TDEST_WIDTH {3} \
                         CONFIG.DECODER_REG {1} ] [get_ips axis_m_switch_0]
generate_target {instantiation_template} [get_files ./${project_dir}/axis_m_switch_0/axis_m_switch_0.xci]
generate_target all [get_files  ./${project_dir}/axis_m_switch_0/axis_m_switch_0.xci]
ipx::package_project -force -import_files ./${project_dir}/axis_m_switch_0/axis_m_switch_0.xci

create_ip -name axis_switch -vendor xilinx.com -library ip -version 1.1 -module_name mem_switch_0 -dir ./${project_dir}
set_property -dict [list CONFIG.NUM_SI {7} \
                         CONFIG.NUM_MI {7} \
                         CONFIG.TDATA_NUM_BYTES {64} \
                         CONFIG.HAS_TKEEP {1} \
                         CONFIG.HAS_TLAST {1} \
                         CONFIG.TUSER_WIDTH {128} \
                         CONFIG.ARB_ALGORITHM {1} \
                         CONFIG.TDEST_WIDTH {3} \
                         CONFIG.DECODER_REG {1} ] [get_ips mem_switch_0]
generate_target {instantiation_template} [get_files ./${project_dir}/mem_switch_0/mem_switch_0.xci]
generate_target all [get_files  ./${project_dir}/mem_switch_0/mem_switch_0.xci]
ipx::package_project -force -import_files ./${project_dir}/mem_switch_0/mem_switch_0.xci

create_ip -name axis_switch -vendor xilinx.com -library ip -version 1.1 -module_name cache_switch_0 -dir ./${project_dir}
set_property -dict [list CONFIG.NUM_SI {8} \
                         CONFIG.NUM_MI {8} \
                         CONFIG.TDATA_NUM_BYTES {64} \
                         CONFIG.HAS_TKEEP {1} \
                         CONFIG.HAS_TLAST {1} \
                         CONFIG.TUSER_WIDTH {128} \
                         CONFIG.ARB_ALGORITHM {1} \
                         CONFIG.TDEST_WIDTH {3} \
                         CONFIG.DECODER_REG {1} ] [get_ips cache_switch_0]
generate_target {instantiation_template} [get_files ./${project_dir}/cache_switch_0/cache_switch_0.xci]
generate_target all [get_files  ./${project_dir}/cache_switch_0/cache_switch_0.xci]
ipx::package_project -force -import_files ./${project_dir}/cache_switch_0/cache_switch_0.xci

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.3 -module_name cache_1k -dir ./${project_dir}
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} \
                         CONFIG.Algorithm {Minimum_Area} \
                         CONFIG.Assume_Synchronous_Clk {true} \
                         CONFIG.Write_Width_A {535} \
                         CONFIG.Write_Depth_A {1024} \
                         CONFIG.Operating_Mode_A {READ_FIRST} \
                         CONFIG.Use_RSTA_Pin {false} \
                         CONFIG.Read_Width_A {535} \
                         CONFIG.Write_Width_B {535} \
                         CONFIG.Read_Width_B {535} \
                         CONFIG.Enable_B {Use_ENB_Pin} \
                         CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
                         CONFIG.Port_B_Clock {100} \
                         CONFIG.Port_B_Write_Rate {50} \
                         CONFIG.Port_B_Enable_Rate {100}] [get_ips cache_1k]
generate_target {instantiation_template} [get_files ./${project_dir}/cache_1k/cache_1k.xci]
generate_target all [get_files  ./${project_dir}/cache_1k/cache_1k.xci]
ipx::package_project -force -import_files ./${project_dir}/cache_1k/cache_1k.xci

create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.3 -module_name hcache_1k -dir ./${project_dir}
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} \
                         CONFIG.Algorithm {Minimum_Area} \
                         CONFIG.Assume_Synchronous_Clk {true} \
                         CONFIG.Write_Width_A {87} \
                         CONFIG.Write_Depth_A {1024} \
                         CONFIG.Operating_Mode_A {READ_FIRST} \
                         CONFIG.Use_RSTA_Pin {false} \
                         CONFIG.Read_Width_A {87} \
                         CONFIG.Write_Width_B {87} \
                         CONFIG.Read_Width_B {87} \
                         CONFIG.Enable_B {Use_ENB_Pin} \
                         CONFIG.Register_PortB_Output_of_Memory_Primitives {true} \
                         CONFIG.Port_B_Clock {100} \
                         CONFIG.Port_B_Write_Rate {50} \
                         CONFIG.Port_B_Enable_Rate {100}] [get_ips hcache_1k]
generate_target {instantiation_template} [get_files ./${project_dir}/hcache_1k/hcache_1k.xci]
generate_target all [get_files  ./${project_dir}/hcache_1k/hcache_1k.xci]
ipx::package_project -force -import_files ./${project_dir}/hcache_1k/hcache_1k.xci

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_624 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Almost_Full_Flag {true} \
                         CONFIG.Programmable_Full_Type {Single_Programmable_Full_Threshold_Constant} \
                         CONFIG.Input_Data_Width {624} \
                         CONFIG.Input_Depth {32} \
                         CONFIG.Output_Data_Width {624} \
                         CONFIG.Output_Depth {32} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {5} \
                         CONFIG.Write_Data_Count_Width {5} \
                         CONFIG.Read_Data_Count_Width {5} \
                         CONFIG.Full_Threshold_Assert_Value {26} \
                         CONFIG.Full_Threshold_Negate_Value {25} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_624]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_624/asfifo_624.xci]
generate_target all [get_files  ./${project_dir}/asfifo_624/asfifo_624.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_624/asfifo_624.xci


create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_552 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Input_Data_Width {552} \
                         CONFIG.Input_Depth {16} \
                         CONFIG.Output_Data_Width {552} \
                         CONFIG.Output_Depth {16} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {4} \
                         CONFIG.Write_Data_Count_Width {4} \
                         CONFIG.Read_Data_Count_Width {4} \
                         CONFIG.Full_Threshold_Assert_Value {15} \
                         CONFIG.Full_Threshold_Negate_Value {14} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_552]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_552/asfifo_552.xci]
generate_target all [get_files  ./${project_dir}/asfifo_552/asfifo_552.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_552/asfifo_552.xci


create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_64 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Input_Data_Width {64} \
                         CONFIG.Input_Depth {16} \
                         CONFIG.Output_Data_Width {64} \
                         CONFIG.Output_Depth {16} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {4} \
                         CONFIG.Write_Data_Count_Width {4} \
                         CONFIG.Read_Data_Count_Width {4} \
                         CONFIG.Full_Threshold_Assert_Value {15} \
                         CONFIG.Full_Threshold_Negate_Value {14} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_64]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_64/asfifo_64.xci]
generate_target all [get_files  ./${project_dir}/asfifo_64/asfifo_64.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_64/asfifo_64.xci


create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_18 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Input_Data_Width {18} \
                         CONFIG.Input_Depth {16} \
                         CONFIG.Output_Data_Width {18} \
                         CONFIG.Output_Depth {16} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {4} \
                         CONFIG.Write_Data_Count_Width {4} \
                         CONFIG.Read_Data_Count_Width {4} \
                         CONFIG.Full_Threshold_Assert_Value {15} \
                         CONFIG.Full_Threshold_Negate_Value {14} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_18]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_18/asfifo_18.xci]
generate_target all [get_files  ./${project_dir}/asfifo_18/asfifo_18.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_18/asfifo_18.xci

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_146 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Input_Data_Width {146} \
                         CONFIG.Input_Depth {16} \
                         CONFIG.Output_Data_Width {146} \
                         CONFIG.Output_Depth {16} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {4} \
                         CONFIG.Write_Data_Count_Width {4} \
                         CONFIG.Read_Data_Count_Width {4} \
                         CONFIG.Full_Threshold_Assert_Value {15} \
                         CONFIG.Full_Threshold_Negate_Value {14} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_146]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_146/asfifo_146.xci]
generate_target all [get_files  ./${project_dir}/asfifo_146/asfifo_146.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_146/asfifo_146.xci

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_167 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Input_Data_Width {167} \
                         CONFIG.Input_Depth {16} \
                         CONFIG.Output_Data_Width {167} \
                         CONFIG.Output_Depth {16} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {4} \
                         CONFIG.Write_Data_Count_Width {4} \
                         CONFIG.Read_Data_Count_Width {4} \
                         CONFIG.Full_Threshold_Assert_Value {15} \
                         CONFIG.Full_Threshold_Negate_Value {14} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_167]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_167/asfifo_167.xci]
generate_target all [get_files  ./${project_dir}/asfifo_167/asfifo_167.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_167/asfifo_167.xci

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_43 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Input_Data_Width {43} \
                         CONFIG.Input_Depth {16} \
                         CONFIG.Output_Data_Width {43} \
                         CONFIG.Output_Depth {16} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {4} \
                         CONFIG.Write_Data_Count_Width {4} \
                         CONFIG.Read_Data_Count_Width {4} \
                         CONFIG.Full_Threshold_Assert_Value {15} \
                         CONFIG.Full_Threshold_Negate_Value {14} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_43]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_43/asfifo_43.xci]
generate_target all [get_files  ./${project_dir}/asfifo_43/asfifo_43.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_43/asfifo_43.xci

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.1 -module_name asfifo_44 -dir ./${project_dir}
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
                         CONFIG.Performance_Options {First_Word_Fall_Through} \
                         CONFIG.Input_Data_Width {44} \
                         CONFIG.Input_Depth {16} \
                         CONFIG.Output_Data_Width {44} \
                         CONFIG.Output_Depth {16} \
                         CONFIG.Reset_Type {Asynchronous_Reset} \
                         CONFIG.Full_Flags_Reset_Value {1} \
                         CONFIG.Data_Count_Width {4} \
                         CONFIG.Write_Data_Count_Width {4} \
                         CONFIG.Read_Data_Count_Width {4} \
                         CONFIG.Full_Threshold_Assert_Value {15} \
                         CONFIG.Full_Threshold_Negate_Value {14} \
                         CONFIG.Empty_Threshold_Assert_Value {4} \
                         CONFIG.Empty_Threshold_Negate_Value {5} \
                         CONFIG.Enable_Safety_Circuit {true}] [get_ips asfifo_44]
generate_target {instantiation_template} [get_files ./${project_dir}/asfifo_44/asfifo_44.xci]
generate_target all [get_files  ./${project_dir}/asfifo_44/asfifo_44.xci]
ipx::package_project -force -import_files ./${project_dir}/asfifo_44/asfifo_44.xci
## Debug
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list CONFIG.C_PROBE0_WIDTH {386} \
                         CONFIG.C_DATA_DEPTH {2048}] [get_ips ila_0]
generate_target {instantiation_template} [get_files ./${project_dir}/ila_0/ila_0.xci]
generate_target all [get_files  ./${project_dir}/ila_0/ila_0.xci]
ipx::package_project -force -import_files ./${project_dir}/ila_0/ila_0.xci


# Create IP Information
set_property name ${design} [ipx::current_core]
set_property library ${lib_name} [ipx::current_core]
set_property vendor_display_name {NetFPGA} [ipx::current_core]
set_property company_url {www.netfpga.org} [ipx::current_core]
set_property vendor {NetFPGA} [ipx::current_core]
set_property supported_families {{virtex7} {Production}} [ipx::current_core]
set_property taxonomy {{/NetFPGA/Generic}} [ipx::current_core]
set_property version ${ip_version} [ipx::current_core]
set_property display_name ${design} [ipx::current_core]
set_property description ${design} [ipx::current_core]


# Parameters

ipx::add_user_parameter {C_M_AXIS_DATA_WIDTH} [ipx::current_core]
set_property value_resolve_type {user} [ipx::get_user_parameter C_M_AXIS_DATA_WIDTH [ipx::current_core]]
set_property display_name {C_M_AXIS_DATA_WIDTH} [ipx::get_user_parameter C_M_AXIS_DATA_WIDTH [ipx::current_core]]
set_property value {256} [ipx::get_user_parameter C_M_AXIS_DATA_WIDTH [ipx::current_core]]
set_property value_format {long} [ipx::get_user_parameter C_M_AXIS_DATA_WIDTH [ipx::current_core]]

ipx::add_user_parameter {C_S_AXIS_DATA_WIDTH} [ipx::current_core]
set_property value_resolve_type {user} [ipx::get_user_parameter C_S_AXIS_DATA_WIDTH [ipx::current_core]]
set_property display_name {C_S_AXIS_DATA_WIDTH} [ipx::get_user_parameter C_S_AXIS_DATA_WIDTH [ipx::current_core]]
set_property value {256} [ipx::get_user_parameter C_S_AXIS_DATA_WIDTH [ipx::current_core]]
set_property value_format {long} [ipx::get_user_parameter C_S_AXIS_DATA_WIDTH [ipx::current_core]]

ipx::add_user_parameter {C_M_AXIS_TUSER_WIDTH} [ipx::current_core]
set_property value_resolve_type {user} [ipx::get_user_parameter C_M_AXIS_TUSER_WIDTH [ipx::current_core]]
set_property display_name {C_M_AXIS_TUSER_WIDTH} [ipx::get_user_parameter C_M_AXIS_TUSER_WIDTH [ipx::current_core]]
set_property value {128} [ipx::get_user_parameter C_M_AXIS_TUSER_WIDTH [ipx::current_core]]
set_property value_format {long} [ipx::get_user_parameter C_M_AXIS_TUSER_WIDTH [ipx::current_core]]

ipx::add_user_parameter {C_S_AXIS_TUSER_WIDTH} [ipx::current_core]
set_property value_resolve_type {user} [ipx::get_user_parameter C_S_AXIS_TUSER_WIDTH [ipx::current_core]]
set_property display_name {C_S_AXIS_TUSER_WIDTH} [ipx::get_user_parameter C_S_AXIS_TUSER_WIDTH [ipx::current_core]]
set_property value {128} [ipx::get_user_parameter C_S_AXIS_TUSER_WIDTH [ipx::current_core]]
set_property value_format {long} [ipx::get_user_parameter C_S_AXIS_TUSER_WIDTH [ipx::current_core]]

ipx::add_user_parameter {C_S_AXI_DATA_WIDTH} [ipx::current_core]
set_property value_resolve_type {user} [ipx::get_user_parameter C_S_AXI_DATA_WIDTH [ipx::current_core]]
set_property display_name {C_S_AXI_DATA_WIDTH} [ipx::get_user_parameter C_S_AXI_DATA_WIDTH [ipx::current_core]]
set_property value {32} [ipx::get_user_parameter C_S_AXI_DATA_WIDTH [ipx::current_core]]
set_property value_format {long} [ipx::get_user_parameter C_S_AXI_DATA_WIDTH [ipx::current_core]]

ipx::add_user_parameter {C_S_AXI_ADDR_WIDTH} [ipx::current_core]
set_property value_resolve_type {user} [ipx::get_user_parameter C_S_AXI_ADDR_WIDTH [ipx::current_core]]
set_property display_name {C_S_AXI_ADDR_WIDTH} [ipx::get_user_parameter C_S_AXI_ADDR_WIDTH [ipx::current_core]]
set_property value {32} [ipx::get_user_parameter C_S_AXI_ADDR_WIDTH [ipx::current_core]]
set_property value_format {long} [ipx::get_user_parameter C_S_AXI_ADDR_WIDTH [ipx::current_core]]

ipx::add_user_parameter {C_BASEADDR} [ipx::current_core]
set_property value_resolve_type {user} [ipx::get_user_parameter C_BASEADDR [ipx::current_core]]
set_property display_name {C_BASEADDR} [ipx::get_user_parameter C_BASEADDR [ipx::current_core]]
set_property value {0x00000000} [ipx::get_user_parameter C_BASEADDR [ipx::current_core]]
set_property value_format {bitstring} [ipx::get_user_parameter C_BASEADDR [ipx::current_core]]

ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis -of_objects [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis -of_objects [ipx::current_core]]

ipx::infer_user_parameters [ipx::current_core]
            
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
update_ip_catalog
close_project


