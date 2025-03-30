library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SdRamTypes.all;

entity SdRamHandler is 
    port(Reset_n : in std_logic := '1';
         ActlClk : in std_logic := '0';
         SDRAM_CLKOUT : out std_logic;
         Address : out std_logic_vector (12 downto 0) := (others => '0');
         Bank : inout std_logic_vector (1 downto 0) := (others => '0');
         CAS : out std_logic := '0';
         CKE : out std_logic := '0';
         CS : out std_logic := '1';
         DQM : out std_logic_vector (0 to 1) := (others => '0');
         DQ : inout std_logic_vector (15 downto 0) := (others => '0');
         RAS : out std_logic := '0';
         WE : out std_logic := '0';
		 DebugLeds : out std_logic_vector (7 downto 0) := (others => '0')
         );

end SdRamHandler;

architecture rtl of SdRamHandler is

    type SDRAMHANDLER_STATE is
    (
        IDLE,
		IDLE2,
        START_WRITE,
        CHECK_WRITE,
        START_READ,
        CHECK_READ,
        END_READ,
		VALIDATE_READ,
        DELAY_RESTART
    );
    signal SdRamHandlerState : SDRAMHANDLER_STATE := IDLE;
    signal Wren : std_logic := '0';
	signal RdEn : std_logic := '0';
    signal RdFinish : std_logic := '1';
    signal WrFinish : std_logic := '1';
    signal DataColsOutput : DataCols_t := (others => (others => '0'));
	signal DataColsInput : DataCols_t := (others => (others => '0'));
    signal RowsAddress : unsigned (12 downto 0) := (others => '0');
    signal ColsAddress : unsigned (9 downto 0) := (others => '0');
    signal PllLocked : std_logic := '0';
    signal Reset_Sync : std_logic := '1';
	signal SdRamClk : std_logic := '0';
    signal GlobalClk : std_logic := '0';
	signal SdRamEnd : std_logic := '0';
    signal Cnt : integer := 0;
    signal Index : STD_LOGIC_VECTOR (0 downto 0) := (others => '0');
    signal switch : std_logic := '0';
	component SdRamSysClock is
		port (
			ref_clk_clk        : in  std_logic := 'X'; -- clk
			ref_reset_reset    : in  std_logic := 'X'; -- reset
			sys_clk_clk        : out std_logic;        -- clk
			sdram_clk_clk      : out std_logic;        -- clk
			reset_source_reset : out std_logic         -- reset
		);
	end component SdRamSysClock;

begin
    SdRamPll:entity work.SdRamPll(SYN)
    port map
    (
       areset => Reset_n,
	   inclk0 => ActlClk,	
	   c0     => SdRamClk,
       c1     => GlobalClk,
	   locked => PllLocked
    );

    SdRam:entity work.SdRam(SYN)
    port map
    (
        ActlClk     => ActlClk,
        Reset_n     => Reset_Sync,
        SDRAM_CLKOUT => SDRAM_CLKOUT,
		SdRamClk    => SdRamClk,
        GlobalClk  => GlobalClk,
        PllLocked   => PllLocked,
        Address     => Address,
        Bank        => Bank, 
        CAS         => CAS,
        CKE         => CKE,
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
    process(SdRamClk ,Reset_Sync, PllLocked) is
    begin
        if (Reset_Sync = '1') then
            Index(0) <= '0';
            SdRamHandlerState <= IDLE;
			RdEn <= '0';
            WrEn <= '0';
			DataColsInput <= (others => (others => '0'));
			SdRamEnd <= '0';
			RowsAddress <= to_unsigned(0,13);
			ColsAddress <= to_unsigned(0,10);
			DebugLeds <= b"00000000";
            Cnt <= 0;
            switch <= '0';
        elsif rising_edge(SdRamClk) and PllLocked = '1' then
            case SdRamHandlerState is
                when IDLE =>
                    SdRamHandlerState <= START_WRITE;
                    if switch = '0' then
                        DataColsInput(1) <= x"0F12";
								DataColsInput(0) <= x"1500";
                    else
                        DataColsInput(1) <= x"4312";
								DataColsInput(0) <= x"23FF";
                    end if;

                when START_WRITE =>
                    RowsAddress <= to_unsigned(15, 13);
                    ColsAddress <= to_unsigned(5, 10);
                    WrEn <= '1';
                    SdRamHandlerState <= CHECK_WRITE;
                
                when CHECK_WRITE =>
                    if (WrFinish = '0') then
                        -- Deactivate the write enable
                        WrEn <= '0';
						RdEn <= '0';
                        SdRamHandlerState <= START_READ;
                    else
                        -- DO NOTHING JUST WAIT
                        SdRamHandlerState <= CHECK_WRITE;
                    end if;

                when START_READ =>
                    if (WrFinish = '1') then
                        -- Go to wait state for testing reasons
                        SdRamHandlerState <= CHECK_READ;
                        RdEn <= '1';
                        RowsAddress <= to_unsigned(15, 13);
                        ColsAddress <= to_unsigned(5, 10);
                    else
                        SdRamHandlerState <= START_READ;
                    end if;

                WHEN CHECK_READ =>
                    if (RdFinish = '0') then
                        -- Deactivate the read enable
                        RdEn <= '0';
                        WrEn <= '0';
                        SdRamHandlerState <= VALIDATE_READ;
                    else
                        SdRamHandlerState <= CHECK_READ;
                    end if;
                
                WHEN VALIDATE_READ =>
                    if RdFinish = '1' then
                        if (to_integer(unsigned(DataColsOutput(0)) ) = to_integer(unsigned(DataColsInput(0)) ) ) then
                            SdRamEnd <= '0';
                        else
                            SdRamEnd <= '1';
                        end if;
                        DebugLeds <= DataColsOutput(to_integer(unsigned(Index)))(15 downto 8);
                        SdRamHandlerState <= DELAY_RESTART;
                    else
                        SdRamHandlerState <= VALIDATE_READ;
                    end if;

                when DELAY_RESTART =>
                    if Cnt = 100000000 then
                        Cnt <= 0;
                        if (Index(0) = '1') then
									 Index(0) <= '0';
                            switch <= not switch;
									 SdRamHandlerState <= IDLE;
                        else
									 Index(0) <= '1';
                            SdRamHandlerState <= VALIDATE_READ;
                        end if;
                    else
                        Cnt <= Cnt + 1;
                    end if;

                when others => null;
            end case;
        end if;
    end process;

    process (Reset_n, PllLocked) is
    begin
        if (Reset_n = '1') then
            Reset_Sync <= '1';
            CS <= '1';
        elsif PllLocked='1' then
            CS <= '0';
            Reset_Sync <= '0';
		  else
			Reset_Sync <= '1';
			CS <= '0';
        end if;
    end process;

end architecture;
