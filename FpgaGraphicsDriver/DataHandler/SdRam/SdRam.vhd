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
        SdRam_DQM : OUT STD_LOGIC_VECTOR (0 TO 1) := (OTHERS => '1');
        SdRam_DQ : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => 'Z');
        SdRam_RAS : OUT STD_LOGIC := '0';
        SdRam_WE : OUT STD_LOGIC := '0';
        SdRam_RdEn : IN STD_LOGIC;
        SdRam_WrEn : IN STD_LOGIC;
        SdRam_RdFinish : OUT STD_LOGIC := '1';
        SdRam_WrFinish : OUT STD_LOGIC := '1';
        SdRam_DataColsInput : IN DataCols_t := (OTHERS => (OTHERS => '0'));
        SdRam_DataColsOutput : OUT DataCols_t := (OTHERS => (OTHERS => '0'));
        SdRam_RowsAddress : IN unsigned (12 DOWNTO 0);
        SdRam_ColsAddress : IN unsigned (8 DOWNTO 0);
        SdRam_Init : OUT STD_LOGIC := '0'
    );

END SdRam;

ARCHITECTURE SYN OF SdRam IS
    CONSTANT SdRam_MaxCycles : unsigned(9 DOWNTO 0) := "0101110111";
    SIGNAL SdRam_SdRamNextState : SDRAM_STATE := POWERON;
    SIGNAL SdRam_NopCounter : INTEGER := 0;
    SIGNAL SdRam_NopThreshold : INTEGER := 0;
    SIGNAL SdRam_DatacolsIndex : unsigned(0 DOWNTO 0) := "0";
    SIGNAL SdRam_RowsAddress_reg : unsigned (12 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SdRam_ColsAddress_reg : unsigned (8 DOWNTO 0) := (OTHERS => '0');
    SIGNAL SdRam_AutoNumOfCycles : unsigned(9 DOWNTO 0) := "0000000000"; --This should be increased on all the cycles except on IDLE second process
    SIGNAL SdRam_AutoRefreshStartup : unsigned(0 DOWNTO 0) := "0";
    SIGNAL SdRam_SdRamState : SDRAM_STATE := POWERON;
    SIGNAL SdRam_BankSwitch : STD_LOGIC := '0';
    SIGNAL SdRam_WrEn_reg : STD_LOGIC := '0';
    SIGNAL SdRam_RdEn_reg : STD_LOGIC := '0';
BEGIN

    PROCESS (SdRam_SdRamClk, SdRam_Reset_n, SdRam_PllLocked) IS
    BEGIN
        IF (SdRam_Reset_n = '1') THEN
            SdRam_DatacolsIndex <= "0";
            SdRam_NopCounter <= 0;
            SdRam_SdRamState <= POWERON;
            SdRam_SdRamNextState <= PRECHARGE_ALL;
            SdRam_NopThreshold <= 0;
            -- Start with 4 in order to set it to 0
            SdRam_Bank <= b"00";
            SdRam_DQM <= b"11";
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
            SdRam_AutoNumOfCycles <= (OTHERS => '0');
            SdRam_AutoRefreshStartup <= "0";
            SdRam_Init <= '0';
            SdRam_RdEn_reg <= '0';
            SdRam_WrEn_reg <= '0';
        ELSIF rising_edge(SdRam_SdRamClk) AND SdRam_PllLocked = '1' THEN
            CASE SdRam_SdRamState IS
                WHEN POWERON =>
                    -- APPLY NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_NopCounter <= 0;
                    SdRam_NopThreshold <= 20000; --200 us  = 20000 cycles with 100 mhz speed
                    SdRam_NopCounter <= SdRam_NopCounter + 1;
                    SdRam_Init <= '0';
                    SdRam_SdRamNextState <= PRECHARGE_ALL;
                    SdRam_SdRamState <= DELAY;

                WHEN DELAY =>
                    IF (SdRam_NopCounter > SdRam_NopThreshold) THEN
                        -- Send precharge command
                        -- PREPARE PRECHARGE
                        SdRam_Address(12 DOWNTO 11) <= (OTHERS => '0');
                        SdRam_Address(9 DOWNTO 0) <= (OTHERS => '0');
                        SdRam_Address(10) <= '1';
                        SdRam_DQM <= b"11";
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '0';
                        SdRam_NopCounter <= 0;
                        SdRam_SdRamState <= SdRam_SdRamNextState;
                    ELSE
                        SdRam_NopCounter <= SdRam_NopCounter + 1;
                        SdRam_SdRamState <= DELAY;
                    END IF;

                WHEN PRECHARGE_ALL =>
                    -- APPLY NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_NopThreshold <= 1; -- Number of cycles is 2 is ok
                    SdRam_SdRamNextState <= AUTO_REFRESH_STARTUP;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;

                WHEN AUTO_REFRESH_STARTUP =>
                    -- Send auto refresh command
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '1';
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    IF SdRam_AutoRefreshStartup = "1" THEN
                        SdRam_AutoRefreshStartup <= "0";
                        SdRam_NopThreshold <= 6; -- Number of repetitions is 5
                        SdRam_SdRamNextState <= MODE_REGISTER_SET;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    ELSE
                        SdRam_AutoRefreshStartup <= SdRam_AutoRefreshStartup + 1;
                        SdRam_NopThreshold <= 6; -- Number of repetitions is 5
                        SdRam_SdRamNextState <= AUTO_REFRESH_STARTUP;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    END IF;

                WHEN MODE_REGISTER_SET =>
                    --SEND REGISTER MODE
                    -- CAS LATENCY = 2 AND BURST LENGTH  = 1 (2 words) PREPARE FOR MODE REGISTER SET
                    SdRam_Address <= b"0000000100001";
                    SdRam_Bank <= b"00";
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '0';
                    SdRam_NopThreshold <= 0;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_SdRamNextState <= IDLE;
                    SdRam_Init <= '1';
                    SdRam_SdRamState <= NOP_WITH_COUNTER;

                WHEN IDLE =>
                    SdRam_WrEn_reg <= SdRam_WrEn;
                    SdRam_RdEn_reg <= SdRam_RdEn;
                    IF (SdRam_AutoNumOfCycles >= SdRam_MaxCycles) THEN
                        -- Send auto refresh command
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '0';
                        SdRam_CAS <= '0';
                        SdRam_WE <= '1';
                        SdRam_NopThreshold <= 6;
                        SdRam_AutoNumOfCycles <= (OTHERS => '0');
                        SdRam_SdRamNextState <= IDLE;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    ELSIF (SdRam_WrEn = '1') OR (SdRam_RdEn = '1') THEN
                        -- SEND NOP
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        -- Take the data we want to write
                        SdRam_RowsAddress_reg <= SdRam_RowsAddress;
                        SdRam_ColsAddress_reg <= SdRam_ColsAddress;
                        SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                        SdRam_SdRamState <= ACTIVE_STATE;
                    ELSE
                        -- SEND NOP
                        SdRam_CKE <= '1';
                        SdRam_RAS <= '1';
                        SdRam_CAS <= '1';
                        SdRam_WE <= '1';
                        SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                        SdRam_SdRamState <= IDLE;
                    END IF;

                WHEN ACTIVE_STATE =>
                    -- SEND ACTIVE
                    -- STORE THE BANK AND CHANGE THE REGISTER FOR THE SWITCH ON THE NEXT WRITE/READ
                    SdRam_DQ <= (OTHERS => 'Z');
                    SdRam_DQM <= "00";
                    SdRam_Bank(0) <= SdRam_BankSwitch;
                    SdRam_Address(12 DOWNTO 0) <= STD_LOGIC_VECTOR(SdRam_RowsAddress_reg);
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    IF (SdRam_WrEn_reg = '1' OR SdRam_WrEn = '1') THEN
                        SdRam_WrEn_reg <= '1';
                        SdRam_WrFinish <= '0';
                        SdRam_SdRamNextState <= WRITE_STATE;
                    ELSIF (SdRam_RdEn_reg = '1' OR SdRam_RdEn = '1') THEN
                        SdRam_RdEn_reg <= '1';
                        SdRam_RdFinish <= '0';
                        SdRam_SdRamNextState <= READ_STATE;
                    END IF;
                    SdRam_DataColsIndex <= "0";
                    -- TRCD
                    SdRam_NopThreshold <= 0;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;

                WHEN READ_STATE =>
                    -- SEND READ COMMAND
                    -- Choose the collumns address
                    SdRam_Address(12 DOWNTO 0) <= "0000" & STD_LOGIC_VECTOR(SdRam_ColsAddress_reg);
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '1';
                    -- CAS LATENCY 2
                    SdRam_NopThreshold <= 1;
                    SdRam_SdRamNextState <= READ_STORE;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;

                WHEN READ_STORE =>
                    SdRam_DataColsOutput(to_integer(SdRam_DataColsIndex)) <= SdRam_DQ;
                    -- SEND NOP
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    IF (SdRam_DataColsIndex = "1") THEN
                        -- TRCD
                        SdRam_NopThreshold <= 1;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                        SdRam_SdRamNextState <= PRECHARGE_TO_READ_FINISH;
                    ELSE
                        SdRam_DataColsIndex <= SdRam_DataColsIndex + 1;
                        SdRam_SdRamState <= READ_STORE;
                    END IF;

                WHEN PRECHARGE_TO_READ_FINISH =>
                    -- Send precharge command
                    SdRam_DQM <= b"11";
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '0';
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_BankSwitch <= NOT SdRam_BankSwitch;
                    SdRam_SdRamState <= READ_FINISH;

                WHEN READ_FINISH =>
                    -- SEND NOP
                    SdRam_DQ <= (OTHERS => 'Z');
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_RdFinish <= '1';
                    SdRam_RdEn_reg <= '0';
                    -- TRP we send one nop since on idle we have one more
                    SdRam_NopThreshold <= 0;
                    SdRam_SdRamNextState <= IDLE;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;

                WHEN WRITE_STATE =>
                    SdRam_Address(12 DOWNTO 0) <= "0000" & STD_LOGIC_VECTOR(SdRam_ColsAddress_reg);
                    SdRam_DQ <= SdRam_DatacolsInput(to_integer(SdRam_DataColsIndex));
                    -- SEND WRITE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '0';
                    SdRam_WE <= '0';
                    SdRam_DatacolsIndex <= SdRam_DatacolsIndex + 1;
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    SdRam_SdRamState <= WRITE_STORE;

                WHEN WRITE_STORE =>
                    -- SEND THE DATA
                    SdRam_DQ <= SdRam_DatacolsInput(to_integer(SdRam_DataColsIndex));
                    -- SEND NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    IF (SdRam_DataColsIndex = "1") THEN
                        SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                        SdRam_NopThreshold <= 1;
                        -- tdpl = 2 nop
                        SdRam_SdRamNextState <= PRECHARGE_TO_WRITE_FINISH;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    ELSE
                        SdRam_DatacolsIndex <= SdRam_DatacolsIndex + 1;
                        SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                        SdRam_SdRamState <= WRITE_STORE;
                    END IF;

                WHEN PRECHARGE_TO_WRITE_FINISH =>
                    SdRam_DQM <= "11";
                    -- SEND PRECHARGE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '0';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '0';
                    -- TRP = 2 nops
                    SdRam_BankSwitch <= NOT SdRam_BankSwitch;
                    SdRam_SdRamState <= WRITE_FINISH;

                WHEN WRITE_FINISH =>
                    SdRam_DQ <= (OTHERS => 'Z');
                    -- SEND NOP
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    IF SdRam_BankSwitch = '1' THEN
                        -- TRP
                        SdRam_WrEn_reg <= '1';
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= ACTIVE_STATE;
                    ELSE
                        SdRam_WrEn_reg <= '0';
                        SdRam_WrFinish <= '1';
                        -- TRP
                        SdRam_NopThreshold <= 0;
                        SdRam_SdRamNextState <= IDLE;
                    END IF;
                    SdRam_SdRamState <= NOP_WITH_COUNTER;

                WHEN NOP_WITH_COUNTER =>
                    -- SEND NOP HERE
                    SdRam_CKE <= '1';
                    SdRam_RAS <= '1';
                    SdRam_CAS <= '1';
                    SdRam_WE <= '1';
                    SdRam_AutoNumOfCycles <= SdRam_AutoNumOfCycles + 1;
                    IF (SdRam_NopCounter >= SdRam_NopThreshold) THEN
                        SdRam_NopCounter <= 0;
                        SdRam_SdRamState <= SdRam_SdRamNextState;
                    ELSE
                        SdRam_NopCounter <= SdRam_NopCounter + 1;
                        SdRam_SdRamState <= NOP_WITH_COUNTER;
                    END IF;

                WHEN OTHERS => NULL;
            END CASE;

        END IF;
    END PROCESS;
    SDRAM_CLKOUT <= SdRam_GlobalClk;
END ARCHITECTURE;