LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY work;
USE work.DataHandlerTypes.ALL;
USE work.SdRamTypes.ALL;
USE work.SpiSlaveTypes.ALL;
USE work.VgaTypes.ALL;

ENTITY VideoCtrl_test IS

END ENTITY;

ARCHITECTURE sim OF VideoCtrl_test IS
  TYPE miso_mem_t IS ARRAY (0 TO 15) OF STD_LOGIC_VECTOR(15 DOWNTO 0);

    CONSTANT Test_MISO_0_Data : miso_mem_t := (
    x"1200", x"5612", x"5812", x"1035",
    x"0838", x"4313", x"5012", x"6040",
    x"5311", x"1922", x"1033", x"2044",
    x"3450", x"2039", x"5520", x"2540"
  );  

  CONSTANT Test_MISO_1_Data : miso_mem_t := (
    x"1234", x"5678", x"9ABC", x"DEF0",
    x"AAAA", x"5555", x"F0F0", x"0F0F",
    x"1111", x"2222", x"3333", x"4444",
    x"9999", x"ABCD", x"FEDC", x"BA98"
  );

  CONSTANT Test_MISO_2_Data : miso_mem_t := (
    x"1234", x"5678", x"9ABC", x"DEF0",
    x"AAAA", x"5555", x"F0F0", x"0F0F",
    x"1111", x"2222", x"3333", x"4444",
    x"9999", x"ABCD", x"FEDC", x"BA98"
  );  
  SIGNAL Test_Reset : STD_LOGIC := '1';
  -- Clocks
  SIGNAL Test_ActlClk : STD_LOGIC := '0';
  -- SDRAM PINS
  SIGNAL Test_SdRamClk : STD_LOGIC := '0';
  SIGNAL Test_GlobalClk : STD_LOGIC := '0';
  SIGNAL Test_SdRamClkOut : STD_LOGIC;
  SIGNAL Test_Address : STD_LOGIC_VECTOR (12 DOWNTO 0);
  SIGNAL Test_Bank : STD_LOGIC_VECTOR (1 DOWNTO 0);
  SIGNAL Test_CAS : STD_LOGIC;
  SIGNAL Test_CKE : STD_LOGIC;
  SIGNAL Test_SdRamCS : STD_LOGIC;
  SIGNAL Test_DQM : STD_LOGIC_VECTOR (0 TO 1);
  SIGNAL Test_DQ : STD_LOGIC_VECTOR (15 DOWNTO 0);
  SIGNAL Test_RAS : STD_LOGIC;
  SIGNAL Test_WE : STD_LOGIC;
  --Test_DebugLeds : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
  -- SPI PINS
  SIGNAL Test_SpiClk : STD_LOGIC := '0';
  SIGNAL Test_So : STD_LOGIC;
  SIGNAL Test_Si : STD_LOGIC_VECTOR(0 TO 2) := (OTHERS => '0');
  SIGNAL Test_Cs : STD_LOGIC := '1';
  SIGNAL Test_SpiReady : STD_LOGIC;
  -- Vga PINS
  SIGNAL Test_ColorClk : STD_LOGIC := '0';
  SIGNAL Test_HsyncClk : STD_LOGIC;
  SIGNAL Test_VsyncClk : STD_LOGIC;
  SIGNAL Test_R : STD_LOGIC_VECTOR (7 DOWNTO 0);
  SIGNAL Test_G : STD_LOGIC_VECTOR (7 DOWNTO 0);
  SIGNAL Test_B : STD_LOGIC_VECTOR (7 DOWNTO 0);

BEGIN

VideoController : ENTITY  work.VideoCtrl(rtl)
  PORT MAP
  (
        VideoCtrl_Reset => Test_Reset,
        -- Clocks
        VideoCtrl_ActlClk => Test_ActlClk,
        -- SDRAM PINS
        VideoCtrl_SdRamClk => Test_SdRamClk,
        VideoCtrl_GlobalClk => Test_GlobalClk,
        VideoCtrl_SdRamClkOut => Test_SdRamClkOut,
        VideoCtrl_Address => Test_Address,
        VideoCtrl_Bank => Test_Bank,
        VideoCtrl_CAS => Test_CAS,
        VideoCtrl_CKE => Test_CKE,
        VideoCtrl_SdRamCS => Test_SdRamCS,
        VideoCtrl_DQM => Test_DQM,
        VideoCtrl_DQ => Test_DQ,
        VideoCtrl_RAS => Test_RAS,
        VideoCtrl_WE  => Test_WE,
        --VideoCtrl_DebugLeds : OUT STD_LOGIC_VECTOR (7 DOWNTO 0) := (OTHERS => '0');
        -- SPI PINS
        VideoCtrl_SpiClk => Test_SpiClk,
        VideoCtrl_So => Test_So,
        VideoCtrl_Si => Test_Si,
        VideoCtrl_Cs => Test_Cs,
        VideoCtrl_SpiReady => Test_SpiReady,
        -- Vga PINS
        VideoCtrl_ColorClk => Test_ColorClk,
        VideoCtrl_HsyncClk => Test_HsyncClk,
        VideoCtrl_VsyncClk => Test_VsyncClk,
        VideoCtrl_R => Test_R,
        VideoCtrl_G => Test_G,
        VideoCtrl_B => Test_B
  );


-- actual clock process
process
begin
  Test_ActlClk <= '0';
  wait for 10 ps;
  Test_ActlClk <= '1';
  wait for 10 ps;
end process;


-- sdram clock process
process
begin
  Test_SdRamClk <= '0';
  -- 90 degrees phase
  Test_GlobalClk <= '1';
  wait for 5 ps;
  Test_SdRamClk <= '1';
  -- 90 degrees phase
  Test_GlobalClk <= '0';
  wait for 5 ps;
end process;

-- vga clock process
process
begin
  Test_ColorClk <= '0';
  wait for 12.5 ps;
  Test_ColorClk <= '1';
  wait for 12.5 ps;
end process;

process
variable word_i: integer;
variable bit_i : integer;
begin
  Test_Reset <= '0';
  wait for 10 ps;
  wait until Test_SpiReady = '1';

  Test_Cs <= '0';
  wait for 10 ps;

  for word_i in 0 to 15 loop
    for bit_i in 0 to 15 loop
      Test_Si(0) <= Test_MISO_0_Data(word_i)(bit_i);
      Test_Si(1) <= Test_MISO_1_Data(word_i)(bit_i);
      Test_Si(2) <= Test_MISO_2_Data(word_i)(bit_i);
      Test_SpiClk <= not Test_SpiClk;
      wait for 50 ps;
    end loop;
  end loop;

  Test_Cs <= '1';
  Test_SpiClk <= '0';
  wait for 20 ps;
  wait until Test_SpiReady = '1';
  wait;
end process;


END ARCHITECTURE;