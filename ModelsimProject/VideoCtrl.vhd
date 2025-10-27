LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.DataHandlerTypes.ALL;
USE work.SdRamTypes.ALL;
USE work.VgaTypes.ALL;

ENTITY VideoCtrl IS
    PORT (
        VideoCtrl_Reset : IN STD_LOGIC := '1';
        -- Clocks
        VideoCtrl_ActlClk : IN STD_LOGIC := '0';
        -- SDRAM PINS
        VideoCtrl_SdRamClk : IN STD_LOGIC := '0';
        VideoCtrl_GlobalClk : IN STD_LOGIC := '0';
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
        --VideoCtrl_DebugLeds : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        -- SPI PINS
        VideoCtrl_SpiClk : IN STD_LOGIC;
        VideoCtrl_So : OUT STD_LOGIC := '0';
        VideoCtrl_Si : IN STD_LOGIC_VECTOR(0 TO 2);
        VideoCtrl_Cs : IN STD_LOGIC;
        VideoCtrl_SpiReady : OUT STD_LOGIC;
        -- Vga PINS
        VideoCtrl_ColorClk : IN STD_LOGIC := '0';
        VideoCtrl_HsyncClk : OUT STD_LOGIC := '1';
        VideoCtrl_VsyncClk : OUT STD_LOGIC := '1';
        VideoCtrl_R : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        VideoCtrl_G : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        VideoCtrl_B : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0')
    );

END VideoCtrl;

ARCHITECTURE rtl OF VideoCtrl IS
    -- Datahandler state type
    TYPE DATAHANDLER_STATE_T IS
    (
    WAIT_DATAHANDLER_READY,
    HANDLE_ONE_TWO,
    HANDLE_TWO_THREE,
    WAIT_VGA_STARTREAD,
    WAIT_VGA_READ,
    WAIT_DATAHANDLER_RESTART,
    WAIT_DATAHANDLER_FINISH
    );

    -- Vga State type
    TYPE VGA_STATE_T IS
    (
    VGA_BEFORE_START,
    VGA_WAIT_SDRAM_SWITCH,
    VGA_WAIT_SDRAM,
    VGA_STORE_ZEROS,
    VGA_STORE_WALL,
    START_ADD_ANGLE_STEP,
    START_REMOVE_ANGLE_STEP,
    VGA_SWITCH_BUFFER,
    VGA_WAIT_LINE_FREE,
    VGA_VSYNC_WAIT,
    VGA_VSYNC_RESTART
    );

    CONSTANT ANGLESTEP_MAX_U5 : UNSIGNED (5 DOWNTO 0) := "111111";
    SIGNAL VideoCtrl_SdRamPllLocked : STD_LOGIC := '1';
    SIGNAL VideoCtrl_DataHandlerFinish : STD_LOGIC := '0';
    SIGNAL VideoCtrl_DataHandlerFinish_reg : STD_LOGIC := '0';
    SIGNAL VideoCtrl_DataHandlerStart : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Xaxis : Data_Xaxis_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Yaxis : Data_Yaxis_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Xbuffer : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Ybuffer : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Type : Data_Type_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Ackn : Data_Ackn_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_AngleStep : Data_AngleStep_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Resolution : Data_Resolution_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Color : DataColor_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_SpiWordsReg : INTEGER := 0;
    SIGNAL VideoCtrl_DataAvailable : STD_LOGIC := '0';
    SIGNAL VideoCtrl_SdRamReset_Sync : STD_LOGIC := '1';

    -- Vga Signals
    SIGNAL VideoCtrl_VgaResetSync : STD_LOGIC := '1';
    SIGNAL VideoCtrl_y_axis : unsigned (9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_HsyncComplete : STD_LOGIC := '0';
    SIGNAL VideoCtrl_VsyncComplete : STD_LOGIC := '0';
    SIGNAL VideoCtrl_LineBufferIndex : STD_LOGIC := '0';
    SIGNAL VideoCtrl_VgaPllLocked : STD_LOGIC := '1';
    SIGNAL VideoCtrl_VgaBusy : STD_LOGIC_VECTOR (1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaStoreNumStart : unsigned (1 DOWNTO 0) := "00";
    SIGNAL VideoCtrl_VgaState : VGA_STATE_T := VGA_WAIT_SDRAM_SWITCH;
    SIGNAL VideoCtrl_VgaNextState : VGA_STATE_T := VGA_STORE_WALL;
    SIGNAL VideoCtrl_ColorValue : ColorWriteValue_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_VgaWriteEn : ColorWrEn_t := (OTHERS => '0');
    SIGNAL VideoCtrl_WriteAddress : ColorWriteAddress_t := (OTHERS => (OTHERS => '0'));

    -- VideoCtlr state machine
    SIGNAL VideoCtrl_DataHandlerState : DATAHANDLER_STATE_T := WAIT_DATAHANDLER_READY;
    SIGNAL VideoCtrl_DataHandlerNextState : DATAHANDLER_STATE_T := HANDLE_ONE_TWO;

    -- Communication between Sdrams clock and Vga clock
    -- VGA WRITE Communication signals
    SIGNAL VideoCtrl_VgaStart_n : STD_LOGIC := '1';
    -- SDRAM communication SIGNALS
    SIGNAL VideoCtrl_SdRamStartStoreWall : STD_LOGIC := '0';
    SIGNAL VideoCtrl_VgaWallStoredFlagEnd : STD_LOGIC := '1';
    SIGNAL VideoCtrl_SdRamXstart : unsigned(6 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamXend : unsigned(6 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamYend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamType : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamAckn : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamAngleStep : unsigned(5 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamRed : unsigned(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamGreen : unsigned(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamBlue : unsigned(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaStartOutput_n : STD_LOGIC := '1';
    SIGNAL VideoCtrl_LineBufferIndexOutput : STD_LOGIC := '0';
    SIGNAL VideoCtrl_y_axisInput : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_HsyncCompleteInput : STD_LOGIC := '0';

    --SYNC COMMUNICATION SIGNALS
    SIGNAL VideoCtrl_Sync1VgaStart_n : STD_LOGIC := '1';
    SIGNAL VideoCtrl_Sync2VgaStart_n : STD_LOGIC := '1';

    SIGNAL VideoCtrl_Sync1LineBufferIndex : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Sync2LineBufferIndex : STD_LOGIC := '0';

    SIGNAL VideoCtrl_y_axisSync1 : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_y_axisSync2 : unsigned(9 DOWNTO 0) := (OTHERS => '0');

    SIGNAL VideoCtrl_Sync1HsyncComplete : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Sync2HsyncComplete : STD_LOGIC := '0';

    SIGNAL VideoCtrl_Sync1VgaStart_n_prev : STD_LOGIC := '1';
    SIGNAL VideoCtrl_LineBufferIndex_prev : STD_LOGIC := '0';
BEGIN

    DataHandler : ENTITY work.DataHandler(rtl)
        PORT MAP
        (
            DataHandler_Reset => VideoCtrl_Reset,
            -- Clocks
            DataHandler_ActlClk => VideoCtrl_ActlClk,
            DataHandler_SdRamClk => VideoCtrl_SdRamClk,
            DataHandler_GlobalClk => VideoCtrl_GlobalClk,
            DataHandler_PllLocked => VideoCtrl_SdRamPllLocked,
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
            -- SPI PINS
            DataHandler_SpiClk => VideoCtrl_SpiClk,
            DataHandler_So => VideoCtrl_So,
            DataHandler_Si => VideoCtrl_Si,
            DataHandler_Cs => VideoCtrl_Cs,
            DataHandler_SpiReady => VideoCtrl_SpiReady,
            -- SPI DATA
            DataHandler_Xaxis => VideoCtrl_Xaxis,
            DataHandler_Yaxis => VideoCtrl_Yaxis,
            DataHandler_Type => VideoCtrl_Type,
            DataHandler_Ackn => VideoCtrl_Ackn,
            DataHandler_AngleStep => VideoCtrl_AngleStep,
            DataHandler_Resolution => VideoCtrl_Resolution,
            DataHandler_Color => VideoCtrl_Color,
            DataHandler_Finish => VideoCtrl_DataHandlerFinish,
            DataHandler_Start => VideoCtrl_DataHandlerStart,
            DataHandler_SpiWordsReg => VideoCtrl_SpiWordsReg
        );

    Vga : ENTITY work.Vga(rtl)
        PORT MAP
        (
            Reset => VideoCtrl_Reset,
            StartSignal_n => VideoCtrl_VgaStart_n,
            ColorClk => VideoCtrl_ColorClk,
            ExtClock => VideoCtrl_SdRamClk,
            HsyncClk => VideoCtrl_HsyncClk,
            VsyncClk => VideoCtrl_VsyncClk,
            R => VideoCtrl_R,
            G => VideoCtrl_G,
            B => VideoCtrl_B,
            ColorWrite => VideoCtrl_ColorValue,
            WriteEn => VideoCtrl_VgaWriteEn,
            ColorWriteAddress => VideoCtrl_WriteAddress,
            y_axis => VideoCtrl_y_axis,
            HsyncComplete => VideoCtrl_HsyncComplete,
            VsyncComplete => VideoCtrl_VsyncComplete,
            LineBufferIndex => VideoCtrl_LineBufferIndex,
            PllLocked => VideoCtrl_SdRamPllLocked
        );
    -- SdRam Reset Sync signal handler process
    PROCESS (VideoCtrl_Reset, VideoCtrl_SdRamClk, VideoCtrl_SdRamPllLocked) IS
    BEGIN
        IF (VideoCtrl_Reset = '1') THEN
            VideoCtrl_SdRamReset_Sync <= '1';
        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_SdRamPllLocked = '1' THEN
            VideoCtrl_SdRamReset_Sync <= '0';
        END IF;
    END PROCESS;

    -- Vga Reset Sync signal handler process
    PROCESS (VideoCtrl_Reset, VideoCtrl_ColorClk, VideoCtrl_SdRamPllLocked) IS
    BEGIN
        IF (VideoCtrl_Reset = '1') THEN
            VideoCtrl_VgaResetSync <= '1';
        ELSIF rising_edge(VideoCtrl_ColorClk) AND VideoCtrl_SdRamPllLocked = '1' THEN
            VideoCtrl_VgaResetSync <= '0';
        END IF;
    END PROCESS;
    -- SdRam -> Vga Com
    PROCESS (VideoCtrl_Reset, VideoCtrl_SdRamPllLocked, VideoCtrl_ColorClk)
    BEGIN
        IF rising_edge(VideoCtrl_ColorClk) THEN
            -- ASSIGN SYNC1 SIGNALS
            VideoCtrl_Sync1LineBufferIndex <= VideoCtrl_LineBufferIndexOutput;
            VideoCtrl_Sync2LineBufferIndex <= VideoCtrl_Sync1LineBufferIndex;
            IF (VideoCtrl_LineBufferIndex_prev /= VideoCtrl_Sync2LineBufferIndex) THEN
                VideoCtrl_LineBufferIndex_prev <= VideoCtrl_Sync2LineBufferIndex;
                VideoCtrl_LineBufferIndex <= VideoCtrl_Sync2LineBufferIndex;
            END IF;

            VideoCtrl_Sync1VgaStart_n <= VideoCtrl_VgaStartOutput_n;
            VideoCtrl_Sync2VgaStart_n <= VideoCtrl_Sync1VgaStart_n;
            VideoCtrl_VgaStart_n <= VideoCtrl_Sync2VgaStart_n;
        END IF;
    END PROCESS;

    -- DataHandler Main process, here we read data from Spi after the initialization of SdRam
    -- Then we decide what type of data is, we change the signals which are used as connection with Vga
    -- Then we enable the handling of data from the vga process
    PROCESS (VideoCtrl_Reset, VideoCtrl_SdRamPllLocked, VideoCtrl_SdRamClk) IS
    BEGIN
        IF (VideoCtrl_Reset = '1') THEN
            VideoCtrl_DataHandlerState <= WAIT_DATAHANDLER_READY;
            VideoCtrl_DataHandlerNextState <= HANDLE_ONE_TWO;
            VideoCtrl_SdRamStartStoreWall <= '0';
            VideoCtrl_SdRamXstart <= (OTHERS => '0');
            VideoCtrl_SdRamXend <= (OTHERS => '0');
            VideoCtrl_SdRamYend <= (OTHERS => '0');
            VideoCtrl_SdRamType <= (OTHERS => '0');
            VideoCtrl_SdRamAckn <= (OTHERS => '0');
            VideoCtrl_SdRamAngleStep <= (OTHERS => '0');
            VideoCtrl_SdRamRed <= (OTHERS => '0');
            VideoCtrl_SdRamGreen <= (OTHERS => '0');
            VideoCtrl_SdRamBlue <= (OTHERS => '0');
            VideoCtrl_DataHandlerStart <= '0';
            VideoCtrl_DataHandlerFinish_reg <= '0';
        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_SdRamPllLocked = '1' THEN
            CASE VideoCtrl_DataHandlerState IS
                WHEN WAIT_DATAHANDLER_READY =>
                    IF (VideoCtrl_DataHandlerFinish_reg = '1') THEN
                        VideoCtrl_DataHandlerState <= HANDLE_ONE_TWO;
                    ELSE
                        VideoCtrl_DataHandlerFinish_reg <= VideoCtrl_DataHandlerFinish;
                    END IF;

                WHEN HANDLE_ONE_TWO =>
                    IF (VideoCtrl_VgaWallStoredFlagEnd = '1') THEN -- HERE WE START ONLY WHEN THE VGA IS READY TO GET DATA                
                        IF ((VideoCtrl_Yaxis(1) > VideoCtrl_Yaxis(0))) THEN -- Linebuffer shall be fulled with the same color
                            VideoCtrl_SdRamXstart <= RESIZE(unsigned(VideoCtrl_Xaxis(0)), 7);
                            VideoCtrl_SdRamXend <= RESIZE(x"64", 7); -- Set the end to be maximum
                            VideoCtrl_SdRamYend <= RESIZE(unsigned(VideoCtrl_Yaxis(1)) SLL 2, 10) + RESIZE(unsigned(VideoCtrl_Yaxis(1)) SLL 1, 10);
                            VideoCtrl_SdRamRed <= unsigned(VideoCtrl_Color(0)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(0));
                            VideoCtrl_SdRamGreen <= unsigned(VideoCtrl_Color(0)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(0));
                            VideoCtrl_SdRamBlue <= unsigned(VideoCtrl_Color(0)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(0));
                            VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                            VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                            VideoCtrl_SdRamAngleStep <= unsigned(VideoCtrl_AngleStep(0));

                            -- Tell to vga that all thats all folks, SEE YA NEXT LINE
                        ELSIF (VideoCtrl_Yaxis(1) < VideoCtrl_Yaxis(0)) THEN -- HERE WE ARE TALKING ABOUT THE SAME LINE NEW IMAGE
                            VideoCtrl_SdRamXstart <= RESIZE(unsigned(VideoCtrl_Xaxis(0)), 7); --shift 3 times (0- 100)
                            VideoCtrl_SdRamXend <= RESIZE(x"64", 7); -- Set the end to be maximum
                            VideoCtrl_SdRamYend <= RESIZE(X"257", 10);
                            VideoCtrl_SdRamRed <= unsigned(VideoCtrl_Color(0)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(0));
                            VideoCtrl_SdRamGreen <= unsigned(VideoCtrl_Color(0)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(0));
                            VideoCtrl_SdRamBlue <= unsigned(VideoCtrl_Color(0)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(0));
                            VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                            VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                            VideoCtrl_SdRamAngleStep <= unsigned(VideoCtrl_AngleStep(0));
                            -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE

                        ELSE
                            IF (VideoCtrl_Xaxis(1) <= VideoCtrl_Xaxis(0)) THEN
                                VideoCtrl_SdRamXstart <= RESIZE(unsigned(VideoCtrl_Xaxis(0)), 7); --shift 3 times (0- 100) (0 -- 800)
                                VideoCtrl_SdRamXend <= RESIZE(x"64", 7); -- Set the end to be maximum
                                VideoCtrl_SdRamYend <= RESIZE(X"257", 10);
                                VideoCtrl_SdRamRed <= unsigned(VideoCtrl_Color(0)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(0));
                                VideoCtrl_SdRamGreen <= unsigned(VideoCtrl_Color(0)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(0));
                                VideoCtrl_SdRamBlue <= unsigned(VideoCtrl_Color(0)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(0));
                                VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                                VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                                VideoCtrl_SdRamAngleStep <= unsigned(VideoCtrl_AngleStep(0));
                                -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE

                            ELSE
                                VideoCtrl_SdRamXstart <= RESIZE(unsigned(VideoCtrl_Xaxis(0)), 7); --shift 3 times (0- 100) (0 -- 800)
                                VideoCtrl_SdRamXend <= RESIZE(unsigned(VideoCtrl_Xaxis(1)) - 1, 7); -- Set the end to be removal
                                VideoCtrl_SdRamYend <= RESIZE(unsigned(VideoCtrl_Yaxis(0)) SLL 2, 10) + RESIZE(unsigned(VideoCtrl_Yaxis(0)) SLL 1, 10);
                                VideoCtrl_SdRamRed <= unsigned(VideoCtrl_Color(0)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(0));
                                VideoCtrl_SdRamGreen <= unsigned(VideoCtrl_Color(0)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(0));
                                VideoCtrl_SdRamBlue <= unsigned(VideoCtrl_Color(0)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(0));
                                VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                                VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                                VideoCtrl_SdRamAngleStep <= unsigned(VideoCtrl_AngleStep(0));
                            END IF;

                        END IF;
                        VideoCtrl_DataHandlerNextState <= HANDLE_TWO_THREE;
                        -- START THE READ ON THE VGA
                        VideoCtrl_SdRamStartStoreWall <= '1';
                        VideoCtrl_DataHandlerState <= WAIT_VGA_STARTREAD;
                    END IF;
                WHEN HANDLE_TWO_THREE =>
                    IF (VideoCtrl_VgaWallStoredFlagEnd = '1') THEN -- HERE WE START ONLY WHEN THE VGA IS READY TO GET DATA                
                        IF ((VideoCtrl_Yaxis(0) > VideoCtrl_Ybuffer)) THEN -- Linebuffer shall be fulled with the same color
                            VideoCtrl_SdRamXend <= RESIZE(x"64", 7); -- Set the end to be maximum
                            VideoCtrl_SdRamYend <= RESIZE(unsigned(VideoCtrl_Yaxis(0)) SLL 2, 10) + RESIZE(unsigned(VideoCtrl_Yaxis(0)) SLL 1, 10);
                            -- Tell to vga that all thats all folks, SEE YA NEXT LINE
                        ELSIF (VideoCtrl_Yaxis(0) < VideoCtrl_Ybuffer) THEN-- HERE WE ARE TALKING ABOUT THE SAME LINE NEW IMAGE
                            VideoCtrl_SdRamXend <= RESIZE(x"64", 7); -- Set the end to be maximum
                            VideoCtrl_SdRamYend <= RESIZE(X"257", 10);
                            -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE
                        ELSE
                            IF (VideoCtrl_Xaxis(0) <= VideoCtrl_Xbuffer) THEN
                                VideoCtrl_SdRamXend <= RESIZE(x"64", 7); -- Set the end to be maximum
                                VideoCtrl_SdRamYend <= RESIZE(X"257", 10);
                                -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE

                            ELSE
                                VideoCtrl_SdRamXend <= RESIZE(unsigned(VideoCtrl_Xaxis(0)) - 1, 7); -- Set the end to be removal
                                VideoCtrl_SdRamYend <= RESIZE(unsigned(VideoCtrl_Ybuffer) SLL 2, 10) + RESIZE(unsigned(VideoCtrl_Ybuffer) SLL 1, 10);
                            END IF;
                        END IF;

                        VideoCtrl_DataHandlerNextState <= HANDLE_ONE_TWO;
                        -- START THE READ ON THE VGA
                        VideoCtrl_SdRamStartStoreWall <= '1';
                        VideoCtrl_DataHandlerState <= WAIT_VGA_STARTREAD;
                    END IF;

                WHEN WAIT_VGA_STARTREAD =>
                    IF (VideoCtrl_VgaWallStoredFlagEnd = '0') THEN
                        VideoCtrl_SdRamStartStoreWall <= '0'; -- STOP TO AVOID REPETITION FOR NO REASON
                        -- HERE WE HAVE TO RESTART THE READ PROCEDURE FROM THE DATA HANDLER
                        -- FOR NOW WE STORE THE SECOND DATA TO THE SDRAM COMMUNICATION SIGNALS THEY ARE NOT UPDATED
                        -- ON VGA PART BECAUSE THE VGA HAS STARTED THE READ OPERATION
                        IF (VideoCtrl_DataHandlerNextState = HANDLE_TWO_THREE) THEN
                            VideoCtrl_Xbuffer <= VideoCtrl_Xaxis(1);
                            VideoCtrl_Ybuffer <= VideoCtrl_Yaxis(1);

                            -- these are not changed on two three
                            VideoCtrl_SdRamXstart <= RESIZE(unsigned(VideoCtrl_Xaxis(1)), 7); --shift 3 times (0- 100) (0 -- 800)
                            VideoCtrl_SdRamRed <= unsigned(VideoCtrl_Color(1)(23 DOWNTO 16)) * unsigned(VideoCtrl_Resolution(1));
                            VideoCtrl_SdRamGreen <= unsigned(VideoCtrl_Color(1)(15 DOWNTO 8)) * unsigned(VideoCtrl_Resolution(1));
                            VideoCtrl_SdRamBlue <= unsigned(VideoCtrl_Color(1)(7 DOWNTO 0)) * unsigned(VideoCtrl_Resolution(1));
                            VideoCtrl_SdRamType <= VideoCtrl_Type(1);
                            VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(1);

                            VideoCtrl_SdRamAngleStep <= unsigned(VideoCtrl_AngleStep(1));

                            -- RESTART THE DATAHANDLER
                            VideoCtrl_DataHandlerStart <= '1';
                            VideoCtrl_DataHandlerState <= WAIT_DATAHANDLER_RESTART;
                        ELSE
                            VideoCtrl_DataHandlerState <= HANDLE_ONE_TWO;
                        END IF;
                    END IF;

                WHEN WAIT_DATAHANDLER_RESTART =>
                    IF (VideoCtrl_DataHandlerFinish_reg = '0') THEN
                        VideoCtrl_DataHandlerStart <= '0'; -- STOP FALSE REPEAT OF THE DATAHANDLER
                        VideoCtrl_DataHandlerState <= WAIT_DATAHANDLER_FINISH;
                    ELSE
                        VideoCtrl_DataHandlerFinish_reg <= VideoCtrl_DataHandlerFinish;
                    END IF;

                WHEN WAIT_DATAHANDLER_FINISH =>
                    IF (VideoCtrl_DataHandlerFinish_reg = '1') THEN
                        VideoCtrl_DataHandlerState <= HANDLE_TWO_THREE;
                    ELSE
                        VideoCtrl_DataHandlerFinish_reg <= VideoCtrl_DataHandlerFinish;
                    END IF;

                WHEN OTHERS => NULL;
            END CASE;
        END IF;
    END PROCESS;

    -- Vga Main process, here we take the data from the DataHandler main process
    -- Data are handled here and stored in the linebuffer, Vga works in parallel
    -- This process checks the vga state and updates the data
    PROCESS (VideoCtrl_Reset, VideoCtrl_SdRamPllLocked, VideoCtrl_SdRamClk) IS
        VARIABLE VgaBufferIndex : unsigned(6 DOWNTO 0) := "0000000";
        VARIABLE angle_var : unsigned(5 DOWNTO 0);
        VARIABLE VgaLineBufferIndexNext : unsigned(0 DOWNTO 0) := (OTHERS => '0');
        VARIABLE VgaYend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
        VARIABLE VgaRed : unsigned(7 DOWNTO 0) := (OTHERS => '0');
        VARIABLE VgaGreen : unsigned(7 DOWNTO 0) := (OTHERS => '0');
        VARIABLE VgaBlue : unsigned(7 DOWNTO 0) := (OTHERS => '0');
        VARIABLE VgaXstart : unsigned(6 DOWNTO 0) := (OTHERS => '0');
        VARIABLE VgaXend : unsigned(6 DOWNTO 0) := (OTHERS => '0');
        VARIABLE VgaYaxis : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        IF (VideoCtrl_Reset = '1') THEN
            VideoCtrl_VgaWallStoredFlagEnd <= '1';
            VideoCtrl_VgaState <= VGA_WAIT_SDRAM_SWITCH;
            VideoCtrl_VgaNextState <= VGA_STORE_WALL;
            VideoCtrl_VgaBusy <= (OTHERS => '0');
            VideoCtrl_VgaStoreNumStart <= "00";
            VideoCtrl_LineBufferIndexOutput <= '0';
            VideoCtrl_VgaWriteEn <= (OTHERS => '0');
            VideoCtrl_VgaStartOutput_n <= '1';
            -- Reset Vga Input Signals
        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_SdRamPllLocked = '1' THEN
            CASE VideoCtrl_VgaState IS
                WHEN VGA_WAIT_SDRAM_SWITCH =>
                    IF (VideoCtrl_SdRamStartStoreWall = '1') THEN
                        VgaXstart := VideoCtrl_SdRamXstart;
                        VgaXend := VideoCtrl_SdRamXend;
                        VgaYend := VideoCtrl_SdRamYend;
                        VgaRed := resize(VideoCtrl_SdRamRed(15 DOWNTO 8), 8);
                        VgaGreen := resize(VideoCtrl_SdRamGreen(15 DOWNTO 8), 8);
                        VgaBlue := resize(VideoCtrl_SdRamBlue(15 DOWNTO 8), 8);
                        IF VideoCtrl_SdRamType = "011" THEN
                            angle_var := ANGLESTEP_MAX_U5 - VideoCtrl_SdRamAngleStep + 1;
                            IF (VideoCtrl_SdRamXend /= "0000000") THEN
                                VideoCtrl_VgaNextState <= START_ADD_ANGLE_STEP;
                                VgaBufferIndex := "0000001";
                                VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= (OTHERS => '0');
                                VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '1';
                                VideoCtrl_VgaWallStoredFlagEnd <= '0';
                                VideoCtrl_VgaState <= VGA_STORE_ZEROS;
                            ELSE
                                VgaBufferIndex := VideoCtrl_SdRamXstart + 1;
                                VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VideoCtrl_SdRamXstart);
                                VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '1';
                                VideoCtrl_VgaWallStoredFlagEnd <= '0';
                                VideoCtrl_VgaState <= START_ADD_ANGLE_STEP;
                            END IF;
                        ELSIF VideoCtrl_SdRamType = "010" THEN
                            angle_var := VideoCtrl_SdRamAngleStep;
                            IF (VideoCtrl_SdRamXend /= "0000000") THEN
                                VideoCtrl_VgaNextState <= START_REMOVE_ANGLE_STEP;
                                VgaBufferIndex := "0000001";
                                VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= (OTHERS => '0');
                                VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '1';
                                VideoCtrl_VgaWallStoredFlagEnd <= '0';
                                VideoCtrl_VgaState <= VGA_STORE_ZEROS;
                            ELSE
                                VgaBufferIndex := VideoCtrl_SdRamXstart + 1;
                                VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VideoCtrl_SdRamXstart);
                                VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '1';
                                VideoCtrl_VgaWallStoredFlagEnd <= '0';
                                VideoCtrl_VgaState <= START_REMOVE_ANGLE_STEP;
                            END IF;
                        ELSE
                            IF (VideoCtrl_SdRamXend /= "0000000") THEN
                                VideoCtrl_VgaNextState <= VGA_STORE_WALL;
                                VgaBufferIndex := "0000001";
                                VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= (OTHERS => '0');
                                VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '1';
                                VideoCtrl_VgaWallStoredFlagEnd <= '0';
                                VideoCtrl_VgaState <= VGA_STORE_ZEROS;
                            ELSE
                                VgaBufferIndex := VideoCtrl_SdRamXstart + 1;
                                VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VideoCtrl_SdRamXstart);
                                VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '1';
                                VideoCtrl_VgaWallStoredFlagEnd <= '0';
                                VideoCtrl_VgaState <= VGA_STORE_WALL;
                            END IF;
                        END IF;
                    END IF;

                WHEN VGA_WAIT_SDRAM =>
                    IF (VideoCtrl_SdRamStartStoreWall = '1') THEN
                        VgaBufferIndex := VideoCtrl_SdRamXstart + 1;
                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VideoCtrl_SdRamXstart);
                        VgaXend := VideoCtrl_SdRamXend;
                        VgaYend := VideoCtrl_SdRamYend;
                        VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '1';
                        VgaRed := resize(VideoCtrl_SdRamRed(15 DOWNTO 8), 8);
                        VgaGreen := resize(VideoCtrl_SdRamGreen(15 DOWNTO 8), 8);
                        VgaBlue := resize(VideoCtrl_SdRamBlue(15 DOWNTO 8), 8);
                        IF VideoCtrl_SdRamType = "011" THEN
                            angle_var := ANGLESTEP_MAX_U5 - VideoCtrl_SdRamAngleStep + 1;
                            VideoCtrl_VgaWallStoredFlagEnd <= '0';
                            VideoCtrl_VgaState <= START_ADD_ANGLE_STEP;
                        ELSIF VideoCtrl_SdRamType = "010" THEN
                            angle_var := VideoCtrl_SdRamAngleStep;
                            VideoCtrl_VgaWallStoredFlagEnd <= '0';
                            VideoCtrl_VgaState <= START_REMOVE_ANGLE_STEP;
                        ELSE
                            VideoCtrl_VgaWallStoredFlagEnd <= '0';
                            VideoCtrl_VgaState <= VGA_STORE_WALL;
                        END IF;
                    END IF;

                WHEN VGA_STORE_ZEROS =>
                    IF (VgaBufferIndex >= VgaXStart) THEN
                        VgaBufferIndex := VgaXstart + 1;
                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VgaXstart);
                        VideoCtrl_VgaState <= VideoCtrl_VgaNextState;
                    ELSE
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        <= (OTHERS => '0');
                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VgaBufferIndex);
                        VgaBufferIndex := VgaBufferIndex + 1;
                    END IF;

                WHEN VGA_STORE_WALL =>
                    IF (VgaBufferIndex >= x"64") THEN
                        VideoCtrl_VgaBusy(to_integer(VgaLineBufferIndexNext)) <= '1';
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        <= STD_LOGIC_VECTOR(VgaRed & VgaGreen & VgaBlue);
                        VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '0';
                        VideoCtrl_VgaState <= VGA_SWITCH_BUFFER;
                    ELSIF (VgaBufferIndex >= (VgaXend + 1)) THEN
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        <= STD_LOGIC_VECTOR(VgaRed & VgaGreen & VgaBlue);
                        VideoCtrl_VgaWallStoredFlagEnd <= '1';
                        VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '0';
                        VideoCtrl_VgaState <= VGA_WAIT_SDRAM;
                    ELSE
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        <= STD_LOGIC_VECTOR(VgaRed & VgaGreen & VgaBlue);
                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VgaBufferIndex);
                        VgaBufferIndex := VgaBufferIndex + 1;
                    END IF;

                WHEN START_REMOVE_ANGLE_STEP =>
                    IF (VgaBufferIndex >= x"64") THEN
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(VgaRed - angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(VgaGreen - angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(VgaBlue - angle_var, 8));

                        VideoCtrl_VgaBusy(to_integer(VgaLineBufferIndexNext)) <= '1';
                        VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '0';
                        VideoCtrl_VgaState <= VGA_SWITCH_BUFFER;
                    ELSIF (VgaBufferIndex >= (VgaXend + 1)) THEN
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(VgaRed - angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(VgaGreen - angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(VgaBlue - angle_var, 8));

                        VideoCtrl_VgaWallStoredFlagEnd <= '1';
                        VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '0';
                        VideoCtrl_VgaState <= VGA_WAIT_SDRAM;
                    ELSE
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(VgaRed - angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(VgaGreen - angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(VgaBlue - angle_var, 8));

                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VgaBufferIndex);
                        VgaBufferIndex := VgaBufferIndex + 1;

                        VgaRed := VgaRed - angle_var;

                        VgaGreen := VgaGreen - angle_var;

                        VgaBlue := VgaBlue - angle_var;

                    END IF;

                WHEN START_ADD_ANGLE_STEP =>
                    IF (VgaBufferIndex >= x"64") THEN
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(VgaRed + angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(VgaGreen + angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(VgaBlue + angle_var, 8));

                        VideoCtrl_VgaBusy(to_integer(VgaLineBufferIndexNext)) <= '1';
                        VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '0';
                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= (OTHERS => '0');
                        VideoCtrl_VgaState <= VGA_SWITCH_BUFFER;
                    ELSIF (VgaBufferIndex >= (VgaXend + 1)) THEN
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(VgaRed + angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(VgaGreen + angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(VgaBlue + angle_var, 8));

                        VideoCtrl_VgaWallStoredFlagEnd <= '1';
                        VideoCtrl_VgaWriteEn(to_integer(VgaLineBufferIndexNext)) <= '0';
                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= (OTHERS => '0');
                        VideoCtrl_VgaState <= VGA_WAIT_SDRAM;
                    ELSE
                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (23 DOWNTO 16) <= STD_LOGIC_VECTOR(resize(VgaRed + angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (15 DOWNTO 8) <= STD_LOGIC_VECTOR(resize(VgaGreen + angle_var, 8));

                        VideoCtrl_ColorValue(to_integer(VgaLineBufferIndexNext))
                        (7 DOWNTO 0) <= STD_LOGIC_VECTOR(resize(VgaBlue + angle_var, 8));

                        VideoCtrl_WriteAddress(to_integer(VgaLineBufferIndexNext)) <= STD_LOGIC_VECTOR(VgaBufferIndex);
                        VgaBufferIndex := VgaBufferIndex + 1;
                        VgaRed := VgaRed + angle_var;

                        VgaGreen := VgaGreen + angle_var;

                        VgaBlue := VgaBlue + angle_var;

                    END IF;

                WHEN VGA_SWITCH_BUFFER =>
                    IF (VideoCtrl_VgaStoreNumStart >= x"2") THEN
                        -- HERE AGAIN WE SHOULD CHECK
                        IF VideoCtrl_VgaBusy(to_integer(NOT VgaLineBufferIndexNext)) = '1' THEN -- THERE IS NO DATA AVAILABLE TO BE HANDLED
                            VideoCtrl_VgaBusy(to_integer(VgaLineBufferIndexNext)) <= '1';
                            VideoCtrl_VgaState <= VGA_WAIT_LINE_FREE;
                        ELSE
                            VideoCtrl_VgaBusy(to_integer(VgaLineBufferIndexNext)) <= '1';
                            VgaLineBufferIndexNext := NOT VgaLineBufferIndexNext;
                            VideoCtrl_VgaWallStoredFlagEnd <= '1';
                            VideoCtrl_VgaState <= VGA_WAIT_SDRAM_SWITCH;
                        END IF;

                    ELSIF (VideoCtrl_VgaStoreNumStart = x"1") THEN
                        -- START THE VGA AND BLOCK THE COMMUNICATION TILL AT LEAST ONE LINE BUFFER IS READY
                        -- HERE WE MAY HAVE A COMPLETELY DIFFERENT STATE MACHINE
                        VideoCtrl_VgaStoreNumStart <= VideoCtrl_VgaStoreNumStart + 1;
                        VideoCtrl_VgaBusy(to_integer(VgaLineBufferIndexNext)) <= '1';
                        VideoCtrl_VgaWallStoredFlagEnd <= '1';
                        VideoCtrl_VgaStartOutput_n <= '0';
                        VideoCtrl_VgaState <= VGA_WAIT_LINE_FREE;
                    ELSE
                        VideoCtrl_VgaStoreNumStart <= VideoCtrl_VgaStoreNumStart + 1;
                        VideoCtrl_VgaBusy(to_integer(VgaLineBufferIndexNext)) <= '1';
                        VgaLineBufferIndexNext := NOT VgaLineBufferIndexNext;
                        VideoCtrl_VgaWallStoredFlagEnd <= '1';
                        VideoCtrl_VgaState <= VGA_WAIT_SDRAM_SWITCH;
                    END IF;

                WHEN VGA_WAIT_LINE_FREE =>
                    IF ((VideoCtrl_HsyncComplete = '1') AND (VideoCtrl_y_axis = VgaYend)) THEN
                        -- UPDATE FOR THE NEXT Y THAT EXISTS
                        --TAKE THE YEND OF THE FREE SIGNAL
                        IF VgaLineBufferIndexNext = "1" THEN
                            VideoCtrl_LineBufferIndexOutput <= '1';
                        ELSE
                            VideoCtrl_LineBufferIndexOutput <= '0';
                        END IF;
                        VideoCtrl_VgaBusy(to_integer(NOT VgaLineBufferIndexNext)) <= '0';
                        VgaLineBufferIndexNext := NOT VgaLineBufferIndexNext;
                        VideoCtrl_VgaWallStoredFlagEnd <= '1';
                        VideoCtrl_VgaState <= VGA_WAIT_SDRAM_SWITCH;
                    ELSIF (VideoCtrl_y_axis > VgaYend) THEN
                        VideoCtrl_VgaState <= VGA_VSYNC_WAIT;
                    END IF;

                WHEN VGA_VSYNC_WAIT =>
                    IF (VideoCtrl_VsyncComplete = '1') THEN
                        VideoCtrl_VgaState <= VGA_VSYNC_RESTART;
                    END IF;

                WHEN VGA_VSYNC_RESTART =>
                    IF (VideoCtrl_VsyncComplete = '0' AND VideoCtrl_y_axis = "000000000") THEN
                        VideoCtrl_VgaState <= VGA_WAIT_LINE_FREE;
                    END IF;

                WHEN OTHERS => NULL;
            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE;