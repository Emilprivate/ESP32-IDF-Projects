#!/bin/bash

# Function to prompt user for input with a default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    echo -n "$prompt [$default]: "
    read -r "$var_name"
    eval "$var_name=\${$var_name:-$default}"
}

# Prompt user for input
prompt_with_default "Enter the name of the output bin file" "output.bin" outfile
prompt_with_default "Enter the name of the bootloader bin file" "bootloader.bin" bootloader
prompt_with_default "Enter the name of the partition table bin file" "partition-table.bin" partition_table
prompt_with_default "Enter the name of the main bin file" "main.bin" main
prompt_with_default "Enter the flash mode" "dio" flash_mode
prompt_with_default "Enter the flash frequency" "40m" flash_freq
prompt_with_default "Enter the flash size" "4MB" flash_size
prompt_with_default "Enter the path for esptool.py" "/opt/esp/idf/components/esptool_py/esptool/esptool.py" esptool_path
prompt_with_default "Enter the chip" "esp32" chip

# Generate merge.sh script
cat <<EOF > merge.sh
#!/bin/bash

# Merge Bins
python "$esptool_path" --chip $chip merge_bin --output $outfile --fill-flash-size $flash_size 0x1000 build/bootloader/$bootloader 0x8000 build/partition_table/$partition_table 0x10000 build/$main --flash_mode $flash_mode --flash_freq $flash_freq --flash_size $flash_size
EOF

# Generate run.sh script
cat <<EOF > run.sh
#!/bin/bash

# Run Normally
qemu-system-xtensa -nographic -machine $chip -drive file=$outfile,if=mtd,format=raw
EOF

# Generate debug.sh script
cat <<EOF > debug.sh
#!/bin/bash

# Debug
qemu-system-xtensa -s -S -nographic -machine $chip -drive file=$outfile,if=mtd,format=raw
EOF

# Set execute permissions
chmod +x merge.sh run.sh debug.sh

echo "Scripts merge.sh, run.sh, and debug.sh have been generated successfully."

