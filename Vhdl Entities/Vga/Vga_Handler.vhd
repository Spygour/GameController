library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.VgaTypes.all;


entity Vga_Handler is 
    port(Reset_n  : in std_logic := '0';
         InputClk : in std_logic := '0';
         HsyncClk : out std_logic := '1';
         VsyncClk : out std_logic := '1';
         R : out std_logic_vector (7 downto 0) := (others => '0');
	 G : out std_logic_vector (7 downto 0) := (others => '0');
	 B : out std_logic_vector (7 downto 0) := (others => '0')
    );
end Vga_Handler;

architecture rtl of Vga_Handler is
    constant SystemFreq : integer := 40000000;
    constant VsyncFreq : integer := 60;
    constant HsyncFreq : integer := 37680;

    signal ColorClk :  std_logic  := '0';
    signal LineBuffer : LineBuffer_t := (others => (others => (others => '0')));
    signal x_axis   : unsigned (9 downto 0) := (others => '0');
    signal y_axis   : unsigned (9 downto 0) := (others => '0');
    signal locked : std_logic := '1';
    signal HsyncComplete : std_logic := '0';
    signal VsyncComplete : std_logic := '0';
    signal Reset_Sync : std_logic := '1';
    signal Reset_Reg : std_logic := '1';
    signal BufferIndex : integer := 0;
	 signal BufferIndex_tmp: integer := 1; --temp value of BufferIndex
    signal ScreenCounter : integer := 0;

    type Handler_State is
        (
            Update,
            Send_Green,
            Send_Blue,
            Send_Red,
            Send_Mixed,
            Nop
        );
    signal HandlerState : Handler_State := Send_Green;
    signal ScreenState : Handler_State := Send_Green;
begin
	VgaPll:entity work.VgaPll(SYN)
	port map
	(
		areset => Reset_n,
		inclk0 => InputClk,	
		c0     => ColorClk,
		locked =>  locked
	);

    
    Vga: entity work.Vga(rtl)
        generic map(SystemFreq => SystemFreq, 
                    VsyncFreq  => VsyncFreq, 
                    HsyncFreq  => HsyncFreq)
        port map(Reset_n   => Reset_Sync,
                 ColorClk  => ColorClk,
                 HsyncClk  => HsyncClk,
                 VsyncClk  => VsyncClk,
                 R         => R,    
                 G         => G,
                 B         => B,  
                 --LineCycle => LineCycle,
                 LineBuffer => LineBuffer,
                 x_axis    => x_axis,
                 y_axis    => y_axis,
		         HsyncComplete => HsyncComplete,
		         VsyncComplete => VsyncComplete,
		         LineBufferIndex => BufferIndex);

    process(ColorClk, Reset_Sync, locked)
    begin
        if (Reset_Sync = '1') then
            LineBuffer(0) <= (others => x"00FF00");
				LineBuffer(1) <= (others => x"0000FF");
			BufferIndex_tmp <= 1;
			BufferIndex <= 0;
			HandlerState <= Send_Green;
			ScreenState <= Send_Green;
        elsif (rising_edge(ColorClk) and (locked='1')) then
            case HandlerState is
                when Send_Green => 
                    if (HsyncComplete = '0') then
                        LineBuffer(BufferIndex_tmp) <= (others => x"FF00FF");
                        HandlerState <= Update;
                        ScreenState <= Send_Blue;
                    end if;

                when Send_Blue =>
                    if (HsyncComplete = '0') then
                        LineBuffer(BufferIndex_tmp) <= (others => x"FF0000");
                        HandlerState <= Update;
                        ScreenState <= Send_Red;
                    end if;

                when Send_Mixed =>
                    if (HsyncComplete = '0') then
                        for i in 0 to 299 loop
                            LineBuffer(BufferIndex_tmp)(i) <= x"FF0000";
                        end loop;

                        for i in 300 to 599 loop
                            LineBuffer(BufferIndex_tmp)(i) <= x"00FF00";
                        end loop;

                        for i in 600 to 799 loop
                            LineBuffer(BufferIndex_tmp)(i) <= x"0000FF";
                        end loop;
                        HandlerState <= Update;
                        ScreenState <= Send_Green;
                    end if;
						  
				when Send_Red =>
                    if (HsyncComplete = '0') then
						LineBuffer(BufferIndex_tmp) <= (others => x"00FF00");
						HandlerState <= Update;
                        ScreenState <= Send_Mixed;
                    end if;

                when Update =>
                    if (HsyncComplete = '1') then
                        if ScreenCounter = 5 then
                            ScreenCounter <= 0;
							if (BufferIndex = 1) then
								BufferIndex <= 0;
								BufferIndex_tmp <= 1;
							else
								BufferIndex <= 1;
								BufferIndex_tmp <= 0;
							end if;
                            HandlerState <= ScreenState;
                        else
                            HandlerState <= Nop;
                            ScreenCounter <= ScreenCounter + 1;
                        end if;
                    end if;
                
                when Nop =>
                    if (HsyncComplete = '0') then
                        HandlerState <= Update;
                    end if; 
                
				when others => null;
                
            end case;
				
        end if;
    end process;


    process (ColorClk, Reset_n, locked) is
    begin
        if (Reset_n = '1') then
            Reset_Sync <= '1';
        elsif (rising_edge(ColorClk) and (locked='1')) then
            Reset_Sync <= '0';
        end if;
    end process;

end architecture;
