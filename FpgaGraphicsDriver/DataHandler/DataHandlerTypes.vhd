library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package DataHandlerTypes is 
    -- 8 bits per color (We hope)
    type DataColor_t is array (0 to 2) of std_logic_vector(23 downto 0);
    type DataPart_t is array (0 to 2) of std_logic_vector(7 downto 0);
end DataHandlerTypes;
