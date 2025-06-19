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


/* Common definitions */           
`define Enable          1'b1       
`define Disable         1'b0       
`define Enable_         1'b0       
`define Disable_        1'b1       
`define High            1'b1       
`define Low             1'b0       
`define Write           1'b1       
`define Read            1'b0       
`define NULL            0          

/* Data width (165-bit data + 2-bit type) */ 
`define DATAW           166                  
`define DATAW_P1        167                  
`define TYPE_LSB        165                  
`define TYPE_MSB        166                  

/* Flit type */                 
`define TYPEW           1       
`define TYPEW_P1        2       
`define TYPE_NONE       2'b00   
`define TYPE_HDR        2'b01   
`define TYPE_DATA       2'b10   
`define TYPE_TAIL       2'b11   

/* Input FIFO (4-element) */ 
`define FIFO            3 
`define FIFO_P1         4 
`define FIFOD           1 
`define FIFOD_P1        2 

/* Port number (6-port) */        
`define PORT            5         
`define PORT_P1         6         
`define PORTW           2         
`define PORTW_P1        3         

/* Vch number (2-VC) */   
`define VCH             1 
`define VCH_P1          2 
`define VCHW            0 
`define VCHW_P1         1 

/* Node number (36-node) */        
`define NODE            35         
`define NODE_P1         36         
`define NODEW           5         
`define NODEW_P1        6         

/* Routing (Dimension-order routing) */
`define ENTRYW          5         
`define ENTRYW_P1       6         
`define DST_LSB         0          
`define DST_MSB         5         
`define ARRAYW          2         
`define ARRAYW_P1       3         
`define XPOS_LSB        0          
`define XPOS_MSB        2         
`define YPOS_LSB        3         
`define YPOS_MSB        5         
`define ARRAY_DIV2      3         
