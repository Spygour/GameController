LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.DataHandlerTypes.ALL;
USE work.SdRamTypes.ALL;
USE work.SpiSlaveTypes.ALL;

ENTITY DataHandler IS
    PORT (
        DataHandler_Reset_n : IN STD_LOGIC := '1';
        -- Clocks
        DataHandler_ActlClk : IN STD_LOGIC := '0';
        DataHandler_SdRamClk : IN STD_LOGIC := '0';
        DataHandler_GlobalClk : IN STD_LOGIC := '0';
        DataHandler_PllLocked : IN STD_LOGIC := '0';
        -- SDRAM PINS
        DataHandler_SdRamClkOut : OUT STD_LOGIC;
        DataHandler_Address : OUT STD_LOGIC_VECTOR (12 DOWNTO 0) := (OTHERS => '0');
        DataHandler_Bank : OUT STD_LOGIC_VECTOR (1 DOWNTO 0) := (OTHERS => '0');
        DataHandler_CAS : OUT STD_LOGIC := '0';
        DataHandler_CKE : OUT STD_LOGIC := '0';
        DataHandler_SdRamCS : OUT STD_LOGIC := '1';
        DataHandler_DQM : OUT STD_LOGIC_VECTOR (0 TO 1) := (OTHERS => '0');
        DataHandler_DQ : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
        DataHandler_RAS : OUT STD_LOGIC := '0';
        DataHandler_WE : OUT STD_LOGIC := '0';
        DataHandler_DebugLeds : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        -- SPI PINS
        DataHandler_SpiClk : IN STD_LOGIC;
        DataHandler_So : OUT STD_LOGIC := '0';
        DataHandler_Si : IN STD_LOGIC_VECTOR(0 TO 2);
        DataHandler_Cs : IN STD_LOGIC;
        DataHandler_SpiReady : OUT STD_LOGIC := '0';
        DataHandler_Xaxis : OUT DataPart_t := (OTHERS => (OTHERS => '0'));
        DataHandler_Yaxis : OUT DataPart_t := (OTHERS => (OTHERS => '0'));
        DataHandler_Resolution : INOUT DataPart_t := (OTHERS => (OTHERS => '0'));
        DataHandler_Color : INOUT DataColor_t := (OTHERS => (OTHERS => '0'));
        -- DATA HANDLER CONTROL PINS
        DataHandler_Finish : OUT STD_LOGIC := '1';
        DataHandler_Start : IN STD_LOGIC;
        DataHandler_SpiWordsReg : INOUT INTEGER := 0
    );

END DataHandler;

ARCHITECTURE rtl OF DataHandler IS

    TYPE DATAHANDLER_STATE IS
    (
    START_WRITE,
    WAIT_START,
    WAIT_WRITE,
    WRITE_SDRAM,
    START_READ,
    WAIT_READ,
    CHECK_DATA_AVAILABLE,
    READ_DATA,
    STORE_DATA,
    READ_DATA_RESTART,
    READ_DATA_IDLE
    );

    TYPE DATAHANDLER_STORE_STATE IS
    (
    DATA_1,
    DATA_2,
    DATA_3,
    END_STORE_DATA,
    WAIT_INDEX_0
    );
    SIGNAL DataHandler_SdRamHandlerState : DATAHANDLER_STATE := START_WRITE;
    SIGNAL DataHandler_SdRamStoreState : DATAHANDLER_STORE_STATE := DATA_1;
    SIGNAL DataHandler_SdRamStoreNextState : DATAHANDLER_STORE_STATE := DATA_1;
    SIGNAL DataHandler_Wren : STD_LOGIC := '0';
    SIGNAL DataHandler_RdEn : STD_LOGIC := '0';
    SIGNAL DataHandler_RdFinish : STD_LOGIC := '1';
    SIGNAL DataHandler_WrFinish : STD_LOGIC := '1';
    SIGNAL DataHandler_DataColsOutput : DataCols_t := (OTHERS => (OTHERS => '0'));
    SIGNAL DataHandler_DataColsInput : DataCols_t := (OTHERS => (OTHERS => '0'));
    SIGNAL DataHandler_RowsAddress : unsigned (12 DOWNTO 0) := (OTHERS => '0');
    SIGNAL DataHandler_ColsAddress : unsigned (8 DOWNTO 0) := (OTHERS => '0');
    SIGNAL DataHandler_Reset_Sync : STD_LOGIC := '1';
    SIGNAL DataHandler_SdRamEnd : STD_LOGIC := '0';
    SIGNAL DataHandler_SdRamState : SDRAM_STATE;
    SIGNAL DataHandler_BankSwitch : STD_LOGIC;
    SIGNAL DataHandler_WriteDataBuffer : DataCols_ary := (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"),
    ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
    ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
    ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
    ("0101010110111111", "1111111100000000"));
    SIGNAL DataHandler_WriteDataBuffer_reg : DataCols_ary := (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"),
    ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
    ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
    ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
    ("0101010110111111", "1111111100000000"));
    SIGNAL DataHandler_WriteDataBufferIdx : INTEGER := 0;

    -- QSPI SIGNALS
    SIGNAL DataHandler_StartSpi : STD_LOGIC := '0';
    SIGNAL DataHandler_SpiWrEn : STD_LOGIC := '0';
    SIGNAL DataHandler_WriteDataWord : Spi_QSpiCorrected := (OTHERS => (OTHERS => '0'));
    SIGNAL DataHandler_ReadDataWord : Spi_QSpiCorrected := (OTHERS => (OTHERS => '0'));
    SIGNAL DataHandler_WriteAddress : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL DataHandler_ReadAddress : Spi_Address_t := (OTHERS => (OTHERS => '0'));
    SIGNAL DataHandler_SpiPllLocked : STD_LOGIC := '0';
    SIGNAL DataHandler_Words : INTEGER := 0;
    SIGNAL DataHandler_EndSpi : STD_LOGIC := '1';
    SIGNAL DataHandler_MisoIndex : unsigned (1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL DataHandler_MisoIndexReg : unsigned (1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL DataHandler_SdRamReadAddress : Address_t := (OTHERS => (OTHERS => '0'));

BEGIN
    SdRam : ENTITY work.SdRam(SYN)
        PORT MAP
        (
            SdRam_ActlClk => DataHandler_ActlClk,
            SdRam_Reset_n => DataHandler_Reset_Sync,
            SdRam_ClkOut => DataHandler_SdRamClkOut,
            SdRam_SdRamClk => DataHandler_SdRamClk,
            SdRam_GlobalClk => DataHandler_GlobalClk,
            SdRam_PllLocked => DataHandler_PllLocked,
            SdRam_Address => DataHandler_Address,
            SdRam_Bank => DataHandler_Bank,
            SdRam_CAS => DataHandler_CAS,
            SdRam_CKE => DataHandler_CKE,
            SdRam_DQM => DataHandler_DQM,
            SdRam_DQ => DataHandler_DQ,
            SdRam_RAS => DataHandler_RAS,
            SdRam_WE => DataHandler_WE,
            SdRam_RdEn => DataHandler_RdEn,
            SdRam_WrEn => DataHandler_WrEn,
            SdRam_RdFinish => DataHandler_RdFinish,
            SdRam_WrFinish => DataHandler_WrFinish,
            SdRam_DataColsInput => DataHandler_DataColsOutput,
            SdRam_DataColsOutput => DataHandler_DataColsInput,
            SdRam_RowsAddress => DataHandler_RowsAddress,
            SdRam_ColsAddress => DataHandler_ColsAddress,
            SdRam_SdRamState => DataHandler_SdRamState,
            SdRam_BankSwitch => DataHandler_BankSwitch
        );

    SpiSlave : ENTITY work.SpiSlave(rtl)
        PORT MAP
        (
            Spi_ActlClk => DataHandler_ActlClk,
            Spi_Clk => DataHandler_SdRamClk,
            Spi_SpiClk => DataHandler_SpiClk,
            Spi_Reset_n => DataHandler_Reset_Sync,
            Spi_So => DataHandler_So,
            Spi_Si => DataHandler_Si,
            Spi_Cs => DataHandler_Cs,
            Spi_StartSpi => DataHandler_StartSpi,
            Spi_EndSpi => DataHandler_EndSpi,
            Spi_Words => DataHandler_Words,
            Spi_WrEn => DataHandler_SpiWrEn,
            Spi_WriteDataWord => DataHandler_WriteDataWord,
            Spi_ReadDataWord => DataHandler_ReadDataWord,
            Spi_WriteAddress => DataHandler_WriteAddress,
            Spi_ReadAddress => DataHandler_ReadAddress,
            Spi_lockedloop => DataHandler_PllLocked
        );

    SpiRam_1 : ENTITY work.SpiRam_1(SYN)
        PORT MAP
        (
            clock => DataHandler_SdRamClk,
            data => DataHandler_WriteDataWord(0),
            rdaddress => DataHandler_ReadAddress(0),
            wraddress => DataHandler_WriteAddress,
            wren => DataHandler_SpiWrEn,
            q => DataHandler_ReadDataWord(0)
        );

    SpiRam_2 : ENTITY work.SpiRam_2(SYN)
        PORT MAP
        (
            clock => DataHandler_SdRamClk,
            data => DataHandler_WriteDataWord(1),
            rdaddress => DataHandler_ReadAddress(1),
            wraddress => DataHandler_WriteAddress,
            wren => DataHandler_SpiWrEn,
            q => DataHandler_ReadDataWord(1)
        );

    SpiRam_3 : ENTITY work.SpiRam_3(SYN)
        PORT MAP
        (
            clock => DataHandler_SdRamClk,
            data => DataHandler_WriteDataWord(2),
            rdaddress => DataHandler_ReadAddress(2),
            wraddress => DataHandler_WriteAddress,
            wren => DataHandler_SpiWrEn,
            q => DataHandler_ReadDataWord(2)
        );

    PROCESS (DataHandler_SdRamClk, DataHandler_Reset_Sync, DataHandler_PllLocked) IS
    BEGIN
        IF (DataHandler_Reset_Sync = '1') THEN
            DataHandler_Finish <= '1';
            DataHandler_SdRamHandlerState <= START_WRITE;
            DataHandler_RdEn <= '0';
            DataHandler_WrEn <= '0';
            DataHandler_DataColsOutput <= (OTHERS => (OTHERS => '0'));
            DataHandler_SdRamEnd <= '0';
            DataHandler_RowsAddress <= to_unsigned(0, 13);
            DataHandler_ColsAddress <= to_unsigned(0, 9);
            DataHandler_DebugLeds <= b"00000000";
            DataHandler_WriteDataBufferIdx <= 0;
            DataHandler_MisoIndex <= "00";
            DataHandler_MisoIndexReg <= "00";
            -- SPI PART
            DataHandler_SpiReady <= '0';
            DataHandler_StartSpi <= '0';
            DataHandler_ReadAddress <= (OTHERS => (OTHERS => '0'));
            DataHandler_SpiWordsReg <= 0;
            -- SDRAM STORE ARRAY
            DataHandler_WriteDataBuffer <= (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"),
                ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
                ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
                ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
                ("0101010110111111", "1111111100000000"));
        ELSIF rising_edge(DataHandler_SdRamClk) AND DataHandler_PllLocked = '1' THEN
            CASE DataHandler_SdRamHandlerState IS
                WHEN START_WRITE =>
                    DataHandler_DebugLeds <= "01010101";
                    DataHandler_WrEn <= '1';
                    DataHandler_DataColsOutput <= DataHandler_WriteDataBuffer(DataHandler_WriteDataBufferIdx);
                    DataHandler_WriteDataBufferIdx <= DataHandler_WriteDataBufferIdx + 1;
                    DataHandler_SdRamHandlerState <= WAIT_START;

                WHEN WAIT_START =>
                    IF DataHandler_WrFinish = '0' OR DataHandler_BankSwitch = '1' THEN
                        DataHandler_SdRamHandlerState <= WAIT_WRITE;
                    ELSE
                        DataHandler_SdRamHandlerState <= WAIT_START;
                    END IF;

                WHEN WAIT_WRITE =>
                    IF (DataHandler_BankSwitch = '0' AND DataHandler_SdRamState = WRITE_FINISH) THEN
                        IF DataHandler_SdRamStoreState = END_STORE_DATA AND DataHandler_WriteDataBufferIdx = 64 THEN --write has been finished
                            -- DEACTIVATE THE WRITE COMMAND
                            DataHandler_WrEn <= '0';
                            DataHandler_SdRamHandlerState <= START_READ;
                            -- START THE SPI and prepare the spi ready
                            DataHandler_StartSpi <= '1';
                            DataHandler_SpiReady <= '1';
                        ELSIF (DataHandler_WriteDataBufferIdx = 64) THEN
                            DataHandler_WriteDataBuffer <= DataHandler_WriteDataBuffer_reg;
                            DataHandler_DataColsOutput <= DataHandler_WriteDataBuffer_reg(0);
                            DataHandler_WriteDataBufferIdx <= 1;
                            DataHandler_SdRamHandlerState <= WAIT_START;
                        ELSE
                            DataHandler_DataColsOutput <= DataHandler_WriteDataBuffer(DataHandler_WriteDataBufferIdx);
                            DataHandler_WriteDataBufferIdx <= DataHandler_WriteDataBufferIdx + 1;
                            DataHandler_SdRamHandlerState <= WAIT_START;
                        END IF;
                    ELSE
                        DataHandler_SdRamHandlerState <= WAIT_WRITE;
                    END IF;

                WHEN START_READ =>
                    IF (DataHandler_EndSpi = '0') THEN
                        DataHandler_DebugLeds <= "11110000";
                        DataHandler_Finish <= '0';
                        -- AVOID EXTRA WRONG DATA SEND
                        DataHandler_SpiReady <= '0';
                        DataHandler_StartSpi <= '0';
                        DataHandler_MisoIndex <= "00";
                        DataHandler_SdRamHandlerState <= CHECK_DATA_AVAILABLE;
                        DataHandler_RowsAddress <= (OTHERS => '0');
                    END IF;

                WHEN CHECK_DATA_AVAILABLE =>
                    IF (DataHandler_SpiWordsReg + 1) < DataHandler_Words THEN
                        DataHandler_ColsAddress <= unsigned(DataHandler_ReadDataWord(0)(15 DOWNTO 8)) & '0';
                        DataHandler_SdRamReadAddress(0) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadDataWord(0)(15 DOWNTO 8)) & '0');
                        DataHandler_SdRamReadAddress(1) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadDataWord(1)(15 DOWNTO 8)) & '0');
                        DataHandler_SdRamReadAddress(2) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadDataWord(2)(15 DOWNTO 8)) & '0');

                        DataHandler_Resolution(0) <= DataHandler_ReadDataWord(0)(7 DOWNTO 0);
                        DataHandler_Resolution(1) <= DataHandler_ReadDataWord(1)(7 DOWNTO 0);
                        DataHandler_Resolution(2) <= DataHandler_ReadDataWord(2)(7 DOWNTO 0);
                        DataHandler_RdEn <= '1';
                        DataHandler_SdRamHandlerState <= WAIT_READ;
                        DataHandler_DebugLeds <= "11111111";
                    END IF;

                WHEN WAIT_READ =>
                    IF DataHandler_SdRamState = READ_STATE THEN
                        IF (DataHandler_MisoIndex = "10") THEN
                            DataHandler_MisoIndexReg <= DataHandler_MisoIndex;
                            DataHandler_MisoIndex <= "00";
                            DataHandler_ReadAddress(2) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadAddress(2)) + 1);
                            DataHandler_SdRamHandlerState <= STORE_DATA;
                            DataHandler_DebugLeds <= "11000100";
                        ELSE
                            DataHandler_ColsAddress <= unsigned(DataHandler_SdRamReadAddress(to_integer(DataHandler_MisoIndex + 1)));
                            DataHandler_ReadAddress(to_integer(DataHandler_MisoIndex)) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadAddress(to_integer(DataHandler_MisoIndex))) + 1);
                            DataHandler_MisoIndexReg <= DataHandler_MisoIndex;
                            DataHandler_MisoIndex <= DataHandler_MisoIndex + 1;
                            DataHandler_SdRamHandlerState <= READ_DATA;
                            DataHandler_DebugLeds <= "11001000";
                        END IF;
                    END IF;

                WHEN READ_DATA =>
                    IF DataHandler_SdRamState = ACTIVE_STATE THEN
                        -- Store the color
                        DataHandler_Color(to_integer(DataHandler_MisoIndexReg))(23 DOWNTO 8) <= DataHandler_DataColsInput(0);
                        DataHandler_Color(to_integer(DataHandler_MisoIndexReg))(7 DOWNTO 0) <= DataHandler_DataColsInput(1)(15 DOWNTO 8);
                        DataHandler_Finish <= '0';
                        DataHandler_SdRamHandlerState <= WAIT_READ;
                        DataHandler_DebugLeds <= "11001100";
                    END IF;

                WHEN STORE_DATA =>
                    -- If we increase and overflows data is maximum
                    IF DataHandler_SdRamState = READ_STORE AND (DataHandler_SpiWordsReg = 255 OR DataHandler_SpiWordsReg = DataHandler_Words) THEN
                        DataHandler_DebugLeds <= "11110100";
                    ELSIF DataHandler_SdRamState = READ_STORE AND (DataHandler_SpiWordsReg + 1) < DataHandler_Words THEN -- NEW DATA HAS BEEN ARRIVED
                        DataHandler_Xaxis(0) <= DataHandler_ReadDataWord(0)(15 DOWNTO 8);
                        DataHandler_Xaxis(1) <= DataHandler_ReadDataWord(1)(15 DOWNTO 8);
                        DataHandler_Xaxis(2) <= DataHandler_ReadDataWord(2)(15 DOWNTO 8);

                        DataHandler_Yaxis(0) <= DataHandler_ReadDataWord(0)(7 DOWNTO 0);
                        DataHandler_Yaxis(1) <= DataHandler_ReadDataWord(1)(7 DOWNTO 0);
                        DataHandler_Yaxis(2) <= DataHandler_ReadDataWord(2)(7 DOWNTO 0);

                        DataHandler_ReadAddress(0) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadAddress(0)) + 1);
                        DataHandler_ReadAddress(1) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadAddress(1)) + 1);
                        DataHandler_ReadAddress(2) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadAddress(2)) + 1);
                        DataHandler_DebugLeds <= DataHandler_Resolution(to_integer(DataHandler_MisoIndexReg));
                    END IF;
                    DataHandler_SpiWordsReg <= DataHandler_SpiWordsReg + 2;
                    DataHandler_RdEn <= '0';
                    -- Go back to read data in order to store the data for vga
                    DataHandler_SdRamHandlerState <= READ_DATA_RESTART;

                WHEN READ_DATA_RESTART =>
                    IF DataHandler_SdRamState = ACTIVE_STATE THEN
                        -- Store the color
                        DataHandler_Color(to_integer(DataHandler_MisoIndexReg))(23 DOWNTO 8) <= DataHandler_DataColsInput(0);
                        DataHandler_Color(to_integer(DataHandler_MisoIndexReg))(7 DOWNTO 0) <= DataHandler_DataColsInput(1)(15 DOWNTO 8);
                        DataHandler_Finish <= '1';
                        DataHandler_SdRamHandlerState <= READ_DATA_IDLE;
                        DataHandler_DebugLeds <= DataHandler_Resolution(to_integer(0));
                    END IF;

                WHEN READ_DATA_IDLE =>
                    IF (DataHandler_Start = '1' AND (DataHandler_SpiWordsReg + 1) < DataHandler_Words) THEN
                        DataHandler_ColsAddress(8 DOWNTO 0) <= unsigned(DataHandler_ReadDataWord(0)(15 DOWNTO 8)) & '0';
                        DataHandler_SdRamReadAddress(0) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadDataWord(0)(15 DOWNTO 8)) & '0');
                        DataHandler_SdRamReadAddress(1) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadDataWord(1)(15 DOWNTO 8)) & '0');
                        DataHandler_SdRamReadAddress(2) <= STD_LOGIC_VECTOR(unsigned(DataHandler_ReadDataWord(2)(15 DOWNTO 8)) & '0');

                        DataHandler_Resolution(0) <= DataHandler_ReadDataWord(0)(7 DOWNTO 0);
                        DataHandler_Resolution(1) <= DataHandler_ReadDataWord(1)(7 DOWNTO 0);
                        DataHandler_Resolution(2) <= DataHandler_ReadDataWord(2)(7 DOWNTO 0);

                        DataHandler_Finish <= '0';
                        DataHandler_RdEn <= '1';
                        DataHandler_SdRamHandlerState <= WAIT_READ;
                        DataHandler_DebugLeds <= "11110011";
                    ELSIF ((DataHandler_Start = '1') AND (DataHandler_SpiWordsReg = DataHandler_Words) AND (DataHandler_EndSpi = '1')) THEN
                        -- START THE SPI and prepare the spi ready
                        DataHandler_SpiWordsReg <= 0;
                        DataHandler_StartSpi <= '1';
                        DataHandler_SpiReady <= '1';
                        DataHandler_DebugLeds <= "00000011";
                        DataHandler_SdRamHandlerState <= START_READ;
                    END IF;

                WHEN OTHERS => NULL;

            END CASE;
        END IF;
    END PROCESS;

    PROCESS (DataHandler_Reset_Sync, DataHandler_SdRamClk, DataHandler_PllLocked) IS
    BEGIN
        IF (DataHandler_Reset_Sync = '1') THEN
            DataHandler_WriteDataBuffer_reg <= (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"),
                ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
                ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
                ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
                ("0101010110111111", "1111111100000000"));
            DataHandler_SdRamStoreState <= DATA_1;
            DataHandler_SdRamStoreNextState <= DATA_1;
        ELSIF rising_edge(DataHandler_SdRamClk) AND DataHandler_PllLocked = '1' THEN
            CASE DataHandler_SdRamStoreState IS
                WHEN DATA_1 =>
                    IF DataHandler_WriteDataBufferIdx = 64 THEN
                        -- store here
                        DataHandler_WriteDataBuffer_reg <= (("0101010111011111", "0000000000000000"), ("0101010111011111", "0101010100000000"), ("0101010111011111", "1010101000000000"), ("0101010111011111", "1111111100000000"), ("0101010111111111", "0000000000000000"), ("0101010111111111", "0101010100000000"),
                            ("0101010111111111", "1010101000000000"), ("0101010111111111", "1111111100000000"), ("0111111100000000", "0000000000000000"), ("0111111100000000", "0101010100000000"), ("0111111100000000", "1010101000000000"), ("0111111100000000", "1111111100000000"), ("0111111100011111", "0000000000000000"), ("0111111100011111", "0101010100000000"), ("0111111100011111", "1010101000000000"), ("0111111100011111", "1111111100000000"), ("0111111100111111", "0000000000000000"), ("0111111100111111", "0101010100000000"), ("0111111100111111", "1010101000000000"), ("0111111100111111", "1111111100000000"), ("0111111101011111", "0000000000000000"),
                            ("0111111101011111", "0101010100000000"), ("0111111101011111", "1010101000000000"), ("0111111101011111", "1111111100000000"), ("0111111101111111", "0000000000000000"), ("0111111101111111", "0101010100000000"), ("0111111101111111", "1010101000000000"), ("0111111101111111", "1111111100000000"), ("0111111110011111", "0000000000000000"), ("0111111110011111", "0101010100000000"), ("0111111110011111", "1010101000000000"), ("0111111110011111", "1111111100000000"), ("0111111110111111", "0000000000000000"), ("0111111110111111", "0101010100000000"), ("0111111110111111", "1010101000000000"), ("0111111110111111", "1111111100000000"), ("0111111111011111", "0000000000000000"), ("0111111111011111", "0101010100000000"), ("0111111111011111", "1010101000000000"), ("0111111111011111", "1111111100000000"), ("0111111111111111", "0000000000000000"), ("0111111111111111", "0101010100000000"),
                            ("0111111111111111", "1010101000000000"), ("0111111111111111", "1111111100000000"), ("1010101000000000", "0000000000000000"), ("1010101000000000", "0101010100000000"), ("1010101000000000", "1010101000000000"), ("1010101000000000", "1111111100000000"), ("1010101000011111", "0000000000000000"), ("1010101000011111", "0101010100000000"), ("1010101000011111", "1010101000000000"), ("1010101000011111", "1111111100000000"), ("1010101000111111", "0000000000000000"), ("1010101000111111", "0101010100000000"), ("1010101000111111", "1010101000000000"), ("1010101000111111", "1111111100000000"), ("1010101001011111", "0000000000000000"), ("1010101001011111", "0101010100000000"), ("1010101001011111", "1010101000000000"), ("1010101001011111", "1111111100000000"), ("1010101001111111", "0000000000000000"), ("1010101001111111", "0101010100000000"), ("1010101001111111", "1010101000000000"),
                            ("1010101001111111", "1111111100000000"));
                        DataHandler_SdRamStoreNextState <= DATA_2;
                        DataHandler_SdRamStoreState <= WAIT_INDEX_0;
                    END IF;

                WHEN DATA_2 =>
                    IF DataHandler_WriteDataBufferIdx = 64 THEN
                        -- store here
                        DataHandler_WriteDataBuffer_reg <= (("1010101010011111", "0000000000000000"), ("1010101010011111", "0101010100000000"), ("1010101010011111", "1010101000000000"), ("1010101010011111", "1111111100000000"), ("1010101010111111", "0000000000000000"), ("1010101010111111", "0101010100000000"),
                            ("1010101010111111", "1010101000000000"), ("1010101010111111", "1111111100000000"), ("1010101011011111", "0000000000000000"), ("1010101011011111", "0101010100000000"), ("1010101011011111", "1010101000000000"), ("1010101011011111", "1111111100000000"), ("1010101011111111", "0000000000000000"), ("1010101011111111", "0101010100000000"), ("1010101011111111", "1010101000000000"), ("1010101011111111", "1111111100000000"), ("1101010000000000", "0000000000000000"), ("1101010000000000", "0101010100000000"), ("1101010000000000", "1010101000000000"), ("1101010000000000", "1111111100000000"), ("1101010000011111", "0000000000000000"),
                            ("1101010000011111", "0101010100000000"), ("1101010000011111", "1010101000000000"), ("1101010000011111", "1111111100000000"), ("1101010000111111", "0000000000000000"), ("1101010000111111", "0101010100000000"), ("1101010000111111", "1010101000000000"), ("1101010000111111", "1111111100000000"), ("1101010001011111", "0000000000000000"), ("1101010001011111", "0101010100000000"), ("1101010001011111", "1010101000000000"), ("1101010001011111", "1111111100000000"), ("1101010001111111", "0000000000000000"), ("1101010001111111", "0101010100000000"), ("1101010001111111", "1010101000000000"), ("1101010001111111", "1111111100000000"), ("1101010010011111", "0000000000000000"), ("1101010010011111", "0101010100000000"), ("1101010010011111", "1010101000000000"), ("1101010010011111", "1111111100000000"), ("1101010010111111", "0000000000000000"), ("1101010010111111", "0101010100000000"),
                            ("1101010010111111", "1010101000000000"), ("1101010010111111", "1111111100000000"), ("1101010011011111", "0000000000000000"), ("1101010011011111", "0101010100000000"), ("1101010011011111", "1010101000000000"), ("1101010011011111", "1111111100000000"), ("1101010011111111", "0000000000000000"), ("1101010011111111", "0101010100000000"), ("1101010011111111", "1010101000000000"), ("1101010011111111", "1111111100000000"), ("1111111100000000", "0101010100000000"), ("1111111100000000", "1010101000000000"), ("1111111100011111", "0000000000000000"), ("1111111100011111", "0101010100000000"), ("1111111100011111", "1010101000000000"), ("1111111100011111", "1111111100000000"), ("1111111100111111", "0000000000000000"), ("1111111100111111", "0101010100000000"), ("1111111100111111", "1010101000000000"), ("1111111100111111", "1111111100000000"), ("1111111101011111", "0000000000000000"),
                            ("1111111101011111", "0101010100000000"));
                        DataHandler_SdRamStoreNextState <= DATA_3;
                        DataHandler_SdRamStoreState <= WAIT_INDEX_0;
                    END IF;

                WHEN DATA_3 =>
                    IF DataHandler_WriteDataBufferIdx = 64 THEN
                        -- store here
                        DataHandler_WriteDataBuffer_reg <= (("1111111101011111", "1010101000000000"), ("1111111101011111", "1111111100000000"), ("1111111101111111", "0000000000000000"), ("1111111101111111", "0101010100000000"), ("1111111101111111", "1010101000000000"), ("1111111101111111", "1111111100000000"),
                            ("1111111110011111", "0000000000000000"), ("1111111110011111", "0101010100000000"), ("1111111110011111", "1010101000000000"), ("1111111110011111", "1111111100000000"), ("1111111110111111", "0000000000000000"), ("1111111110111111", "0101010100000000"), ("1111111110111111", "1010101000000000"), ("1111111110111111", "1111111100000000"), ("1111111111011111", "0000000000000000"), ("1111111111011111", "0101010100000000"), ("1111111111011111", "1010101000000000"), ("1111111111011111", "1111111100000000"), ("1111111111111111", "0101010100000000"), ("1111111111111111", "1010101000000000"), ("1100110011001100", "1111111100000000"),
                            ("1111111111001100", "1111111100000000"), ("0011001111111111", "1111111100000000"), ("0110011011111111", "1111111100000000"), ("1001100111111111", "1111111100000000"), ("1100110011111111", "1111111100000000"), ("0000000001111111", "0000000000000000"), ("0000000001111111", "0101010100000000"), ("0000000001111111", "1010101000000000"), ("0000000001111111", "1111111100000000"), ("0000000010011111", "0000000000000000"), ("0000000010011111", "0101010100000000"), ("0000000010011111", "1010101000000000"), ("0000000010011111", "1111111100000000"), ("0000000010111111", "0000000000000000"), ("0000000010111111", "0101010100000000"), ("0000000010111111", "1010101000000000"), ("0000000010111111", "1111111100000000"), ("0000000011011111", "0000000000000000"), ("0000000011011111", "0101010100000000"), ("0000000011011111", "1010101000000000"), ("0000000011011111", "1111111100000000"),
                            ("0000000011111111", "0101010100000000"), ("0000000011111111", "1010101000000000"), ("0010101000000000", "0000000000000000"), ("0010101000000000", "0101010100000000"), ("0010101000000000", "1010101000000000"), ("0010101000000000", "1111111100000000"), ("0010101000011111", "0000000000000000"), ("0010101000011111", "0101010100000000"), ("0010101000011111", "1010101000000000"), ("0010101000011111", "1111111100000000"), ("0010101000111111", "0000000000000000"), ("0010101000111111", "0101010100000000"), ("1111111111111011", "1111000000000000"), ("1010000010100000", "1010010000000000"), ("1000000010000000", "1000000000000000"), ("1111111100000000", "0000000000000000"), ("0000000011111111", "0000000000000000"), ("1111111111111111", "0000000000000000"), ("0000000000000000", "1111111100000000"), ("1111111100000000", "1111111100000000"), ("0000000011111111", "1111111100000000"),
                            ("1111111111111111", "1111111100000000"));
                        DataHandler_SdRamStoreNextState <= END_STORE_DATA;
                        DataHandler_SdRamStoreState <= WAIT_INDEX_0;
                    END IF;

                WHEN WAIT_INDEX_0 =>
                    IF DataHandler_WriteDataBufferIdx < 64 THEN --data has been stored to the actual WriteDataBuffer
                        DataHandler_SdRamStoreState <= DataHandler_SdRamStoreNextState;
                    ELSE
                        DataHandler_SdRamStoreState <= END_STORE_DATA;
                    END IF;

                WHEN OTHERS => NULL;

            END CASE;

        END IF;
    END PROCESS;

    PROCESS (DataHandler_Reset_n, DataHandler_PllLocked) IS
    BEGIN
        IF (DataHandler_Reset_n = '1') THEN
            DataHandler_Reset_Sync <= '1';
            DataHandler_SdRamCS <= '1';
        ELSIF DataHandler_PllLocked = '1' THEN
            DataHandler_SdRamCS <= '0';
            DataHandler_Reset_Sync <= '0';
        ELSE
            DataHandler_Reset_Sync <= '1';
            DataHandler_SdRamCS <= '0';
        END IF;
    END PROCESS;

END ARCHITECTURE;