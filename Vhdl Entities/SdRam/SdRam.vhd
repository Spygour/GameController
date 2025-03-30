library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SdRamTypes.all;


entity SdRam is 
    port(ActlClk : in std_logic := '0';
		 Reset_n : in std_logic := '1';
         SDRAM_CLKOUT : out std_logic := '0';
         SdRamClk : in std_logic := '0';
         GlobalClk : in std_logic := '0';
		 PllLocked : inout std_logic := '0';
         Address : out std_logic_vector (12 downto 0) := (others => '0');
         Bank : inout std_logic_vector (1 downto 0) := b"00";
         CAS : out std_logic := '0';
         CKE : out std_logic := '0';
         DQM : out std_logic_vector (0 to 1) := (others => '0');
         DQ : inout std_logic_vector (15 downto 0) := (others => 'Z');
         RAS : out std_logic := '0';
         WE : out std_logic := '0';
         RdEn : in std_logic := '0';
         WrEn : in std_logic := '0';
	     RdFinish : out std_logic := '1';
	     WrFinish : out std_logic := '1';
         DataColsInput : in DataCols_t := (others => (others => '0'));
		 DataColsOutput : out DataCols_t := (others => (others => '0'));
         RowsAddress : in unsigned (12 downto 0);
         ColsAddress : in unsigned (9 downto 0)
         );

end SdRam;

architecture SYN of SdRam is

    type SDRAM_STATE is
    (
        POWERON,
        DELAY,
        POWERDOWN,
        IDLE,
        MODE_REGISTER_SET,
        ACTIVE_STATE,
        WRITE_STATE,
        WRITE_STORE,
        BURST_TERMINATE_WRITE,
        READ_STATE,
        READ_STORE,
        BURST_TERMINATE_READ,
        PRECHARGE_ALL,
        AUTO_REFRESH_STARTUP,
        SELF_REFRESH_EXIT,
        NOP_WITH_COUNTER,
		NOP
    );
    
    signal SdRamState : SDRAM_STATE := POWERON;
    signal SdRamNextState : SDRAM_STATE := POWERON;
    signal NopCounter : integer := 0;
    signal NopThreshold : integer := 0;
    signal DatacolsIndex : integer := 0;
    signal BankSwitch : std_logic := '0';

begin

    SDRAM_CLKOUT <= GlobalClk;
    process(SdRamClk, Reset_n, PllLocked) is
    begin
        if (Reset_n = '1') then
            DatacolsIndex <= 0;
            NopCounter <= 0;
            SdRamState <= POWERON;
            NopThreshold <= 0;
            -- Start with 4 in order to set it to 0
            Bank <= b"00";
            DQM <= b"00";
            DQ <= (others => 'Z');
	        RdFinish <= '1';
	        WrFinish <= '1';
            -- NOTHING HERE
            CKE <= '0';
            RAS <= '0';
            CAS <= '0';
            WE <= '0';
            Address <= b"0000000000000";
            DataColsOutput <= (others => (others => '0'));
        elsif rising_edge(SdRamClk) and PllLocked = '1' then
            case SdRamState is
                when POWERON =>
                    -- APPLY NOP HERE
                    CKE <= '1';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    SdRamNextState <= PRECHARGE_ALL;
                    SdRamState <= DELAY;
                    NopThreshold <= 20000; --200 us  = 20000 cycles with 100 mhz speed
                    NopCounter <= NopCounter + 1;

                when DELAY =>
                    if (NopCounter = NopThreshold) then
                        NopCounter <= 0;
                        SdRamState <= SdRamNextState;
                    else
                        NopCounter <= NopCounter + 1;
                    end if;
                
                when PRECHARGE_ALL =>
		            -- Send precharge command
		            DQM <= b"11";
                    CKE <= '1';
                    RAS <=  '0';
                    CAS <= '1';
                    WE <= '0';
                    Address(10) <= '1';
                    NopThreshold <= 1; -- Number of repetitions is 2
                    SdRamState <= AUTO_REFRESH_STARTUP;

                when AUTO_REFRESH_STARTUP =>
                    Address(10) <= '0';
		             -- Send auto refresh command
                    CKE <= '1';
                    RAS <= '0';
                    CAS <= '0';
                    WE <= '1';
		            -- Move to noP
                    SdRamState <= NOP;
                    if (NopCounter = NopThreshold) then
                        NopCounter <= 0;
			            -- AutoRefresh -> NOP -> AutoRefresh -> NOP -> MODE_REGISTER_SET
                        SdRamNextState <= MODE_REGISTER_SET;
                    else
                        SdRamNextState <= AUTO_REFRESH_STARTUP;
                    end if;

                when MODE_REGISTER_SET =>
                    --SEND REGISTER MODE
                    CKE <= '1';
                    RAS <= '0';
                    CAS <= '0';
                    WE <= '0';
                    -- CAS LATENCY = 2 AND BURST LENGTH  = 1 (2 words)
                    Address <= b"0000000100001";
                    SdRamState <= NOP_WITH_COUNTER;
		            NopThreshold <= 0;
                    NopCounter <= 0;
                    SdRamNextState <= IDLE;
                
                when IDLE =>
                    if  RdEn = '0' and WrEn = '0' then
                        -- SEND SELF REFRESH
                        CKE <= '0';
                        RAS <= '0';
                        CAS <= '0';
                        WE <= '1';
                        Address(12 downto 0) <= b"0000000000000";
                        SdRamState <= SELF_REFRESH_EXIT;
                        NopThreshold <= 9;
                    else
                        -- SEND ACTIVE 
                        CKE <= '1';
                        RAS <= '0';
                        CAS <= '1';
                        WE <= '1';
						Address(12 downto 0) <= std_logic_vector(RowsAddress);
                        SdRamState <= ACTIVE_STATE;
                        DQM <= b"11";
                    end if;


                when SELF_REFRESH_EXIT =>
                    if (NopCounter = 10) then
                        NopCounter <= 1;
                        NopThreshold <= 1;
                        -- SEND NOP 
                        CKE <= '1';
                        RAS <= '1';
                        CAS <= '1';
                        WE <= '1';
                        SdRamNextState <= IDLE;
                        SdRamState <= NOP_WITH_COUNTER;
                    else
                        DQM <= b"11";
                        Address(12 downto 0) <= b"0000000000000";
                        NopCounter <= NopCounter + 1;
                        SdRamState <= SELF_REFRESH_EXIT;
                    end if;

                when ACTIVE_STATE =>
                    -- Inputs here are the Row and the Bank which is 0 at startup
                    Address <= b"0000000000000";
                    -- SEND NOP
                    CKE <= '1';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    NopCounter <= 0;
                    -- DQ is high 'z' cause we don't know if it is read or write
                    DQ <= (others => 'Z');
                    -- DQM is '11' cause we don't want to get feedback now
                    DQM <= b"11";
                    if (RdEn = '1') then
			            -- This will be used to update the next rows once this happens
			            RdFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        NopThreshold <= 0;
                        SdRamNextState <= READ_STATE;
                        SdRamState <=  NOP_WITH_COUNTER;
                    elsif WrEn = '1' or BankSwitch = '1' then
						-- This will be used to update the next rows once this happens
						WrFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        NopThreshold <= 0;
                        SdRamNextState <= WRITE_STATE;
                        SdRamState <=  NOP_WITH_COUNTER;
                    else 
                        -- This will be used to update the next rows once this happens
						WrFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        NopThreshold <= 0;
                        SdRamNextState <= WRITE_STATE;
                        SdRamState <=  NOP_WITH_COUNTER;
                    end if;

                when READ_STATE =>
                    -- SEND READ COMMAND
                    CKE <= '1';
                    RAS <= '1';
                    CAS <= '0';
                    WE <= '1';
		            DQM <= b"00";
                    -- Choose the collumns address
                    DQ <= (others => 'Z');
                    Address(12 downto 10) <= b"001";
                    Address(9 downto 0) <= std_logic_vector(ColsAddress);
                    NopThreshold <= 0;
                    SdRamNextState <= READ_STORE;
                    SdRamState <=  NOP_WITH_COUNTER;

                when READ_STORE =>
                    if (DataColsIndex = 1) then
                        DataColsOutput(DataColsIndex) <= DQ;
                        DataColsIndex <= 0;
                        if RdEn = '1' then
                            -- SEND ACTIVE
                            CKE <= '1';
                            RAS <= '0';
                            CAS <= '1';
                            WE <= '1';
                            Bank(0) <= not Bank(0);
                            Address(12 downto 0) <= std_logic_vector(RowsAddress);
                             -- Wait extra time here thats why its zero (WAIT FOR PRECHARGE)
                            SdRamState <= ACTIVE_STATE;
                            NopThreshold <= 0;
                        else
                            -- SEND SELF REFRESH
                            CKE <= '0';
                            RAS <= '0';
                            CAS <= '0';
                            WE <= '1';
                            SdRamState <= SELF_REFRESH_EXIT;
                            NopThreshold <= 9;
                            RdFinish <= '1';
                        end if;
                    else
                        DataColsOutput(DataColsIndex) <= DQ;
                        -- SEND NOP
                        CKE <= '1';
                        RAS <= '1';
                        CAS <= '1';
                        WE <= '1';
                        DataColsIndex <= DataColsIndex+1;
                        SdRamState <= READ_STORE;
                    end if;
                
                when WRITE_STATE =>
                    -- SEND WRITE HERE
                    CKE <= '1';
                    RAS <= '1';
                    CAS <= '0';
                    WE <= '0';
                    -- ENABLE AUTO PRECHARGE
                    Address <= b"001" & std_logic_vector(ColsAddress);
                    DQM <= b"00";
                    DQ <= DatacolsInput(DataColsIndex);
                    SdRamState <= WRITE_STORE;
                    DatacolsIndex <= DatacolsIndex + 1;
                    -- PREPARE TO WRITE DATA IN TWO BANKS
                    BankSwitch <= not BankSwitch;

                when WRITE_STORE =>
                    -- SEND THE DATA
                    DQ <= DatacolsInput(DataColsIndex);
                    if (DataColsIndex = 1) then
                        DataColsIndex <= 0;
                        -- SEND BURST TERMINATE
                        CKE <= '1';
                        RAS <= '1';
                        CAS <= '1';
                        WE <= '0';
                        SdRamState <= BURST_TERMINATE_WRITE;
                    else
                        -- SEND NOP HERE
                        CKE <= '1';
                        RAS <= '1';
                        CAS <= '1';
                        WE <= '1';
                        SdRamState <= WRITE_STORE;
                        DatacolsIndex <= DatacolsIndex + 1;
                    end if;

                when BURST_TERMINATE_WRITE =>
                    if BankSwitch = '1' or WrEn = '1' then
                        -- SEND ACTIVE
                        CKE <= '1';
                        RAS <= '0';
                        CAS <= '1';
                        WE <= '1';
                        Bank(0) <= not Bank(0);
                        Address(12 downto 0) <= std_logic_vector(RowsAddress);
                        SdRamState <= ACTIVE_STATE;
                        NopThreshold <= 0;
                    elsif WrEn = '0' then
                        -- SEND SELF REFRESH
                        CKE <= '0';
                        RAS <= '0';
                        CAS <= '0';
                        WE <= '1';
                        -- DEFAULT ADDRESS VALUE
                        Address(9 downto 0) <= b"0000000000";
                        SdRamState <= SELF_REFRESH_EXIT;
                        NopThreshold <= 9;
                        WrFinish <= '1';
                    end if;

                when NOP_WITH_COUNTER =>
                    -- SEND NOP HERE
                    CKE <= '1';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    Address(10) <= '0';
                    if (NopCounter = NopThreshold) then
                        NopCounter <= 0;
                        SdRamState <= SdRamNextState;
                    else
                        NopCounter <= NopCounter + 1;
                        SdRamState <= NOP_WITH_COUNTER;
                    end if;

                when NOP =>
                    CKE <= '1';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    NopCounter <= NopCounter + 1;
                    SdRamState <= SdRamNextState;
						  
					when others => null;
                end case;

        end if;
    end process;
end architecture;
