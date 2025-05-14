library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_signed.all;

package SpiSlaveTypes is
    subtype Spi_SpiWord is std_logic_vector(0 to 31);
    subtype Spi_SpiCorrected is std_logic_vector(31 downto 0);
    subtype Spi_QSpiWord is array(0 to 2) of Spi_SpiWord;
    subtype Spi_QSpiCorrected is array(0 to 2) of Spi_SpiCorrected;
	 
	 type Spi_State is
    (IDLE_STATE,
     RISE_DETECT_START,
	 CLOCK_HIGH,
     CLOCK_LOW,
     RISE_DETECT,
     FALL_DETECT,
     END_STATE);

     type Spi_Handler_State is
    (IDLE_STATE,
     ACTIVATE_SPI,
     RUN_STATE,
     END_STATE,
	   DELAY,
	   EVAL_STATE,
     SUCCESS,
     FAIL
    );
end SpiSlaveTypes;