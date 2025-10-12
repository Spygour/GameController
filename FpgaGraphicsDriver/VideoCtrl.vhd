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

    -- Datahandler state type
    SUBTYPE  DATAHANDLER_STATE_T unsigned(7 downto 0);
    -- Datahandler constant values
    CONSTANT WAIT_DATAHANDLER_READY :  DATAHANDLER_STATE_T  := x"00";
    CONSTANT HANDLE_ONE_TWO : DATAHANDLER_STATE_T           := x"01"; -- REVERSE THE NEXT STATE
    CONSTANT HANDLE_TWO_THREE : DATAHANDLER_STATE_T         := x"FE"; -- REVERSE THE NEXT STATE
    CONSTANT WAIT_VGA_STARTREAD : DATAHANDLER_STATE_T       := X"02";
    CONSTANT WAIT_VGA_READ  : DATAHANDLER_STATE_T           := x"03";
    CONSTANT WAIT_DATAHANDLER_RESTART : DATAHANDLER_STATE_T := x"04";
    CONSTANT WAIT_DATAHANDLER_FINISH : DATAHANDLER_STATE_T  := x"05";
    CONSTANT HANDLE_TWO_THREE : DATAHANDLER_STATE_T         := x"06";

    SIGNAL VideoCtrl_SdRamClk : STD_LOGIC := '0';
    SIGNAL VideoCtrl_GlobalClk : STD_LOGIC := '0';
    SIGNAL VideoCtrl_SdRamPllLocked : STD_LOGIC := '0';
    SIGNAL VideoCtrl_ReadDataFinish : STD_LOGIC := '1';
    SIGNAL VideoCtrl_DataHanlderStart : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Xaxis : Data_Xaxis_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Yaxis : Data_Yaxis_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Xbuffer : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Ybuffer  : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Type : Data_Type_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Ackn : Data_Ackn_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_AngleStep : Data_AngleStep_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Idx : DataPart_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Resolution : Data_Resolution_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_Color : DataColor_t := (OTHERS => (OTHERS => '0'));
    SIGNAL VideoCtrl_SpiWordsReg : INTEGER := 0;
    SIGNAL VideoCtrl_DataAvailable : STD_LOGIC := '0';
    SIGNAL VideoCtrl_SdRamReset_Sync : STD_LOGIC := '0';
    -- Vga Signals
    SIGNAL VideoCtrl_ColorClk : STD_LOGIC := '0';
    SIGNAL VideoCtrl_HsyncClk : STD_LOGIC := '1';
    SIGNAL VideoCtrl_VsyncClk : STD_LOGIC := '1';
    SIGNAL VideoCtrl_R : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_G : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_B : STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_LineBuffer : LineBuffer_t := (OTHERS => (OTHERS => (OTHERS => '0')));
    SIGNAL VideoCtrl_x_axis : unsigned (9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_y_axis : unsigned (9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_HsyncComplete : STD_LOGIC := '0';
    SIGNAL VideoCtrl_VsyncComplete : STD_LOGIC := '0';
    SIGNAL VideoCtrl_LineBufferIndex : INTEGER := 0;
    SIGNAL VideoCtrl_VgaPllLocked : STD_LOGIC := '1';

    -- VideoCtlr state machine
    SIGNAL VideoCtrl_Counter : INTEGER := 0;
    SIGNAL VideoCtrl_DataHandlerState : DATAHANDLER_STATE_T := WAIT_DATAHANDLER_READY;
    SIGNAL VideoCtrl_DataHandlerNextState : DATAHANDLER_STATE_T := HANDLE_ONE_TWO;

    -- Communication between Sdrams clock and Vga clock
    -- VGA Communication signals
    SIGNAL VideoCtrl_VgaStart_n : STD_LOGIC := '1';
    SIGNAL VideoCtrl_VgaStartStoreWall : STD_LOGIC := '0';
    SIGNAL VideoCtrl_VgaWallStoredFlagEnd : STD_LOGIC := '1';
    SIGNAL VideoCtrl_VgaXstart : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaXend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaYend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaType : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaAckn : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaAngleStep : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaResolution :  STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_VgaColor : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');

    -- SYNC1 SIGNALS
    SIGNAL VideoCtrl_Sync1StartStoreWall : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Sync1WallStoredFlagEnd : STD_LOGIC := '1';
    SIGNAL VideoCtrl_Sync1Xstart : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync1Xend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync1Yend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync1Type : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync1Ackn : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync1AngleStep : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0);
    SIGNAL VideoCtrl_Sync1Resolution :  STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync1Color : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');

    -- SYNC1 SIGNALS

    SIGNAL VideoCtrl_Sync2StartStoreWall : STD_LOGIC := '0';
    SIGNAL VideoCtrl_Sync2WallStoredFlagEnd : STD_LOGIC := '1';
    SIGNAL VideoCtrl_Sync2Xstart : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync2Xend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync2Yend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync2Type : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync2Ackn : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync2AngleStep : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0);
    SIGNAL VideoCtrl_Sync2Resolution :  STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_Sync2Color : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');

    -- SDRAM communication SIGNALS
    SIGNAL VideoCtrl_SdRamStartStoreWall : STD_LOGIC := '0';
    SIGNAL VideoCtrl_SdRamWallStoredFlagEnd : STD_LOGIC := '1';
    SIGNAL VideoCtrl_SdRamXstart : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamXend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamYend : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamType : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamAckn : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamAngleStep : STD_LOGIC_VECTOR(5 DOWNTO 0) := (OTHERS => '0);
    SIGNAL VideoCtrl_SdRamResolution :  STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VideoCtrl_SdRamColor : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
BEGIN

    VgaPll : ENTITY work.VgaPll(SYN)
        PORT MAP
        (
            areset => VideoCtrl_Reset,
            inclk0 => VideoCtrl_ActlClk,
            c0 => VideoCtrl_ColorClk,
            locked => VideoCtrl_VgaPllLocked
        );

    SdRamPll : ENTITY work.SdRamPll(SYN)
        PORT MAP
        (
            areset => VideoCtrl_Reset,
            inclk0 => VideoCtrl_ActlClk,
            c0 => VideoCtrl_SdRamClk,
            c1 => VideoCtrl_GlobalClk,
            locked => VideoCtrl_SdRamPllLocked
        );

    DataHandler : ENTITY work.DataHandler(rtl)
        PORT MAP
        (
            DataHandler_Reset => VideoCtrl_SdRamReset_Sync,
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
            DataHandler_Finish => VideoCtrl_ReadDataFinish,
            DataHandler_Start => VideoCtrl_DataHandlerStart,
            DataHandler_SpiWordsReg => VideoCtrl_SpiWordsReg
        );

    Vga : ENTITY work.Vga(rtl)
        PORT MAP
        (
            Reset => VideoCtrl_VgaStart_n,
            ColorClk => VideoCtrl_ColorClk,
            HsyncClk => VideoCtrl_HsyncClk,
            VsyncClk => VideoCtrl_VsyncClk,
            R => VideoCtrl_R,
            G => VideoCtrl_G,
            B => VideoCtrl_B,
            LineBuffer => VideoCtrl_LineBuffer,
            x_axis => VideoCtrl_x_axis,
            y_axis => VideoCtrl_y_axis,
            HsyncComplete => VideoCtrl_HsyncComplete,
            VsyncComplete => VideoCtrl_VsyncComplete,
            LineBufferIndex => VideoCtrl_LineBufferIndex,
            PllLocked => VideoCtrl_VgaPllLocked
        );
    -- SdRam Reset Sync signal handler process
    PROCESS (VideoCtrl_Reset, VideoCtrl_SdRamPllLocked) IS
    BEGIN
        IF (VideoCtrl_Reset = '1') THEN
            VideoCtrl_SdRamReset_Sync <= '1';
        ELSIF VideoCtrl_SdRamPllLocked = '1' THEN
            VideoCtrl_SdRamReset_Sync <= '0';
        ELSE
            VideoCtrl_SdRamReset_Sync <= '1';
        END IF;
    END PROCESS;

    -- SdRam -> Vga Com
    PROCESS (VideoCtrl_Reset, VideoCtrl_VgaPllLocked, VideoCtrl_ColorClk)
    BEGIN
        IF (VideoCtrl_Reset = '1') THEN
            -- Reset Vga Input Signals
            VideoCtrl_VgaStartStoreWall  <= '0';
            VideoCtrl_VgaXstart  <= (OTHERS => '0');
            VideoCtrl_VgaXend <= (OTHERS => '0');
            VideoCtrl_VgaYend <= (OTHERS => '0');
            VideoCtrl_VgaType <= (OTHERS => '0);
            VideoCtrl_VgaAckn <= (OTHERS => '0);
            VideoCtrl_VgaAngleStep <= (OTHERS => '0);
            VideoCtrl_VgaResolution <= (OTHERS => '0');
            VideoCtrl_VgaColor <= (OTHERS => '0');
        ELSIF rising_edge(VideoCtrl_ColorClk) AND VideoCtrl_VgaPllLocked = '1' THEN
            -- ASSIGN SYNC1 SIGNALS
            VideoCtrl_Sync1Xstart          <= VideoCtrl_SdRamXstart;
            VideoCtrl_Sync1Xend            <= VideoCtrl_SdRamXend;
            VideoCtrl_Sync1Yend            <= VideoCtrl_SdRamYend;
            VideoCtrl_Sync1Type            <= VideoCtrl_SdRamType;
            VideoCtrl_Sync1Ackn            <= VideoCtrl_SdRamAckn;
            VideoCtrl_Sync1AngleStep       <= VideoCtrl_SdRamAngleStep;
            VideoCtrl_Sync1Resolution      <= VideoCtrl_SdRamResolution;
            VideoCtrl_Sync1Color           <= VideoCtrl_SdRamColor;
            VideoCtrl_Sync1StartStoreWall  <= VideoCtrl_SdRamStartStoreWall;

            -- ASSIGN SYNC2 SIGNALS
            VideoCtrl_Sync2Xstart          <= VideoCtrl_Sync1Xstart;
            VideoCtrl_Sync2Xend            <= VideoCtrl_Sync1Xend;
            VideoCtrl_Sync2Yend            <= VideoCtrl_Sync1Yend;
            VideoCtrl_Sync2Type            <= VideoCtrl_Sync1Type;
            VideoCtrl_Sync2Ackn            <= VideoCtrl_Sync1Ackn;
            VideoCtrl_Sync2AngleStep       <= VideoCtrl_Sync1AngleStep;
            VideoCtrl_Sync2Resolution      <= VideoCtrl_Sync1Resolution;
            VideoCtrl_Sync2Color           <= VideoCtrl_Sync1Color;
            VideoCtrl_Sync2StartStoreWall  <= VideoCtrl_Sync1StartStoreWall;
            
            VideoCtrl_VgaStartStoreWall  <= VideoCtrl_Sync2StartStoreWall;
            -- Assign new values only when the Vga does not handle data
            IF (VideoCtrl_VgaWallStoredFlagEnd  = '1') THEN
                VideoCtrl_VgaXstart          <= VideoCtrl_Sync2Xstart;
                VideoCtrl_VgaXend            <= VideoCtrl_Sync2Xend;
                VideoCtrl_VgaYend            <= VideoCtrl_Sync2Yend;
                VideoCtrl_VgaType            <= VideoCtrl_Sync2Type;
                VideoCtrl_VgaAckn            <= VideoCtrl_Sync2Ackn;
                VideoCtrl_VgaAngleStep       <= VideoCtrl_Sync2AngleStep;
                VideoCtrl_VgaResolution      <= VideoCtrl_Sync2Resolution;
                VideoCtrl_VgaColor           <= VideoCtrl_Sync2Color;
            END IF;
        END IF;
    END PROCESS;

    -- Vga -> SdRam Com
    PROCESS (VideoCtrl_SdRamReset_Sync, VideoCtrl_SdRamPllLocked, VideoCtrl_SdRamClk)
    BEGIN
        IF (VideoCtrl_SdRamReset_Sync = '1') THEN
            -- Reset Vga Input Signals
            VideoCtrl_SdRamWallStoredFlagEnd  <= '1';
        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_SdRamPllLocked = '1' THEN
            -- ASSIGN SYNC1 SIGNALS
            VideoCtrl_Sync1WallStoredFlagEnd    <= VideoCtrl_VgaWallStoredFlagEnd;

            -- ASSIGN SYNC2 SIGNALS
            VideoCtrl_Sync2WallStoredFlagEnd    <= VideoCtrl_Sync1WallStoredFlagEnd;
            -- Assign the actual SdRam Signals
            VideoCtrl_SdRamWallStoredFlagEnd    <= VideoCtrl_Sync2WallStoredFlagEnd;
        END IF;
    END PROCESS;

    -- DataHandler Main process, here we read data from Spi after the initialization of SdRam
    -- Then we decide what type of data is, we change the signals which are used as connection with Vga
    -- Then we enable the handling of data from the vga process
    PROCESS (VideoCtrl_SdRamClk, VideoCtrl_SdRamReset_Sync, VideoCtrl_SdRamPllLocked) IS
    BEGIN
        IF (VideoCtrl_SdRamReset_Sync = '1') THEN
            VideoCtrl_DataHandlerState     <= WAIT_DATAHANDLER_READY;
            VideoCtrl_DataHandlerNextState <= HANDLE_ONE_TWO;
            VideoCtrl_SdRamStartStoreWall <= '0';
            VideoCtrl_SdRamXstart          <= (OTHERS => '0');
            VideoCtrl_SdRamXend            <= (OTHERS => '0');
            VideoCtrl_SdRamYend            <= (OTHERS => '0');
            VideoCtrl_SdRamType            <= (OTHERS => '0');
            VideoCtrl_SdRamAckn            <= (OTHERS => '0');
            VideoCtrl_SdRamAngleStep       <= (OTHERS => '0');
            VideoCtrl_SdRamResolution      <= (OTHERS => '0');
            VideoCtrl_SdRamColor           <= (OTHERS => '0');
            VideoCtrl_SdRamVgaStart_n      <= '0';
            VideoCtrl_DataHanlderStart <= '0';
        ELSIF rising_edge(VideoCtrl_SdRamClk) AND VideoCtrl_SdRamPllLocked = '1' THEN
            CASE VideoCtrl_DataHandlerState is
                WHEN WAIT_DATAHANDLER_READY =>
                    IF (VideoCtrl_ReadDataFinish = '1') THEN
                        VideoCtrl_DataHandlerState <= HANDLE_ONE_TWO;
                    END IF;

                WHEN HANDLE_ONE_TWO =>
                    IF (VideoCtrl_SdRamWallStoredFlagEnd = '1') THEN  -- HERE WE START ONLY WHEN THE VGA IS READY TO GET DATA                
                        IF ((VideoCtrl_Yaxis(1) > VideoCtrl_Yaxis(0))) THEN  -- Linebuffer shall be fulled with the same color
                            VideoCtrl_SdRamXstart <= VideoCtrl_Xaxis(0) & "000" ; --shift 3 times (0- 100) (0 -- 800)
                            VideoCtrl_SdRamXend <=  x"320"; -- Set the end to be maximum
                            VideoCtrl_SdRamYend <= (VideoCtrl_Yaxis(1) & "00") + (VideoCtrl_Yaxis(1) & "0");
                            VideoCtrl_SdRamColor <= VideoCtrl_Color(0);
                            VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                            VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                            VideoCtrl_SdRamAngleStep <= VideoCtrl_AngleStep(0);
                            VideoCtrl_SdRamResolotuion <= VideoCtrl_Resolution(0);
                            -- Tell to vga that all thats all folks, SEE YA NEXT LINE


                        ELSIF (VideoCtrl_Yaxis(1) < VideoCtrl_Yaxis(0)) -- HERE WE ARE TALKING ABOUT THE SAME LINE NEW IMAGE
                                VideoCtrl_SdRamXstart <= VideoCtrl_Xaxis(0) & "000" ; --shift 3 times (0- 100) (0 -- 800)
                                VideoCtrl_SdRamXend <=  x"320"; -- Set the end to be maximum
                                VideoCtrl_SdRamYend <= X"258";
                                VideoCtrl_SdRamColor <= VideoCtrl_Color(0);
                                VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                                VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                                VideoCtrl_SdRamAngleStep <= VideoCtrl_AngleStep(0);
                                VideoCtrl_SdRamResolotuion <= VideoCtrl_Resolution(0);
                                -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE

                        ELSE
                            IF (VideoCtrl_Xaxis(1) <= VideoCtrl_Xaxis(0)) THEN
                                VideoCtrl_SdRamXstart <= VideoCtrl_Xaxis(0) & "000" ; --shift 3 times (0- 100) (0 -- 800)
                                VideoCtrl_SdRamXend <=  x"320"; -- Set the end to be maximum
                                VideoCtrl_SdRamYend <= X"258";
                                VideoCtrl_SdRamColor <= VideoCtrl_Color(0);
                                VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                                VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                                VideoCtrl_SdRamAngleStep <= VideoCtrl_AngleStep(0);
                                VideoCtrl_SdRamResolotuion <= VideoCtrl_Resolution(0);
                                -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE
                                
                            ELSE
                                VideoCtrl_SdRamXstart <= VideoCtrl_Xaxis(0) & "000" ; --shift 3 times (0- 100) (0 -- 800)
                                VideoCtrl_SdRamXend <=  (VideoCtrl_Xaxis(1) - '1') & "000"; -- Set the end to be removal
                                VideoCtrl_SdRamYend <= (VideoCtrl_Yaxis(0) & "00") + (VideoCtrl_Yaxis(0) & "0");
                                VideoCtrl_SdRamColor <= VideoCtrl_Color(0);
                                VideoCtrl_SdRamType <= VideoCtrl_Type(0);
                                VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(0);
                                VideoCtrl_SdRamAngleStep <= VideoCtrl_AngleStep(0);
                                VideoCtrl_SdRamResolotuion <= VideoCtrl_Resolution(0);
                            END IF;

                        END IF;
                        VideoCtrl_DataHandlerNextState <= HANDLE_TWO_THREE;
                        -- START THE READ ON THE VGA
                        VideoCtrl_SdRamStartStoreWall <= '1';
                        VideoCtrl_DataHandlerState <= WAIT_VGA_STARTREAD;
                    END IF;


                WHEN HANDLE_TWO_THREE =>
                    IF (VideoCtrl_SdRamWallStoredFlagEnd = '1') THEN  -- HERE WE START ONLY WHEN THE VGA IS READY TO GET DATA                
                        IF ((VideoCtrl_Yaxis(0) > VideoCtrl_Ybuffer)) THEN  -- Linebuffer shall be fulled with the same color
                            VideoCtrl_SdRamXend <=  x"320"; -- Set the end to be maximum
                            VideoCtrl_SdRamYend <= (VideoCtrl_Yaxis(0) & "00") + (VideoCtrl_Yaxis(0) & "0");
                            -- Tell to vga that all thats all folks, SEE YA NEXT LINE


                        ELSIF (VideoCtrl_Yaxis(0) < VideoCtrl_Ybuffer) -- HERE WE ARE TALKING ABOUT THE SAME LINE NEW IMAGE
                                VideoCtrl_SdRamXend <=  x"320"; -- Set the end to be maximum
                                VideoCtrl_SdRamYend <= X"258";
                                -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE
                        ELSE
                            IF (VideoCtrl_Xaxis(0) <= VideoCtrl_Xbuffer) THEN
                                VideoCtrl_SdRamXend <=  x"320"; -- Set the end to be maximum
                                VideoCtrl_SdRamYend <= X"258";
                                -- TELL TO VGA THAT A WHOLE SCREEN IS BEEN DETECTED BY A SINGLE MESSAGE

                            ELSE
                                VideoCtrl_SdRamXend <=  (VideoCtrl_Xaxis(0) - '1') & "000"; -- Set the end to be removal
                                VideoCtrl_SdRamYend <= (VideoCtrl_Ybuffer & "00") + (VideoCtrl_Ybuffer & "0");
                            END IF;
                        END IF;

                        VideoCtrl_DataHandlerNextState <= HANDLE_ONE_TWO;
                        -- START THE READ ON THE VGA
                        VideoCtrl_SdRamStartStoreWall <= '1';
                        VideoCtrl_DataHandlerState <= WAIT_VGA_STARTREAD;
                    END IF;
            
                WHEN WAIT_VGA_STARTREAD =>
                    IF (VideoCtrl_SdRamWallStoredFlagEnd = '0') THEN
                        VideoCtrl_SdRamStartStoreWall <= '0'; -- STOP TO AVOID REPETITION FOR NO REASON
                        -- HERE WE HAVE TO RESTART THE READ PROCEDURE FROM THE DATA HANDLER
                        -- FOR NOW WE STORE THE SECOND DATA TO THE SDRAM COMMUNICATION SIGNALS THEY ARE NOT UPDATED
                        -- ON VGA PART BECAUSE THE VGA HAS STARTED THE READ OPERATION
                        IF (VideoCtrl_DataHandlerNextState = HANDLE_TWO_THREE) THEN
                            VideoCtrl_Xbuffer <= VideoCtrl_Xaxis(1);
                            VideoCtrl_Ybuffer <= VideoCtrl_Yaxis(1);

                            -- these are not changed on two three
                            VideoCtrl_SdRamXstart <= VideoCtrl_Xaxis(1) & "000" ; --shift 3 times (0- 100) (0 -- 800)
                            VideoCtrl_SdRamColor <= VideoCtrl_Color(1);
                            VideoCtrl_SdRamType <= VideoCtrl_Type(1);
                            VideoCtrl_SdRamAckn <= VideoCtrl_Ackn(1);
                            VideoCtrl_SdRamAngleStep <= VideoCtrl_AngleStep(1);
                            VideoCtrl_SdRamResolotuion <= VideoCtrl_Resolution(1);

                            -- RESTART THE DATAHANDLER
                            VideoCtrl_DataHandlerStart <= '1';
                            VideoCtrl_DataHandlerState <= WAIT_DATAHANDLER_RESTART;
                        ELSE
                            VideoCtrl_DataHandlerState <= HANDLE_ONE_TWO;
                        END IF;
                    END IF;

                WHEN WAIT_DATAHANDLER_RESTART =>
                    IF (VideoCtrl_ReadDataFinish = '0') THEN
                        VideoCtrl_DataHandlerStart <= '0';  -- STOP FALSE REPEAT OF THE DATAHANDLER
                        VideoCtrl_DataHandlerState <= WAIT_DATAHANDLER_FINISH;
                    END IF;

                WHEN WAIT_DATAHANDLER_FINISH =>
                    IF (VideoCtrl_ReadDataFinish = '1') THEN
                        VideoCtrl_DataHandlerState <= HANDLE_TWO_THREE;
                    END IF;

                WHEN OTHERS => NULL;
            END CASE;
        END IF;
    END PROCESS;

    -- Vga Main process, here we take the data from the DataHandler main process
    -- Data are handled here and stored in the linebuffer, Vga works in parallel
    -- This process checks the vga state and updates the data
    PROCESS (VideoCtrl_ColorClk, VideoCtrl_Reset, VideoCtrl_VgaPllLocked) IS
    BEGIN
        IF (VideoCtrl_Reset = '1') THEN
            VideoCtrl_VgaWallStoredFlagStart <= '0';
            VideoCtrl_VgaWallStoredFlagEnd <= '1';
        ELSIF rising_edge(VideoCtrl_ColorClk) AND VideoCtrl_VgaPllLocked = '1' THEN

        END IF;
    END PROCESS;

END ARCHITECTURE;