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
signal failIndex :unsigned (7 DOWNTO 0) := "00000011";
signal bitIndex : unsigned(1 DOWNTO 0) := (others => '0');
constant SuccessArray : Success_Arr := (x"ABCD", x"2321");
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
			failIndex <= "00000011";
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
				else
					counter <= counter + 1;
					SpiHandlerState <= DELAY;
				end if;

			when EVAL_STATE =>
				if (ReadAddress = "00000011") then
					SpiHandlerNextState <= ACTIVATE_SPI;
					SpiHandlerState <= DELAY;
					if (failIndex = "00000011") then
						Leds <= std_logic_vector(successbits);
					else
						Leds <= std_logic_vector(failIndex);
					end if;
					failIndex <= "00000011";
					bitIndex <= "00";
					StartSpi <= '1';
					ReadAddress <= "00000000";
				else
					if (CompareReg = SuccessArray(to_integer(bitIndex))) then
						CompareReg <= ReadDataWord;
						bitIndex <= bitIndex + 1;
						successbits <= successbits + 1;
						ReadAddress <= std_logic_vector(unsigned(ReadAddress) + 1);
						SpiHandlerState <= EVAL_STATE;
					else
						failIndex <= unsigned(CompareReg(15 downto 8));
						CompareReg <= ReadDataWord;
						bitIndex <= bitIndex + 1;
						failbits <= failbits + 1;
						ReadAddress <= std_logic_vector(unsigned(ReadAddress) + 1);
						SpiHandlerState <= EVAL_STATE;
					end if;
				end if;

			when SUCCESS =>
				if (failbits = x"00") then
					Leds <= std_logic_vector(successbits);
				else
					Leds <= std_logic_vector(failbits);
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
