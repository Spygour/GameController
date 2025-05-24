LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE DataHandlerTypes IS
    -- 8 bits per color (We hope)
    TYPE DataColor_t IS ARRAY (0 TO 2) OF STD_LOGIC_VECTOR(23 DOWNTO 0);
    TYPE DataPart_t IS ARRAY (0 TO 2) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
END DataHandlerTypes;