LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_signed.ALL;

PACKAGE SpiSlaveTypes IS
    SUBTYPE Spi_SpiWord IS STD_LOGIC_VECTOR(0 TO 15);
    SUBTYPE Spi_SpiCorrected IS STD_LOGIC_VECTOR(15 DOWNTO 0);
    TYPE Spi_QSpiWord IS ARRAY(0 TO 2) OF Spi_SpiWord;
    TYPE Spi_QSpiCorrected IS ARRAY(0 TO 2) OF Spi_SpiCorrected;
    TYPE Spi_Address_t IS ARRAY (0 TO 2) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

    TYPE Spi_State IS
    (IDLE_STATE,
    RISE_DETECT_START,
    CLOCK_HIGH,
    CLOCK_LOW,
    RISE_DETECT,
    FALL_DETECT,
    END_STATE);

    TYPE Spi_Handler_State IS
    (IDLE_STATE,
    ACTIVATE_SPI,
    RUN_STATE,
    END_STATE,
    DELAY,
    EVAL_STATE,
    SUCCESS,
    FAIL
    );
END SpiSlaveTypes;