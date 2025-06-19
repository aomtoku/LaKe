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
module muxcont ( 
        port_0,   
        req_0,    

        port_1,   
        req_1,    

        port_2,   
        req_2,    

        port_3,   
        req_3,    

        port_4,   
        req_4,    

        port_5,   
        req_5,    

        sel, 
        grt, 

        clk, 
        rst  
);
parameter       PORTID = 0; 

input  [`PORTW:0] port_0;   
input             req_0;    

input  [`PORTW:0] port_1;   
input             req_1;    

input  [`PORTW:0] port_2;   
input             req_2;    

input  [`PORTW:0] port_3;   
input             req_3;    

input  [`PORTW:0] port_4;   
input             req_4;    

input  [`PORTW:0] port_5;   
input             req_5;    

output [`PORT:0]  sel; 
output [`PORT:0]  grt; 

input             clk, rst; 

reg    [`PORT:0]  last; 
wire   [`PORT:0]  req;  
wire   [`PORT:0]  grt0; 
wire   [`PORT:0]  hold; 
wire              anyhold;

assign  req[0]  = req_0 & (port_0 == PORTID); 
assign  req[1]  = req_1 & (port_1 == PORTID); 
assign  req[2]  = req_2 & (port_2 == PORTID); 
assign  req[3]  = req_3 & (port_3 == PORTID); 
assign  req[4]  = req_4 & (port_4 == PORTID); 
assign  req[5]  = req_5 & (port_5 == PORTID); 

assign  hold    = last & req; 
assign  anyhold = |hold;      
assign  sel     = last;       

always @ (posedge clk) begin 
        if (rst) 
                last    <= `PORT_P1'b0; 
        else if (last != grt)               
                last    <= grt;             
end 

assign  grt[0]  = anyhold ? hold[0] : grt0[0]; 
assign  grt[1]  = anyhold ? hold[1] : grt0[1]; 
assign  grt[2]  = anyhold ? hold[2] : grt0[2]; 
assign  grt[3]  = anyhold ? hold[3] : grt0[3]; 
assign  grt[4]  = anyhold ? hold[4] : grt0[4]; 
assign  grt[5]  = anyhold ? hold[5] : grt0[5]; 

/*                     
 * Arbiter             
 */                    
arb a0 (               
        .req ( req  ), 
        .grt ( grt0 ), 
        .clk ( clk  ), 
        .rst ( rst  )  
);                     

endmodule
