library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package VgaTypes is 
    -- 8 bits per color (We hope)
    type LineColor_t is array (0 to 800) of std_logic_vector(23 downto 0);
    type LineBuffer_t is array (0 to 2) of LineColor_t;


    type Sprite_t is record
        x_start : unsigned (9 downto 0);
        y_start : unsigned (9 downto 0);
        -- Here we have the type of the sprite which will be aknowledged by the memory address to get the colors
        -- Sprites are 16x16 and are stored in SD ram
        sprite_type : unsigned (4 downto 0);
    end record;

end VgaTypes;
