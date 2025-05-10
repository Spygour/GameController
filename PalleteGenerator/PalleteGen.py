def parse_clean_hex_file(file_path):
    """
    Parses a hex file that contains clean hex data (no checksum) and returns the 24-bit words.
    Each line is expected to be a sequence of hex characters.
    """
    words_24bit = []

    with open(file_path, 'r') as hex_file:
        for line in hex_file:
            line = line.strip()  # Remove any leading/trailing whitespace
            # Process the line in chunks of 6 hex characters (24-bit words)
            if len(line) % 6 == 0:
                for i in range(0, len(line), 6):
                    hex_value = line[i:i+6]
                    # Convert the 6-character hex string to an integer (24-bit)
                    word_24bit = int(hex_value, 16)
                    words_24bit.append(word_24bit)
            else:
                print(f"Warning: Skipping invalid line (not a multiple of 6 characters): {line}")
    
    return words_24bit


def split_24bit_to_16bit(words_24bit):
    """
    Splits 24-bit words into two 16-bit words.
    """
    words_16bit = []
    for word_24bit in words_24bit:
        high_word_16bit = (word_24bit >> 8) & 0xFFFF  # upper 16 bits
        low_word_16bit = (word_24bit & 0xFF) << 8  # lower 16 bits
        words_16bit.append(high_word_16bit)
        words_16bit.append(low_word_16bit)
    return words_16bit


def generate_vhdl_code(words_16bit):
    """
    Generates VHDL code to assign 16-bit words to an array.
    """
    vhdl_code = "signal WriteDataBuffer_reg <= ("
    i = 0
    new_line = 0
    while ( i < len(words_16bit) - 2):
        vhdl_code += "(\"{}\", ".format(format(words_16bit[i], '016b'))
        i+=1
        vhdl_code += "\"{}\"), ".format(format(words_16bit[i], '016b'))
        i+=1
        if new_line == 20:
             vhdl_code+= "\n"
             new_line = 0
        else:
            new_line += 1
    
    vhdl_code += "(\"{}\", ".format(format(words_16bit[len(words_16bit) - 2], '016b'))
    vhdl_code += "\"{}\")".format(format(words_16bit[len(words_16bit) - 1], '016b'))
    vhdl_code += ");\n"
    return vhdl_code


# Example usage
file_path = "windows-95-256-colours.hex"  # Replace with the path to your .hex file

# Step 1: Parse the clean hex file and extract 24-bit words
words_24bit = parse_clean_hex_file(file_path)

# Step 2: Split the 24-bit words into two 16-bit words
words_16bit = split_24bit_to_16bit(words_24bit)

# Step 3: Generate VHDL code
vhdl_code = generate_vhdl_code(words_16bit[0:128])

# Step 4: Print the VHDL code
print(vhdl_code)

# Step 3: Generate VHDL code
vhdl_code = generate_vhdl_code(words_16bit[128:256])

# Step 4: Print the VHDL code
print(vhdl_code)

# Step 3: Generate VHDL code
vhdl_code = generate_vhdl_code(words_16bit[256:384])

# Step 4: Print the VHDL code
print(vhdl_code)

# Step 3: Generate VHDL code
vhdl_code = generate_vhdl_code(words_16bit[384:512])

# Step 4: Print the VHDL code
print(vhdl_code)