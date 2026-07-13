-----------------------------------------------------------------------------
-- Wrapper for SCOS image pre-processing
--
-- 
--
-- BU Neurophotonics Center 2026
-- bzim@bu.edu
------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity process_image is
generic(
	BIT_DEPTH	: integer := 12
);
port (
    ClkxCI          : in std_logic;
    ResetxRI        : in std_logic;
	RunxSI			: in std_logic;
    PixValxDI       : in std_logic_vector(4*BIT_DEPTH-1 downto 0);
	PixDarkValxDI	: in std_logic_vector(7 downto 0);
	PixValidxSI		: in std_logic;
    FrameValidxSI   : in std_logic;
    LineValidxSI    : in std_logic;

    PDatxDO	       : out std_logic_vector(7 downto 0);
    PDatValidxSO    : out std_logic;
	RdyForPDatxSI	: in std_logic;
	
	-- debug
	PDatValidFromProcxSO    : out std_logic
);
end process_image;
architecture architecture_process_image of process_image is

	constant N_BYTES_PER_TILE : integer := 8; -- number of output bytes per tile

	type fsmstatetype is (sIdle, sWaitInterFrame, sAcquire, sLoadSReg1, sLoadSReg2, sTxBytes, sPauseAcquire, sPauseLoadSReg1, sPauseLoadSReg2, sPauseTxBytes, sWaitIdle);
	signal StatexDP, StatexDN : fsmstatetype;
	
	signal ByteCntxDP, ByteCntxDN : integer range 0 to N_BYTES_PER_TILE-1;
	signal PixValidxS	: std_logic;
 	signal FrameValidxS : std_logic;
	signal LineValidxS  : std_logic;
	signal RunMSxS : std_logic;

	signal PixSumxD : std_logic_vector(31 downto 0);
	signal PixSqSumxD : std_logic_vector(31 downto 0);
	signal PDatValidxS : std_logic;
	
	signal FIFOAlmostFullxS : std_logic;
	signal FIFOAlmostEmptyxS : std_logic;
	signal FIFOEmptyxS : std_logic;
	signal FIFORdEnxS : std_logic;
	signal FIFOOutDatxD : std_logic_vector(63 downto 0);
	signal SRegxDP, SRegxDN : std_logic_vector(63 downto 0);

	component process_image_out_fifo is
		port(
			clk_i: in std_logic;
			rst_i: in std_logic;
			wr_en_i: in std_logic;
			rd_en_i: in std_logic;
			wr_data_i: in std_logic_vector(63 downto 0);
			full_o: out std_logic;
			empty_o: out std_logic;
			almost_full_o: out std_logic;
			almost_empty_o: out std_logic;
			rd_data_o: out std_logic_vector(63 downto 0)
		);
	end component;

begin
	-- debug
	PDatValidFromProcxSO <= FrameValidxSI;

   -- architecture body
	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			StatexDP <= sIdle;
			ByteCntxDP <= 0;
			SRegxDP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			ByteCntxDP <= ByteCntxDN;
			SRegxDP <= SRegxDN;
		end if;
	end process;
	
	PDatxDO <= SRegxDP(7 downto 0);
	
	PixValidxS	<= '0' when RunMSxS = '0' else PixValidxSI;
	FrameValidxS <= '0' when RunMSxS = '0' else FrameValidxSI;
	LineValidxS  <= '0' when RunMSxS = '0' else LineValidxSI;
	
	p_memless : process(all)
	begin
		RunMSxS <= '0';
		PDatValidxSO <= '0';
		FIFORdEnxS <= '0';
		ByteCntxDN <= ByteCntxDP;
		SRegxDN <= SRegxDP;
		StatexDN <= StatexDP;
		case StatexDP is
			when sIdle =>
				if FIFOEmptyxS = '0' then
					FIFORdEnxS <= '1'; -- flush FIFO
				end if;
				if RunxSI = '1' and FIFOAlmostFullxS = '0' then
					StatexDN <= sWaitInterFrame;
				end if;
			when sWaitInterFrame =>
				if RunxSI = '0'  then
					StatexDN <= sIdle;
				elsif FIFOAlmostFullxS = '0' and FrameValidxSI = '0' then
					StatexDN <= sAcquire;
				end if;
			when sAcquire =>
				RunMSxS <= '1';
				if RunxSI = '0' then
					StatexDN <= sWaitIdle;
				elsif (FIFOAlmostFullxS = '1' and FrameValidxSI = '0') then
					StatexDN <= sPauseAcquire;
				elsif FIFOEmptyxS = '0' then
					FIFORdEnxS <= '1';
					StatexDN <= sLoadSReg1;
				end if;
			when sLoadSReg1 =>
				RunMSxS <= '1';
				StatexDN <= sLoadSReg2;
			when sLoadSReg2 =>
				RunMSxS <= '1';
				ByteCntxDN <= N_BYTES_PER_TILE-1;
				SRegxDN <= FIFOOutDatxD;
				StatexDN <= sTxBytes;
			when sTxBytes =>
				RunMSxS <= '1';
				if RunxSI = '0' then
					StatexDN <= sWaitIdle;
				elsif RdyForPDatxSI = '1' then
					if ByteCntxDP = 0 then
						StatexDN <= sAcquire;
					else
						ByteCntxDN <= ByteCntxDP-1;
						SRegxDN(55 downto 0) <= SRegxDP(63 downto 8);
						SRegxDN(63 downto 56) <= (others => '0'); 
					end if;
					PDatValidxSO <= '1';
				end if;	
			
			when sPauseAcquire =>
				if RunxSI = '0' then
					StatexDN <= sWaitIdle;
				elsif (FIFOAlmostEmptyxS = '1' and FrameValidxSI = '0') then
					StatexDN <= sAcquire;
				elsif FIFOEmptyxS = '0' then
					FIFORdEnxS <= '1';
					StatexDN <= sPauseLoadSReg1;
				end if;
			when sPauseLoadSReg1 =>
				StatexDN <= sPauseLoadSReg2;
			when sPauseLoadSReg2 =>
				ByteCntxDN <= N_BYTES_PER_TILE-1;
				SRegxDN <= FIFOOutDatxD;
				StatexDN <= sPauseTxBytes;
			when sPauseTxBytes =>
				if RunxSI = '0' then
					StatexDN <= sWaitIdle;
				elsif RdyForPDatxSI = '1' then
					if ByteCntxDP = 0 then
						StatexDN <= sPauseAcquire;
					else
						ByteCntxDN <= ByteCntxDP-1;
						SRegxDN(55 downto 0) <= SRegxDP(63 downto 8);
						SRegxDN(63 downto 56) <= (others => '0'); 
					end if;
					PDatValidxSO <= '1';
				end if;
				
			when sWaitIdle =>
				RunMSxS <= '1';
				if FrameValidxSI = '0' then
					StatexDN <= sIdle;
				end if;

			when others =>
				StatexDN <= sIdle;
		end case;
   end process;

	img_mean_std_inst : entity work.img_mean_std
	generic map (
		BIT_DEPTH		=> BIT_DEPTH
	)
	port map (
		ClkxCI          => ClkxCI,
		ResetxRI        => ResetxRI,
		PixValxDI       => PixValxDI,
		PixDarkValxDI	=> PixDarkValxDI,
		PixValidxSI		=> PixValidxS,
		FrameValidxSI   => FrameValidxS,
		LineValidxSI    => LineValidxS,
		PixSumxDO       => PixSumxD,
		PixSqSumxDO     => PixSqSumxD,
		PDatValidxSO    => PDatValidxS
	);
	
	process_image_out_fifo_inst : process_image_out_fifo 
	port map(
		clk_i => ClkxCI,
		rst_i => ResetxRI,
		wr_en_i => PDatValidxS,
		rd_en_i => FIFORdEnxS,
		wr_data_i(31 downto 0) => PixSumxD,
		wr_data_i(63 downto 32) => PixSqSumxD,
		full_o => open,
		empty_o => FIFOEmptyxS,
		almost_full_o => FIFOAlmostFullxS,
		almost_empty_o => FIFOAlmostEmptyxS,
		rd_data_o => FIFOOutDatxD
	);
	
end architecture_process_image;
