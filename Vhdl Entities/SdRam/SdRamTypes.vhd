library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package SdRamTypes is 
    -- 8 bits per color (We hope)
    type DataCols_t is array (1 downto 0) of std_logic_vector(15 downto 0);
end SdRamTypes;
