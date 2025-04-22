library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.QSpiSlaveTypes.all;

entity QSpiSlave is
    
    port(ActlClk : in std_logic := '0';
         Clk      : in std_logic := '0';
         SpiClk   : in std_logic;
         Reset_n  : in std_logic := '1';
         SO     : out std_logic := '0';
         SI     : in  std_logic_vector (2 DOWNTO 0);
         CS       : in std_logiC;
         StartSpi : in  std_logic := '0';
         EndSpi   : inout std_logic := '1';
         Words : out integer := 0;
         WrEn : inout std_logic := '0';
	 WriteDataWord : inout QSpiWord := (others => (others => '0'));
	 ReadDataWord : in QSpiWord := (others => (others => '0'));
         WriteAddress  : inout std_logic_vector (7 DOWNTO 0);
         ReadAddress : in std_logic_vector (7 DOWNTO 0);
         lockedloop : in std_logic := '0');

end QSpiSlave;

architecture rtl of QSpiSlave is

constant SpiBits : unsigned (3 downto 0)   := b"1111";
constant SpiWords : unsigned (7 downto 0)  := b"11111111";

signal SpiBitCnt  : unsigned (3 downto 0) := (others => '0');
signal SpiWordCounter : unsigned (7 downto 0) := (others => '0');
signal SpiSlaveState : Spi_State := IDLE_STATE;
signal SpiClk_prev : std_logic;
signal SpiClk_current : std_logic;
signal Cs_prev : std_logic;
signal Cs_current : std_logic;
signal SI_reg : std_logic_vector := (others => '0');

signal SpiTxWord : QSpiWord  := (others => (others => '0'));
signal SpiRxWord : QSpiWord  := (others => (others => '0'));

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
	    EndSpi <= '1';
            SI_reg <= '0';

        elsif rising_edge(Clk) and lockedloop = '1' then
            SpiClk_prev <= SpiClk_current;
            SpiClk_current <= SpiClk;
            Cs_prev <= Cs_current;
            Cs_current <= CS;
            SI_reg <= SI;

            case SpiSlaveState is
                when IDLE_STATE =>
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
                    WrEn <= '0';
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
                        SpiSlaveState <= CLOCK_LOW;
                    end if;

                when CLOCK_LOW =>
                    if (Cs_prev = '0' and Cs_current = '1') then
                        SpiSlaveState <= END_STATE;
                    elsif (SpiClk_current = '0' and SpiClk_prev = '0') then
                        if (SpiBitCnt = SpiBits) then
			    WrEn <= '1';
                            SpiWordCounter <= SpiWordCounter + 1;
                            WriteDataWord <= SpiRxWord;
                            SpiTxWord <= SpiRxWord;
                            SpiBitCnt <= (others => '0');
			else
			    SpiBitCnt <= SpiBitCnt + 1;
                        end if;
                        SpiSlaveState <= RISE_DETECT;
                    end if;


                when END_STATE =>
		    WriteAddress <= (others => '0');
                    SO <= '0';
                    WrEn <= '0';
                    WriteDataWord <= SpiRxWord;
                    SpiTxWord <= SpiRxWord;
                    Words <= to_integer(SpiWordCounter);
                    SpiWordCounter <= (others => '0');
                    EndSpi <= '1';
                    SpiSlaveState <= IDLE_STATE;

                when others => NULL;
            end case;
	end if;
    end process;
end architecture;
