# LaKe module

### Please place xilinx CAM (xapp1151) in this directory.
Download xilinx CAM.

```
$ make update
```

### To prepare LaKe db core
```
1) Access to http://outputlogic.com/?page_id=321
2) Specify 256 as data width and 32 as polynomial width.
3) Choose "CRC32 for 802.3".
4) Click "apply"
5) Click "Step 2" and then "Generate Verilog Code"

In this directory,
$ cd hdl
$ touch crc32.v
Copy and paste generated code to crc32.v. 
```




