#!/bin/bash

# Ensure the scripts directory exists
mkdir -p scripts

# Generate assemble.sh script
cat <<'EOF' > scripts/assemble.sh
#!/bin/bash

echo "Enter the path to your assembly file (.s):"
read -r asm_path

# Extract filename without extension
filename=$(basename -- "$asm_path")
filename=${filename%.*}

# Ensure the asm-build directory exists
mkdir -p asm-build

# Assemble and link
xtensa-esp32-elf-as -o asm-build/"$filename".o "$asm_path"
xtensa-esp32-elf-ld -o asm-build/"$filename".elf asm-build/"$filename".o

# Ask the user if they want to change the output directory for the .bin file
echo "Change output directory for the .bin file? (yes/no)"
read -r change_output_dir

if [ "$change_output_dir" = "yes" ]; then
    echo "Enter the new output directory path:"
    read -r bin_output_dir
    # Ensure the new output directory exists
    mkdir -p "$bin_output_dir"
else
    bin_output_dir="bin"
    # Ensure the default bin directory exists
    mkdir -p "$bin_output_dir"
fi

# Convert ELF to binary format and place it in the specified output directory
bin_file="$bin_output_dir/$filename.bin"
xtensa-esp32-elf-objcopy -O binary asm-build/"$filename".elf "$bin_file"

# Ask if the user wants to pad the binary file
echo "Do you want to pad the binary file to a valid flash size (2, 4, 8, 16 MB)? (yes/no)"
read -r pad_binary

if [ "$pad_binary" = "yes" ]; then
    echo "Enter the desired flash size in MB (2, 4, 8, 16):"
    read -r flash_size

    # Calculate the padding size in bytes
    let pad_size=flash_size*1024*1024

    # Create a padded binary file
    padded_bin_file="$bin_output_dir/padded_$filename.bin"
    dd if=/dev/zero bs=1 count="$pad_size" of="$padded_bin_file" status=none
    dd if="$bin_file" of="$padded_bin_file" conv=notrunc status=none

    echo "Binary file padded to $flash_size MB and located in $bin_output_dir/"
else
    echo "Binary file located in $bin_output_dir/"
fi

echo "Assembled and linked files located in asm-build/"
EOF


# Generate build-merge.sh script with configuration saving/loading
cat <<'EOF' > scripts/build-merge.sh
#!/bin/bash

CONFIG_FILE="scripts/build-merge-config.json"

# Function to prompt user for input with a default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    echo -n "$prompt [$default]: "
    read -r input
    if [ -z "$input" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# Build the project first
idf.py build

# Check if the configuration file exists
if [ -f "$CONFIG_FILE" ]; then
    # Load settings from the JSON file
    while IFS=":" read -r key value; do
        key=$(echo "$key" | tr -d '"{}, ')
        value=$(echo "$value" | tr -d '"{}, ')
        case "$key" in
            "outfile") outfile="$value" ;;
            "bootloader") bootloader="$value" ;;
            "partition_table") partition_table="$value" ;;
            "main") main="$value" ;;
            "flash_mode") flash_mode="$value" ;;
            "flash_freq") flash_freq="$value" ;;
            "flash_size") flash_size="$value" ;;
            "esptool_path") esptool_path="$value" ;;
            "chip") chip="$value" ;;
            *) ;;
        esac
    done < "$CONFIG_FILE"
else
    # Prompt user for input for merging binaries
    prompt_with_default "Enter the name of the output bin file" "output.bin" outfile
    prompt_with_default "Enter the name of the bootloader bin file" "bootloader.bin" bootloader
    prompt_with_default "Enter the name of the partition table bin file" "partition-table.bin" partition_table
    prompt_with_default "Enter the name of the main bin file" "main.bin" main
    prompt_with_default "Enter the flash mode" "dio" flash_mode
    prompt_with_default "Enter the flash frequency" "40m" flash_freq
    prompt_with_default "Enter the flash size" "4MB" flash_size
    prompt_with_default "Enter the path for esptool.py" "/opt/esp/idf/components/esptool_py/esptool/esptool.py" esptool_path
    prompt_with_default "Enter the chip" "esp32" chip

    echo "Do you wish to save these settings for future use? (Y/N)"
    read -r save_choice

    if [[ "$save_choice" =~ ^[Yy]$ ]]; then
        {
            echo "{"
            echo "  \"outfile\": \"$outfile\","
            echo "  \"bootloader\": \"$bootloader\","
            echo "  \"partition_table\": \"$partition_table\","
            echo "  \"main\": \"$main\","
            echo "  \"flash_mode\": \"$flash_mode\","
            echo "  \"flash_freq\": \"$flash_freq\","
            echo "  \"flash_size\": \"$flash_size\","
            echo "  \"esptool_path\": \"$esptool_path\","
            echo "  \"chip\": \"$chip\""
            echo "}"
        } > "$CONFIG_FILE"
    fi
fi

# Check if bin directory exists, if not create it
if [ ! -d "bin" ]; then
    mkdir bin
fi

echo "Bootloader location: " $bootloader
echo "Partition Table location: " $partition_table

python "$esptool_path" --chip $chip merge_bin --output bin/"$outfile" --fill-flash-size $flash_size 0x1000 build/bootloader/"$bootloader" 0x8000 build/partition_table/"$partition_table" 0x10000 build/"$main" --flash_mode $flash_mode --flash_freq $flash_freq --flash_size $flash_size

echo "Project built and binaries merged successfully."
EOF

# Generate run.sh script
cat <<'EOF' > scripts/run.sh
#!/bin/bash

BIN_DIR="bin"

# Check if the bin directory exists
if [ -d "$BIN_DIR" ]; then
    # Find all .bin files in the bin directory
    bin_files=($(find "$BIN_DIR" -maxdepth 1 -type f -name "*.bin"))
    
    # Check the number of binary files found
    num_files=${#bin_files[@]}
    if [ "$num_files" -eq 0 ]; then
        echo "No .bin files found in the bin directory."
        exit 1
    elif [ "$num_files" -eq 1 ]; then
        # If only one binary file, select it automatically
        binary_path="${bin_files[0]}"
    else
        # If multiple binary files, let the user choose
        echo "Multiple .bin files found:"
        for i in "${!bin_files[@]}"; do
            echo "$((i+1))) ${bin_files[$i]}"
        done
        echo "Please select the binary file to run (1-$num_files):"
        read -r user_choice
        
        # Validate user input
        if [[ $user_choice =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "$num_files" ]; then
            binary_path="${bin_files[$((user_choice-1))]}"
        else
            echo "Invalid selection."
            exit 1
        fi
    fi
    
    # Run the selected binary file with QEMU
    qemu-system-xtensa -nographic -machine esp32 -drive file="$binary_path",if=mtd,format=raw
else
    echo "The bin directory does not exist. Please make sure to build the project first."
fi
EOF

# Generate debug.sh script
cat <<'EOF' > scripts/debug.sh
#!/bin/bash

BIN_DIR="bin"

# Check if the bin directory exists
if [ -d "$BIN_DIR" ]; then
    # Find all .bin files in the bin directory
    bin_files=($(find "$BIN_DIR" -maxdepth 1 -type f -name "*.bin"))
    
    # Check the number of binary files found
    num_files=${#bin_files[@]}
    if [ "$num_files" -eq 0 ]; then
        echo "No .bin files found in the bin directory."
        exit 1
    elif [ "$num_files" -eq 1 ]; then
        # If only one binary file, select it automatically
        binary_path="${bin_files[0]}"
    else
        # If multiple binary files, let the user choose
        echo "Multiple .bin files found:"
        for i in "${!bin_files[@]}"; do
            echo "$((i+1))) ${bin_files[$i]}"
        done
        echo "Please select the binary file to debug (1-$num_files):"
        read -r user_choice
        
        # Validate user input
        if [[ $user_choice =~ ^[0-9]+$ ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "$num_files" ]; then
            binary_path="${bin_files[$((user_choice-1))]}"
        else
            echo "Invalid selection."
            exit 1
        fi
    fi
    
    # Debug the selected binary file with QEMU
    qemu-system-xtensa -s -S -nographic -machine esp32 -drive file="$binary_path",if=mtd,format=raw
else
    echo "The bin directory does not exist. Please make sure to build the project first."
fi
EOF

# Generate disassemble.sh script
cat <<EOF > scripts/disassemble.sh
#!/bin/bash

echo "Enter the path to your .elf file:"
read -r elf_path

# Disassemble the ELF file
xtensa-esp32-elf-objdump -d "\$elf_path" > DISASSEMBLY.txt

echo "Disassembly completed. Output is in DISASSEMBLY.txt"
EOF

# Set execute permissions
chmod +x scripts/assemble.sh scripts/build-merge.sh scripts/run.sh scripts/debug.sh scripts/disassemble.sh

echo "Scripts assemble.sh, build-merge.sh, run.sh, debug.sh, and disassemble.sh have been generated in the 'scripts' directory successfully."
