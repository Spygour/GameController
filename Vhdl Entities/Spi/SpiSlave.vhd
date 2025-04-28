library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SpiSlaveTypes.all;

entity SpiSlave is
    
    port(ActlClk : in std_logic := '0';
         Clk      : in std_logic := '0';
         SpiClk   : in std_logic;
         Reset_n  : in std_logic := '1';
         SO     : out std_logic := '0';
         SI     : in  std_logic;
         CS       : in std_logiC;
         StartSpi : in  std_logic := '0';
         EndSpi   : inout std_logic := '1';
         Words : out integer := 0;
         WrEn : inout std_logic := '0';
		 WriteDataWord : inout SpiWord := (others => '0');
		 ReadDataWord : in SpiWord := (others => '0');
         WriteAddress  : inout std_logic_vector (7 DOWNTO 0);
         ReadAddress : in std_logic_vector (7 DOWNTO 0);
         lockedloop : in std_logic := '0');

end SpiSlave;

architecture rtl of SpiSlave is

constant SpiBits : unsigned (3 downto 0)   := b"1111";
constant SpiWords : unsigned (7 downto 0)  := b"11111111";

signal SpiBitCnt  : unsigned (3 downto 0) := SpiBits;
signal SpiWordCounter : unsigned (7 downto 0) := (others => '0');
signal SpiSlaveState : Spi_State := IDLE_STATE;
signal SpiClk_prev : std_logic;
signal SpiClk_current : std_logic;
signal CS_current : std_logic;
signal SI_reg : std_logic := '0';

signal SpiTxWord : SpiWord  := (others => '0');
signal SpiRxWord : SpiWord  := (others => '0');

begin
    process(Clk, Reset_n, lockedloop) is
    begin
        if (Reset_n = '1') then
			SpiTxWord <= (others => '0');
			SpiRxWord <= (others => '0');
            SpiWordCounter <= (others => '0');
            SpiBitCnt <= SpiBits;
            SpiSlaveState <= IDLE_STATE;
            WriteAddress <= (others => '0');
            SO <= '0';
            WrEn <= '1';
            Words <= 0;
			EndSpi <= '1';
            SI_reg <= '0';
            CS_current <= '1';
            SpiClk_prev <= '0';
            SpiClk_current <= '0';

        elsif rising_edge(Clk) and lockedloop = '1' then
            case SpiSlaveState is
                when IDLE_STATE =>
                    if ( StartSpi = '1' and CS_current = '0')   then
                        EndSpi <= '0';
                        if (SpiClk_current = '1') then
                            SpiRxWord(to_integer(SpiBitCnt)) <= SI_reg;
                            WrEn <= '0';
                            SpiBitCnt <= SpiBitCnt - 1;
                            SpiSlaveState <= FALL_DETECT;
                        else
                            SpiSlaveState <= RISE_DETECT_START;
                        end if;
                    else
                        WriteAddress <= (others => '0');
                        SpiSlaveState <= IDLE_STATE;
                        SpiBitCnt <= SpiBits;
                        SpiWordCounter <= (others => '0');
                        SpiTxWord <= (others => '0');
                        SpiRxWord <= (others => '0');
                        SO <= '0';
                    end if;

                    when RISE_DETECT_START =>
                        if (CS_current ='1') then
                            -- MSB FIRST
                            WriteDataWord <= SpiRxWord;
                            WrEn <= '1';
                            SpiSlaveState <= END_STATE;
                        elsif (SpiClk_current = '1' and SpiClk_prev = '0') then
                            SpiRxWord(to_integer(SpiBitCnt)) <= SI_reg;
                            WrEn <= '0';
                            SO <= SpiTxWord(to_integer(SpiBitCnt));
                            SpiSlaveState <= CLOCK_HIGH;
                            SpiBitCnt <= SpiBitCnt - 1;
                        end if;

                when CLOCK_LOW =>
                    if (CS_current ='1') then
                        -- MSB FIRST
                        WriteDataWord <= SpiRxWord;
                        WrEn <= '1';
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '0') then
                        if SpiWordCounter = SpiWords then
                            -- MSB FIRST
                            WriteDataWord <= SpiRxWord;
                            WrEn <= '1';
                            SpiSlaveState <= END_STATE;
                        elsif SpiBitCnt = SpiBits then
                            -- MSB FIRST
                            WriteDataWord <= SpiRxWord;
                            WrEn <= '1';
                            Words <= to_integer(SpiWordCounter);
                            SpiWordCounter <= SpiWordCounter + 1;
                            SpiTxWord <= SpiRxWord;
                            SpiSlaveState <= RISE_DETECT;
                        else
                            SpiSlaveState <= RISE_DETECT;
                        end if;
                    end if;

                when CLOCK_HIGH =>
                    if (CS_current ='1') then
                        -- MSB FIRST
                        WriteDataWord <= SpiRxWord;
                        WrEn <= '1';
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '1') then
                        if SpiWordCounter = SpiWords then
                            -- MSB FIRST
                            WriteDataWord <= SpiRxWord;
                            WrEn <= '1';
                            SpiSlaveState <= END_STATE;
                        elsif SpiBitCnt = SpiBits then
                            -- MSB FIRST
                            WriteDataWord <= SpiRxWord;
                            WrEn <= '1';
                            Words <= to_integer(SpiWordCounter);
                            SpiWordCounter <= SpiWordCounter + 1;
                            SpiTxWord <= SpiRxWord;
                            SpiSlaveState <= FALL_DETECT;
                        else
                            SpiSlaveState <= FALL_DETECT;
                        end if;
                    end if;

                when RISE_DETECT =>
                    if (CS_current ='1') then
                        -- MSB FIRST
                        WriteDataWord <= SpiRxWord;
                        WrEn <= '1';
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '1' and SpiClk_prev = '0') then
                        SpiRxWord(to_integer(SpiBitCnt)) <= SI_reg;
                        WrEn <= '0';
						SO <= SpiTxWord(to_integer(SpiBitCnt));
                        IF (SpiBitCnt = SpiBits) then
                            WriteAddress <= std_logic_vector(unsigned(WriteAddress) + 1);
                        END IF;
                        SpiSlaveState <= CLOCK_HIGH;
                        SpiBitCnt <= SpiBitCnt - 1;
                    end if;

                when FALL_DETECT =>
                    if (CS_current ='1') then
                        -- MSB FIRST
                        WriteDataWord <= SpiRxWord;
                        WrEn <= '1';
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '0' and SpiClk_prev = '1') then
                        SpiRxWord(to_integer(SpiBitCnt)) <= SI_reg;
                        WrEn <= '0';
                        SO <= SpiTxWord(to_integer(SpiBitCnt));
                        IF (SpiBitCnt = SpiBits) then
                            WriteAddress <= std_logic_vector(unsigned(WriteAddress) + 1);
                        END IF;
                        SpiSlaveState <= CLOCK_LOW;
                        SpiBitCnt <= SpiBitCnt - 1;
                    end if;

                

                when END_STATE =>
                    WrEn <= '0';
                    SO <= '0';
                    Words <= 0;
                    SpiWordCounter <= (others => '0');
                    EndSpi <= '1';
                    SpiSlaveState <= IDLE_STATE;
                    SpiBitCnt <= SpiBits;

                when others => 
                    null;
            end case;
            SpiClk_prev <= SpiClk_current;
            SpiClk_current <= SpiClk;
            CS_current <= CS;
            SI_reg <= SI;
	end if;
    end process;

end architecture;
