LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.SdRamTypes.ALL;
ENTITY SdRam IS
    PORT (
        SdRam_ActlClk : IN STD_LOGIC := '0';
        SdRam_Reset_n : IN STD_LOGIC := '1';
        SdRam_ClkOut : OUT STD_LOGIC := '0';
        SdRam_SdRamClk : IN STD_LOGIC := '0';
        SdRam_GlobalClk : IN STD_LOGIC := '0';
        SdRam_PllLocked : IN STD_LOGIC := '0';
        SdRam_Address : OUT STD_LOGIC_VECTOR (12 DOWNTO 0) := (OTHERS => '0');
        SdRam_Bank : OUT STD_LOGIC_VECTOR (1 DOWNTO 0) := b"00";
        SdRam_CAS : OUT STD_LOGIC := '0';
        SdRam_CKE : OUT STD_LOGIC := '0';
        SdRam_DQM : OUT STD_LOGIC_VECTOR (0 TO 1) := (OTHERS => '0');
        SdRam_DQ : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => 'Z');
        SdRam_RAS : OUT STD_LOGIC := '0';
        SdRam_WE : OUT STD_LOGIC := '0';
        SdRam_RdEn : IN STD_LOGIC := '0';
        SdRam_WrEn : IN STD_LOGIC := '0';
        SdRam_RdFinish : OUT STD_LOGIC := '1';
        SdRam_WrFinish : OUT STD_LOGIC := '1';
        SdRam_DataColsInput : IN DataCols_t := (OTHERS => (OTHERS => '0'));
        SdRam_DataColsOutput : OUT DataCols_t := (OTHERS => (OTHERS => '0'));
        SdRam_RowsAddress : IN unsigned (12 DOWNTO 0);
        SdRam_ColsAddress : IN unsigned (8 DOWNTO 0);
        SdRam_SdRamState : INOUT SDRAM_STATE := POWERON;
        SdRam_BankSwitch : INOUT STD_LOGIC := '0'
    );

END SdRam;

ARCHITECTURE SYN OF SdRam IS
    CONSTANT SdRam_MaxCycles : unsigned(9 DOWNTO 0) := "1100001101";
    SIGNAL SdRam_SdRamNextState : SDRAM_STATE := POWERON;
    SIGNAL SdRam_NopCounter : INTEGER := 0;
    SIGNAL SdRam_NopThreshold : INTEGER := 0;
    SIGNAL SdRam_DatacolsIndex : INTEGER := 0;
    SIGNAL SdRam_RowsAddress_reg : unsigned (12 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SdRam_ColsAddress_reg : unsigned (8 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SdRam_AutoNumOfCycles :  unsigned(9 DOWNTO 0) := "0000000000"; --This should be increased on all the cycles except on IDLE second process
    SIGNAL SdRam_AutoRefreshStartup : unsigned(0 DOWNTO 0) := "0";
BEGIN

    SDRAM_CLKOUT <= SdRam_GlobalClk;
    PROCESS (SdRam_SdRamClk, SdRam_Reset_n, SdRam_PllLocked, SdRam_ColsAddress, SdRam_RowsAddress) IS
    BEGIN
        IF (SdRam_Reset_n = '1') THEN
            SdRam_DatacolsIndex <= 0;
            SdRam_NopCounter <= 0;
            SdRam_SdRamState <= POWERON;
            SdRam_NopThreshold <= 0;
            -- Start with 4 in order to set it to 0
            SdRam_Bank <= b"00";
            SdRam_DQM <= b"00";
            SdRam_DQ <= (OTHERS => 'Z');
            SdRam_RdFinish <= '1';
            SdRam_WrFinish <= '1';
            -- NOTHING HERE
            SdRam_CKE <= '0';
            SdRam_RAS <= '0';
            SdRam_CAS <= '0';
            SdRam_WE <= '0';
            SdRam_Address <= b"0000000000000";
            SdRam_DataColsOutput <= (OTHERS => (OTHERS => '0'));
            SdRam_ColsAddress_reg <= (OTHERS => '0');
            SdRam_RowsAddress_reg <= (OTHERS => '0');
            SdRam_BankSwitch <= '0';
            SdRam_AutoNumOfCycles <= (others => '0');
        ELSIF rising_edge(SdRam_SdRamClk) AND SdRam_PllLocked = '1' THEN
            CASE SdRam_SdRamState IS
                WHEN POWERON =>
                    -- APPLY NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_SdRamNextState <= PRECHARGE_ALL;
                    SdRam_SdRamState <= DELAY;
                    SdRam_NopThreshold <= 20000; --200 us  = 20000 cycles with 100 mhz speed
                    SdRam_NopCounter <= SdRam_NopCounter + 1;

                WHEN DELAY =>
                    IF (SdRam_NopCounter = SdRam_NopThreshold) THEN
                        SdRam_NopCounter <= 0;
                        SdRam_SdRamState <= SdRam_SdRamNextState;
                    ELSE
                        SdRam_NopCounter <= SdRam_NopCounter + 1;
                    END IF;

                WHEN PRECHARGE_ALL =>
                    -- Send precharge command
                    SdRam_DQM <= b"11";
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '0';
                    SdRam_Address(10) <= '1';
                    SdRam_NopThreshold <= 1; -- Number of repetitions is 2
                    SdRam_SdRamState <= NOP_WITH_COUNTER;
                    SdRam_SdRamNextState <= AUTO_REFRESH_STARTUP;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;

                WHEN AUTO_REFRESH_STARTUP =>
                    SdRam_Address(10) <= '0';
                    -- Send auto refresh command
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '1';
                    -- Move to noP
                    SdRam_NopThreshold <= 5; -- Number of repetitions is 2
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    IF SdRam_AutoRefreshStartup = "1" THEN
                        SdRam_NopThreshold <= 5; -- Number of repetitions is 2
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                        SdRam_SdRamNextState <= MODE_REGISTER_SET;
                    ELSE
                        SdRam_AutoRefreshStartup <= SdRam_AutoRefreshStartup + 1;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                        SdRam_SdRamNextState <= AUTO_REFRESH_STARTUP;
                    END IF;

                WHEN MODE_REGISTER_SET =>
                    --SEND REGISTER MODE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '0';
                    -- CAS LATENCY = 2 AND BURST LENGTH  = 1 (2 words)
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_Address <= b"0000000100001";
                    SdRam_NopThreshold <= 0;
                    SdRam_NopCounter <= 0;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;
                    SdRam_SdRamNextState <= IDLE;

                WHEN IDLE =>
                    IF (SdRam_RdEn = '0' AND SdRam_WrEn = '0') OR (SdRam_AutoNumOfCycles >= SdRam_MaxCycles) THEN
                        SdRam_Address(10) <= '0';
                        -- Send auto refresh command
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '0';
                        SdRam_WE <= '1';
                        SdRam_NopCounter <= 0;
                        SdRam_NopThreshold <= 6;
                        SdRam_AutoNumOfCycles <= (others => '0');
                        SdRam_SdRamNextState <= IDLE;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    ELSE
                        -- SEND ACTIVE 
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_Address(12 DOWNTO 0) <= STD_LOGIC_VECTOR(SdRam_RowsAddress);
                        SdRam_DQM <= b"11";
                        SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                        SdRam_SdRamState <= ACTIVE_STATE;
                    END IF;

                WHEN ACTIVE_STATE =>
                    -- Inputs here are the Row and the Bank which is 0 at startup
                    SdRam_Address <= b"0000000000000";
                    -- SEND NOP
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_NopCounter <= 0;
                    -- DQ is high 'z' cause we don't know if it is read or write
                    SdRam_DQ <= (OTHERS => 'Z');
                    -- DQM is '11' cause we don't want to get feedback now
                    SdRam_DQM <= b"11";
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    IF (SdRam_RdEn = '1') THEN
                        -- This will be used to update the next rows once this happens
                        SdRam_RdFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= READ_STATE;
                        SdRam_RowsAddress_reg <= SdRam_RowsAddress;
                        SdRam_ColsAddress_reg <= SdRam_ColsAddress;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    ELSIF SdRam_WrEn = '1' OR SdRam_BankSwitch = '1' THEN
                        -- This will be used to update the next rows once this happens
                        SdRam_WrFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= WRITE_STATE;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    ELSE
                        -- This will be used to update the next rows once this happens
                        SdRam_WrFinish <= '0';
                        -- Go to nop for one cycle since we run at 100 mhz
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= WRITE_STATE;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    END IF;

                WHEN READ_STATE =>
                    -- SEND READ COMMAND
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '1';
                    SdRam_DQM <= b"00";
                    -- Choose the collumns address
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_DQ <= (OTHERS => 'Z');
                    SdRam_Address(12 DOWNTO 9) <= b"0010";
                    SdRam_Address(8 DOWNTO 0) <= STD_LOGIC_VECTOR(SdRam_ColsAddress_reg);
                    SdRam_NopThreshold <= 1;
                    SdRam_SdRamNextState <= READ_STORE;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;

                WHEN READ_STORE =>
                    SdRam_DataColsOutput(SdRam_DataColsIndex) <= SdRam_DQ;
                    IF (SdRam_DataColsIndex = 1) THEN
                        SdRam_DataColsIndex <= 0;
                        IF SdRam_RdEn = '1' AND (SdRam_AutoNumOfCycles < SdRam_MaxCycles) THEN
                            -- SEND ACTIVE
                            SdRam_CKE <= '1';
                            SdRam_RAS <= '0';
                            SdRam_CAS <= '1';
                            SdRam_WE <= '1';
                            SdRam_Bank(0) <= SdRam_BankSwitch;
                            SdRam_BankSwitch <= NOT SdRam_BankSwitch;
                            SdRam_Address(12 DOWNTO 0) <= STD_LOGIC_VECTOR(SdRam_RowsAddress_reg);
                            -- Wait extra time here thats why its zero (WAIT FOR PRECHARGE)
                            SdRam_NopThreshold <= 0;
                            SdRam_SdRamState <= ACTIVE_STATE;
                        ELSE
                            SdRam_Bank(0) <= '0';
                            SdRam_BankSwitch <= '0';
                            SdRam_Address(10) <= '0';
                            -- SEND NOP
                            SdRam_CKE <= '1';
                            SdRam_RAS <= '1';
                            SdRam_CAS <= '1';
                            SdRam_WE <= '1';
                            SdRam_NopCounter <= 0;
                            SdRam_NopThreshold <= 1;
                            SdRam_RdFinish <= '1';
                            SdRam_SdRamNextState <= IDLE;
                            SdRam_SdRamState <= NOP_WITH_COUNTER;
                        END IF;
                    ELSE
                        -- SEND NOP
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_DataColsIndex <= SdRam_DataColsIndex + 1;
                        SdRam_SdRamState <= READ_STORE;
                    END IF;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;

                WHEN WRITE_STATE =>
                    -- SEND WRITE HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '0';
                    -- ENABLE AUTO PRECHARGE
                    SdRam_Address <= b"0010" & STD_LOGIC_VECTOR(SdRam_ColsAddress_reg);
                    SdRam_DQM <= b"00";
                    SdRam_DQ <= SdRam_DatacolsInput(SdRam_DataColsIndex);
                    SdRam_DatacolsIndex <= SdRam_DatacolsIndex + 1;
                    -- PREPARE TO WRITE DATA IN TWO BANKS
                    SdRam_BankSwitch <= NOT SdRam_BankSwitch;
                    SdRam_SdRamState <= WRITE_STORE;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;

                WHEN WRITE_STORE =>
                    -- SEND THE DATA
                    SdRam_DQ <= SdRam_DatacolsInput(SdRam_DataColsIndex);
                    -- SEND NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    IF (SdRam_DataColsIndex = 1) THEN
                        SdRam_DataColsIndex <= 0;
                        SdRam_SdRamState <= WRITE_FINISH;
                    ELSE
                        SdRam_DatacolsIndex <= SdRam_DatacolsIndex + 1;
                        SdRam_SdRamState <= WRITE_STORE;
                    END IF;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;

                WHEN WRITE_FINISH =>
                    IF SdRam_BankSwitch = '1' THEN
                        -- SEND ACTIVE
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_Bank(0) <= SdRam_BankSwitch;
                        SdRam_Address(12 DOWNTO 0) <= STD_LOGIC_VECTOR(SdRam_RowsAddress_reg);
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamState <= ACTIVE_STATE;
                    ELSIF SdRam_WrEn = '1' AND (SdRam_AutoNumOfCycles < SdRam_MaxCycles) THEN
                        -- SEND ACTIVE
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_Bank(0) <= SdRam_BankSwitch;
                        -- Since we store 2 data the index should be 510 instead of 511
                        IF (SdRam_ColsAddress_reg = x"1FE") THEN
                            SdRam_Address(12 DOWNTO 0) <= STD_LOGIC_VECTOR(SdRam_RowsAddress_reg + 1);
                            SdRam_RowsAddress_reg <= SdRam_RowsAddress_reg + 1;
                            SdRam_ColsAddress_reg <= (OTHERS => '0');
                        ELSE
                            SdRam_Address(12 DOWNTO 0) <= STD_LOGIC_VECTOR(SdRam_RowsAddress_reg);
                            -- we store 2 data not one
                            SdRam_ColsAddress_reg <= SdRam_ColsAddress_reg + 2;
                        END IF;
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamState <= ACTIVE_STATE;
                    ELSIF (SdRam_WrEn = '0') OR (SdRam_AutoNumOfCycles >= SdRam_MaxCycles) THEN
                        -- we store 2 data not one
                        SdRam_ColsAddress_reg <= SdRam_ColsAddress_reg + 2;
                        SdRam_Bank(0) <= '0';
                        SdRam_BankSwitch <= '0';
                        SdRam_Address(10) <= '0';
                        -- SEND NOP
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_NopCounter <= 0;
                        SdRam_NopThreshold <= 1;
                        SdRam_WrFinish <= '1';
                        SdRam_SdRamNextState <= IDLE;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    END IF;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;

                WHEN NOP_WITH_COUNTER =>
                    -- SEND NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_Address(10) <= '0';
                    IF (SdRam_NopCounter = SdRam_NopThreshold) THEN
                        SdRam_NopCounter <= 0;
                        SdRam_SdRamState <= SdRam_SdRamNextState;
                    ELSE
                        SdRam_NopCounter <= SdRam_NopCounter + 1;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    END IF;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;

                WHEN NOP =>
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_NopCounter <= SdRam_NopCounter + 1;
                    SdRam_SdRamState <= SdRam_SdRamNextState;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;

                WHEN OTHERS => NULL;
            END CASE;

        END IF;
    END PROCESS;
END ARCHITECTURE;