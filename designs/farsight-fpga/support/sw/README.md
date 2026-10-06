# Farsight FPGA SW functional test support

The following folder contains CMake build tools, drivers and a functions that
can be used to turn on IMX sensor, configure the camera sensor registers via SPI
commands, request write image frames to the DDR4 and read frames and export them
to a lab computer via UDP.

## Execusion

To lead the .elf file via JTAG OpenOCD and GDB can be used. The commands are shown below:

```
riscv64-unknown-elf-gdb -ex "target extended-remote localhost:3333" -ex "set mem inaccessible-by-default off" -ex "set arch riscv:rv32" -ex "load" build/bin/exec_farsight.elf
```