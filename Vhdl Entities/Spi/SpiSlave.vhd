library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SpiSlaveTypes.all;

entity SpiSlave is
    
    port(ActlClk : in std_logic := '1';
         Clk      : in std_logic := '1';
         SpiClk   : in std_logic := '0';
         Reset_n  : in std_logic := '1';
         SO     : out std_logic := '0';
         SI     : in  std_logic := '0';
         CS       : in std_logic := '1';
         StartSpi : in  std_logic := '0';
         EndSpi   : inout std_logic := '1';
         Words : out integer := 0;
         WrEn : inout std_logic := '0';
		 WriteDataWord : inout SpiWord := (others => '0');
		 ReadDataWord : in SpiWord := (others => '0');
         WriteAddress  : inout std_logic_vector (6 DOWNTO 0);
         ReadAddress : in std_logic_vector (6 DOWNTO 0);
         lockedloop : in std_logic := '0');

end SpiSlave;

architecture rtl of SpiSlave is

constant SpiBits : unsigned (4 downto 0)   := "11111";
constant SpiWords : unsigned (6 downto 0)  := "1100100";

signal SpiBitCnt  : unsigned (4 downto 0) := (others => '0');
signal SpiWordCounter : unsigned (6 downto 0) := (others => '0');
signal SpiSlaveState : Spi_State := IDLE_STATE;
signal SpiClk_prev : std_logic;
signal SpiClk_current : std_logic;
signal Cs_prev : std_logic;
signal Cs_current : std_logic;

signal SpiTxWord : SpiWord  := (others => '0');
signal SpiRxWord : SpiWord  := (others => '0');

begin
    process(Clk, Reset_n, lockedloop) is
    begin
        if (Reset_n = '1') then
			SpiTxWord <= (others => '0');
			SpiRxWord <= (others => '0');
            SpiWordCounter <= (others => '0');
            SpiBitCnt <= (others => '0');
            SpiSlaveState <= IDLE_STATE;
            WriteAddress <= (others => '0');
            SO <= '0';
            WrEn <= '0';
            Words <= 0;
			SpiClk_current <= '0';
			SpiClk_prev <= '0';
            Cs_current <= '1';
            Cs_prev <= '1';

        elsif rising_edge(Clk) and lockedloop = '1' then
            SpiClk_prev <= SpiClk_current;
            SpiClk_current <= SpiClk;
            Cs_prev <= Cs_current;
            Cs_current <= CS;

            case SpiSlaveState is
                when IDLE_STATE =>
                    if ( StartSpi = '1' and (Cs_prev = '1' and Cs_current = '0') )  then
                        SpiSlaveState <= RISE_DETECT_START;
                        SpiBitCnt <= (others => '0');
                        SpiWordCounter <= (others => '0');
                        SpiTxWord <= (others => '0');
                        SpiRxWord <= (others => '0');
                        WrEn <= '0';
                        SO <= '0';
                    end if;

                when RISE_DETECT_START =>
                    if (Cs_prev = '0' and Cs_current = '1') then
			            SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '1' and SpiClk_prev = '0') then
                        WrEn <= '0';
                        SO <= SpiTxWord(to_integer(SpiBitCnt));
                        SpiSlaveState <= CLOCK_HIGH;
                    end if;

                when RISE_DETECT =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '1' and SpiClk_prev = '0') then
                        WrEn <= '0';
						SO <= SpiTxWord(to_integer(SpiBitCnt));
                        if SpiWordCounter >= SpiWords then
                            SpiSlaveState <= END_STATE;
                        elsif SpiBitCnt <= "00000" then
                            WriteAddress <= std_logic_vector(unsigned(WriteAddress) + 1);
                            SpiSlaveState <= CLOCK_HIGH;
                        else
                            SpiSlaveState <= CLOCK_HIGH;
                        end if;
                    end if;

                when CLOCK_HIGH =>
                    if (SpiClk_current = '1' and SpiClk_prev = '1') then
                        SpiSlaveState <= FALL_DETECT;
                    elsif (Cs_prev = '0' and Cs_current = '1') then
			            SpiSlaveState <= END_STATE;
                    end if;

                when FALL_DETECT =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '0' and SpiClk_prev = '1') then
                        SpiRxWord(to_integer(SpiBitCnt)) <= SI;
                        SpiSlaveState <= CLOCK_LOW;
                    end if;

                when CLOCK_LOW =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '0' and SpiClk_prev = '0') then
                        SpiSlaveState <= RISE_DETECT;
                        if (SpiBitCnt = SpiBits) then
							WrEn <= '1';
                            SpiWordCounter <= SpiWordCounter + 1;
                            WriteDataWord <= SpiRxWord;
                            SpiTxWord <= SpiRxWord;
                            SpiBitCnt <= (others => '0');
			            else
			                SpiBitCnt <= SpiBitCnt + 1;
                        end if;
                    end if;


                when END_STATE =>
					WriteAddress <= (others => '0');
                    SO <= '0';
                    WrEn <= '0';
                    WriteDataWord <= SpiRxWord;
                    SpiTxWord <= ReadDataWord;
                    Words <= to_integer(SpiWordCounter);
                    SpiWordCounter <= (others => '0');
                    EndSpi <= '1';
                    SpiSlaveState <= IDLE_STATE;

                when others => NULL;
            end case;
	end if;
    end process;
end architecture;
