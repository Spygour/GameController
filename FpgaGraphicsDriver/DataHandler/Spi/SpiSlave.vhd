library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SpiSlaveTypes.all;

entity SpiSlave is
    
    port(Spi_ActlClk : in std_logic := '0';
         Spi_Clk      : in std_logic := '0';
         Spi_SpiClk   : in std_logic;
         Spi_Reset_n  : in std_logic := '1';
         Spi_So     : out std_logic := '0';
         Spi_Si     : in  std_logic_vector(0 to 3);
         Spi_Cs       : in std_logiC;
         Spi_StartSpi : in  std_logic := '0';
         Spi_EndSpi   : inout std_logic := '1';
         Spi_Words : out integer := 0;
         Spi_WrEn : inout std_logic := '0';
		 Spi_WriteDataWord : inout Spi_QSpiWord := (others => (others => '0');
		 Spi_ReadDataWord : in Spi_QSpiWord := (others => (others => '0') );
         Spi_WriteAddress  : inout std_logic_vector (7 DOWNTO 0);
         Spi_ReadAddress : in std_logic_vector (7 DOWNTO 0);
         Spi_lockedloop : in std_logic := '0');

end SpiSlave;

architecture rtl of SpiSlave is

constant Spi_SpiBits : unsigned (4 downto 0)   := b"11111";
constant Spi_SpiWords : unsigned (7 downto 0)  := b"11111111";

signal Spi_SpiBitCnt  : unsigned (4 downto 0) := SpiBits;
signal Spi_SpiWordCounter : unsigned (7 downto 0) := (others => '0');
signal Spi_SpiSlaveState : Spi_State := IDLE_STATE;
signal Spi_SpiClkPrev : std_logic;
signal Spi_SpiClkCurrent : std_logic;
signal Spi_CsCurrent : std_logic;
signal Spi_SiReg : std_logic_vector(0 to 3):= (others => '0');

signal Spi_SpiTxWord : Spi_SpiWord  := (others => (others => '0') );
signal Spi_SpiRxWord : Spi_QSpiWord  := (others => (others => '0') );

begin
    process(Spi_Clk, Spi_Reset_n, Spi_lockedloop) is
    begin
        if (Spi_Reset_n = '1') then
			Spi_SpiTxWord <= (others => '0');
			Spi_SpiRxWord <= (others => (others => '0'));
            Spi_SpiWordCounter <= (others => '0');
            Spi_SpiBitCnt <= Spi_SpiBits;
            Spi_SpiSlaveState <= IDLE_STATE;
            Spi_WriteAddress <= (others => '0');
            Spi_So <= '0';
            Spi_WrEn <= '1';
            Spi_Words <= 0;
			Spi_EndSpi <= '1';
            Spi_SiReg <= (others => '0');
            Spi_CsCurrent <= '1';
            Spi_SpiClkPrev <= '0';
            Spi_SpiClkCurrent <= '0';

        elsif rising_edge(Spi_Clk) and Spi_lockedloop = '1' then
            case Spi_SpiSlaveState is
                when IDLE_STATE =>
                    if ( Spi_StartSpi = '1' and Spi_CsCurrent = '0')   then
                        Spi_Words <= 0;
                        Spi_EndSpi <= '0';
                        if (Spi_SpiClkCurrent = '1') then
                            -- MISO READ 
                            Spi_SpiRxWord(0)(to_integer(SpiBitCnt)) <= Spi_SiReg(0);
                            Spi_SpiRxWord(1)(to_integer(SpiBitCnt)) <= Spi_SiReg(1);
                            Spi_SpiRxWord(2)(to_integer(SpiBitCnt)) <= Spi_SiReg(2);
                            -- BRAM DISABLE 
                            Spi_WrEn <= '0';
                            Spi_SpiBitCnt <= Spi_SpiBitCnt - 1;
                            Spi_SpiSlaveState <= FALL_DETECT;
                        else
                            Spi_SpiSlaveState <= RISE_DETECT_START;
                        end if;
                    else
                        Spi_WriteAddress <= (others => '0');
                        Spi_SpiSlaveState <= IDLE_STATE;
                        Spi_SpiBitCnt <= Spi_SpiBits;
                        Spi_SpiWordCounter <= (others => '0');
                        Spi_SpiTxWord <= (others => '0');
                        Spi_SpiRxWord <= (others => '0');
                        Spi_So <= '0';
                    end if;

                    when RISE_DETECT_START =>
                        if (Spi_CsCurrent ='1') then
                            -- MSB FIRST
                            Spi_WriteDataWord <= SpiRxWord;
                            Spi_WrEn <= '1';
                            Spi_SpiSlaveState <= END_STATE;
                        elsif (SpiClkCurrent = '1' and SpiClkPrev = '0') then
                            -- MISO READ 
                            Spi_SpiRxWord(0)(to_integer(SpiBitCnt)) <= Spi_SiReg(0);
                            Spi_SpiRxWord(1)(to_integer(SpiBitCnt)) <= Spi_SiReg(1);
                            Spi_SpiRxWord(2)(to_integer(SpiBitCnt)) <= Spi_SiReg(2);
                             --BRAM DISABLE
                            Spi_WrEn <= '0';
                            Spi_So <= SpiTxWord(to_integer(SpiBitCnt));
                            Spi_SpiSlaveState <= CLOCK_HIGH;
                            Spi_SpiBitCnt <= Spi_SpiBitCnt - 1;
                        end if;

                when RISE_DETECT =>
                    if (Spi_CsCurrent ='1') then
                        -- MSB FIRST
                        Spi_WriteDataWord <= SpiRxWord;
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    elsif (Spi_SpiClkCurrent = '1' and Spi_SpiClkPrev = '0') then
                         -- MISO READ 
                        Spi_SpiRxWord(0)(to_integer(SpiBitCnt)) <= Spi_SiReg(0);
                        Spi_SpiRxWord(1)(to_integer(SpiBitCnt)) <= Spi_SiReg(1);
                        Spi_SpiRxWord(2)(to_integer(SpiBitCnt)) <= Spi_SiReg(2);
                        --BRAM DISABLE
                        Spi_WrEn <= '0';
						Spi_So <= Spi_SpiTxWord(to_integer(Spi_SpiBitCnt));
                        IF (Spi_SpiBitCnt = Spi_SpiBits) then
                            Spi_WriteAddress <= std_logic_vector(unsigned(Spi_WriteAddress) + 1);
                        END IF;
                        Spi_SpiSlaveState <= CLOCK_HIGH;
                        Spi_SpiBitCnt <= SpiBitCnt - 1;
                    end if;

                when CLOCK_HIGH =>
                    if (Spi_CsCurrent ='1') then
                        -- MSB FIRST
                        Spi_WriteDataWord <= Spi_SpiRxWord;
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    elsif (Spi_SpiClkCurrent = '1') then
                        if Spi_SpiWordCounter = Spi_SpiWords then
                            -- MSB FIRST
                            Spi_WriteDataWord <= Spi_SpiRxWord;
                            Spi_WrEn <= '1';
                            Spi_SpiSlaveState <= END_STATE;
                        elsif Spi_SpiBitCnt = Spi_SpiBits then
                            -- MSB FIRST
                            Spi_WriteDataWord <= Spi_SpiRxWord;
                            Spi_WrEn <= '1';
                            Spi_Words <= to_integer(Spi_SpiWordCounter + 1);
                            Spi_SpiWordCounter <= Spi_SpiWordCounter + 1;
                            Spi_SpiTxWord <= Spi_SpiRxWord(0);
                            Spi_SpiSlaveState <= FALL_DETECT;
                        else
                            Spi_SpiSlaveState <= FALL_DETECT;
                        end if;
                    end if;

                when FALL_DETECT =>
                    if (Spi_CsCurrent ='1') then
                        -- MSB FIRST
                        Spi_WriteDataWord <= Spi_SpiRxWord;
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    elsif (Spi_SpiClkCurrent = '0' and Spi_SpiClkPrev = '1') then
                         -- MISO READ 
                        Spi_SpiRxWord(0)(to_integer(SpiBitCnt)) <= Spi_SiReg(0);
                        Spi_SpiRxWord(1)(to_integer(SpiBitCnt)) <= Spi_SiReg(1);
                        Spi_SpiRxWord(2)(to_integer(SpiBitCnt)) <= Spi_SiReg(2);
                        -- BRAM DISABLE
                        Spi_WrEn <= '0';
                        Spi_So <= Spi_SpiTxWord(to_integer(Spi_SpiBitCnt));
                        IF (Spi_SpiBitCnt = Spi_SpiBits) then
                            Spi_WriteAddress <= std_logic_vector(unsigned(Spi_WriteAddress) + 1);
                        END IF;
                        Spi_SpiSlaveState <= CLOCK_LOW;
                        Spi_SpiBitCnt <= SpiBitCnt - 1;
                    end if;

                when CLOCK_LOW =>
                    if (Spi_CsCurrent ='1') then
                        -- MSB FIRST
                        Spi_WriteDataWord <= Spi_SpiRxWord;
                        Spi_WrEn <= '1';
                        Spi_SpiSlaveState <= END_STATE;
                    elsif (Spi_SpiClkCurrent = '0') then
                        if Spi_SpiWordCounter = Spi_SpiWords then
                            -- MSB FIRST
                            Spi_WriteDataWord <= Spi_SpiRxWord;
                            Spi_WrEn <= '1';
                            Spi_SpiSlaveState <= END_STATE;
                        elsif Spi_SpiBitCnt = Spi_SpiBits then
                            -- MSB FIRST
                            Spi_WriteDataWord <= Spi_SpiRxWord;
                            Spi_WrEn <= '1';
                            Spi_Words <= to_integer(Spi_SpiWordCounter + 1);
                            Spi_SpiWordCounter <= Spi_SpiWordCounter + 1;
                            Spi_SpiTxWord <= Spi_SpiRxWord(0);
                            Spi_SpiSlaveState <= RISE_DETECT;
                        else
                            Spi_SpiSlaveState <= RISE_DETECT;
                        end if;
                    end if;

                

                when END_STATE =>
                    Spi_WrEn <= '0';
                    Spi_So <= '0';
                    Spi_SpiWordCounter <= (others => '0');
                    Spi_EndSpi <= '1';
                    Spi_SpiSlaveState <= IDLE_STATE;
                    Spi_SpiBitCnt <= Spi_SpiBits;

                when others => 
                    null;
            end case;
            Spi_SpiClkPrev <= Spi_SpiClkCurrent;
            Spi_SpiClkCurrent <= Spi_SpiClk;
            Spi_CsCurrent <= Spi_Cs;
            Spi_SiReg <= Spi_Si;
	end if;
    end process;

end architecture;
