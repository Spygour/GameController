library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;

package SpiSlaveTypes is
    subtype SpiWord is std_logic_vector(0 to 31);
	 
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
     END_STATE
    );
end SpiSlaveTypes;