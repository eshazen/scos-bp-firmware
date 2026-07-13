-----------------------------------------------------------------------------
-- Top level unit
--
-- Firmware to acquire raw image slices and real-time pre-processing for
-- speckle contrast optical spectroscopy from a AMS MIRA220 sensor.
--
-- BU Neurophotonics Center 2026
-- bzim@bu.edu
------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity mira_test_top is
port (
	Clk48xCI   : IN  std_logic;
    ResetxRI   : IN  std_logic;

	-- Image sensor interface
    MipiRxP     : INOUT  std_logic_vector(1 downto 0);
    MipiRxN     : INOUT  std_logic_vector(1 downto 0);
    MipiRxCkP   : INOUT  std_logic;
    MipiRxCkN   : INOUT  std_logic;
	
	-- FTDI UART USB interface
	UartRTSntoFPGAxDI : in  std_logic;
	UartCTSntoFTDIxDO : out  std_logic;
	UartFPGAtoFTDIxDO : out  std_logic;
	UartFTDItoFPGAxDI : in std_logic;
	
	-- Misc / Debug
    DebugDataxDO    : OUT  std_logic_vector(11 downto 0);
	LEDxSO : out std_logic_vector(13 downto 0)
);
end mira_test_top;

architecture architecture_mira_test_top of mira_test_top is

	constant FW_VER : integer := 1;
	constant BIT_DEPTH : integer := 10; -- Image data bit depth. Supported: 8,10,12. Mira config must match
	constant UART_CLK_DIV : integer := 8; -- Determines UART baud rate. 96 / 8 = 12 MBPS
	constant N_CFG_REG_ADDR_BITS : integer := 4; -- determines number of available config registers
	constant N_CMD_BYTES : integer := 2; -- number of bytes to read/write config register

	signal ClkxC : std_logic;
	signal PLLLockxS : std_logic;

	signal ClkCntxDP, ClkCntxDN : integer range 0 to 47999999; -- only for blinking LED
	-- ## Configuration Register related ##
	type cfgreg_type is array (0 to N_CFG_REG_ADDR_BITS**2-1) of std_logic_vector(7 downto 0);
	signal CfgRegxDP, CfgRegxDN : cfgreg_type;
	
	type cfgfsmsreg_type is array (0 to N_CMD_BYTES-1) of std_logic_vector(7 downto 0);
	signal CfgFSMSRegxDP, CfgFSMSRegxDN : cfgfsmsreg_type;
	
	type cfgfsmstate_type is (sIdle, sRxBytes, sDecodeCmd, sTxHeader, sTxReg);
	signal CfgStatexDP, CfgStatexDN : cfgfsmstate_type;

	signal CfgByteCntxDP, CfgByteCntxDN : integer range 0 to N_CMD_BYTES-1;
	signal CfgPDatOutxD : std_logic_vector(7 downto 0);
	signal CfgPDatOutValidxS : std_logic;
	signal RdyForCfgPDatxS : std_logic;
	signal CfgPDatInxD : std_logic_vector(7 downto 0);
	signal CfgPDatInValidxS : std_logic;

	-- ## Pixel Data related ##
	signal PixDataxD : std_logic_vector(4*BIT_DEPTH-1 downto 0); -- 2 MIPI lanes * 16x gearing = up to 4 pixels per clock
	signal PixDataValidxS : std_logic;
	signal InFramexS : std_logic;
	signal InLinexS : std_logic;
	
	-- ## UART / Control logic related ##
	signal UartFPGAtoFTDIxD : std_logic;
	
	signal PDatOutTxRdyxS : std_logic;
	signal PDatOutValidxS : std_logic;
	signal PDatOutxD : std_logic_vector(7 downto 0);
	
	signal FrameTrigxS : std_logic;
	signal RdyForFrameDatxS : std_logic;
	signal FrameDatxD : std_logic_vector(7 downto 0);
	signal FrameDatValidxS : std_logic;
	
	signal ProcDatxD : std_logic_vector(7 downto 0);
	signal ProcDatValidxS : std_logic;
	signal RdyForProcDatxS : std_logic;
	signal RunProcxS : std_logic;
	
	component main_pll is
    port(
        clki_i: in std_logic;
        clkop_o: out std_logic;
        lock_o: out std_logic
    );
	end component;

begin
	assert N_CFG_REG_ADDR_BITS < 8 severity error; -- ensure <=7 bit address for cfg reg. high bit is r/w
	
	-- config FSM
	-- FSM used to write/read configuration registers
	p_cfg_memzing : process (ClkxC, ResetxRI)
	begin
		if (ResetxRI = '1') then
			CfgStatexDP <= sIdle;
			CfgFSMSRegxDP <= (others => (others => '0'));
			CfgRegxDP <= (others => (others => '0'));
			CfgByteCntxDP <= 0;
		elsif (rising_edge(ClkxC)) then
			CfgStatexDP <= CfgStatexDN;
			CfgFSMSRegxDP <= CfgFSMSRegxDN;
			CfgRegxDP <= CfgRegxDN;
			CfgByteCntxDP <= CfgByteCntxDN;
		end if;
	end process;

	p_cfg_memless : process(all)
	begin
		CfgStatexDN <= CfgStatexDP;
		CfgFSMSRegxDN <= CfgFSMSRegxDP;
		CfgRegxDN <= CfgRegxDP;
		CfgByteCntxDN <= CfgByteCntxDP;
		CfgPDatOutxD <= x"FE";
		CfgPDatOutValidxS <= '0';
		
		case CfgStatexDP is
			when sIdle =>
				CfgByteCntxDN <= N_CMD_BYTES-1;
				if (CfgPDatInValidxS = '1' and CfgPDatInxD = x"FE") then -- all commands must start with 0xFE
					CfgStatexDN <= sRxBytes;
				end if;
			when sRxBytes =>
				if CfgPDatInValidxS = '1' then
					CfgByteCntxDN <= CfgByteCntxDP -1;
					CfgFSMSRegxDN <= CfgFSMSRegxDP(1 to N_CMD_BYTES-1) & CfgPDatInxD; -- shift in byte
					if CfgByteCntxDP = 0 then
						CfgStatexDN <= sDecodeCmd;
					end if;
				end if;
			when sDecodeCmd =>
				if CfgFSMSRegxDP(0)(7) = '1' then -- write register
					CfgRegxDN(to_integer(unsigned(CfgFSMSRegxDP(0)(N_CFG_REG_ADDR_BITS-1 downto 0)))) <= CfgFSMSRegxDP(1);
					CfgStatexDN <= sIdle;
				else -- read register
					CfgStatexDN <= sTxHeader;
				end if;
			when sTxHeader =>
				CfgPDatOutxD <= x"FD"; -- all replies start with 0xFD
				if RdyForCfgPDatxS = '1' then
					CfgPDatOutValidxS <= '1';
					CfgStatexDN <= sTxReg;
				end if;
			when sTxReg =>
				CfgPDatOutxD <= CfgRegxDP(to_integer(unsigned(CfgFSMSRegxDP(0)(N_CFG_REG_ADDR_BITS-1 downto 0))));
				if RdyForCfgPDatxS = '1' then
					CfgPDatOutValidxS <= '1';
					CfgStatexDN <= sIdle;
				end if;
				
			when others =>
				CfgStatexDN <= sIdle;
		end case;
		
		-- Constant registers for information
		CfgRegxDN(14) <= std_logic_vector(to_unsigned(BIT_DEPTH, 8));
		CfgRegxDN(15) <= std_logic_vector(to_unsigned(FW_VER, 8));		
	end process;
	
	-- Configuration Register Map -- CfgReg
	-- ( 0) - Status Bits: (0) Run Img Processing, (1) Trigger Raw Frame, (7) Reset FIFOs
	-- ( 1) - Select Data Souce: 0x00 CfgReg, 0x01 Img Processing, 0x02 Raw Frame
	-- ( 2) - Img Processing : Dark level subtraction value
	-- ( 3) - Spare
	-- ( 4) - Spare
	-- ( 5) - Raw Frame: Index of image slice to be acquired
	-- ( 6) - Raw Frame: Number of frames to be summed
	-- (7-13) - Spare
	-- (14) - Bit Depth setting of this bitstream 
	-- (15) - Firmware version
	
	
	-- this MUX selects which datastream is sent to the computer 
	p_acq_mux_memless : process(all)
	begin
	
		RunProcxS <= CfgRegxDP(0)(0);
		FrameTrigxS <= CfgRegxDP(0)(1);
		
		RdyForCfgPDatxS <= '0';
		RdyForProcDatxS <= '0';
		RdyForFrameDatxS <= '0';

		case CfgRegxDP(1) is
			when x"00" => -- readback from CfgReg
				RdyForCfgPDatxS <= PDatOutTxRdyxS;
				PDatOutValidxS <= CfgPDatOutValidxS;
				PDatOutxD <= CfgPDatOutxD;
			when x"01" => -- data from process_image 
				RdyForProcDatxS <= PDatOutTxRdyxS;
				PDatOutValidxS <= ProcDatValidxS;
				PDatOutxD <= ProcDatxD;
			when x"02" => -- data from frame buffer
				RdyForFrameDatxS <= PDatOutTxRdyxS;
				PDatOutValidxS <= FrameDatValidxS;
				PDatOutxD <= FrameDatxD;
			when others => -- same as x"00"
				RdyForCfgPDatxS <= PDatOutTxRdyxS;
				PDatOutValidxS <= CfgPDatOutValidxS;
				PDatOutxD <= CfgPDatOutxD;
		end case;
	end process;
	
	
	-- process just for blinking LED
	p_memzing : process (ClkxC, ResetxRI)
	begin
		if (ResetxRI = '1') then
			ClkCntxDP <= 0;
		elsif (rising_edge(ClkxC)) then
			ClkCntxDP <= ClkCntxDN;
		end if;
	end process;
	
	-- debug signals
	ClkCntxDN <= ClkCntxDP + 1 when ClkCntxDP < 47999999 else 0;
	LEDxSO(10) <= '0' when ClkCntxDP < 12000000 else '1';
	LEDxSO(11) <= '0' when ClkCntxDP > 36000000 else '1';
	--LEDxSO(2) <= '1';
	--LEDxSO(3) <= '1';
	--LEDxSO(4) <= UartRTSntoFPGAxDI;
	--LEDxSO(11 downto 5) <= (others => '1');
	LEDxSO(7 downto 0) <= not CfgRegxDP(10);
	LEDxSO(9 downto 8) <= (others => '1');
	LEDxSO(12) <= not RunProcxS;
	LEDxSO(13) <= not PLLLockxS ;
	
	DebugDataxDO(0) <= UartFPGAtoFTDIxD;
	DebugDataxDO(1) <= UartFTDItoFPGAxDI;
	DebugDataxDO(2) <= UartRTSntoFPGAxDI;
	DebugDataxDO(3) <= InFramexS;
	--DebugDataxDO(4) <= FrameTrigxS;
	--DebugDataxDO(5) <= UartParDatValidxS;
	DebugDataxDO(11 downto 4) <= (others => '0');
	
	-- ## component instances ##
	mipi_rx_inst : entity work.mipi_rx
	generic map(
		BIT_DEPTH => BIT_DEPTH
	)
	port map(
		ClkxCI => ClkxC,
		ResetxRI => ResetxRI,
		MipiRxP => MipiRxP,
		MipiRxN => MipiRxN,
		MipiRxCkP => MipiRxCkP,
		MipiRxCkN => MipiRxCkN,
		PixDataxDO => PixDataxD,
		PixDataValidxSO => PixDataValidxS,
		InLinexSO => InLinexS,
		InFramexSO => InFramexS,
		DebugDataxDO => open
	);
	
	process_image_inst : entity work.process_image
	generic map(
		BIT_DEPTH => BIT_DEPTH
	)
	port map(
		ClkxCI => ClkxC,
		ResetxRI => ResetxRI,
		RunxSI => RunProcxS,
		PixValxDI => PixDataxD,
		PixDarkValxDI => CfgRegxDP(2),
		PixValidxSI => PixDataValidxS,
		FrameValidxSI => InFramexS,
		LineValidxSI => InLinexS,

		PDatxDO => ProcDatxD,
		PDatValidxSO => ProcDatValidxS,
		RdyForPDatxSI => RdyForProcDatxS,
		-- debug
		PDatValidFromProcxSO => open
	);

	frame_buf_inst : entity work.frame_buf
	generic map(
		BIT_DEPTH => BIT_DEPTH
	)
    port map(
        ClkxCI          => ClkxC,
        ResetxRI        => ResetxRI,
        PixDatxDI       => PixDataxD,
        PixDatValidxSI  => PixDataValidxS,
        InFramexSI      => InFramexS,
        TrigxSI         => FrameTrigxS,
		SliceSelxDI	   => CfgRegxDP(5),
		SumCntxDI		=> CfgRegxDP(6),
        UartRdyxSI      => RdyForFrameDatxS,
        PDatxDO         => FrameDatxD,
        PDatValidxSO    => FrameDatValidxS
    );
	
    uart_tx_inst : entity work.uart_tx
	generic map(
		TX_CLK_DIV      => UART_CLK_DIV
	)
	port map(
		ClkxCI 	 	    => ClkxC,
		ResetxRI 	    => ResetxRI,
		CTSnxSI		    => UartRTSntoFPGAxDI,
		SerDatxDO 	    => UartFPGAtoFTDIxD,
		UartRdyxSO      => PDatOutTxRdyxS,
		ParDatValidxSI  => PDatOutValidxS,
		ParDatxDI 	    => PDatOutxD
	);
	
	uart_rx_inst : entity work.uart_rx
	generic map(
		RX_CLK_DIV	=> UART_CLK_DIV
	)
	port map(
		ClkxCI 		=> ClkxC,
		ResetxRI	=> ResetxRI,
		SerDatxDI 	=> UartFTDItoFPGAxDI,
		ParDatxDO 	=> CfgPDatInxD,
		ParDatRdyxSO => CfgPDatInValidxS,
		DebugxSO 	=> open
	);
	UartCTSntoFTDIxDO <= '0'; -- FPGA processes commands from PC nearly instantly, no flow control required.
	UartFPGAtoFTDIxDO <= UartFPGAtoFTDIxD;
	
	main_pll_inst : main_pll port map(
		clki_i => Clk48xCI,
		clkop_o => ClkxC,
		lock_o => PLLLockxS
	);

end architecture_mira_test_top;
