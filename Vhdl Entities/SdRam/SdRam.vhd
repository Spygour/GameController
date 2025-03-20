library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SdRamTypes.all


entity SdRam is 
    generic();

    port(Reset_n : in std_logic := '1';
         CLK : in std_logic := '0';
	     PllLocked : in std_logic := '1';
         Address : out std_logic_vector (12 downto 0) := (others => '0');
         Bank : out std_logic_vector (1 downto 0) := (others => '0');
         CAS : out std_logic := '0';
         CKE : out std_logic := '0';
         CS : out std_logic := '0';
         DQM : out std_logic_vector (0 to 1) := (others => '0');
         DQ : inout std_logic_vector (15 downto 0) : (others => '0');
         RAS : out std_logic := '0';
         WE : out std_logic := '0';
         RdEn : in std_logic := '0';
         WrEn : in std_logic := '0';
	     RdFinish : out std_logic := '0';
	     WrFinish : out std_logic := '0;
         DataCols : out DataCols_t := (others => (others => '0');
         RowsAddress : in std_logic_vector (9 downto 0) := (others => '0');
         ColsAddress : in std_logic_vector (9 downto 0) := (others => '0');
         );
         );

end SdRam;

architecture rtl of SdRam is

    type SDRAM_STATE is
    (
        POWERON,
        DELAY,
        POWERDOWN,
        IDLE_STATE,
        MODE_REGISTER_SET,
        ROW_ACTIVE,
        WRITE_STATE,
        READ_STATE,
        READ_STORE,
        PRECHARGE_ALL,
        PRECHARGE
        AUTO_REFRESH_STARTUP,
        SELF_REFRESH_EXIT,
        NOP_WITH_COUNTER,

    );
    
    signal SdRamState : SDRAM_STATE := POWERON;
    signal SdRamNextState : SDRAM_STATE := POWERON;
    signal NopCounter : integer := 0;
    signal NopThreshold : integer := 0;
    signal DatacolsIndex : integer := 0;



begin
    process(Reset_n, PllLocked) is
    begin
        if (Reset_n = '1') then
            DatacolsIndex <= 0;
            NopCounter <= 0;
            SdRamState <= POWERON;
            NopThreshold <= 0;
            -- Start with 4 in order to set it to 0
            Bank <= x"4";
            DQM <= b"11";
	    RdFinish <= '1';
	    WrFinish <= '1';
        elsif rising_edge(CLK) and PllLocked = '1' then --Here we should increase the counter
            case SdRamState is
                when POWERON =>
                    Bank <= (others => '0');
                    SdRamNextState <= PRECHARGE_ALL;
                    SdRamState <= DELAY;
                    NopThreshold <= 10000; --100 us  = 10000 cycles with 100 mhz speed
                    -- APPLY NOP HERE
                    CKE <= '1';
                    CS <= '0';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    NopCounter <= NopCounter + 1;

                when DELAY =>
                    if (NopCounter = NopThreshold) then
                        NopCounter <= 0;
                        -- APPLY NOP HERE
                        CKE <= '1';
                        CS <= '0';
                        RAS <= '1';
                        CAS <= '1';
                        WE <= '1';
                        SdRamState <= SdRamNextState;
                    else
                        NopCounter <= NopCounter + 1;
                    end if;
                
                when PRECHARGE_ALL =>
		            -- Send precharge command
		            DQM <= b"11";
                    CKE <= '1';
                    CS <= '0';
                    RAS <=  '0';
                    CAS <= '1';
                    WE <= '0';
                    Address(10) <= '1';
                    NopThreshold <= 1; -- Number of repetitions is 2
                    SdRamState <= AUTO_REFRESH_STARTUP;

                when AUTO_REFRESH_STARTUP =>
		             -- Send auto refresh command
                    CKE <= '1';
                    CS <= '0';
                    RAS <= '0';
                    CAS <= '0';
                    WE <= '1';
		            -- Move to no0
                    SdRamState <= NOP;
                    if (NopCounter = NopThreshold) then
                        NopCounter = 0;
			            -- AutoRefresh -> NOP -> AutoRefresh -> NOP -> MODE_REGISTER_SET
                        SdRamNextState <= MODE_REGISTER_SET;
                    else
			            NopCounter <= NopCounter + 1;
                        SdRamNextState <= AUTO_REFRESH_STARTUP;
                    end if;

                when MODE_REGISTER_SET =>
                    --SEND REGISTER MODE
                    CKE <= '1';
                    CS <= '0';
                    RAS <= '0';
                    CAS <= '0';
                    WE <= '0';
                    Bank <= (others => '0');
                    -- CAS LATENCY = 2 AND BURST LENGTH  = 2
                    Address(9 downto 0) <= x"22";
                    SdRamState <= NOP_WITH_COUNTER;
		            NopThreshold <= 0;
                    SdRamNextState <= IDLE;
                
                when IDLE =>
                    if  RdEn = '0' and WrEn = '0' then
                        -- SEND SELF REFRESH
                        CKE <= '0';
                        CS <= '0';
                        RAS <= '0';
                        CAS <= '0';
                        WE <= '1';
                        Address <= (others => '0');
                        SdRamState <= SELF_REFRESH_EXIT;
                        NopThreshold <= 9;
                    else
                        SdRamState <= ACTIVE;
                    end if;


                when SELF_REFRESH_EXIT =>
                    if (NopCounter = 10) then
                        NopCounter <= 1;
                        NopThreshold <= 1;
                        -- SEND NOP 
                        CKE <= '1';
                        CS <= '0';
                        RAS <= '1';
                        CAS <= '1';
                        WE <= '1';
                        SdRamNextState <= IDLE;
                        SdRamState <= NOP_WITH_COUNTER;
                    else
                        NopCounter <= NopCounter + 1;
                        SdRamState <= SELF_REFRESH_EXIT;
                    end if;


                when ACTIVE =>
                    -- Inputs here are the Row and the Bank which is 0 at startup
                    if Bank = x"4" then
                        Bank <= x"0";
                    else
                        Bank <= std_logic(unsigned(Bank) + 1);
                    end if;
                    Address(9 downto 0) <= RowsAddress;
                    -- SEND ACTIVE 
                    CKE <= '1';
                    CS <= '0';
                    RAS <= '0';
                    CAS <= '1';
                    WE <= '1';
                    NopCounter = 0;
                    if (RdEn = '1') then
			            -- This will be used to update the next rows once this happens
			            RdFinish <= '0';
                        --Go to nop for one cycle since we run at 100 mhz
                        NopThreshold <= 0;
                        SdRamNextState <= READ_STATE;
                        SdRamState <=  NOP_WITH_COUNTER;
                    else
			            -- This will be used to update the next rows once this happens
			            WrFinish <= '0';
                       --Go to nop for one cycle since we run at 100 mhz
                        NopThreshold <= 0;
                        SdRamNextState <= WRITE_STATE;
                        SdRamState <=  NOP_WITH_COUNTER;
                    end if;

                when READ_STATE =>
                    -- Auto Precharge so just a nop after the end of read (READ_STORE)
                    Address(10) = '1';
                    CS <= '0';
                    RAS <= '1';
                    CAS <= '0';
                    WE <= '1';
		            DQM <= b"00";
                    -- Choose the collumns address
                    Address(9 downto 0) <= ColsAddress;
                    NopThreshold <= 0;
                    SdRamNextState <= READ_STORE;
                    SdRamState <=  NOP_WITH_COUNTER;

                when READ_STORE =>
                    if (DataColsIndex = 1) then
			            RdFinish <= '1';
                        DataCols(DatacolsIndex) <= DQ;
                        DatacolsIndex <= 0;
                        DQM <= b"11";
                        -- Wait extra time here thats why its zero (WAIT FOR PRECHARGE)
                        NopThreshold <= 0;
                        SdRamNextState <= ACTIVE;
                        SdRamState <= NOP_WITH_COUNTER;
                    else
                        DataCols(DatacolsIndex) <= DQ;
                        DataColsIndex <= DataColsIndex+1;
                        SdRamState <= READ_STORE;
                    end if;
                
                when WRITE_STATE =>
                    -- SEND WRITE HERE
                    CS <= '0';
                    RAS <= '1';
                    CAS <= '0';
                    WE <= '0';
                    DQ <= Datacols(DataColsIndex);
                    SdRamState <= WRITE_STORE;

                when WRITE_STORE =>
                    -- SEND NOP HERE
                    CKE <= '1';
                    CS <= '0';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    DQ <= Datacols(DataColsIndex);
                    if (DataColsIndex = 1) then
                        NopThreshold <= 0;
                        SdRamState <= NOP_WITH_COUNTER;
                        SdRamNextState <= ACTIVE;
                        DQ <= Datacols(DataColsIndex);
                        DatacolsIndex <= 0;
                    else
                        SdRamState <= WRITE_STORE;
                        DQ <= Datacols(DataColsIndex);
                        DatacolsIndex <= DatacolsIndex + 1;
                    end if;


                when NOP_WITH_COUNTER =>
                    Address(10) = '0';
                    CKE <= '1';
                    CS <= '0';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    if (NopCounter = NopThreshold) then
                        NopCounter <= 0;
                        SdRamState <= SdRamNextState;
                    else
                        NopCounter <= NopCounter + 1;
                        SdRamState <= NOP_WITH_COUNTER;
                    end if;

                when NOP =>
                    CKE <= '1';
                    CS <= '0';
                    RAS <= '1';
                    CAS <= '1';
                    WE <= '1';
                    NopCounter <= NopCounter + 1;
                    SdRamState <= SdRamNextState;
            end case;
        end if;
    end process;



end architecture;
