library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SdRamTypes.all;


entity SdRamHandler is 
    port(Reset_n : in std_logic := '1';
         ActlClk : in std_logic := '1';
         CLK : out std_logic := '0';
         Address : out std_logic_vector (12 downto 0) := (others => '0');
         Bank : inout std_logic_vector (1 downto 0) := (others => '0');
         CAS : out std_logic := '0';
         CKE : out std_logic := '0';
         CS : out std_logic := '0';
         DQM : out std_logic_vector (0 to 1) := (others => '0');
         DQ : inout std_logic_vector (15 downto 0) := (others => '0');
         RAS : out std_logic := '0';
         WE : out std_logic := '0';
			SdRamEnd : out std_logic := '0'
         );

end SdRamHandler;

architecture rtl of SdRamHandler is

    type SDRAMHANDLER_STATE is
    (
        IDLE,
        START_WRITE,
        CHECK_START,
        END_WRITE
    );
    signal SdRamHandlerState : SDRAMHANDLER_STATE := IDLE;
    signal Wren : std_logic := '0';
	 signal RdEn : std_logic := '0';
    signal RdFinish : std_logic := '1';
    signal WrFinish : std_logic := '1';
    signal DataColsOutput : std_logic_vector (15 downto 0) := (others => '0');
	 signal DataColsInput : std_logic_vector (15 downto 0) := (others => '0');
    signal RowsAddress : unsigned (9 downto 0) := (others => '0');
    signal ColsAddress : unsigned (9 downto 0) := (others => '0');
    signal PllLocked : std_logic := '0';
	 signal SdRamClock : std_logic := '0';

begin

    SdRamPll:entity work.SdRamPll(SYN)
    port map
    (
        areset => Reset_n,
		  inclk0 => ActlClk,	
	     c0     => SdRamClock,
	     locked => PllLocked
    );


    SdRam:entity work.SdRam(SYN)
    port map
    (
        Reset_n     => Reset_n,
        CLK         => CLK,
		  SdRamClock  => SdRamClock,
        PllLocked   => PllLocked,
        Address     => Address,
        Bank        => Bank, 
        CAS         => CAS,
        CKE         => CKE,
        CS          => CS,
        DQM         => DQM,
        DQ          => DQ,
        RAS         => RAS,
        WE          => WE,
        RdEn        => RdEn, 
        WrEn        => WrEn,
        RdFinish    => RdFinish,
        WrFinish    => WrFinish,
        DataColsInput => DataColsInput,
		  DataColsOutput => DataColsOutput,
        RowsAddress => RowsAddress,
        ColsAddress => ColsAddress
    );

    process(SdRamClock ,Reset_n, PllLocked) is
    begin
        if (Reset_n = '1') then
            SdRamHandlerState <= IDLE;
				RdEn <= '0';
				DataColsInput <= (others => '0');
				SdRamEnd <= '0';
        elsif rising_edge(SdRamClock) and PllLocked = '1' then --Here we should increase the counter
            case SdRamHandlerState is
                when IDLE =>
                    SdRamHandlerState <= START_WRITE;
                    DataColsInput <= x"A412";
                when START_WRITE =>
                    RowsAddress <= to_unsigned(15, 10);
                    ColsAddress <= to_unsigned(5, 10);
                    WrEn <= '1';
                    SdRamHandlerState <= CHECK_START;
                
                when CHECK_START =>
                    if (WrFinish = '0') then
                        -- Deactivate the write enable
                        WrEn <= '0';
								RdEn <= '0';
                        SdRamHandlerState <= END_WRITE;
                    else
                        -- DO NOTHING JUST WAIT
                        SdRamHandlerState <= CHECK_START;
                    end if;

                when END_WRITE =>
                    if (WrFinish = '1') then
								SdRamEnd <= '1';
                        -- Go back to IDLE STATE
                        SdRamHandlerState <= IDLE;
                    else
                        SdRamHandlerState <= END_WRITE;
                    end if;

            end case;
        end if;
    end process;
			
end architecture;
