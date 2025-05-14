library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SdRamTypes.all;
use work.SpiSlaveTypes.all;

entity DataHandler is 
    port(DataHandler_Reset_n : in std_logic := '1';
         DataHandler_ActlClk : in std_logic := '0';
         -- SDRAM PINS
         DataHandler_SdRamClkOut : out std_logic;
         DataHandler_Address : out std_logic_vector (12 downto 0) := (others => '0');
         DataHandler_Bank : out std_logic_vector (1 downto 0) := (others => '0');
         DataHandler_CAS : out std_logic := '0';
         DataHandler_CKE : out std_logic := '0';
         DataHandler_CS : out std_logic := '1';
         DataHandler_DQM : out std_logic_vector (0 to 1) := (others => '0');
         DataHandler_DQ : inout std_logic_vector (15 downto 0) := (others => '0');
         DataHandler_RAS : out std_logic := '0';
         DataHandler_WE : out std_logic := '0';
		 DataHandler_DebugLeds : out std_logic_vector (7 downto 0) := (others => '0');
         -- SPI PINS
         DataHandler_SpiClk   : in std_logic;
         DataHandler_So     : out std_logic := '0';
         DataHandler_Si     : in  std_logic;
         DataHandler_Cs       : in std_logic;
         DataHandler_SpiReady : out std_logic := '0'
         );

end DataHandler;

architecture rtl of DataHandler is

    type DataHandler_STATE is
    (
        START_WRITE,
        WAIT_START,
        WAIT_WRITE,
        WRITE_SDRAM,
        START_READ,
        CHECK_DATA_AVAILABLE,
        READ_DATA,
        READ_DATA_NEW
    );

    type DataHandlerSTORE_STATE is
    (
        DATA_1,
        DATA_2,
        DATA_3,
        END_STORE_DATA,
        WAIT_INDEX_0
    );
    signal DataHandler_SdRamHandlerState : SDRAMHANDLER_STATE := START_WRITE;
	signal DataHandler_SdRamStoreState : SDRAMHANDLERSTORE_STATE := DATA_1;
    signal DataHandler_SdRamStoreNextState : SDRAMHANDLERSTORE_STATE := DATA_1;
    signal DataHandler_Wren : std_logic := '0';
	signal DataHandler_RdEn : std_logic := '0';
    signal DataHandler_RdFinish : std_logic := '1';
    signal DataHandler_WrFinish : std_logic := '1';
    signal DataHandler_DataColsOutput : DataCols_t := (others => (others => '0'));
	signal DataHandler_DataColsInput : DataCols_t := (others => (others => '0'));
    signal DataHandler_RowsAddress : unsigned (12 downto 0) := (others => '0');
    signal DataHandler_ColsAddress : unsigned (8 downto 0) := (others => '0');
    signal DataHandler_PllLocked : std_logic := '0';
    signal DataHandler_Reset_Sync : std_logic := '1';
	signal DataHandler_SdRamClk : std_logic := '0';
    signal DataHandler_GlobalClk : std_logic := '0';
	signal DataHandler_SdRamEnd : std_logic := '0';
    signal DataHandler_SdRamState : SDRAM_STATE;
    signal DataHandler_BankSwitch : std_logic;
    signal DataHandler_WriteDataBuffer : DataCols_ary := (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"), 
                ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
                ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
                ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
                ("0101010110111111", "1111111100000000"));
    signal DataHandler_WriteDataBuffer_reg : DataCols_ary := (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"), 
                ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
                ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
                ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
                ("0101010110111111", "1111111100000000"));
    signal DataHandler_WriteDataBufferIdx : integer := 0;

    -- QSPI SIGNALS
    signal DataHandler_StartSpi : std_logic := '0';
    signal DataHandler_WrEn     : std_logic := '0';
    signal DataHandler_WriteDataWord : QSpiCorrected := (others => (others => '0') );
    signal DataHandler_ReadDataWord  : QSpiCorrected;
    signal DataHandler_WriteAddress : std_logic_vector (7 DOWNTO 0) := (others => '0');
    signal DataHandler_ReadAddress : std_logic_vector (7 DOWNTO 0) := (others => '0');
    signal DataHandler_SpiPllLocked : std_logic := '0';
    signal DataHandler_Words : integer := 0;
    signal DataHandler_EndSpi : std_logic := '1';
    signal DataHandler_SpiWordsReg : integer := 0;
    signal DataHandler_MisoIndex : unsigned (1 downto 0) := (others => '0');

begin
    SdRamPll:entity work.SdRamPll(SYN)
    port map
    (
       areset => DataHandler_Reset_n,
	   inclk0 => DataHandler_ActlClk,	
	   c0     => DataHandler_SdRamClk,
       c1     => DataHandler_GlobalClk,
	   locked => DataHandler_PllLocked
    );

    SdRam:entity work.SdRam(SYN)
    port map
    (
        SdRam_ActlClk     => DataHandler_ActlClk,
        SdRam_Reset_n     => DataHandler_Reset_Sync,
        SdRam_ClkOut      => DataHandler_SdRamClkOut,
		SdRam_SdRamClk    => DataHandler_SdRamClk,
        SdRam_GlobalClk  => DataHandler_GlobalClk,
        SdRam_PllLocked   => DataHandler_PllLocked,
        SdRam_Address     => DataHandler_Address,
        SdRam_Bank        => DataHandler_Bank, 
        SdRam_CAS         => DataHandler_CAS,
        SdRam_CKE         => DataHandler_CKE,
        SdRam_DQM         => DataHandler_DQM,
        SdRam_DQ          => DataHandler_DQ,
        SdRam_RAS         => DataHandler_RAS,
        SdRam_WE          => DataHandler_WE,
        SdRam_RdEn        => DataHandler_RdEn, 
        SdRam_WrEn        => DataHandler_WrEn,
        SdRam_RdFinish    => DataHandler_RdFinish,
        SdRam_WrFinish    => DataHandler_WrFinish,
        SdRam_DataColsInput => DataHandler_DataColsOutput,
		SdRam_DataColsOutput => DataHandler_DataColsInput,
        SdRam_RowsAddress => DataHandler_RowsAddress,
        SdRam_ColsAddress => DataHandler_ColsAddress,
        SdRam_SdRamState => DataHandler_SdRamState,
        SdRam_BankSwitch => DataHandler_BankSwitch
    );

    SpiSlave:entity work.SpiSlave(rtl)
    port map
    (
        Spi_ActlClk       => DataHanlder_ActlClk,
        Spi_Clk           => DataHandler_SdRamClk,
        Spi_SpiClk        => DataHanlder_SpiClk,
        Spi_Reset_n       => DataHandler_Reset_Sync,
        Spi_So            => DataHanlder_So, 
        Spi_Si            => DataHanlder_Si,
        Spi_Cs            => DataHanlder_Cs,
        Spi_StartSpi      => DataHanlder_StartSpi,
        Spi_EndSpi        => DataHanlder_EndSpi,
        Spi_Words         => DataHanlder_Words,
        Spi_WrEn          => DataHanlder_WrEn,
		Spi_WriteDataWord => DataHandler_WriteDataWord,
		Spi_ReadDataWord  => DataHandler_ReadDataWord,
        Spi_WriteAddress   => DataHandler_WriteAddress,
        Spi_ReadAddress   => DataHandler_ReadAddress,
        Spi_lockedloop  => DataHandler_PllLocked
    );

    SpiRam:entity work.SpiRam(SYN)
    port map
    (
      clock		=> DataHandler_SdRamClk,
      data		=> DataHandler_WriteDataWord(0),
      rdaddress	=> DataHandler_ReadAddress,
      wraddress	=> DataHandler_WriteAddress,
      wren		=> DataHandler_WrEn,
      q		    => DataHandler_ReadDataWord(0)
    );

    SpiRam_1:entity work.SpiRam_1(SYN)
    port map
    (
      clock		=> DataHandler_SdRamClk,
      data		=> DataHandler_WriteDataWord(1),
      rdaddress	=> DataHandler_ReadAddress,
      wraddress	=> DataHandler_WriteAddress,
      wren		=> DataHandler_WrEn,
      q		    => DataHandler_ReadDataWord(1)
    );

    SpiRam_2:entity work.SpiRam_2(SYN)
    port map
    (
      clock		=> DataHandler_SdRamClk,
      data		=> DataHandler_WriteDataWord(2),
      rdaddress	=> DataHandler_ReadAddress,
      wraddress	=> DataHandler_WriteAddress,
      wren		=> DataHandler_WrEn,
      q		    => DataHandler_ReadDataWord(2)
    );
    
    process(DataHandler_SdRamClk ,DataHandler_Reset_Sync, DataHandler_PllLocked) is
    begin
        if (DataHandler_Reset_Sync = '1') then
            DataHandler_SdRamHandlerState <= WAIT_WRITE;
			DataHandler_RdEn <= '0';
            DataHandler_WrEn <= '0';
			DataHandler_DataColsOutput <= (others => (others => '0'));
			DataHandler_SdRamEnd <= '0';
			DataHandler_RowsAddress <= to_unsigned(0,13);
			DataHandler_ColsAddress <= to_unsigned(0,9);
			DataHandler_DebugLeds <= b"00000000";
            DataHandler_WriteDataBufferIdx <= 0;
            DataHandler_MisoIndex <= "00"
            -- SPI PART
            DataHandler_SpiReady <= '0';
            DataHandler_StartSpi <= '0';
            DataHandler_ReadAddress <= (others => '0');
            DataHandler_SpiWordsReg <= 0;
            -- SDRAM STORE ARRAY
            DataHandler_WriteDataBuffer <= (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"), 
                ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
                ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
                ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
                ("0101010110111111", "1111111100000000"));
        elsif rising_edge(DataHandler_SdRamClk) and DataHandler_PllLocked = '1' then
            case DataHandler_SdRamHandlerState is
                when START_WRITE =>
                    DataHandler_WrEn <= '1';
                    DataHandler_DataColsOutput <= WriteDataBuffer(WriteDataBufferIdx);
                    DataHandler_WriteDataBufferIdx <= DataHandler_WriteDataBufferIdx + 1;
                    DataHandler_SdRamHandlerState <= WAIT_START;

                when WAIT_START =>
                    if DataHandler_DataHandler_WrFinish = '0' or DataHandler_DataHandler_BankSwitch = '1' then
                        DataHandler_DataHandler_SdRamHandlerState <= WAIT_WRITE;
                    else
                        DataHandler_DataHandler_SdRamHandlerState <= WAIT_START;
                    end if;

                when WAIT_WRITE =>
                    if (DataHandler_BankSwitch = '0' and DataHandler_SdRamState = BURST_TERMINATE_WRITE) then
                        if (DataHandler_WriteDataBufferIdx = 64) then
                            DataHandler_WriteDataBuffer <= DataHandler_WriteDataBuffer_reg;
                            DataHandler_DataColsOutput <= DataHandler_WriteDataBuffer_reg(0);
                            DataHandler_WriteDataBufferIdx <= 1;
                            DataHandler_SdRamHandlerState <= WAIT_START;
                        elsif DataHandler_SdRamStoreState = END_STORE_DATA and DataHandler_WriteDataBufferIdx = 64 then --write has been finished
                            -- DEACTIVATE THE WRITE COMMAND
                            DataHandler_WrEn <= '0';
                            DataHandler_SdRamHandlerState <= START_READ;
                            -- START THE SPI and prepare the spi ready
                            DataHandler_StartSpi <= '1';
                            DataHander_SpiReady <= '1';
                        else
                            DataHandler_DataColsOutput <= DataHandler_WriteDataBuffer(WriteDataBufferIdx);
                            DataHandler_WriteDataBufferIdx <= DataHandler_WriteDataBufferIdx + 1;
                            DataHandler_SdRamHandlerState <= WAIT_START;
                        end if;
                    else
                        DataHandler_SdRamHandlerState <= WAIT_WRITE;
                    end if;
                
                when START_READ =>
                    if (DataHanlder_EndSpi = '0') then
                        -- AVOID EXTRA WRONG DATA SEND
                        DataHander_SpiReady <= '0';
                        DataHandler_StartSpi <= '0';
                        DataHandler_SdRamHandlerState = CHECK_DATA_AVAILABLE;
                        DataHandler_RowsAddress <= (others => '0');
                    end if;
                
                when CHECK_DATA_AVAILABLE =>
                    if DataHandler_SpiWordsReg < DataHandler_Words then
                        DataHandler_ColsAddress <= (unsigned(0 & DataHandler_ReadDataWord(DataHandler_MisoIndex)(7 downto 0)) << 1);
                        DataHandler_MisoIndex <= DataHandler_MisoIndex + 1;
                        DataHandler_RdEn <= '1';
                        DataHandler_SdRamHandlerState <= WAIT_READ;
                    end if;

                when WAIT_READ =>
                    if DataHandler_SdRamState = READ_STATE and DataHandler_MisoIndex < "11" then
                        DataHandler_ColsAddress <= (unsigned(0 & DataHandler_ReadDataWord(DataHandler_MisoIndex)(7 downto 0)) << 1);
                        DataHandler_MisoIndex <= DataHandler_MisoIndex + 1;
                        DataHandler_SdRamHandlerState <= READ_DATA;
                    elsif DataHandler_SdRamState = READ_STATE and DataHandler_MisoIndex = "11" then
                        DataHandler_MisoIndex <= 0;
                        DataHandler_ReadAddress <= std_logic(unsigned(DataHandler_ReadAddress) + 1);
                        DataHandler_SpiWordsReg <= DataHandler_SpiWordsReg + 1;
                        DataHandler_SdRamHandlerState <= READ_DATA_NEW;
                    end if;
                
                when READ_DATA =>
                    if DataHandler_SdRamState = ACTIVE_STATE then
                        -- Store the data

                        DataHandler_SdRamHandlerState <= WAIT_READ;
                    end if;

                when READ_DATA_NEW =>
                    -- If we increase and overflows data is maximum
                    if DataHandler_SdRamState = WAIT_STORE and DataHandler_SpiWordsReg = b"00000000" then
                        DataHandler_RdEn <= '0';
                        -- increase the double buffer index

                        -- Go back to read state
                        DataHandler_SdRamHandlerState <= PREPARE_READ;
                    elsif DataHandler_SdRamState = WAIT_STORE then
                        DataHandler_ColsAddress <= (unsigned(0 & DataHandler_ReadDataWord(DataHandler_MisoIndex)(7 downto 0)) << 1);
                        DataHandler_MisoIndex <= DataHandler_MisoIndex + 1;
                        -- Go back to read data in order to store the data for vga
                        DataHandler_SdRamHandlerState <= READ_DATA;
                    end if;

                
                when others => null;

            end case;
        end if;
    end process;

    process(DataHandler_Reset_Sync, DataHandler_SdRamClk, DataHandler_PllLocked) is
    begin
        if (DataHandler_Reset_Sync = '1') then
                DataHandler_WriteDataBuffer_reg <= (("0000000000000000", "0000000000000000"), ("1000000000000000", "0000000000000000"), ("0000000010000000", "0000000000000000"), ("1000000010000000", "0000000000000000"), ("0000000000000000", "1000000000000000"), ("1000000000000000", "1000000000000000"), 
                ("0000000010000000", "1000000000000000"), ("1100000011000000", "1100000000000000"), ("1100000011011100", "1100000000000000"), ("1010011011001010", "1111000000000000"), ("0010101000111111", "1010101000000000"), ("0010101000111111", "1111111100000000"), ("0010101001011111", "0000000000000000"), ("0010101001011111", "0101010100000000"), ("0010101001011111", "1010101000000000"), ("0010101001011111", "1111111100000000"), ("0010101001111111", "0000000000000000"), ("0010101001111111", "0101010100000000"), ("0010101001111111", "1010101000000000"), ("0010101001111111", "1111111100000000"), ("0010101010011111", "0000000000000000"),
                ("0010101010011111", "0101010100000000"), ("0010101010011111", "1010101000000000"), ("0010101010011111", "1111111100000000"), ("0010101010111111", "0000000000000000"), ("0010101010111111", "0101010100000000"), ("0010101010111111", "1010101000000000"), ("0010101010111111", "1111111100000000"), ("0010101011011111", "0000000000000000"), ("0010101011011111", "0101010100000000"), ("0010101011011111", "1010101000000000"), ("0010101011011111", "1111111100000000"), ("0010101011111111", "0000000000000000"), ("0010101011111111", "0101010100000000"), ("0010101011111111", "1010101000000000"), ("0010101011111111", "1111111100000000"), ("0101010100000000", "0000000000000000"), ("0101010100000000", "0101010100000000"), ("0101010100000000", "1010101000000000"), ("0101010100000000", "1111111100000000"), ("0101010100011111", "0000000000000000"), ("0101010100011111", "0101010100000000"),
                ("0101010100011111", "1010101000000000"), ("0101010100011111", "1111111100000000"), ("0101010100111111", "0000000000000000"), ("0101010100111111", "0101010100000000"), ("0101010100111111", "1010101000000000"), ("0101010100111111", "1111111100000000"), ("0101010101011111", "0000000000000000"), ("0101010101011111", "0101010100000000"), ("0101010101011111", "1010101000000000"), ("0101010101011111", "1111111100000000"), ("0101010101111111", "0000000000000000"), ("0101010101111111", "0101010100000000"), ("0101010101111111", "1010101000000000"), ("0101010101111111", "1111111100000000"), ("0101010110011111", "0000000000000000"), ("0101010110011111", "0101010100000000"), ("0101010110011111", "1010101000000000"), ("0101010110011111", "1111111100000000"), ("0101010110111111", "0000000000000000"), ("0101010110111111", "0101010100000000"), ("0101010110111111", "1010101000000000"),
                ("0101010110111111", "1111111100000000"));
				DataHandler_SdRamStoreState <= DATA_1;
                DataHandler_SdRamStoreNextState <= DATA_1;
        elsif rising_edge(DataHandler_SdRamClk) and DataHandler_PllLocked = '1' then
            case DataHandler_SdRamStoreState is
                when DATA_1 =>
                    if DataHandler_WriteDataBufferIdx = 64 then
                        -- store here
                        DataHandler_WriteDataBuffer_reg <= (("0101010111011111", "0000000000000000"), ("0101010111011111", "0101010100000000"), ("0101010111011111", "1010101000000000"), ("0101010111011111", "1111111100000000"), ("0101010111111111", "0000000000000000"), ("0101010111111111", "0101010100000000"), 
                        ("0101010111111111", "1010101000000000"), ("0101010111111111", "1111111100000000"), ("0111111100000000", "0000000000000000"), ("0111111100000000", "0101010100000000"), ("0111111100000000", "1010101000000000"), ("0111111100000000", "1111111100000000"), ("0111111100011111", "0000000000000000"), ("0111111100011111", "0101010100000000"), ("0111111100011111", "1010101000000000"), ("0111111100011111", "1111111100000000"), ("0111111100111111", "0000000000000000"), ("0111111100111111", "0101010100000000"), ("0111111100111111", "1010101000000000"), ("0111111100111111", "1111111100000000"), ("0111111101011111", "0000000000000000"),
                        ("0111111101011111", "0101010100000000"), ("0111111101011111", "1010101000000000"), ("0111111101011111", "1111111100000000"), ("0111111101111111", "0000000000000000"), ("0111111101111111", "0101010100000000"), ("0111111101111111", "1010101000000000"), ("0111111101111111", "1111111100000000"), ("0111111110011111", "0000000000000000"), ("0111111110011111", "0101010100000000"), ("0111111110011111", "1010101000000000"), ("0111111110011111", "1111111100000000"), ("0111111110111111", "0000000000000000"), ("0111111110111111", "0101010100000000"), ("0111111110111111", "1010101000000000"), ("0111111110111111", "1111111100000000"), ("0111111111011111", "0000000000000000"), ("0111111111011111", "0101010100000000"), ("0111111111011111", "1010101000000000"), ("0111111111011111", "1111111100000000"), ("0111111111111111", "0000000000000000"), ("0111111111111111", "0101010100000000"),
                        ("0111111111111111", "1010101000000000"), ("0111111111111111", "1111111100000000"), ("1010101000000000", "0000000000000000"), ("1010101000000000", "0101010100000000"), ("1010101000000000", "1010101000000000"), ("1010101000000000", "1111111100000000"), ("1010101000011111", "0000000000000000"), ("1010101000011111", "0101010100000000"), ("1010101000011111", "1010101000000000"), ("1010101000011111", "1111111100000000"), ("1010101000111111", "0000000000000000"), ("1010101000111111", "0101010100000000"), ("1010101000111111", "1010101000000000"), ("1010101000111111", "1111111100000000"), ("1010101001011111", "0000000000000000"), ("1010101001011111", "0101010100000000"), ("1010101001011111", "1010101000000000"), ("1010101001011111", "1111111100000000"), ("1010101001111111", "0000000000000000"), ("1010101001111111", "0101010100000000"), ("1010101001111111", "1010101000000000"),
                        ("1010101001111111", "1111111100000000"));
                        DataHandler_SdRamStoreNextState <= DATA_2;
                        DataHandler_SdRamStoreState <= WAIT_INDEX_0;
                    end if;
                
                when DATA_2 =>
                    if DataHandler_WriteDataBufferIdx = 64 then
                        -- store here
                        DataHandler_WriteDataBuffer_reg <= (("1010101010011111", "0000000000000000"), ("1010101010011111", "0101010100000000"), ("1010101010011111", "1010101000000000"), ("1010101010011111", "1111111100000000"), ("1010101010111111", "0000000000000000"), ("1010101010111111", "0101010100000000"), 
                        ("1010101010111111", "1010101000000000"), ("1010101010111111", "1111111100000000"), ("1010101011011111", "0000000000000000"), ("1010101011011111", "0101010100000000"), ("1010101011011111", "1010101000000000"), ("1010101011011111", "1111111100000000"), ("1010101011111111", "0000000000000000"), ("1010101011111111", "0101010100000000"), ("1010101011111111", "1010101000000000"), ("1010101011111111", "1111111100000000"), ("1101010000000000", "0000000000000000"), ("1101010000000000", "0101010100000000"), ("1101010000000000", "1010101000000000"), ("1101010000000000", "1111111100000000"), ("1101010000011111", "0000000000000000"),
                        ("1101010000011111", "0101010100000000"), ("1101010000011111", "1010101000000000"), ("1101010000011111", "1111111100000000"), ("1101010000111111", "0000000000000000"), ("1101010000111111", "0101010100000000"), ("1101010000111111", "1010101000000000"), ("1101010000111111", "1111111100000000"), ("1101010001011111", "0000000000000000"), ("1101010001011111", "0101010100000000"), ("1101010001011111", "1010101000000000"), ("1101010001011111", "1111111100000000"), ("1101010001111111", "0000000000000000"), ("1101010001111111", "0101010100000000"), ("1101010001111111", "1010101000000000"), ("1101010001111111", "1111111100000000"), ("1101010010011111", "0000000000000000"), ("1101010010011111", "0101010100000000"), ("1101010010011111", "1010101000000000"), ("1101010010011111", "1111111100000000"), ("1101010010111111", "0000000000000000"), ("1101010010111111", "0101010100000000"),
                        ("1101010010111111", "1010101000000000"), ("1101010010111111", "1111111100000000"), ("1101010011011111", "0000000000000000"), ("1101010011011111", "0101010100000000"), ("1101010011011111", "1010101000000000"), ("1101010011011111", "1111111100000000"), ("1101010011111111", "0000000000000000"), ("1101010011111111", "0101010100000000"), ("1101010011111111", "1010101000000000"), ("1101010011111111", "1111111100000000"), ("1111111100000000", "0101010100000000"), ("1111111100000000", "1010101000000000"), ("1111111100011111", "0000000000000000"), ("1111111100011111", "0101010100000000"), ("1111111100011111", "1010101000000000"), ("1111111100011111", "1111111100000000"), ("1111111100111111", "0000000000000000"), ("1111111100111111", "0101010100000000"), ("1111111100111111", "1010101000000000"), ("1111111100111111", "1111111100000000"), ("1111111101011111", "0000000000000000"),
                        ("1111111101011111", "0101010100000000"));
                        DataHandler_SdRamStoreNextState <= DATA_3;
                        DataHandler_SdRamStoreState <= WAIT_INDEX_0;
                    end if;

                when DATA_3 =>
                    if DataHandler_WriteDataBufferIdx = 64 then
                        -- store here
                        DataHandler_WriteDataBuffer_reg <= (("1111111101011111", "1010101000000000"), ("1111111101011111", "1111111100000000"), ("1111111101111111", "0000000000000000"), ("1111111101111111", "0101010100000000"), ("1111111101111111", "1010101000000000"), ("1111111101111111", "1111111100000000"), 
                        ("1111111110011111", "0000000000000000"), ("1111111110011111", "0101010100000000"), ("1111111110011111", "1010101000000000"), ("1111111110011111", "1111111100000000"), ("1111111110111111", "0000000000000000"), ("1111111110111111", "0101010100000000"), ("1111111110111111", "1010101000000000"), ("1111111110111111", "1111111100000000"), ("1111111111011111", "0000000000000000"), ("1111111111011111", "0101010100000000"), ("1111111111011111", "1010101000000000"), ("1111111111011111", "1111111100000000"), ("1111111111111111", "0101010100000000"), ("1111111111111111", "1010101000000000"), ("1100110011001100", "1111111100000000"),
                        ("1111111111001100", "1111111100000000"), ("0011001111111111", "1111111100000000"), ("0110011011111111", "1111111100000000"), ("1001100111111111", "1111111100000000"), ("1100110011111111", "1111111100000000"), ("0000000001111111", "0000000000000000"), ("0000000001111111", "0101010100000000"), ("0000000001111111", "1010101000000000"), ("0000000001111111", "1111111100000000"), ("0000000010011111", "0000000000000000"), ("0000000010011111", "0101010100000000"), ("0000000010011111", "1010101000000000"), ("0000000010011111", "1111111100000000"), ("0000000010111111", "0000000000000000"), ("0000000010111111", "0101010100000000"), ("0000000010111111", "1010101000000000"), ("0000000010111111", "1111111100000000"), ("0000000011011111", "0000000000000000"), ("0000000011011111", "0101010100000000"), ("0000000011011111", "1010101000000000"), ("0000000011011111", "1111111100000000"),
                        ("0000000011111111", "0101010100000000"), ("0000000011111111", "1010101000000000"), ("0010101000000000", "0000000000000000"), ("0010101000000000", "0101010100000000"), ("0010101000000000", "1010101000000000"), ("0010101000000000", "1111111100000000"), ("0010101000011111", "0000000000000000"), ("0010101000011111", "0101010100000000"), ("0010101000011111", "1010101000000000"), ("0010101000011111", "1111111100000000"), ("0010101000111111", "0000000000000000"), ("0010101000111111", "0101010100000000"), ("1111111111111011", "1111000000000000"), ("1010000010100000", "1010010000000000"), ("1000000010000000", "1000000000000000"), ("1111111100000000", "0000000000000000"), ("0000000011111111", "0000000000000000"), ("1111111111111111", "0000000000000000"), ("0000000000000000", "1111111100000000"), ("1111111100000000", "1111111100000000"), ("0000000011111111", "1111111100000000"),
                        ("1111111111111111", "1111111100000000"));
                        DataHandler_SdRamStoreNextState <= END_STORE_DATA;
                        DataHandler_SdRamStoreState <= WAIT_INDEX_0;
                    end if;

                when WAIT_INDEX_0 =>
                    if DataHandler_WriteDataBufferIdx < 64 then --data has been stored to the actual WriteDataBuffer
                        DataHandler_SdRamStoreState <= DataHandler_SdRamStoreNextState;
                    else
                        DataHandler_SdRamStoreState <= END_STORE_DATA;
                    end if;

                when others => null;
                
            end case;

        end if;
	end process;

    process (DataHandler_Reset_n, DataHandler_PllLocked) is
    begin
        if (DataHandler_Reset_n = '1') then
            DataHandler_Reset_Sync <= '1';
            DataHandler_CS <= '1';
        elsif DataHandler_PllLocked='1' then
            DataHandler_CS <= '0';
            DataHandler_Reset_Sync <= '0';
		  else
			DataHandler_Reset_Sync <= '1';
			DataHandler_CS <= '0';
        end if;
    end process;

end architecture;
