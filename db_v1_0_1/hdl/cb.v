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
module cb ( 
        idata_0,  
        ivalid_0, 
        ivch_0,   
        port_0,   
        req_0,    
        grt_0,    

        idata_1,  
        ivalid_1, 
        ivch_1,   
        port_1,   
        req_1,    
        grt_1,    

        idata_2,  
        ivalid_2, 
        ivch_2,   
        port_2,   
        req_2,    
        grt_2,    

        idata_3,  
        ivalid_3, 
        ivch_3,   
        port_3,   
        req_3,    
        grt_3,    

        idata_4,  
        ivalid_4, 
        ivch_4,   
        port_4,   
        req_4,    
        grt_4,    

        idata_5,  
        ivalid_5, 
        ivch_5,   
        port_5,   
        req_5,    
        grt_5,    

        odata_0,  
        ovalid_0, 
        ovch_0,   

        odata_1,  
        ovalid_1, 
        ovch_1,   

        odata_2,  
        ovalid_2, 
        ovch_2,   

        odata_3,  
        ovalid_3, 
        ovch_3,   

        odata_4,  
        ovalid_4, 
        ovch_4,   

        odata_5,  
        ovalid_5, 
        ovch_5,   

        clk, 
        rst  
);

input   [`DATAW:0]      idata_0;  
input                   ivalid_0; 
input   [`VCHW:0]       ivch_0;   
input   [`PORTW:0]      port_0;   
input                   req_0;    
output  [`PORT:0]       grt_0;    

input   [`DATAW:0]      idata_1;  
input                   ivalid_1; 
input   [`VCHW:0]       ivch_1;   
input   [`PORTW:0]      port_1;   
input                   req_1;    
output  [`PORT:0]       grt_1;    

input   [`DATAW:0]      idata_2;  
input                   ivalid_2; 
input   [`VCHW:0]       ivch_2;   
input   [`PORTW:0]      port_2;   
input                   req_2;    
output  [`PORT:0]       grt_2;    

input   [`DATAW:0]      idata_3;  
input                   ivalid_3; 
input   [`VCHW:0]       ivch_3;   
input   [`PORTW:0]      port_3;   
input                   req_3;    
output  [`PORT:0]       grt_3;    

input   [`DATAW:0]      idata_4;  
input                   ivalid_4; 
input   [`VCHW:0]       ivch_4;   
input   [`PORTW:0]      port_4;   
input                   req_4;    
output  [`PORT:0]       grt_4;    

input   [`DATAW:0]      idata_5;  
input                   ivalid_5; 
input   [`VCHW:0]       ivch_5;   
input   [`PORTW:0]      port_5;   
input                   req_5;    
output  [`PORT:0]       grt_5;    

output  [`DATAW:0]      odata_0;  
output                  ovalid_0; 
output  [`VCHW:0]       ovch_0;   

output  [`DATAW:0]      odata_1;  
output                  ovalid_1; 
output  [`VCHW:0]       ovch_1;   

output  [`DATAW:0]      odata_2;  
output                  ovalid_2; 
output  [`VCHW:0]       ovch_2;   

output  [`DATAW:0]      odata_3;  
output                  ovalid_3; 
output  [`VCHW:0]       ovch_3;   

output  [`DATAW:0]      odata_4;  
output                  ovalid_4; 
output  [`VCHW:0]       ovch_4;   

output  [`DATAW:0]      odata_5;  
output                  ovalid_5; 
output  [`VCHW:0]       ovch_5;   

input                   clk; 
input                   rst; 

wire    [`PORT:0]     cb_sel_0; 
wire    [`PORT:0]     cb_sel_1; 
wire    [`PORT:0]     cb_sel_2; 
wire    [`PORT:0]     cb_sel_3; 
wire    [`PORT:0]     cb_sel_4; 
wire    [`PORT:0]     cb_sel_5; 
wire    [`PORT:0]     cb_grt_0; 
wire    [`PORT:0]     cb_grt_1; 
wire    [`PORT:0]     cb_grt_2; 
wire    [`PORT:0]     cb_grt_3; 
wire    [`PORT:0]     cb_grt_4; 
wire    [`PORT:0]     cb_grt_5; 

muxcont #( 0 ) muxcont_0 ( 
        .port_0   ( port_0   ), 
        .req_0    ( req_0    ), 

        .port_1   ( port_1   ), 
        .req_1    ( req_1    ), 

        .port_2   ( port_2   ), 
        .req_2    ( req_2    ), 

        .port_3   ( port_3   ), 
        .req_3    ( req_3    ), 

        .port_4   ( port_4   ), 
        .req_4    ( req_4    ), 

        .port_5   ( port_5   ), 
        .req_5    ( req_5    ), 

        .sel ( cb_sel_0 ), 
        .grt ( cb_grt_0 ), 

        .clk ( clk ), 
        .rst ( rst ) 
); 

muxcont #( 1 ) muxcont_1 ( 
        .port_0   ( port_0   ), 
        .req_0    ( req_0    ), 

        .port_1   ( port_1   ), 
        .req_1    ( req_1    ), 

        .port_2   ( port_2   ), 
        .req_2    ( req_2    ), 

        .port_3   ( port_3   ), 
        .req_3    ( req_3    ), 

        .port_4   ( port_4   ), 
        .req_4    ( req_4    ), 

        .port_5   ( port_5   ), 
        .req_5    ( req_5    ), 

        .sel ( cb_sel_1 ), 
        .grt ( cb_grt_1 ), 

        .clk ( clk ), 
        .rst ( rst ) 
); 

muxcont #( 2 ) muxcont_2 ( 
        .port_0   ( port_0   ), 
        .req_0    ( req_0    ), 

        .port_1   ( port_1   ), 
        .req_1    ( req_1    ), 

        .port_2   ( port_2   ), 
        .req_2    ( req_2    ), 

        .port_3   ( port_3   ), 
        .req_3    ( req_3    ), 

        .port_4   ( port_4   ), 
        .req_4    ( req_4    ), 

        .port_5   ( port_5   ), 
        .req_5    ( req_5    ), 

        .sel ( cb_sel_2 ), 
        .grt ( cb_grt_2 ), 

        .clk ( clk ), 
        .rst ( rst ) 
); 

muxcont #( 3 ) muxcont_3 ( 
        .port_0   ( port_0   ), 
        .req_0    ( req_0    ), 

        .port_1   ( port_1   ), 
        .req_1    ( req_1    ), 

        .port_2   ( port_2   ), 
        .req_2    ( req_2    ), 

        .port_3   ( port_3   ), 
        .req_3    ( req_3    ), 

        .port_4   ( port_4   ), 
        .req_4    ( req_4    ), 

        .port_5   ( port_5   ), 
        .req_5    ( req_5    ), 

        .sel ( cb_sel_3 ), 
        .grt ( cb_grt_3 ), 

        .clk ( clk ), 
        .rst ( rst ) 
); 

muxcont #( 4 ) muxcont_4 ( 
        .port_0   ( port_0   ), 
        .req_0    ( req_0    ), 

        .port_1   ( port_1   ), 
        .req_1    ( req_1    ), 

        .port_2   ( port_2   ), 
        .req_2    ( req_2    ), 

        .port_3   ( port_3   ), 
        .req_3    ( req_3    ), 

        .port_4   ( port_4   ), 
        .req_4    ( req_4    ), 

        .port_5   ( port_5   ), 
        .req_5    ( req_5    ), 

        .sel ( cb_sel_4 ), 
        .grt ( cb_grt_4 ), 

        .clk ( clk ), 
        .rst ( rst ) 
); 

muxcont #( 5 ) muxcont_5 ( 
        .port_0   ( port_0   ), 
        .req_0    ( req_0    ), 

        .port_1   ( port_1   ), 
        .req_1    ( req_1    ), 

        .port_2   ( port_2   ), 
        .req_2    ( req_2    ), 

        .port_3   ( port_3   ), 
        .req_3    ( req_3    ), 

        .port_4   ( port_4   ), 
        .req_4    ( req_4    ), 

        .port_5   ( port_5   ), 
        .req_5    ( req_5    ), 

        .sel ( cb_sel_5 ), 
        .grt ( cb_grt_5 ), 

        .clk ( clk ), 
        .rst ( rst ) 
); 

mux mux_0 ( 
        .idata_0  ( idata_0  ), 
        .ivalid_0 ( ivalid_0 ), 
        .ivch_0   ( ivch_0   ), 

        .idata_1  ( idata_1  ), 
        .ivalid_1 ( ivalid_1 ), 
        .ivch_1   ( ivch_1   ), 

        .idata_2  ( idata_2  ), 
        .ivalid_2 ( ivalid_2 ), 
        .ivch_2   ( ivch_2   ), 

        .idata_3  ( idata_3  ), 
        .ivalid_3 ( ivalid_3 ), 
        .ivch_3   ( ivch_3   ), 

        .idata_4  ( idata_4  ), 
        .ivalid_4 ( ivalid_4 ), 
        .ivch_4   ( ivch_4   ), 

        .idata_5  ( idata_5  ), 
        .ivalid_5 ( ivalid_5 ), 
        .ivch_5   ( ivch_5   ), 

        .odata  ( odata_0    ), 
        .ovalid ( ovalid_0   ), 
        .ovch   ( ovch_0     ), 

        .sel ( cb_sel_0 ) 
); 

mux mux_1 ( 
        .idata_0  ( idata_0  ), 
        .ivalid_0 ( ivalid_0 ), 
        .ivch_0   ( ivch_0   ), 

        .idata_1  ( idata_1  ), 
        .ivalid_1 ( ivalid_1 ), 
        .ivch_1   ( ivch_1   ), 

        .idata_2  ( idata_2  ), 
        .ivalid_2 ( ivalid_2 ), 
        .ivch_2   ( ivch_2   ), 

        .idata_3  ( idata_3  ), 
        .ivalid_3 ( ivalid_3 ), 
        .ivch_3   ( ivch_3   ), 

        .idata_4  ( idata_4  ), 
        .ivalid_4 ( ivalid_4 ), 
        .ivch_4   ( ivch_4   ), 

        .idata_5  ( idata_5  ), 
        .ivalid_5 ( ivalid_5 ), 
        .ivch_5   ( ivch_5   ), 

        .odata  ( odata_1    ), 
        .ovalid ( ovalid_1   ), 
        .ovch   ( ovch_1     ), 

        .sel ( cb_sel_1 ) 
); 

mux mux_2 ( 
        .idata_0  ( idata_0  ), 
        .ivalid_0 ( ivalid_0 ), 
        .ivch_0   ( ivch_0   ), 

        .idata_1  ( idata_1  ), 
        .ivalid_1 ( ivalid_1 ), 
        .ivch_1   ( ivch_1   ), 

        .idata_2  ( idata_2  ), 
        .ivalid_2 ( ivalid_2 ), 
        .ivch_2   ( ivch_2   ), 

        .idata_3  ( idata_3  ), 
        .ivalid_3 ( ivalid_3 ), 
        .ivch_3   ( ivch_3   ), 

        .idata_4  ( idata_4  ), 
        .ivalid_4 ( ivalid_4 ), 
        .ivch_4   ( ivch_4   ), 

        .idata_5  ( idata_5  ), 
        .ivalid_5 ( ivalid_5 ), 
        .ivch_5   ( ivch_5   ), 

        .odata  ( odata_2    ), 
        .ovalid ( ovalid_2   ), 
        .ovch   ( ovch_2     ), 

        .sel ( cb_sel_2 ) 
); 

mux mux_3 ( 
        .idata_0  ( idata_0  ), 
        .ivalid_0 ( ivalid_0 ), 
        .ivch_0   ( ivch_0   ), 

        .idata_1  ( idata_1  ), 
        .ivalid_1 ( ivalid_1 ), 
        .ivch_1   ( ivch_1   ), 

        .idata_2  ( idata_2  ), 
        .ivalid_2 ( ivalid_2 ), 
        .ivch_2   ( ivch_2   ), 

        .idata_3  ( idata_3  ), 
        .ivalid_3 ( ivalid_3 ), 
        .ivch_3   ( ivch_3   ), 

        .idata_4  ( idata_4  ), 
        .ivalid_4 ( ivalid_4 ), 
        .ivch_4   ( ivch_4   ), 

        .idata_5  ( idata_5  ), 
        .ivalid_5 ( ivalid_5 ), 
        .ivch_5   ( ivch_5   ), 

        .odata  ( odata_3    ), 
        .ovalid ( ovalid_3   ), 
        .ovch   ( ovch_3     ), 

        .sel ( cb_sel_3 ) 
); 

mux mux_4 ( 
        .idata_0  ( idata_0  ), 
        .ivalid_0 ( ivalid_0 ), 
        .ivch_0   ( ivch_0   ), 

        .idata_1  ( idata_1  ), 
        .ivalid_1 ( ivalid_1 ), 
        .ivch_1   ( ivch_1   ), 

        .idata_2  ( idata_2  ), 
        .ivalid_2 ( ivalid_2 ), 
        .ivch_2   ( ivch_2   ), 

        .idata_3  ( idata_3  ), 
        .ivalid_3 ( ivalid_3 ), 
        .ivch_3   ( ivch_3   ), 

        .idata_4  ( idata_4  ), 
        .ivalid_4 ( ivalid_4 ), 
        .ivch_4   ( ivch_4   ), 

        .idata_5  ( idata_5  ), 
        .ivalid_5 ( ivalid_5 ), 
        .ivch_5   ( ivch_5   ), 

        .odata  ( odata_4    ), 
        .ovalid ( ovalid_4   ), 
        .ovch   ( ovch_4     ), 

        .sel ( cb_sel_4 ) 
); 

mux mux_5 ( 
        .idata_0  ( idata_0  ), 
        .ivalid_0 ( ivalid_0 ), 
        .ivch_0   ( ivch_0   ), 

        .idata_1  ( idata_1  ), 
        .ivalid_1 ( ivalid_1 ), 
        .ivch_1   ( ivch_1   ), 

        .idata_2  ( idata_2  ), 
        .ivalid_2 ( ivalid_2 ), 
        .ivch_2   ( ivch_2   ), 

        .idata_3  ( idata_3  ), 
        .ivalid_3 ( ivalid_3 ), 
        .ivch_3   ( ivch_3   ), 

        .idata_4  ( idata_4  ), 
        .ivalid_4 ( ivalid_4 ), 
        .ivch_4   ( ivch_4   ), 

        .idata_5  ( idata_5  ), 
        .ivalid_5 ( ivalid_5 ), 
        .ivch_5   ( ivch_5   ), 

        .odata  ( odata_5    ), 
        .ovalid ( ovalid_5   ), 
        .ovch   ( ovch_5     ), 

        .sel ( cb_sel_5 ) 
); 

assign grt_0[0]  = cb_grt_0[0]; 
assign grt_0[1]  = cb_grt_1[0]; 
assign grt_0[2]  = cb_grt_2[0]; 
assign grt_0[3]  = cb_grt_3[0]; 
assign grt_0[4]  = cb_grt_4[0]; 
assign grt_0[5]  = cb_grt_5[0]; 

assign grt_1[0]  = cb_grt_0[1]; 
assign grt_1[1]  = cb_grt_1[1]; 
assign grt_1[2]  = cb_grt_2[1]; 
assign grt_1[3]  = cb_grt_3[1]; 
assign grt_1[4]  = cb_grt_4[1]; 
assign grt_1[5]  = cb_grt_5[1]; 

assign grt_2[0]  = cb_grt_0[2]; 
assign grt_2[1]  = cb_grt_1[2]; 
assign grt_2[2]  = cb_grt_2[2]; 
assign grt_2[3]  = cb_grt_3[2]; 
assign grt_2[4]  = cb_grt_4[2]; 
assign grt_2[5]  = cb_grt_5[2]; 

assign grt_3[0]  = cb_grt_0[3]; 
assign grt_3[1]  = cb_grt_1[3]; 
assign grt_3[2]  = cb_grt_2[3]; 
assign grt_3[3]  = cb_grt_3[3]; 
assign grt_3[4]  = cb_grt_4[3]; 
assign grt_3[5]  = cb_grt_5[3]; 

assign grt_4[0]  = cb_grt_0[4]; 
assign grt_4[1]  = cb_grt_1[4]; 
assign grt_4[2]  = cb_grt_2[4]; 
assign grt_4[3]  = cb_grt_3[4]; 
assign grt_4[4]  = cb_grt_4[4]; 
assign grt_4[5]  = cb_grt_5[4]; 

assign grt_5[0]  = cb_grt_0[5]; 
assign grt_5[1]  = cb_grt_1[5]; 
assign grt_5[2]  = cb_grt_2[5]; 
assign grt_5[3]  = cb_grt_3[5]; 
assign grt_5[4]  = cb_grt_4[5]; 
assign grt_5[5]  = cb_grt_5[5]; 

endmodule
