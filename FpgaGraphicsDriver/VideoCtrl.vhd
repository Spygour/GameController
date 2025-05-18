library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.DataHandlerTypes.all
use work.SdRamTypes.all;
use work.SpiSlaveTypes.all;

entity VideoCtlr is 
    port(VideoCtlr_Reset_n : in std_logic := '1';
         -- Clocks
         VideoCtlr_ActlClk : in std_logic := '0';
         -- SDRAM PINS
         VideoCtlr_SdRamClkOut : out std_logic;
         VideoCtlr_Address : out std_logic_vector (12 downto 0) := (others => '0');
         VideoCtlr_Bank : out std_logic_vector (1 downto 0) := (others => '0');
         VideoCtlr_CAS : out std_logic := '0';
         VideoCtlr_CKE : out std_logic := '0';
         VideoCtlr_SdRamCS : out std_logic := '1';
         VideoCtlr_DQM : out std_logic_vector (0 to 1) := (others => '0');
         VideoCtlr_DQ : inout std_logic_vector (15 downto 0) := (others => '0');
         VideoCtlr_RAS : out std_logic := '0';
         VideoCtlr_WE : out std_logic := '0';
	     VideoCtlr_DebugLeds : out std_logic_vector (7 downto 0) := (others => '0');
         -- SPI PINS
        VideoCtlr_SpiClk   : in std_logic;
        VideoCtlr_So     : out std_logic := '0';
        VideoCtlr_Si     : in  std_logic;
        VideoCtlr_Cs       : in std_logic;
        VideoCtlr_SpiReady : out std_logic := '0'
         );

end VideoCtlr;

architecture rtl of VideoCtlr is

    type VideoCtlr_STATE is
    (
        START_WRITE,
        WAIT_START,
        WAIT_WRITE,
        WRITE_SDRAM,
        START_READ,
        CHECK_DATA_AVAILABLE,
        READ_DATA,
        READ_DATA_NEW,
		DATA_READ_RESTART
    );

    signal VideoCtlr_SdRamClk : std_logic := '0';
    signal VideoCtlr_GlobalClk : std_logic := '0';
    signal VideoCtlr_PllLocked : std_logic := '0';


    signal VideoCtlr_Finish :  std_logic := '1'
	signal VideoCtlr_Start :  std_logic;
    signal VideoCtlr_Xaxis :  DataPart_t := (others => (others => '0'));
    signal VideoCtlr_Yaxis :  DataPart_t := (others => (others => '0'));
    signal VideoCtlr_Resolution :  DataPart_t := (others => (others => '0'));
    signal VideoCtlr_Color :  DataColor_t := (others => (others => '0'));
    signal VideoCtlr_SpiWordsReg :  integer := 0;
    signal VideoCtlr_DataAvailable :  std_logic := '0'
begin
    SdRamPll:entity work.SdRamPll(SYN)
    port map
    (
       areset => VideoCtlr_Reset_n,
       inclk0 => VideoCtlr_ActlClk,	
       c0     => VideoCtlr_SdRamClk,
       c1     => VideoCtlr_GlobalClk,
       locked => VideoCtlr_PllLocked
    );

    DataHandler:entity work.DataHandler(rtl)
    port map
    (
        DataHandler_Reset_n  => VideoCtlr_Reset_Sync
        -- Clocks
        DataHandler_ActlClk  => VideoCtlr_ActlClk
        DataHandler_SdRamClk => VideoCtlr_SdRamClk
        DataHandler_GlobalClk  => VideoCtlr_GlobalClk
        DataHandler_PllLocked  => VideoCtlr_PllLocked
        -- SDRAM PINS
        DataHandler_SdRamClkOut => VideoCtlr_SdRamClkOut
        DataHandler_Address => VideoCtlr_Address
        DataHandler_Bank    => VideoCtlr_Bank
        DataHandler_CAS =>  VideoCtlr_CAS
        DataHandler_CKE =>  VideoCtlr_CKE
        DataHandler_SdRamCS =>  VideoCtlr_SdRamCS
        DataHandler_DQM =>  VideoCtlr_DQM
        DataHandler_DQ  =>  VideoCtlr_DQ
        DataHandler_RAS =>  VideoCtlr_RAS
        DataHandler_WE  =>  VideoCtlr_WE
        DataHandler_DebugLeds => VideoCtlr_DebugLeds
        -- SPI PINS
        DataHandler_SpiClk => VideoCtlr_SpiClk
        DataHandler_So => VideoCtlr_So
        DataHandler_Si => VideoCtlr_Si
        DataHandler_Cs => VideoCtlr_Cs
        DataHandler_SpiReady => VideoCtlr_SpiReady
        DataHandler_Finish  => VideoCtlr_Finish
        DataHandler_Start => VideoCtlr_Start
        DataHandler_Xaxis => VideoCtlr_Xaxis
        DataHandler_Yaxis => VideoCtlr_Yaxis
        DataHandler_Resolution => VideoCtlr_Resolution
        DataHandler_Color => VideoCtlr_Color
        DataHandler_SpiWordsReg => VideoCtlr_SpiWordsReg
        DataHandler_DataAvailable => VideoCtlr_DataAvailable
    );
    
    process(VideoCtlr_SdRamClk ,VideoCtlr_Reset_Sync, VideoCtlr_PllLocked) is
    begin
        if (VideoCtlr_Reset_Sync = '1') then

        elsif rising_edge(VideoCtlr_SdRamClk) and VideoCtlr_PllLocked = '1' then
 
        end if;
    end process;

    process(VideoCtlr_Reset_Sync, VideoCtlr_SdRamClk, VideoCtlr_PllLocked) is
    begin
        if (VideoCtlr_Reset_Sync = '1') then
       
        elsif rising_edge(VideoCtlr_SdRamClk) and VideoCtlr_PllLocked = '1' then

        end if;
	end process;

    process (VideoCtlr_Reset_n, VideoCtlr_PllLocked) is
    begin
        if (VideoCtlr_Reset_n = '1') then
            VideoCtlr_Reset_Sync <= '1';
        elsif VideoCtlr_PllLocked='1' then
            VideoCtlr_Reset_Sync <= '0';
		  else
			VideoCtlr_Reset_Sync <= '1';
        end if;
    end process;

end architecture;
