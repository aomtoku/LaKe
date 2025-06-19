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

`include "define.h" 
module mux ( 
        idata_0,  
        ivalid_0, 
        ivch_0,   

        idata_1,  
        ivalid_1, 
        ivch_1,   

        idata_2,  
        ivalid_2, 
        ivch_2,   

        idata_3,  
        ivalid_3, 
        ivch_3,   

        idata_4,  
        ivalid_4, 
        ivch_4,   

        idata_5,  
        ivalid_5, 
        ivch_5,   

        sel, 

        odata,  
        ovalid, 
        ovch    
);

input    [`DATAW:0]    idata_0;  
input                  ivalid_0; 
input    [`VCHW:0]     ivch_0;   
input    [`DATAW:0]    idata_1;  
input                  ivalid_1; 
input    [`VCHW:0]     ivch_1;   
input    [`DATAW:0]    idata_2;  
input                  ivalid_2; 
input    [`VCHW:0]     ivch_2;   
input    [`DATAW:0]    idata_3;  
input                  ivalid_3; 
input    [`VCHW:0]     ivch_3;   
input    [`DATAW:0]    idata_4;  
input                  ivalid_4; 
input    [`VCHW:0]     ivch_4;   
input    [`DATAW:0]    idata_5;  
input                  ivalid_5; 
input    [`VCHW:0]     ivch_5;   

input    [`PORT:0]     sel;  

output   [`DATAW:0]    odata;  
output                 ovalid; 
output   [`VCHW:0]     ovch;   

assign odata = 
                (sel == `PORT_P1'b000001) ? idata_0 : 
                (sel == `PORT_P1'b000010) ? idata_1 : 
                (sel == `PORT_P1'b000100) ? idata_2 : 
                (sel == `PORT_P1'b001000) ? idata_3 : 
                (sel == `PORT_P1'b010000) ? idata_4 : 
                (sel == `PORT_P1'b100000) ? idata_5 : 
                `DATAW_P1'b0;

assign ovalid = 
                (sel == `PORT_P1'b000001) ? ivalid_0 : 
                (sel == `PORT_P1'b000010) ? ivalid_1 : 
                (sel == `PORT_P1'b000100) ? ivalid_2 : 
                (sel == `PORT_P1'b001000) ? ivalid_3 : 
                (sel == `PORT_P1'b010000) ? ivalid_4 : 
                (sel == `PORT_P1'b100000) ? ivalid_5 : 
                1'b0;
assign ovch = 
                (sel == `PORT_P1'b000001) ? ivch_0 : 
                (sel == `PORT_P1'b000010) ? ivch_1 : 
                (sel == `PORT_P1'b000100) ? ivch_2 : 
                (sel == `PORT_P1'b001000) ? ivch_3 : 
                (sel == `PORT_P1'b010000) ? ivch_4 : 
                (sel == `PORT_P1'b100000) ? ivch_5 : 
                `VCHW_P1'b0;
endmodule
