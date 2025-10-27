LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.VgaTypes.ALL;
ENTITY Vga IS
    GENERIC (
        SystemFreq : INTEGER := 40000000;
        VsyncFreq : INTEGER := 60;
        HsyncFreq : INTEGER := 37680);

    PORT (
        Reset : IN STD_LOGIC;
        StartSignal_n : IN STD_LOGIC;
        ColorClk : IN STD_LOGIC;
        ExtClock : IN STD_LOGIC;
        HsyncClk : OUT STD_LOGIC := '1';
        VsyncClk : OUT STD_LOGIC := '1';
        R : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        G : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        B : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        ColorWrite : IN ColorWriteValue_t := (OTHERS => (OTHERS => '0'));
        WriteEn : IN ColorWrEn_t := (OTHERS => '0');
        ColorWriteAddress : IN ColorWriteAddress_t := (OTHERS => (OTHERS => '0'));
        y_axis : OUT unsigned (9 DOWNTO 0) := (OTHERS => '0');
        HsyncComplete : OUT STD_LOGIC := '0';
        VsyncComplete : OUT STD_LOGIC := '0';
        LineBufferIndex : IN std_logic := '0';
        PllLocked : IN STD_LOGIC);

END Vga;

ARCHITECTURE rtl OF Vga IS
    CONSTANT VsyncDuty : INTEGER := 4;
    CONSTANT VsyncBackPort : INTEGER := 27;
    CONSTANT VsyncActive : INTEGER := 626;
    CONSTANT VsyncPeriod : INTEGER := 627;

    CONSTANT HsyncDuty : INTEGER := 128;
    CONSTANT HsyncBackPorch : INTEGER := 215;
    CONSTANT HsyncPixel : INTEGER := 1015;
    CONSTANT HsyncPeriod : INTEGER := 1055;

    SIGNAL HsyncCounter : INTEGER := 0;
    SIGNAL VsyncCounter : INTEGER := 0;
    SIGNAL HsyncClk_reg : STD_LOGIC := '1';
    SIGNAL VsyncClk_reg : STD_LOGIC := '1';

    SIGNAL ColorValue : STD_LOGIC_VECTOR(23 DOWNTO 0) := (OTHERS => '0');
    SIGNAL ColorRead : ColorReadValue_t := (OTHERS => (OTHERS => '0'));
    SIGNAL x_axis : unsigned(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL x_axis_read : ColorReadAddress_t := (OTHERS => (OTHERS => '0'));

    TYPE Sync_State IS
    (
    IDLE_STATE,
    PULSE_STATE,
    BACK_PORCH_STATE,
    ACTIVE_STATE,
    EXTEND_STATE,
    FRONT_PORCH,
    PREPARE_PULSE
    );

    SIGNAL HsyncState : Sync_State := IDLE_STATE;
    SIGNAL VsyncState : Sync_State := IDLE_STATE;
    SIGNAL y_axis_reg : unsigned (9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL HsyncComplete_reg : STD_LOGIC := '0';
    SIGNAL LineBufferIndex_reg : UNSIGNED(0 DOWNTO 0) := (OTHERS => '0');
	SIGNAL HsyncComplete_Vsync : STD_LOGIC := '0';
BEGIN

    VgaBram_1 : ENTITY work.VgaBram1(SYN)
        PORT MAP
        (
            data => ColorWrite(0),
            rdaddress => x_axis_read(0),
            rdclock => ColorClk,
            wraddress => ColorWriteAddress(0),
            wrclock => ExtClock,
            wren => WriteEn(0),
            q => ColorRead(0)
        );

    VgaBram_2 : ENTITY work.VgaBram2(SYN)
        PORT MAP
        (
            data => ColorWrite(1),
            rdaddress => x_axis_read(1),
            rdclock => ColorClk,
            wraddress => ColorWriteAddress(1),
            wrclock => ExtClock,
            wren => WriteEn(1),
            q => ColorRead(1)
        );

    --Update the actual signals
    HsyncClk <= HsyncClk_reg;
    VsyncClk <= VsyncClk_reg;
    --Hsync pulse process
    PROCESS (ColorClk, Reset, PllLocked) IS
    BEGIN
        IF (Reset = '1') THEN
            HsyncClk_reg <= '1';
            LineBufferIndex_reg <= (OTHERS => '0');
            HsyncState <= IDLE_STATE;
        ELSIF rising_edge(ColorClk) AND PllLocked = '1' THEN --Here we should increase the counter
            CASE HsyncState IS
                WHEN IDLE_STATE =>
                    IF StartSignal_n = '0' THEN
                        HsyncCounter <= 0;
                        HsyncClk_reg <= NOT HsyncClk_reg;
                        x_axis <= (OTHERS => '0');
                        HsyncComplete_reg <= '0';
                        VsyncCounter <= 0;
                        x_axis_read <= (OTHERS => (OTHERS => '0'));
                        HsyncState <= PULSE_STATE;
                    END IF;

                WHEN PULSE_STATE =>
                    IF (HsyncCounter = HsyncDuty) THEN
                        HsyncClk_reg <= NOT HsyncClk_reg;
                        -- Change the index afterwards to avoid timing issues with the outside port
                        if (LineBufferIndex = '1') then
                            LineBufferIndex_reg <= "1";
                            x_axis_read(1) <= (OTHERS => '0');
                        else
                            LineBufferIndex_reg <= "0";
                            x_axis_read(0) <= (OTHERS => '0');
                        end if;
                        x_axis <= (OTHERS => '0');
                        HsyncCounter <= HsyncCounter + 1;
                        HsyncState <= BACK_PORCH_STATE;
                    ELSE
                        HsyncCounter <= HsyncCounter + 1;
                    END IF;

                WHEN BACK_PORCH_STATE =>
                    IF (HsyncCounter = HsyncBackPorch) THEN
                        HsyncCounter <= HsyncCounter + 1;
                        HsyncState <= ACTIVE_STATE;
                    ElSE
                        HsyncCounter <= HsyncCounter + 1;
                    END IF;
                
                WHEN ACTIVE_STATE =>
                    IF (HsyncCounter = HsyncPixel) THEN
                        HsyncComplete_reg <= '1';
                        HsyncCounter <= HsyncCounter + 1;
                        HsyncState <= FRONT_PORCH;
                    ELSE
                        -- 0x320 = 800
                        IF ((x_axis < X"320") AND (VsyncState = ACTIVE_STATE)) THEN
                            x_axis <= x_axis + 1;
                            x_axis_read(to_integer(LineBufferIndex_reg)) <= STD_LOGIC_VECTOR(resize(shift_right(x_axis + 1,3), 7 ));
                        END IF;
                        HsyncCounter <= HsyncCounter + 1;
                    END IF;

                WHEN FRONT_PORCH =>
                    -- Prepare to start the new pulse (We need to check the HsyncComplete inside the VsyncProcess thats why we need an extra state)
                    IF (HsyncCounter = HsyncPeriod) THEN
                        VsyncCounter <= VsyncCounter + 1;
                        HsyncCounter <= 0;
                        HsyncComplete_reg <= '0';
                        HsyncState <= PREPARE_PULSE;
                    ELSE
                        HsyncCounter <= HsyncCounter + 1;
                    END IF;

                WHEN PREPARE_PULSE =>
                    HsyncClk_reg <= NOT HsyncClk_reg;
                    -- Here we reset the VsyncCounter at the exact time of the pulse that will be generated by Vsync and Hsync
                    IF (VsyncCounter = VsyncPeriod) THEN
                        VsyncCounter <= 0;
                    END IF;
                    HsyncState <= PULSE_STATE;

                WHEN OTHERS => NULL;
            END CASE;
        END IF;
    END PROCESS;
    
    --Vsync pulse process
    PROCESS (ColorClk, Reset, PllLocked) IS
    
    BEGIN
        IF (Reset = '1') THEN
            VsyncClk_reg <= '1';
            VsyncState <= IDLE_STATE;
            VsyncComplete <= '0';
            HsyncComplete_Vsync <= '0';
        ELSIF rising_edge(ColorClk) AND PllLocked = '1' THEN --Here we should increase the counter
            HsyncComplete_Vsync <= HsyncComplete_reg;
            CASE VsyncState IS
                WHEN IDLE_STATE =>
                    IF StartSignal_n = '0' THEN
                        VsyncClk_reg <= NOT VsyncClk_reg;
                        y_axis_reg <= (OTHERS => '0');
                        VsyncComplete <= '0';
                        VsyncState <= PULSE_STATE;
                    END IF;

                WHEN PULSE_STATE =>
                    IF (VsyncCounter = VsyncDuty) THEN
                        VsyncClk_reg <= NOT VsyncClk_reg;
                        VsyncState <= BACK_PORCH_STATE;
                    END IF;

                WHEN BACK_PORCH_STATE =>
                    IF (VsyncCounter = VsyncBackPort) THEN
                        VsyncState <= ACTIVE_STATE;
                    END IF;

                WHEN ACTIVE_STATE =>
                    IF (VsyncCounter = VsyncActive) THEN
                        VsyncComplete <= '1';
                        VsyncState <= FRONT_PORCH;
                    ELSIF (HsyncComplete_reg = '1' AND HsyncComplete_Vsync = '0')  THEN
                        y_axis_reg <= y_axis_reg + 1;
                    END IF;

                WHEN FRONT_PORCH =>
                    IF (((VsyncCounter = VsyncPeriod) OR (VsyncCounter = 0)) AND (HsyncState = PREPARE_PULSE)) THEN
                        y_axis_reg <= (OTHERS => '0');
                        VsyncClk_reg <= NOT VsyncClk_reg;
                        VsyncComplete <= '0';
                        VsyncState <= PULSE_STATE;
                    END IF;

                WHEN OTHERS => NULL;
            END CASE;
        END IF;
    END PROCESS;

    --color pulse process much more complicated
    PROCESS (ColorClk, Reset, PllLocked) IS
    BEGIN
        IF (Reset = '1') THEN
            ColorValue <= (OTHERS => '0');
        ELSIF rising_edge(ColorClk) AND PllLocked = '1' THEN --Here we should increase the counter
            IF (HsyncState = ACTIVE_STATE AND VsyncState = ACTIVE_STATE) THEN
                ColorValue <= ColorRead(to_integer(LineBufferIndex_reg));
            ELSE
                ColorValue <= (OTHERS => '0');
            END IF;
        END IF;
    END PROCESS;
    -- assign the out signals
    HsyncClk <= HsyncClk_reg;
    VsyncClk <= VsyncClk_reg;
    R <= ColorValue(23 DOWNTO 16);
    G <= ColorValue(15 DOWNTO 8);
    B <= ColorValue(7 DOWNTO 0);
    y_axis <= y_axis_reg;
    HsyncComplete <= HsyncComplete_reg;
END ARCHITECTURE;