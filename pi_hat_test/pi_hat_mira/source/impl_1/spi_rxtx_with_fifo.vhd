-- Firmware for NN22_ControlBoard00
-- SPI transceiver with FIFO
-- FPGA is the slave device
-- Assuming SPI mode 0

-- Initial version: 2023-3-13
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_rxtx_with_fifo is
	port (
		ClkxCI 	 		: in std_logic;
		ResetxRI 		: in std_logic;
		ResetTxFIFOxSI 	: in std_logic;
		CSnxSI			: in std_logic;
		MISOxDO 		: out std_logic;
		MOSIxDI			: in std_logic;
		SCKxSI			: in std_logic;
		BuffFullxSO		: out std_logic;
		BuffEmptyxSO	: out std_logic;
		ParDatRdyxSI 	: in std_logic;
		ParDatxDI 		: in std_logic_vector(7 downto 0);
		ParDatxDO		: out std_logic_vector(7 downto 0);
		ParDatRdyxSO 	: out std_logic;
		RxIndxSO		: out std_logic;
		TxIndxSO		: out std_logic
	);
end spi_rxtx_with_fifo;

architecture behavioral of spi_rxtx_with_fifo is

	constant FIFO_ALMOST_EMPTY_TRSH : integer := 6144;
	
	constant N_FIFO_ADDR_BITS : integer := 13;
	constant N_FIFO_WORDS : integer := 2**N_FIFO_ADDR_BITS;
	
	signal FIFOWrAddrxDP, FIFOWrAddrxDN : unsigned(N_FIFO_ADDR_BITS-1 downto 0);
	signal FIFORdAddrxDP, FIFORdAddrxDN : unsigned(N_FIFO_ADDR_BITS-1 downto 0);
	type fifo_mem_type is array (0 to N_FIFO_WORDS-1) of std_logic_vector(ParDatxDI'range);
    signal FIFOMemxDP, FIFOMemxDN : fifo_mem_type;
	
	type fsmstatetype is (sIdle, sFirstByte, sFirstByteRdy, sRxData, sRxDataRdy, sTxBytesAvailableHighByte, sTxData, sRstFIFO);
	signal StatexDP, StatexDN : fsmstatetype;
	
	signal ResetTxFIFOxSP, ResetTxFIFOxSN : std_logic;
	signal ResetTxFIFORqdxSP, ResetTxFIFORqdxSN : std_logic;
	signal FIFOWrAddrRstxS : std_logic;
	
	signal FIFOBytesAvailablexD : unsigned(FIFORdAddrxDP'range);
	signal FIFOBytesAvailableHighBytexDP, FIFOBytesAvailableHighBytexDN : std_logic_vector(7 downto 0);
	signal FIFOFullxSP, FIFOFullxSN : std_logic; 
	signal FIFOEmptyxS : std_logic;
	signal FIFOAlmostEmptyxSP, FIFOAlmostEmptyxSN : std_logic;
	signal FIFOOutDataxD : std_logic_vector(7 downto 0);
	signal TxSRegxDP, TxSRegxDN : std_logic_vector(7 downto 0);
	signal RxSRegxDP, RxSRegxDN : std_logic_vector(7 downto 0);
	
	signal BitCntxDP, BitCntxDN: integer range 0 to 7;
	
	-- synchronizer registers
	signal CSnxSP, CSnxSN : std_logic;
	signal SCKSRegxSP, SCKSRegxSN : std_logic_vector(1 downto 0);
	signal MOSIRegxDP, MOSIRegxDN : std_logic;
	
begin

	
	-- FIFO reset logic related
	ResetTxFIFOxSN <= ResetTxFIFOxSI;
	ResetTxFIFORqdxSN <= '1' when ResetTxFIFOxSP = '0' and ResetTxFIFOxSI = '1' else -- rising edge
						 '0' when FIFOWrAddrRstxS = '1' else
						 ResetTxFIFORqdxSP;
	
	CSnxSN <= CSnxSI;
	SCKSRegxSN(0) <= SCKxSI;
	SCKSRegxSN(1) <= SCKSRegxSP(0);
	MOSIRegxDN <= MOSIxDI;
	ParDatxDO <= RxSRegxDP;
	
	BuffEmptyxSO <= FIFOAlmostEmptyxSP;
	
	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			StatexDP <= sIdle;
			FIFOAlmostEmptyxSP <= '0';
			FIFOFullxSP <= '0';
			ResetTxFIFOxSP <= '0';
			ResetTxFIFORqdxSP <= '0';
			TxSRegxDP  <= (others => '0');
			RxSRegxDP  <= (others => '0');
			FIFOBytesAvailableHighBytexDP <= (others => '0');
			CSnxSP <= '1';
			SCKSRegxSP <= (others => '0');
			BitCntxDP <= 0;
			MOSIRegxDP <= '0';	
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			FIFOAlmostEmptyxSP <= FIFOAlmostEmptyxSN;
			FIFOFullxSP <= FIFOFullxSN;
			ResetTxFIFOxSP <= ResetTxFIFOxSN;
			ResetTxFIFORqdxSP <= ResetTxFIFORqdxSN;
			TxSRegxDP <= TxSRegxDN;
			RxSRegxDP <= RxSRegxDN;
			FIFOBytesAvailableHighBytexDP <= FIFOBytesAvailableHighBytexDN;
			CSnxSP <= CSnxSN;
			SCKSRegxSP <= SCKSRegxSN;
			BitCntxDP <= BitCntxDN;
			MOSIRegxDP <= MOSIRegxDN;			
		end if;
		
		if (rising_edge(ClkxCI)) then
			FIFOMemxDP <= FIFOMemxDN;
			FIFOWrAddrxDP <= FIFOWrAddrxDN;
			FIFORdAddrxDP <= FIFORdAddrxDN;
		end if;
	end process;
	
	p_memless : process (all)
	begin
		MISOxDO <= 'Z';
		TxSRegxDN <= TxSRegxDP;
		RxSRegxDN <= RxSRegxDP;
		BitCntxDN <= BitCntxDP;
		FIFOBytesAvailableHighBytexDN <= FIFOBytesAvailableHighBytexDP;
		FIFOWrAddrRstxS <= '0';
		FIFORdAddrxDN <= FIFORdAddrxDP;
		ParDatRdyxSO <= '0';
		RxIndxSO <= '0';
		TxIndxSO <= '0';
		StatexDN <= StatexDP;
		case StatexDP is 
			when sIdle =>
				TxSRegxDN <= std_logic_vector(FIFOBytesAvailablexD(7 downto 0));
				FIFOBytesAvailableHighBytexDN((FIFOBytesAvailablexD'left-8) downto 0) <= std_logic_vector(FIFOBytesAvailablexD(FIFOBytesAvailablexD'left downto 8));
				FIFOBytesAvailableHighBytexDN(7 downto (FIFOBytesAvailablexD'left-8+1)) <= (others => '0');
				BitCntxDN <= 0;
				if ResetTxFIFORqdxSP = '1' then
					StatexDN <= sRstFIFO;
				elsif CSnxSP = '0' then
					StatexDN <= sFirstByte;
				end if;

			-- first byte determines whether we transmit or receive data
			when sFirstByte =>
				MISOxDO <= TxSRegxDP(7);
				if CSnxSP = '1' then
					StatexDN <= sIdle;
				elsif SCKSRegxSP = "01" then -- rising edge
					RxSRegxDN <= std_logic_vector(shift_left(unsigned(RxSRegxDP), 1));
					RxSRegxDN(0) <= MOSIRegxDP;
				elsif SCKSRegxSP = "10" then -- falling edge
					if BitCntxDP >= 7 then
					-- last edge in byte is falling, so make state transition here
						BitCntxDN <= 0;
						if RxSRegxDP = X"00" then -- tx data
							TxSRegxDN <= FIFOBytesAvailableHighBytexDP;
							StatexDN <= sTxBytesAvailableHighByte;
						else -- receive command
							StatexDN <= sFirstByteRdy;
						end if;			
					else -- shift out
						TxSRegxDN <= std_logic_vector(shift_left(unsigned(TxSRegxDP), 1));
						BitCntxDN <= BitCntxDP +1;
					end if;
				end if;
			
			-- States related to receiving data/commands from Raspberry Pi
			when sFirstByteRdy =>
				ParDatRdyxSO <= '1';
				StatexDN <= sRxData;
			when sRxData =>
				MISOxDO <= '0';
				RxIndxSO <= '1';
				if CSnxSP = '1' then
					StatexDN <= sIdle;
				elsif SCKSRegxSP = "01" then -- rising edge
					RxSRegxDN <= std_logic_vector(shift_left(unsigned(RxSRegxDP), 1));
					RxSRegxDN(0) <= MOSIRegxDP;
				elsif SCKSRegxSP = "10" then -- falling edge
					if BitCntxDP >= 7 then
						StatexDN <= sRxDataRdy;
					else
						BitCntxDN <= BitCntxDP +1;
					end if;
				end if;	
			when sRxDataRdy =>
				BitCntxDN <= 0;
				ParDatRdyxSO <= '1';
				StatexDN <= sRxData;
			
			-- States related to transmitting data to Raspberry Pi
			when sTxBytesAvailableHighByte =>
				MISOxDO <= TxSRegxDP(7);
				if CSnxSP = '1' then
					StatexDN <= sIdle;
				elsif SCKSRegxSP = "10" then -- falling edge
					if BitCntxDP >= 7 then
					-- last edge in byte is falling, so make state transition here
						BitCntxDN <= 0;
						TxSRegxDN <= FIFOOutDataxD;
						StatexDN <= sTxData;
					else -- shift out
						TxSRegxDN <= std_logic_vector(shift_left(unsigned(TxSRegxDP), 1));
						BitCntxDN <= BitCntxDP +1;
					end if;
				end if;
			when sTxData =>
				MISOxDO <= TxSRegxDP(7);
				if CSnxSP = '1' then
					StatexDN <= sIdle;
				elsif SCKSRegxSP = "10" then -- falling edge
					if BitCntxDP >= 7 then
						TxSRegxDN <= FIFOOutDataxD;
						BitCntxDN <= 0;
						TxIndxSO <= '1';
					else -- shift out
						TxSRegxDN <= std_logic_vector(shift_left(unsigned(TxSRegxDP), 1));
						BitCntxDN <= BitCntxDP +1;
					end if;
					-- current addr has been loaded in SReg
					-- prepare next data
					if BitCntxDP = 1 and FIFOEmptyxS = '0' then
						FIFORdAddrxDN <= FIFORdAddrxDP +1;
					end if;
				end if;
				
			-- Misc states
			when sRstFIFO =>
				FIFOWrAddrRstxS <= '1';
				FIFORdAddrxDN <= (others => '0');
				StatexDN <= sIdle;
			when others =>
				StatexDN <= sIdle;
		end case;

		-- ## FIFO related ## 
		FIFOBytesAvailablexD <= FIFOWrAddrxDP - FIFORdAddrxDP;
		
		if FIFORdAddrxDP = FIFOWrAddrxDP then
			FIFOEmptyxS <= '1';
		else
			FIFOEmptyxS <= '0';
		end if;
		
		if FIFOBytesAvailablexD < FIFO_ALMOST_EMPTY_TRSH then
			FIFOAlmostEmptyxSN <= '1';
		else
			FIFOAlmostEmptyxSN <= '0';
		end if;
		
		if (FIFOWrAddrxDP+1+3) = FIFORdAddrxDP then -- 3 spare
			FIFOFullxSN <= '1';
		else
			FIFOFullxSN <= '0';
		end if;
		
		--if FIFOBytesAvailablexD > FIFO_ALMOST_FULL_TRSH then
			--FIFOAlmostFullxS <= '1';
		--else
			--FIFOAlmostFullxS <= '0';
		--end if;
		
		-- FIFO write port
		FIFOMemxDN <= FIFOMemxDP;
		FIFOWrAddrxDN <= FIFOWrAddrxDP;
		if FIFOWrAddrRstxS = '1' then
			FIFOWrAddrxDN <= (others => '0');
		elsif ParDatRdyxSI = '1' and FIFOFullxSP = '0' then
			FIFOWrAddrxDN <= FIFOWrAddrxDP +1;
			FIFOMemxDN(to_integer(FIFOWrAddrxDP)) <= ParDatxDI;
		end if;
		FIFOOutDataxD <= FIFOMemxDP(to_integer(FIFORdAddrxDP));
	end process;

end behavioral;