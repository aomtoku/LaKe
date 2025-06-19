# LaKe - Layered Key-value Store

This repository contains my PhD work: a **hardware-based Memcached implementation** supporting the UDP binary protocol, designed for high-performance and low-latency applications.

## Overview

LaKe is a Layered Key-value store - a hardware implementation of Memcached, designed to run on the NetFPGA-SUME platform. It fully supports the UDP-based Memcached binary protocol, enabling efficient key-value store and retrieval directly in hardware. This project was developed as an open-source contribution to the NetFPGA-SUME ecosystem. Due to licensing requirements, the full NetFPGA-SUME reference platform is available only upon registration. Therefore, this repository provides only the IP cores for Memcached, intended to be integrated into the NetFPGA-SUME datapath by users who have access to the official platform.

## Features

This hardware-based Memcached server is optimized for both performance and flexibility. It leverages a layered cache architecture that supports variable-length key-value pairs, making it suitable for real-world workloads. By offloading Memcached operations to hardware and supporting the UDP binary protocol, LaKe significantly reduces latency and increases throughput compared to traditional software implementations. The design is open source and released as part of the NetFPGA-SUME contribution project, allowing researchers and practitioners to explore, extend, and deploy high-performance in-network key-value stores.

## How to build

To use this project, you need access to the [NetFPGA-SUME platform](https://netfpga.org/).
Please read the public wiki for [NetFPGA-SUME-public](https://github.com/NetFPGA/NetFPGA-SUME-public)

 - Please **register for access** to the full NetFPGA-SUME repository.
 - You need a 10g MAC license from Xilinx (instruction is included in [wiki](https://github.com/NetFPGA/NetFPGA-SUME-public))
 - Xilinx CAM IP : xapp1151_param_cam.zip from Xilix web page

~~~bash
 $ git clone git@github.com:NetFPGA/NetFPGA-SUME-live.git
 $ cd NetFPGA-SUME-live
 $ cp ~/xapp1151_param_cam.zip ./lib/hw/xilinx/cores/cam_v1_1_0/
 $ cp ~/xapp1151_param_cam.zip ./lib/hw/xilinx/cores/tcam_v1_1_0/
 $ make -C ./lib/hw/xilinx/cores/cam_v1_1_0/ update
 $ make -C ./lib/hw/xilinx/cores/tcam_v1_1_0/ update
 $ make
~~~

Please edit `tools/setting.sh`
~~~bash
 export NF_PROJECT_NAME=lake
 export PROJECTS=${SUME_FOLDER}/contrib-projects↲
~~~

~~~bash
 $ source tools/settings.sh 
 $ make -C contrib-projects/lake
~~~

## Citation

If you want to refer to this work, please cite:

- [ReConFig'18]
  Yuta Tokusashi, Hiroki Matsutani, Noa Zilberman, "Lake: The power of in-network computing", Proceedings of IEEE ReConFig 2018.  [[PDF]](https://www.repository.cam.ac.uk/bitstreams/55d098e9-dc4b-48d6-8bca-a1e30fa0f343/download)

- [EuroSys'19]
  Yuta Tokusashi, Huynh Tu Dang, Fernando Pedone, Robert Soulé, Noa Zilberman, "The case for in-network computing on demand", Proceedings of ACM EuroSys 2019. [[PDF]](https://www.repository.cam.ac.uk/bitstreams/1e7ca4e8-de30-49e0-a094-9fe090086b5a/download)

