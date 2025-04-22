library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;

package QSpiSlaveTypes is
    subtype QSpiWord is array (0 to 15) of std_logic_vector(2 DOWNTO 0);
	 
    type Spi_State is
    (IDLE_STATE,
     RISE_DETECT_START,
     RISE_DETECT,
     CLOCK_HIGH,
     FALL_DETECT,
     CLOCK_LOW,
     END_STATE);

     type Spi_Handler_State is
    (IDLE_STATE,
     ACTIVATE_SPI,
     RUN_STATE,
     END_STATE,
     DELAY_ONESEC1,
     DELAY_ONESEC2,
     DELAY_ONESEC3,
     DELAY_ONESEC4,
     DELAY_ONESEC5
    );
end QSpiSlaveTypes;
