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
    READ_DATA_X,
    READ_DATA_Y,
    READ_DATA_COLOR_G,
    READ_DATA_COLOR_B,
    READ_DATA_COLOR_R,
    READ_DATA_RESOLUTION
    DELAY_STATE
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
    SIGNAL VideoCtrl_Counter : integer :=0;
    SIGNAL VideoCtrl_State : VIDEOCTRL_STATE_T := WAIT_SDRAM_WRITE;
    SIGNAL VideoCtrl_ActualColor : DataColor_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_NextState : VIDEOCTRL_STATE_T := WAIT_SDRAM_WRITE;

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
            VideoCtrl_NextState <= WAIT_SDRAM_WRITE;
            VideoCtrl_Start <= '0';
            VideoCtrl_Counter <= 0;
        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_PllLocked = '1' THEN
            CASE VideoCtrl_State IS
                WHEN WAIT_SDRAM_WRITE =>
                    IF VideoCtrl_Finish = '0' THEN
                        VideoCtrl_Start <= '0';
                        VideoCtrl_State <= READ_DATA_X;
                    END IF;

                WHEN READ_DATA_X =>
                    IF VideoCtrl_Finish = '1' THEN
                        VideoCtrl_DebugLeds <= VideoCtrl_Xaxis;
                        VideoCtrl_NextState <= READ_DATA_Y;
                        VideoCtrl_State <= DELAY_STATE;
                    END IF;

                WHEN READ_DATA_Y =>
                    VideoCtrl_DebugLeds <= VideoCtrl_Yaxis;
                    VideoCtrl_NextState <= READ_DATA_COLOR_G;
                    VideoCtrl_State <= DELAY_STATE;

                WHEN READ_DATA_COLOR_G =>
                    VideoCtrl_DebugLeds <= VideoCtrl_Color(23 downto 16);
                    VideoCtrl_NextState <= READ_DATA_COLOR_B;
                    VideoCtrl_State <= DELAY_STATE;

                WHEN READ_DATA_COLOR_B =>
                    VideoCtrl_DebugLeds <= VideoCtrl_Color(15 downto 8);
                    VideoCtrl_NextState <= READ_DATA_COLOR_R;
                    VideoCtrl_State <= DELAY_STATE;

                WHEN READ_DATA_COLOR_G =>
                    VideoCtrl_DebugLeds <= VideoCtrl_Color(7 downto 0);
                    VideoCtrl_NextState <= READ_DATA_RESOLUTION;
                    VideoCtrl_State <= DELAY_STATE;

                WHEN READ_DATA_RESOLUTION =>
                    VideoCtrl_DebugLeds <= VideoCtrl_Resolution;
                    VideoCtrl_NextState <= END_STATE;
                    VideoCtrl_State <= DELAY_STATE;

                WHEN DELAY_STATE =>
                    IF VideoCtrl_Counter = 100000000 THEN
                        VideoCtrl_Counter <= 0;
                        VideoCtrl_State <= VideoCtrl_NextState;
                    ELSE
                        VideoCtrl_Counter <= VideoCtrl_Counter + 1;
                        VideoCtrl_State <= DELAY_STATE;
                    END IF;
                
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
