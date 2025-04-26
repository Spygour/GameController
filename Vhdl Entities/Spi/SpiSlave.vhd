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

signal SpiBitCnt  : unsigned (3 downto 0) := (others => '0');
signal SpiWordCounter : unsigned (7 downto 0) := (others => '0');
signal SpiSlaveState : Spi_State := IDLE_STATE;
signal SpiClk_prev : std_logic;
signal SpiClk_current : std_logic;
signal Cs_prev : std_logic;
signal Cs_current : std_logic;
signal SI_reg : std_logic := '0';
signal Store_En : std_logic := '0';

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
            Words <= 0;
			SpiClk_current <= '0';
			SpiClk_prev <= '0';
            Cs_current <= '1';
            Cs_prev <= '1';
			EndSpi <= '1';
            SI_reg <= '0';
            Store_En <= '0';

        elsif rising_edge(Clk) and lockedloop = '1' then
            SpiClk_prev <= SpiClk_current;
            SpiClk_current <= SpiClk;
            Cs_prev <= Cs_current;
            Cs_current <= CS;
            SI_reg <= SI;

            case SpiSlaveState is
                when IDLE_STATE =>
                    Store_En <= '0';
                    if ( StartSpi = '1' and (Cs_prev = '1' and Cs_current = '0') )  then
                        SpiSlaveState <= RISE_DETECT_START;
                        SpiBitCnt <= (others => '0');
                        SpiWordCounter <= (others => '0');
                        SpiTxWord <= (others => '0');
                        SpiRxWord <= (others => '0');
                        SO <= '0';
						EndSpi <= '0';
                    end if;

                when RISE_DETECT_START =>
                    if (Cs_prev = '0' and Cs_current = '1') then
			            SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '1' and SpiClk_prev = '0') then
                        SpiRxWord(to_integer(SpiBitCnt)) <= SI_reg;
                        SO <= SpiTxWord(to_integer(SpiBitCnt));
                        SpiSlaveState <= CLOCK_HIGH;
                    end if;

                when RISE_DETECT =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '1' and SpiClk_prev = '0') then
                        SpiRxWord(to_integer(SpiBitCnt)) <= SI_reg;
						SO <= SpiTxWord(to_integer(SpiBitCnt));
                        if SpiWordCounter = SpiWords then
                            SpiSlaveState <= END_STATE;
                        elsif SpiBitCnt <= b"0000" then
                            WriteAddress <= std_logic_vector(unsigned(WriteAddress) + 1);
                            SpiSlaveState <= CLOCK_HIGH;
                        else
                            SpiSlaveState <= CLOCK_HIGH;
                        end if;
                    end if;

                when CLOCK_HIGH =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '1' and SpiClk_prev = '1') then
                        SpiSlaveState <= FALL_DETECT;
                    end if;

                when FALL_DETECT =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '0' and SpiClk_prev = '1') then
                        if (SpiBitCnt = SpiBits) then
                            Store_En <= '1';
                            Words <= to_integer(SpiWordCounter);
                            SpiWordCounter <= SpiWordCounter + 1;
                            SpiTxWord <= SpiRxWord;
                            SpiBitCnt <= (others => '0');
			            else
			                SpiBitCnt <= SpiBitCnt + 1;
                        end if;
                        SpiSlaveState <= CLOCK_LOW;
                    end if;

                when CLOCK_LOW =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '0' and SpiClk_prev = '0') then
                        SpiSlaveState <= RISE_DETECT;
                    end if;
                    Store_En <= '0';


                when END_STATE =>
                    Store_En <= '1';
					WriteAddress <= (others => '0');
                    SO <= '0';
                    Words <= to_integer(SpiWordCounter);
                    SpiWordCounter <= (others => '0');
                    EndSpi <= '1';
                    SpiSlaveState <= IDLE_STATE;

                when others => NULL;
            end case;
	end if;
    end process;

    process(Clk, Reset_n, lockedloop , Store_En) is
        begin
            if (Reset_n = '1') then
                WrEn <= '0';
            elsif rising_edge(Clk) and lockedloop = '1' then
                if Store_En = '1' then
                    WrEn <= '1';
                    -- MSB FIRST
                    for i in 0 to 15 loop
                        WriteDataWord(15 - i) <= SpiRxWord(i);
                    end loop;
                else
                    WrEn <= '0';
                end if;
        end if;
	end process;
end architecture;
