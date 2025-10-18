LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE VgaTypes IS
    -- 8 bits per color (We hope)
    TYPE LineColor_t IS ARRAY (0 TO 799) OF STD_LOGIC_VECTOR(23 DOWNTO 0);
    TYPE LineBuffer_t IS ARRAY (0 TO 1) OF LineColor_t;
    TYPE Sprite_t IS RECORD
        x_start : unsigned (9 DOWNTO 0);
        y_start : unsigned (9 DOWNTO 0);
        -- Here we have the type of the sprite which will be aknowledged by the memory address to get the colors
        -- Sprites are 16x16 and are stored in SD ram
        sprite_type : unsigned (4 DOWNTO 0);
    END RECORD;

END VgaTypes;