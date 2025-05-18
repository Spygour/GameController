library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SdRamTypes.all;


entity SdRam is 
    port(SdRam_ActlClk : in std_logic := '0';
		 SdRam_Reset_n : in std_logic := '1';
         SdRam_ClkOut : out std_logic := '0';
         SdRam_SdRamClk : in std_logic := '0';
         SdRam_GlobalClk : in std_logic := '0';
		 SdRam_PllLocked : inout std_logic := '0';
         SdRam_Address : out std_logic_vector (12 downto 0) := (others => '0');
         SdRam_Bank : out std_logic_vector (1 downto 0) := b"00";
         SdRam_CAS : out std_logic := '0';
         SdRam_CKE : out std_logic := '0';
         SdRam_DQM : out std_logic_vector (0 to 1) := (others => '0');
         SdRam_DQ : inout std_logic_vector (15 downto 0) := (others => 'Z');
         SdRam_RAS : out std_logic := '0';
         SdRam_WE : out std_logic := '0';
         SdRam_RdEn : in std_logic := '0';
         SdRam_WrEn : in std_logic := '0';
	     SdRam_RdFinish : out std_logic := '1';
	     SdRam_WrFinish : out std_logic := '1';
         SdRam_DataColsInput : in DataCols_t := (others => (others => '0'));
		 SdRam_DataColsOutput : out DataCols_t := (others => (others => '0'));
         SdRam_RowsAddress : in unsigned (12 downto 0);
         SdRam_ColsAddress : in unsigned (8 downto 0);
         SdRam_SdRamState : inout SDRAM_STATE := POWERON;
         SdRam_BankSwitch : inout std_logic := '0'
         );

end SdRam;

architecture SYN of SdRam is
    
    signal SdRam_SdRamNextState : SDRAM_STATE := POWERON;
    signal SdRam_NopCounter : integer := 0;
    signal SdRam_NopThreshold : integer := 0;
    signal SdRam_DatacolsIndex : integer := 0;
    signal SdRam_RowsAddress_reg : unsigned (12 downto 0) := (others => '0');
    signal SdRam_ColsAddress_reg : unsigned (8 downto 0) := (others => '0');

begin

    SDRAM_CLKOUT <= SdRam_GlobalClk;
    process(SdRam_SdRamClk, SdRam_Reset_n, SdRam_PllLocked, SdRam_ColsAddress, SdRam_RowsAddress) is
    begin
        if (SdRam_Reset_n = '1') then
            SdRam_DatacolsIndex <= 0;
            SdRam_NopCounter <= 0;
            SdRam_SdRamState <= POWERON;
            SdRam_NopThreshold <= 0;
            -- Start with 4 in order to set it to 0
            SdRam_Bank <= b"00";
            SdRam_DQM <= b"00";
            SdRam_DQ <= (others => 'Z');
	        SdRam_RdFinish <= '1';
	        SdRam_WrFinish <= '1';
            -- NOTHING HERE
            SdRam_CKE <= '0';
            SdRam_RAS <= '0';
            SdRam_CAS <= '0';
            SdRam_WE <= '0';
            SdRam_Address <= b"0000000000000";
            SdRam_DataColsOutput <= (others => (others => '0'));
            SdRam_ColsAddress_reg <= SdRam_ColsAddress;
            SdRam_RowsAddress_reg <= SdRam_RowsAddress;
            SdRam_BankSwitch <= '0';
        elsif rising_edge(SdRam_SdRamClk) and SdRam_PllLocked = '1' then
            case SdRam_SdRamState is
                when POWERON =>
                    -- APPLY NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_SdRamNextState <= PRECHARGE_ALL;
                    SdRam_SdRamState <= DELAY;
                    SdRam_NopThreshold <= 20000; --200 us  = 20000 cycles with 100 mhz speed
                    SdRam_NopCounter <= SdRam_NopCounter + 1;

                when DELAY =>
                    if (SdRam_NopCounter = SdRam_NopThreshold) then
                        SdRam_NopCounter <= 0;
                        SdRam_SdRamState <= SdRam_SdRamNextState;
                    else
                        SdRam_NopCounter <= SdRam_NopCounter + 1;
                    end if;
                
                when PRECHARGE_ALL =>
		            -- Send precharge command
		            SdRam_DQM <= b"11";
                    SdRam_CKE <= '1';
                    SdRam_RAS <=  '0';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '0';
                    SdRam_Address(10) <= '1';
                    SdRam_NopThreshold <= 1; -- Number of repetitions is 2
                    SdRam_SdRamState <= AUTO_REFRESH_STARTUP;

                when AUTO_REFRESH_STARTUP =>
                    SdRam_Address(10) <= '0';
		             -- Send auto refresh command
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '1';
		            -- Move to noP
                    SdRam_SdRamState <= NOP;
                    if (SdRam_NopCounter = SdRam_NopThreshold) then
                        SdRam_NopCounter <= 0;
			            -- AutoRefresh -> NOP -> AutoRefresh -> NOP -> MODE_REGISTER_SET
                        SdRam_SdRamNextState <= MODE_REGISTER_SET;
                    else
                        SdRam_SdRamNextState <= AUTO_REFRESH_STARTUP;
                    end if;

                when MODE_REGISTER_SET =>
                    --SEND REGISTER MODE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '0';
                    -- CAS LATENCY = 2 AND BURST LENGTH  = 1 (2 words)
                    SdRam_Address <= b"0000000100001";
		            SdRam_NopThreshold <= 0;
                    SdRam_NopCounter <= 0;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;
                    SdRam_SdRamNextState <= IDLE;
                
                when IDLE =>
                    if  SdRam_RdEn = '0' and SdRam_WrEn = '0' then
                        -- SEND SELF REFRESH
                        SdRam_CKE <= '0';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '0';
                        SdRam_WE <= '1';
                        SdRam_Address(12 downto 0) <= b"0000000000000";
                        SdRam_NopThreshold <= 9;
                        SdRam_SdRamState <= SELF_REFRESH_EXIT;
                    else
                        -- SEND ACTIVE 
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
						SdRam_Address(12 downto 0) <= std_logic_vector(SdRam_RowsAddress);
                        SdRam_DQM <= b"11";
                        SdRam_RowsAddress_reg <= SdRam_RowsAddress;
                        SdRam_ColsAddress_reg <= SdRam_ColsAddress;
                        SdRam_SdRamState <= ACTIVE_STATE;
                    end if;


                when SELF_REFRESH_EXIT =>
                    if (SdRam_NopCounter = 10) then
                        SdRam_NopCounter <= 1;
                        SdRam_NopThreshold <= 1;
                        -- SEND NOP 
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_SdRamNextState <= IDLE;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    else
                        SdRam_DQM <= b"11";
                        SdRam_Address(12 downto 0) <= b"0000000000000";
                        SdRam_NopCounter <= SdRam_NopCounter + 1;
                        SdRam_SdRamState <= SELF_REFRESH_EXIT;
                    end if;

                when ACTIVE_STATE =>
                    -- Inputs here are the Row and the Bank which is 0 at startup
                    SdRam_Address <= b"0000000000000";
                    -- SEND NOP
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_NopCounter <= 0;
                    -- DQ is high 'z' cause we don't know if it is read or write
                    SdRam_DQ <= (others => 'Z');
                    -- DQM is '11' cause we don't want to get feedback now
                    SdRam_DQM <= b"11";
                    if (SdRam_RdEn = '1') then
			            -- This will be used to update the next rows once this happens
			            SdRam_RdFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= READ_STATE;
                        SdRam_ColsAddress_reg <= SdRam_CollsAddress;
                        SdRam_SdRamState <=  NOP_WITH_COUNTER;
                    elsif SdRam_WrEn = '1' or SdRam_BankSwitch = '1' then
						-- This will be used to update the next rows once this happens
						SdRam_WrFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= WRITE_STATE;
                        SdRam_SdRamState <=  NOP_WITH_COUNTER;
                    else 
                        -- This will be used to update the next rows once this happens
						SdRam_WrFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= WRITE_STATE;
                        SdRam_SdRamState <=  NOP_WITH_COUNTER;
                    end if;

                when READ_STATE =>
                    -- SEND READ COMMAND
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '1';
		            SdRam_DQM <= b"00";
                    -- Choose the collumns address
                    SdRam_DQ <= (others => 'Z');
                    SdRam_Address(12 downto 9) <= b"0010";
                    SdRam_Address(8 downto 0) <= std_logic_vector(SdRam_ColsAddress_reg);
                    SdRam_NopThreshold <= 0;
                    SdRam_SdRamNextState <= READ_STORE;
                    SdRam_SdRamState <=  NOP_WITH_COUNTER;

                when READ_STORE =>
                    if (SdRam_DataColsIndex = 1) then
                        SdRam_DataColsOutput(SdRam_DataColsIndex) <= DQ;
                        SdRam_DataColsIndex <= 0;
                        if SdRam_RdEn = '1' then
                            -- SEND ACTIVE
                            SdRam_CKE <= '1';
                            SdRam_RAS <= '0';
                            SdRam_CAS <= '1';
                            SdRam_WE <= '1';
                            SdRam_Bank(0) <= SdRam_BankSwitch;
                            SdRam_BankSwitch <= not SdRam_BankSwitch;
                            SdRam_Address(12 downto 0) <= std_logic_vector(SdRam_RowsAddress);
                            SdRam_RowsAddres_reg <= SdRam_RowsAddress;
                            SdRam_CollsAddress_reg <= SdRam_CollsAddress;
                             -- Wait extra time here thats why its zero (WAIT FOR PRECHARGE)
                            SdRam_NopThreshold <= 0;
                            SdRam_SdRamState <= ACTIVE_STATE;
                        else
                            SdRam_Bank(0) <= '0';
                            SdRam_BankSwitch <= '0';
                            -- SEND SELF REFRESH
                            SdRam_CKE <= '0';
                            SdRam_RAS <= '0';
                            SdRam_CAS <= '0';
                            SdRam_WE <= '1';
                            SdRam_NopThreshold <= 9;
                            SdRam_RdFinish <= '1';
                            SdRam_SdRamState <= SELF_REFRESH_EXIT;
                        end if;
                    else
                        SdRam_DataColsOutput(SdRam_DataColsIndex) <= DQ;
                        -- SEND NOP
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_DataColsIndex <= SdRam_DataColsIndex+1;
                        SdRam_SdRamState <= READ_STORE;
                    end if;
                
                when WRITE_STATE =>
                    -- SEND WRITE HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '0';
                    -- ENABLE AUTO PRECHARGE
                    SdRam_Address <= b"0010" & std_logic_vector(SdRam_ColsAddress_reg);
                    SdRam_DQM <= b"00";
                    SdRam_DQ <= SdRam_DatacolsInput(SdRam_DataColsIndex);
                    SdRam_DatacolsIndex <= SdRam_DatacolsIndex + 1;
                    -- PREPARE TO WRITE DATA IN TWO BANKS
                    SdRam_BankSwitch <= not SdRam_BankSwitch;
                    SdRam_SdRamState <= WRITE_STORE;

                when WRITE_STORE =>
                    -- SEND THE DATA
                    SdRam_DQ <= SdRam_DatacolsInput(SdRam_DataColsIndex);
                    if (SdRam_DataColsIndex = 1) then
                        SdRam_DataColsIndex <= 0;
                        -- SEND BURST TERMINATE
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '0';
                        SdRam_SdRamState <= BURST_TERMINATE_WRITE;
                    else
                        -- SEND NOP HERE
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_DatacolsIndex <= SdRam_DatacolsIndex + 1;
                        SdRam_SdRamState <= WRITE_STORE;
                    end if;

                when BURST_TERMINATE_WRITE =>
                    if SdRam_BankSwitch = '1' then
                        -- SEND ACTIVE
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_Bank(0) <= SdRam_BankSwitch;
                        SdRam_Address(12 downto 0) <= std_logic_vector(SdRam_RowsAddress_reg);
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamState <= ACTIVE_STATE;
                    elsif SdRam_WrEn = '1' then
                        -- SEND ACTIVE
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_Bank(0) <= SdRam_BankSwitch;
                        if (SdRam_ColsAddress x"1FF") then
                            SdRam_Address(12 downto 0) <= std_logic_vector(SdRam_RowsAddress_reg + 1);
                            SdRam_RowsAddress_reg <= SdRam_RowsAddress_reg + 1;
                            SdRam_ColsAddress_reg <= (others => '0');
                        else
                            SdRam_Address(12 downto 0) <= std_logic_vector(SdRam_RowsAddress_reg);
                            SdRam_ColsAddress_reg <= SdRam_ColsAddress_reg + 1;
                        end if;
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamState <= ACTIVE_STATE;
                    elsif SdRam_WrEn = '0' then
                        SdRam_RowsAddress_reg <= SdRam_RowsAddress_reg + 1;
                        SdRam_ColsAddress_reg <= SdRam_ColsAddress_reg + 1;
                        SdRam_Bank(0) <= '0';
                        SdRam_BankSwitch <= '0';
                        -- SEND SELF REFRESH
                        SdRam_CKE <= '0';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '0';
                        SdRam_WE <= '1';
                        -- DEFAULT ADDRESS VALUE
                        SdRam_Address(9 downto 0) <= b"0000000000";
                        SdRam_NopThreshold <= 9;
                        SdRam_WrFinish <= '1';
                        SdRam_SdRamState <= SELF_REFRESH_EXIT;
                    end if;

                when NOP_WITH_COUNTER =>
                    -- SEND NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_Address(10) <= '0';
                    if (SdRam_NopCounter = SdRam_NopThreshold) then
                        SdRam_NopCounter <= 0;
                        SdRam_SdRamState <= SdRam_SdRamNextState;
                    else
                        SdRam_NopCounter <= SdRam_NopCounter + 1;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    end if;

                when NOP =>
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_NopCounter <= SdRam_NopCounter + 1;
                    SdRam_SdRamState <= SdRam_SdRamNextState;
						  
					when others => null;
                end case;

        end if;
    end process;
end architecture;
