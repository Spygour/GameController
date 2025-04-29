library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.SpiSlaveTypes.all;

entity SpiSlaveHandler is
    
    port(ActlClk : in std_logic := '0';
         SpiClk   : in std_logic;
         Reset_n  : in std_logic := '1';
         SO     : out std_logic := '0';
         SI     : in  std_logic;
         CS       : in std_logic;
		 Leds  : out std_logic_vector (7 downto 0) := "11111111";
         SpiReady : out std_logic := '0');

end SpiSlaveHandler;

architecture rtl of SpiSlaveHandler is

signal Clk      : std_logic := '0';
signal StartSpi : std_logic := '0';
signal WrEn     : std_logic := '0';
signal WriteDataWord : SpiCorrected := (others => '0');
signal ReadDataWord  : SpiCorrected;
signal WriteAddress : std_logic_vector (7 DOWNTO 0) := (others => '0');
signal ReadAddress : std_logic_vector (7 DOWNTO 0) := (others => '0');
signal SpiPllLocked : std_logic := '0';
signal Words : integer := 0;
signal EndSpi : std_logic := '1';
--signal SpiSlaveState : Spi_State;

signal SpiTxWord : SpiWord  := (others => '0');
signal SpiRxWord : SpiWord  := (others => '0');
signal SpiHandlerState : Spi_Handler_State := IDLE_STATE;
signal SpiHandlerNextState : Spi_Handler_State := IDLE_STATE;
signal counter : integer := 0;
signal DelayMax : integer :=0;
signal successbits : unsigned (7 DOWNTO 0) := (others => '0');
signal failbits : unsigned (7 DOWNTO 0) := (others => '0');
signal failIndex :unsigned (7 DOWNTO 0) := "00000000";
signal bitIndex : unsigned(7 DOWNTO 0) := (others => '0');
constant SuccessArray : Success_Arr := (
    0  => std_logic_vector(to_unsigned(1, 16)),1  => std_logic_vector(to_unsigned(2, 16)),2  => std_logic_vector(to_unsigned(3, 16)),
    3  => std_logic_vector(to_unsigned(4, 16)),4  => std_logic_vector(to_unsigned(5, 16)),
    5  => std_logic_vector(to_unsigned(6, 16)),6  => std_logic_vector(to_unsigned(7, 16)),
    7  => std_logic_vector(to_unsigned(8, 16)),8  => std_logic_vector(to_unsigned(9, 16)),
    9  => std_logic_vector(to_unsigned(10, 16)),10 => std_logic_vector(to_unsigned(11, 16)),
    11 => std_logic_vector(to_unsigned(12, 16)),12 => std_logic_vector(to_unsigned(13, 16)),
    13 => std_logic_vector(to_unsigned(14, 16)),14 => std_logic_vector(to_unsigned(15, 16)),
    15 => std_logic_vector(to_unsigned(16, 16)),16 => std_logic_vector(to_unsigned(17, 16)),
    17 => std_logic_vector(to_unsigned(18, 16)),
    18 => std_logic_vector(to_unsigned(19, 16)),19 => std_logic_vector(to_unsigned(20, 16)),
    20 => std_logic_vector(to_unsigned(21, 16)),21 => std_logic_vector(to_unsigned(22, 16)),
    22 => std_logic_vector(to_unsigned(23, 16)),23 => std_logic_vector(to_unsigned(24, 16)),
    24 => std_logic_vector(to_unsigned(25, 16)),25 => std_logic_vector(to_unsigned(26, 16)),
    26 => std_logic_vector(to_unsigned(27, 16)),27 => std_logic_vector(to_unsigned(28, 16)),
    28 => std_logic_vector(to_unsigned(29, 16)),29 => std_logic_vector(to_unsigned(30, 16)),
    30 => std_logic_vector(to_unsigned(31, 16)),31 => std_logic_vector(to_unsigned(32, 16)),
    32 => std_logic_vector(to_unsigned(33, 16)),33 => std_logic_vector(to_unsigned(34, 16)),
    34 => std_logic_vector(to_unsigned(35, 16)),35 => std_logic_vector(to_unsigned(36, 16)),
    36 => std_logic_vector(to_unsigned(37, 16)),
    37 => std_logic_vector(to_unsigned(38, 16)),38 => std_logic_vector(to_unsigned(39, 16)),
    39 => std_logic_vector(to_unsigned(40, 16)),40 => std_logic_vector(to_unsigned(41, 16)),
    41 => std_logic_vector(to_unsigned(42, 16)),42 => std_logic_vector(to_unsigned(43, 16)),
    43 => std_logic_vector(to_unsigned(44, 16)),44 => std_logic_vector(to_unsigned(45, 16)),
    45 => std_logic_vector(to_unsigned(46, 16)),46 => std_logic_vector(to_unsigned(47, 16)),
    47 => std_logic_vector(to_unsigned(48, 16)),48 => std_logic_vector(to_unsigned(49, 16)),
    49 => std_logic_vector(to_unsigned(50, 16)),50 => std_logic_vector(to_unsigned(51, 16)),
    51 => std_logic_vector(to_unsigned(52, 16)),52 => std_logic_vector(to_unsigned(53, 16)),
    53 => std_logic_vector(to_unsigned(54, 16)),54 => std_logic_vector(to_unsigned(55, 16)),
    55 => std_logic_vector(to_unsigned(56, 16)),56 => std_logic_vector(to_unsigned(57, 16)),
    57 => std_logic_vector(to_unsigned(58, 16)),58 => std_logic_vector(to_unsigned(59, 16)),
    59 => std_logic_vector(to_unsigned(60, 16)),60 => std_logic_vector(to_unsigned(61, 16)),
    61 => std_logic_vector(to_unsigned(62, 16)),62 => std_logic_vector(to_unsigned(63, 16)),
    63 => std_logic_vector(to_unsigned(64, 16)),64 => std_logic_vector(to_unsigned(65, 16)),
    65 => std_logic_vector(to_unsigned(66, 16)),66 => std_logic_vector(to_unsigned(67, 16)),
    67 => std_logic_vector(to_unsigned(68, 16)),68 => std_logic_vector(to_unsigned(69, 16)),
    69 => std_logic_vector(to_unsigned(70, 16)),70 => std_logic_vector(to_unsigned(71, 16)),
    71 => std_logic_vector(to_unsigned(72, 16)),72 => std_logic_vector(to_unsigned(73, 16)),
    73 => std_logic_vector(to_unsigned(74, 16)),74 => std_logic_vector(to_unsigned(75, 16)),
    75 => std_logic_vector(to_unsigned(76, 16)),76 => std_logic_vector(to_unsigned(77, 16)),
    77 => std_logic_vector(to_unsigned(78, 16)),78 => std_logic_vector(to_unsigned(79, 16)),
    79 => std_logic_vector(to_unsigned(80, 16)),80 => std_logic_vector(to_unsigned(81, 16)),
    81 => std_logic_vector(to_unsigned(82, 16)),82 => std_logic_vector(to_unsigned(83, 16)),
    83 => std_logic_vector(to_unsigned(84, 16)),84 => std_logic_vector(to_unsigned(85, 16)),
    85 => std_logic_vector(to_unsigned(86, 16)),86 => std_logic_vector(to_unsigned(87, 16)),
    87 => std_logic_vector(to_unsigned(88, 16)),88 => std_logic_vector(to_unsigned(89, 16)),
    89 => std_logic_vector(to_unsigned(90, 16)),90 => std_logic_vector(to_unsigned(91, 16)),
    91 => std_logic_vector(to_unsigned(92, 16)),92 => std_logic_vector(to_unsigned(93, 16)),
    93 => std_logic_vector(to_unsigned(94, 16)),94 => std_logic_vector(to_unsigned(95, 16)),
    95 => std_logic_vector(to_unsigned(96, 16)),96 => std_logic_vector(to_unsigned(97, 16)),
    97 => std_logic_vector(to_unsigned(98, 16)),98 => std_logic_vector(to_unsigned(99, 16)),
    99 => std_logic_vector(to_unsigned(100, 16))
);
signal Reset_Reg :std_logic := '1';
signal CompareReg : SpiCorrected := (others => '0');

begin
	 Spipll:entity work.SpiPll(SYN)
    port map
    (
        areset => Reset_n,
	inclk0 => ActlClk,	
	c0     => Clk,
	locked =>  SpiPllLocked
    );
	 
	 SpiRam:entity work.SpiRam(SYN)
    port map
    (
      clock		=> Clk,
      data		=> WriteDataWord,
      rdaddress	=> ReadAddress,
      wraddress	=> WriteAddress,
      wren		=> WrEn,
      q		    => ReadDataWord
    );
	 
	 SpiSlave:entity work.SpiSlave(rtl)
    port map
    (
        ActlClk       => ActlClk,
        Clk           => Clk,
        SpiClk        => SpiClk,
        Reset_n       => Reset_Reg,
        SO            => SO, 
        SI            => SI,
        CS            => CS,
        StartSpi      => StartSpi,
        EndSpi        => EndSpi,
        Words         => Words,
        WrEn          => WrEn,
		WriteDataWord => WriteDataWord,
		ReadDataWord  => ReadDataWord,
        WriteAddress   => WriteAddress,
        ReadAddress   => ReadAddress,
        lockedloop  => SpiPllLocked
    );

    process(Clk, Reset_Reg, SpiPllLocked) is
    begin
        if (Reset_Reg = '1') then
		    StartSpi <= '0';
			counter <= 0;
        	SpiHandlerState <= IDLE_STATE;
        	SpiReady <= '0';
		    Leds <= "11111111";
			DelayMax <= 0;
			SpiHandlerNextState <= IDLE_STATE;
			successbits <= (others => '0');
			failbits <= (others => '0');
			bitIndex <= (others => '0');
			CompareReg <= (others => '0');
			failIndex <= "00000000";
        elsif rising_edge(Clk) and SpiPllLocked = '1' then
          case SpiHandlerState is
            when IDLE_STATE =>
				Leds <= "00011100";
              	StartSpi <= '1';
              	SpiHandlerState <= ACTIVATE_SPI;
              	ReadAddress <= (others => '0');

            when ACTIVATE_SPI =>
				if (successbits >= x"C8") then
					SpiHandlerState <= SUCCESS;
				else
					SpiHandlerState <= RUN_STATE;
					SpiReady <= '1';
				end if;
            
            when RUN_STATE =>
	            -- Set SpiReady to false to avoid the uC to send Data
				if EndSpi = '0' then
				   SpiReady <= '0';
				    StartSpi <= '0';
				    SpiHandlerState <= END_STATE;
				end if;

			when END_STATE =>
              	if (EndSpi = '1' and WrEn = '0') then
              	  	Leds <= "00000000";
					ReadAddress <= (others => '0');
				    SpiHandlerNextState <= EVAL_STATE;
					SpiHandlerState <= DELAY;
					DelayMax <= 50000000;
					CompareReg <= ReadDataWord;
					ReadAddress <= std_logic_vector(unsigned(ReadAddress) + 1);
              	end if;
				  
			when DELAY =>
				if (counter = DelayMax) then
					SpiHandlerState<= SpiHandlerNextState;
					counter <= 0;
					DelayMax <= 10;
				else
					counter <= counter + 1;
					SpiHandlerState <= DELAY;
				end if;

			when EVAL_STATE =>
				if (ReadAddress = "01100100") then
					SpiHandlerNextState <= ACTIVATE_SPI;
					SpiHandlerState <= DELAY;
					DelayMax <= 50000000;
					if (failIndex = "00000000") then
						successbits <= successbits + 1;
						Leds <= std_logic_vector(successbits);
					else
						failbits <= failbits + 1;
						Leds <= "10101010";
					end if;
					failIndex <= "00000000";
					bitIndex <= "00000000";
					StartSpi <= '1';
					ReadAddress <= "00000000";
				else
					if (CompareReg = SuccessArray(to_integer(bitIndex))) then
						bitIndex <= bitIndex + 1;
						CompareReg <= ReadDataWord;
						ReadAddress <= std_logic_vector(unsigned(ReadAddress) + 1);
						SpiHandlerNextState <= EVAL_STATE;
						SpiHandlerState <= DELAY;
					else
						bitIndex <= bitIndex + 1;
						failIndex <= failIndex + 1;
						CompareReg <= ReadDataWord;
						ReadAddress <= std_logic_vector(unsigned(ReadAddress) + 1);
						SpiHandlerNextState <= EVAL_STATE;
						SpiHandlerState <= DELAY;
					end if;
				end if;

			when SUCCESS =>
				if (failbits = x"00") then
					Leds <= std_logic_vector(successbits);
				else
					Leds <= "00011000";
				end if;

            when others => NULL;

          end case;
            
	end if;
    end process;

	process(Clk, Reset_n, SpiPllLocked) is
		begin
			if (Reset_n = '1') then
				Reset_reg <= '1';
			elsif rising_edge(Clk) and SpiPllLocked = '1' then
				Reset_reg <= '0';
			end if;
	end process;

end architecture;
