library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package SdRamTypes is 
    -- 8 bits per color (We hope)
    type DataCols_t is array (1 downto 0) of std_logic_vector(15 downto 0);
    type DataCols_ary is array (63 downto 0) of DataCols_t; --64 data X 4 256 COLORS
    type Address_t is array (0 to 2) of std_logic_vector(8 downto 0);

    type SDRAM_STATE is
        (
            POWERON,
            DELAY,
            POWERDOWN,
            IDLE,
            MODE_REGISTER_SET,
            ACTIVE_STATE,
            WRITE_STATE,
            WRITE_STORE,
            BURST_TERMINATE_WRITE,
            READ_STATE,
            READ_STORE,
            BURST_TERMINATE_READ,
            PRECHARGE_ALL,
            AUTO_REFRESH_STARTUP,
            SELF_REFRESH_EXIT,
            NOP_WITH_COUNTER,
            NOP
        );
end SdRamTypes;
