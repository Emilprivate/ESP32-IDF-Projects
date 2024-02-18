# ESP-IDF Setup Guide for Visual Studio Code

This guide will walk you through setting up the ESP-IDF (Espressif IoT Development Framework) environment on Visual Studio Code. By following these steps, you'll be able to set up your development environment for ESP32 projects correctly.

## Prerequisites

1. **Install Visual Studio Code Extension:**
   - Install the [ESP-IDF Visual Studio Code Extension](https://marketplace.visualstudio.com/items?itemName=espressif.esp-idf-extension) from the Visual Studio Code Marketplace.
   - Native Debug (GDB, LLDB & MAGO-MI Debugger support) extension

2. **Install Prerequisites:**
   - Follow the prerequisite instructions outlined in the official ESP-IDF documentation [here](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/linux-macos-setup.html#step-1-install-prerequisites).

## QEMU Setup

Follow the instructions in this [video tutorial](https://www.youtube.com/watch?v=lZp9L7Ij4Yo) to set up QEMU for ESP32 development.

## Finding Paths
If you're unsure about the paths on your system, you can use the following commands to locate them:

To find the path of the ESP-IDF tools:
```bash
find / -name "xtensa-esp-elf" -type d
```

To locate the ESP-IDF components:
```bash
find / -name "esptool.py"
```

## Commands

### IDF Build
Build your IDF project once you're done before proceeding to debugging configuration:
```idf.py build```. If you're having difficulties or errors occur then scroll down to the configuration fixes section and read about the devcontainer.json fix. This may take some minutes.

### Merge Bins, Run Normally, Debug

To merge bins, run normally, or debug, use the following commands (replace with your own absolute paths):

### Merge Bins
```bash
python /opt/esp/idf/components/esptool_py/esptool/esptool.py --chip esp32 merge_bin --output output.bin --fill-flash-size 4MB 0x1000 build/bootloader/bootloader.bin 0x8000 build/partition_table/partition-table.bin 0x10000 build/main.bin --flash_mode dio --flash_freq 40m --flash_size 4MB
```

### Run Normally
```bash
qemu-system-xtensa -nographic -machine esp32 -drive file=output.bin,if=mtd,format=raw
```

### Debug
```bash
qemu-system-xtensa -s -S -nographic -machine esp32 -drive file=output.bin,if=mtd,format=raw
```

# Configuration Fixes
## Devcontainer.json Configuration
Ensure your devcontainer.json file has the correct environment path to detect the compiler within the Docker container. Replace /opt/esp/tools/xtensa-esp-elf/esp-13.2.0_20230928/xtensa-esp-elf/bin with the appropriate path for your system:
```json
"containerEnv": {
    "PATH": "/opt/esp/tools/xtensa-esp-elf/esp-13.2.0_20230928/xtensa-esp-elf/bin:${env:PATH}"
}
```
## Launch.json Configuration
Configure your launch.json file to attach to the debugger. Adjust the paths accordingly:
```json
{
  "type": "gdb",
  "gdbpath": "<path>/xtensa-esp-elf-gdb/bin/xtensa-esp32-elf-gdb",
  "request": "attach",
  "name": "Attach to QEMU",
  "executable": "${workspaceFolder}/build/<filename>.elf",
  "target": ":1234",
  "remote": true,
  "cwd": "${workspaceRoot}",
  "valuesFormatting": "parseText"
}
```

# ESP-IDF Script Generator

This script `GenerateScripts.sh` helps you generate shell scripts (`merge.sh`, `run.sh`, and `debug.sh`) for ESP-IDF development. These scripts automate the process of merging bins, running normally, and debugging in QEMU.

# Usage of GenerateScripts.sh

1. **Run the Script:**
   - Execute the `GenerateScripts.sh` script ```./GenerateScripts.sh```.
   - You may have to run ```chmod +x GenerateScripts.sh```, before you can execute it.

2. **Provide Information:**
   - The script will prompt you to provide the following information:
     - Name of the output bin file.
     - Name of the bootloader bin file.
     - Name of the partition table bin file.
     - Name of the main bin file.
     - Flash mode.
     - Flash frequency.
     - Flash size.
     - Path for esptool.py (default: `/opt/esp/idf/components/esptool_py/esptool/esptool.py`).
     - Chip (default: `esp32`).

3. **Generated Scripts:**
   - Upon providing the information, the script will generate three shell scripts:
     - `build-merge.sh`: Builds the project using "idf.py build" and merges bins using the provided information. Also saves the information in a config.json file. 
     - `run.sh`: Runs the merged bin file normally in QEMU.
     - `debug.sh`: Runs the merged bin file in QEMU for debugging purposes.
     - `assemble.sh`: Assembles a `.s` file utilizing xtensa assembler.
     - `disassemble.sh`: Disassembles a `.elf` file utilizing xtensa disassembler.

4. **Execute Scripts:**
   - If execute permissions are for some reason not given then make sure to grant execute permissions manually to the generated scripts using `chmod +x merge.sh run.sh debug.sh`.
   - Run the scripts as needed for your ESP-IDF development workflow.

## Note
- Ensure that QEMU and the required tools are properly set up on your system before using the generated scripts.



