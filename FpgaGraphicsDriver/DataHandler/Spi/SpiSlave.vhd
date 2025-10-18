LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.SpiSlaveTypes.ALL;

ENTITY SpiSlave IS

    PORT (
        Spi_ActlClk : IN STD_LOGIC := '0';
        Spi_Clk : IN STD_LOGIC := '0';
        Spi_SpiClk : IN STD_LOGIC;
        Spi_Reset : IN STD_LOGIC := '1';
        Spi_So : OUT STD_LOGIC := '0';
        Spi_Si : IN STD_LOGIC_VECTOR(0 TO 2);
        Spi_Cs : IN STD_LOGIC;
        Spi_StartSpi : IN STD_LOGIC := '0';
        Spi_EndSpi : OUT STD_LOGIC := '1';
        Spi_Words : OUT INTEGER := 0;
        Spi_WrEn : OUT STD_LOGIC := '1';
        Spi_WriteDataWord : OUT Spi_QSpiCorrected := (OTHERS => (OTHERS => '0'));
        Spi_WriteAddress : INOUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        Spi_ReadAddress : IN Spi_Address_t := (OTHERS => (OTHERS => '0'));
        Spi_lockedloop : IN STD_LOGIC := '0');

END SpiSlave;

ARCHITECTURE rtl OF SpiSlave IS

    CONSTANT Spi_SpiBits : unsigned (3 DOWNTO 0) := b"1111";
    CONSTANT Spi_SpiWords : unsigned (7 DOWNTO 0) := b"11111111";

    SIGNAL Spi_SpiBitCnt : unsigned (3 DOWNTO 0) := Spi_SpiBits;
    SIGNAL Spi_SpiWordCounter : unsigned (7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL Spi_SpiSlaveState : Spi_State := IDLE_STATE;
    SIGNAL Spi_SpiClkPrev : STD_LOGIC;
    SIGNAL Spi_SpiClkCurrent : STD_LOGIC;
    SIGNAL Spi_CsCurrent : STD_LOGIC;
    SIGNAL Spi_SiReg : STD_LOGIC_VECTOR(0 TO 2) := (OTHERS => '0');

    SIGNAL Spi_SpiTxWord : Spi_SpiWord := (OTHERS => '0');
    SIGNAL Spi_SpiRxWord : Spi_QSpiWord := (OTHERS => (OTHERS => '0'));

BEGIN
    PROCESS (Spi_Clk, Spi_Reset, Spi_lockedloop) IS
    BEGIN
        IF (Spi_Reset = '1') THEN
            Spi_SpiTxWord <= (OTHERS => '0');
            Spi_SpiRxWord <= (OTHERS => (OTHERS => '0'));
            Spi_SpiWordCounter <= (OTHERS => '0');
            Spi_SpiBitCnt <= Spi_SpiBits;
            Spi_SpiSlaveState <= IDLE_STATE;
            Spi_WriteAddress <= (OTHERS => '0');
            Spi_So <= '0';
            Spi_WrEn <= '1';
            Spi_Words <= 0;
            Spi_EndSpi <= '1';
            Spi_SiReg <= (OTHERS => '0');
            Spi_CsCurrent <= '1';
            Spi_SpiClkPrev <= '0';
            Spi_SpiClkCurrent <= '0';

        ELSIF rising_edge(Spi_Clk) AND Spi_lockedloop = '1' THEN
            CASE Spi_SpiSlaveState IS
                WHEN IDLE_STATE =>
                    IF (Spi_StartSpi = '1' AND Spi_CsCurrent = '0') THEN
                        Spi_Words <= 0;
                        Spi_EndSpi <= '0';
                        IF (Spi_SpiClkCurrent = '1') THEN
                            -- MISO READ 
                            Spi_SpiRxWord(0)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(0);
                            Spi_SpiRxWord(1)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(1);
                            Spi_SpiRxWord(2)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(2);
                            -- BRAM DISABLE 
                            Spi_WrEn <= '0';
                            Spi_SpiBitCnt <= Spi_SpiBitCnt - 1;
                            Spi_SpiSlaveState <= FALL_DETECT;
                        ELSE
                            Spi_SpiSlaveState <= RISE_DETECT_START;
                        END IF;
                    ELSE
                        Spi_WriteAddress <= (OTHERS => '0');
                        Spi_SpiSlaveState <= IDLE_STATE;
                        Spi_SpiBitCnt <= Spi_SpiBits;
                        Spi_SpiWordCounter <= (OTHERS => '0');
                        Spi_SpiTxWord <= (OTHERS => '0');
                        Spi_SpiRxWord <= (OTHERS => (OTHERS => '0'));
                        Spi_So <= '0';
                    END IF;

                WHEN RISE_DETECT_START =>
                    IF (Spi_CsCurrent = '1') THEN
                        -- MSB FIRST
                        Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                        Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                        Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    ELSIF (Spi_SpiClkCurrent = '1' AND Spi_SpiClkPrev = '0') THEN
                        -- MISO READ 
                        Spi_SpiRxWord(0)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(0);
                        Spi_SpiRxWord(1)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(1);
                        Spi_SpiRxWord(2)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(2);
                        --BRAM DISABLE
                        Spi_WrEn <= '0';
                        Spi_So <= Spi_SpiTxWord(to_integer(Spi_SpiBitCnt));
                        Spi_SpiSlaveState <= CLOCK_HIGH;
                        Spi_SpiBitCnt <= Spi_SpiBitCnt - 1;
                    END IF;

                WHEN RISE_DETECT =>
                    IF (Spi_CsCurrent = '1') THEN
                        -- MSB FIRST
                        Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                        Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                        Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    ELSIF (Spi_SpiClkCurrent = '1' AND Spi_SpiClkPrev = '0') THEN
                        -- MISO READ 
                        Spi_SpiRxWord(0)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(0);
                        Spi_SpiRxWord(1)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(1);
                        Spi_SpiRxWord(2)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(2);
                        --BRAM DISABLE
                        Spi_WrEn <= '0';
                        Spi_So <= Spi_SpiTxWord(to_integer(Spi_SpiBitCnt));
                        IF (Spi_SpiBitCnt = Spi_SpiBits) THEN
                            Spi_WriteAddress <= STD_LOGIC_VECTOR(unsigned(Spi_WriteAddress) + 1);
                        END IF;
                        Spi_SpiSlaveState <= CLOCK_HIGH;
                        Spi_SpiBitCnt <= Spi_SpiBitCnt - 1;
                    END IF;

                WHEN CLOCK_HIGH =>
                    IF (Spi_CsCurrent = '1') THEN
                        -- MSB FIRST
                        Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                        Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                        Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    ELSIF (Spi_SpiClkCurrent = '1') THEN
                        IF Spi_SpiWordCounter = Spi_SpiWords THEN
                            -- MSB FIRST
                            Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                            Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                            Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                            Spi_WrEn <= '1';
                            Spi_SpiSlaveState <= END_STATE;
                        ELSIF Spi_SpiBitCnt = Spi_SpiBits THEN
                            -- MSB FIRST
                            Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                            Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                            Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                            Spi_WrEn <= '1';
                            Spi_Words <= to_integer(Spi_SpiWordCounter + 1);
                            Spi_SpiWordCounter <= Spi_SpiWordCounter + 1;
                            Spi_SpiTxWord <= Spi_SpiRxWord(0);
                            Spi_SpiSlaveState <= FALL_DETECT;
                        ELSE
                            Spi_SpiSlaveState <= FALL_DETECT;
                        END IF;
                    END IF;

                WHEN FALL_DETECT =>
                    IF (Spi_CsCurrent = '1') THEN
                        -- MSB FIRST
                        Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                        Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                        Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    ELSIF (Spi_SpiClkCurrent = '0' AND Spi_SpiClkPrev = '1') THEN
                        -- MISO READ 
                        Spi_SpiRxWord(0)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(0);
                        Spi_SpiRxWord(1)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(1);
                        Spi_SpiRxWord(2)(to_integer(Spi_SpiBitCnt)) <= Spi_SiReg(2);
                        -- BRAM DISABLE
                        Spi_WrEn <= '0';
                        Spi_So <= Spi_SpiTxWord(to_integer(Spi_SpiBitCnt));
                        IF (Spi_SpiBitCnt = Spi_SpiBits) THEN
                            Spi_WriteAddress <= STD_LOGIC_VECTOR(unsigned(Spi_WriteAddress) + 1);
                        END IF;
                        Spi_SpiSlaveState <= CLOCK_LOW;
                        Spi_SpiBitCnt <= Spi_SpiBitCnt - 1;
                    END IF;

                WHEN CLOCK_LOW =>
                    IF (Spi_CsCurrent = '1') THEN
                        -- MSB FIRST
                        Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                        Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                        Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    ELSIF (Spi_SpiClkCurrent = '0') THEN
                        IF Spi_SpiWordCounter = Spi_SpiWords THEN
                            -- MSB FIRST
                            Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                            Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                            Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                            Spi_WrEn <= '1';
                            Spi_SpiSlaveState <= END_STATE;
                        ELSIF Spi_SpiBitCnt = Spi_SpiBits THEN
                            -- MSB FIRST
                            Spi_WriteDataWord(0) <= Spi_SpiRxWord(0);
                            Spi_WriteDataWord(1) <= Spi_SpiRxWord(1);
                            Spi_WriteDataWord(2) <= Spi_SpiRxWord(2);
                            Spi_WrEn <= '1';
                            Spi_Words <= to_integer(Spi_SpiWordCounter + 1);
                            Spi_SpiWordCounter <= Spi_SpiWordCounter + 1;
                            Spi_SpiTxWord <= Spi_SpiRxWord(0) OR Spi_SpiRxWord(1) OR Spi_SpiRxWord(2);
                            Spi_SpiSlaveState <= RISE_DETECT;
                        ELSE
                            Spi_SpiSlaveState <= RISE_DETECT;
                        END IF;
                    END IF;

                WHEN END_STATE =>
                    Spi_WrEn <= '0';
                    Spi_So <= '0';
                    Spi_SpiWordCounter <= (OTHERS => '0');
                    Spi_EndSpi <= '1';
                    Spi_SpiSlaveState <= IDLE_STATE;
                    Spi_SpiBitCnt <= Spi_SpiBits;

                WHEN OTHERS =>
                    NULL;
            END CASE;
            Spi_SpiClkPrev <= Spi_SpiClkCurrent;
            Spi_SpiClkCurrent <= Spi_SpiClk;
            Spi_CsCurrent <= Spi_Cs;
            Spi_SiReg(0) <= Spi_Si(0);
            Spi_SiReg(1) <= Spi_Si(1);
            Spi_SiReg(2) <= Spi_Si(2);
        END IF;
    END PROCESS;

END ARCHITECTURE;