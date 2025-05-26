LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.DataHandlerTypes.ALL;
USE work.SdRamTypes.ALL;

ENTITY VideoCtrl IS
    PORT (
        VideoCtrl_Reset_n : IN STD_LOGIC := '1';
        -- Clocks
        VideoCtrl_ActlClk : IN STD_LOGIC := '0';
        -- SDRAM PINS
        VideoCtrl_SdRamClkOut : OUT STD_LOGIC;
        VideoCtrl_Address : OUT STD_LOGIC_VECTOR (12 DOWNTO 0) := (OTHERS => '0');
        VideoCtrl_Bank : OUT STD_LOGIC_VECTOR (1 DOWNTO 0) := (OTHERS => '0');
        VideoCtrl_CAS : OUT STD_LOGIC := '0';
        VideoCtrl_CKE : OUT STD_LOGIC := '0';
        VideoCtrl_SdRamCS : OUT STD_LOGIC := '1';
        VideoCtrl_DQM : OUT STD_LOGIC_VECTOR (0 TO 1) := (OTHERS => '0');
        VideoCtrl_DQ : INOUT STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0');
        VideoCtrl_RAS : OUT STD_LOGIC := '0';
        VideoCtrl_WE : OUT STD_LOGIC := '0';
        VideoCtrl_DebugLeds : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        -- SPI PINS
        VideoCtrl_SpiClk : IN STD_LOGIC;
        VideoCtrl_So : OUT STD_LOGIC := '0';
        VideoCtrl_Si : IN STD_LOGIC_VECTOR(0 TO 2);
        VideoCtrl_Cs : IN STD_LOGIC;
        VideoCtrl_SpiReady : OUT STD_LOGIC
    );

END VideoCtrl;

ARCHITECTURE rtl OF VideoCtrl IS

    TYPE VIDEOCTRL_STATE_T IS
    (
    WAIT_SDRAM_WRITE,
    WAIT_SPI_START,
    READ_DATA
    );

    SIGNAL VideoCtrl_SdRamClk : STD_LOGIC := '0';
    SIGNAL VideoCtrl_GlobalClk : STD_LOGIC := '0';
    SIGNAL VideoCtrl_PllLocked : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Finish : STD_LOGIC := '1';
    SIGNAL VideoCtrl_Start : STD_LOGIC;
    SIGNAL VideoCtrl_Xaxis : DataPart_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Yaxis : DataPart_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Idx : DataPart_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Resolution : DataPart_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Color : DataColor_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_SpiWordsReg : INTEGER := 0;
    SIGNAL VideoCtrl_DataAvailable : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Reset_Sync : STD_LOGIC := '0';
    -- VideoCtlr state machine
    SIGNAL VideoCtrl_State : VIDEOCTRL_STATE_T := WAIT_SDRAM_WRITE;
    SIGNAL VideOCtrl_ActualColor : DataColor_t := (OTHERS => (OTHERS => '0'));

BEGIN
    SdRamPll : ENTITY work.SdRamPll(SYN)
        PORT MAP
        (
            areset => VideoCtrl_Reset_n,
            inclk0 => VideoCtrl_ActlClk,
            c0 => VideoCtrl_SdRamClk,
            c1 => VideoCtrl_GlobalClk,
            locked => VideoCtrl_PllLocked
        );

    DataHandler : ENTITY work.DataHandler(rtl)
        PORT MAP
        (
            DataHandler_Reset_n => VideoCtrl_Reset_Sync,
            -- Clocks
            DataHandler_ActlClk => VideoCtrl_ActlClk,
            DataHandler_SdRamClk => VideoCtrl_SdRamClk,
            DataHandler_GlobalClk => VideoCtrl_GlobalClk,
            DataHandler_PllLocked => VideoCtrl_PllLocked,
            -- SDRAM PINS
            DataHandler_SdRamClkOut => VideoCtrl_SdRamClkOut,
            DataHandler_Address => VideoCtrl_Address,
            DataHandler_Bank => VideoCtrl_Bank,
            DataHandler_CAS => VideoCtrl_CAS,
            DataHandler_CKE => VideoCtrl_CKE,
            DataHandler_SdRamCS => VideoCtrl_SdRamCS,
            DataHandler_DQM => VideoCtrl_DQM,
            DataHandler_DQ => VideoCtrl_DQ,
            DataHandler_RAS => VideoCtrl_RAS,
            DataHandler_WE => VideoCtrl_WE,
            DataHandler_DebugLeds => VideoCtrl_DebugLeds,
            -- SPI PINS
            DataHandler_SpiClk => VideoCtrl_SpiClk,
            DataHandler_So => VideoCtrl_So,
            DataHandler_Si => VideoCtrl_Si,
            DataHandler_Cs => VideoCtrl_Cs,
            DataHandler_Start => VideoCtrl_Start,
            DataHandler_Xaxis => VideoCtrl_Xaxis,
            DataHandler_Yaxis => VideoCtrl_Yaxis,
            DataHandler_Resolution => VideoCtrl_Resolution,
            DataHandler_Color => VideoCtrl_Color,
            DataHandler_SpiWordsReg => VideoCtrl_SpiWordsReg,
            DataHandler_SpiReady => VideoCtrl_SpiReady,
            DataHandler_Finish => VideoCtrl_Finish
        );

    PROCESS (VideoCtrl_SdRamClk, VideoCtrl_Reset_Sync, VideoCtrl_PllLocked) IS
    BEGIN
        IF (VideoCtrl_Reset_Sync = '1') THEN
            VideoCtrl_State <= WAIT_SDRAM_WRITE;
            VideoCtrl_Start <= '0';
        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_PllLocked = '1' THEN
            CASE VideoCtrl_State IS
                WHEN WAIT_SDRAM_WRITE =>
                    IF VideoCtrl_Finish = '0' THEN
                        VideoCtrl_Start <= '0';
                        VideoCtrl_State <= WAIT_SPI_START;
                    END IF;

                WHEN WAIT_SPI_START =>
                    IF VideoCtrl_Finish = '1' THEN
                        VideoCtrl_Idx <= VideoCtrl_Xaxis;
                        VideoCtrl_State <= READ_DATA;
                    END IF;

                WHEN READ_DATA =>
                    VideoCtrl_Idx <= VideoCtrl_Yaxis;
                    VideoCtrl_State <= READ_DATA;
                    VideoCtrl_ActualColor(0)(23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(0)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(0)) SRL 8, 8));
                    VideoCtrl_ActualColor(1)(23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(1)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(1)) SRL 8, 8));
                    VideoCtrl_ActualColor(2)(23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(2)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(2)) SRL 8, 8));

                    VideoCtrl_ActualColor(0)(15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(0)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(0)) SRL 8, 8));
                    VideoCtrl_ActualColor(1)(15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(1)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(1)) SRL 8, 8));
                    VideoCtrl_ActualColor(2)(15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(2)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(2)) SRL 8, 8));

                    VideoCtrl_ActualColor(0)(7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(0)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(0)) SRL 8, 8));
                    VideoCtrl_ActualColor(1)(7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(1)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(1)) SRL 8, 8));
                    VideoCtrl_ActualColor(2)(7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(unsigned(VideoCtrl_Color(2)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(2)) SRL 8, 8));
                WHEN OTHERS => NULL;
            END CASE;

        END IF;
    END PROCESS;

    PROCESS (VideoCtrl_Reset_Sync, VideoCtrl_SdRamClk, VideoCtrl_PllLocked) IS
    BEGIN
        IF (VideoCtrl_Reset_Sync = '1') THEN

        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_PllLocked = '1' THEN

        END IF;
    END PROCESS;

    PROCESS (VideoCtrl_Reset_n, VideoCtrl_PllLocked) IS
    BEGIN
        IF (VideoCtrl_Reset_n = '1') THEN
            VideoCtrl_Reset_Sync <= '1';
        ELSIF VideoCtrl_PllLocked = '1' THEN
            VideoCtrl_Reset_Sync <= '0';
        ELSE
            VideoCtrl_Reset_Sync <= '1';
        END IF;
    END PROCESS;

END ARCHITECTURE;