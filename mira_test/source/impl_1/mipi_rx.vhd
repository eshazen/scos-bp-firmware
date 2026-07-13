-----------------------------------------------------------------------------
-- MIPI receiver unit
--
-- Instantiates MIPI DPHY receiver, cross-clock FIFO, and minimal MIPI CSI decoder.
--
-- BU Neurophotonics Center 2026
-- bzim@bu.edu
------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;

entity mipi_rx is
generic (
	BIT_DEPTH  : integer := 12
);
port (
	ClkxCI   : IN  std_logic;
    ResetxRI   : IN  std_logic;
    MipiRxP     : INOUT  std_logic_vector(1 downto 0);
    MipiRxN     : INOUT  std_logic_vector(1 downto 0);
    MipiRxCkP   : INOUT  std_logic;
    MipiRxCkN   : INOUT  std_logic;
    PixDataxDO  : OUT  std_logic_vector(4*BIT_DEPTH-1 downto 0);
    PixDataValidxSO : OUT  std_logic;
	InLinexSO : OUT  std_logic;
	InFramexSO : OUT  std_logic;
	DebugDataxDO    : OUT  std_logic_vector(11 downto 0)
);
end mipi_rx;

architecture architecture_mipi_rx of mipi_rx is
	
	constant N_LINE_BYTES : integer := 1600/4 * BIT_DEPTH/8;
	
	-- D-PHY reset / start up signals
    signal DPhyPDxSP, DPhyPDxSN : std_logic;
	signal DPhySyncRstxSP, DPhySyncRstxSN : std_logic;
	signal DPhyLmmiRstNxSP, DPhyLmmiRstNxSN : std_logic;
	
	constant MAX_START_DELAY : integer := 12000;
	signal StartDelayCntxDP, StartDelayCntxDN : integer range 0 to MAX_START_DELAY;
	
	-- D-PHY data, Mira clock domain
	signal DPhyPDatxD : std_logic_vector(31 downto 0);
	signal DPhySyncxS : std_logic_vector(1 downto 0);
	signal DPhyClkxC, DPhyClkxCN : std_logic;
	signal DPhyReadyxS : std_logic;
	
	-- cross-clock FIFO signals
	signal FifoPDatxD : std_logic_vector(31 downto 0);
	signal FifoSyncxS : std_logic_vector(1 downto 0);
	signal FifoEmptyxS, FifoFullxS : std_logic;
	signal FifoWrEnxS, FifoRdEnxS : std_logic;
	signal FifoValidxSP, FifoValidxSN : std_logic_vector(1 downto 0);
	
	-- MIPI CSI decoder signals
	type fsmstatetype is (sWaitFSSync, sFSDI, sWaitLSSync, sLSDI, sWaitLData, sReadLDataFirst, sReadLData0, sReadLData1, sReadLData2, sReadLData3, sReadLData4, sReadLDataLast);
	signal StatexDP, StatexDN : fsmstatetype;
	signal ByteCntxDP, ByteCntxDN : integer range 0 to N_LINE_BYTES-1;
	
    signal PixDataxDP, PixDataxDN : std_logic_vector(PixDataxDO'range);
	
	function get_pixdatapre_width(bit_depth_in:integer) 
        return integer is
    begin
        if bit_depth_in = 8 then
            return 1; -- pre storage not needed for RAW8
		elsif bit_depth_in = 10 then
            return 24;
        elsif bit_depth_in = 12 then
            return 16;
		else
			assert false report "BIT_DEPTH not supported" severity error;
			return 0;
        end if;
    end function;
	
	signal PixDataPrexDP, PixDataPrexDN : std_logic_vector(get_pixdatapre_width(BIT_DEPTH)-1 downto 0);
	
	component mipi_dphy_rx is
    port(
        sync_clk_i: in std_logic;
        sync_rst_i: in std_logic;
        lmmi_clk_i: in std_logic;
        lmmi_resetn_i: in std_logic;
        lmmi_wdata_i: in std_logic_vector(3 downto 0);
        lmmi_wr_rdn_i: in std_logic;
        lmmi_offset_i: in std_logic_vector(4 downto 0);
        lmmi_request_i: in std_logic;
        lmmi_ready_o: out std_logic;
        lmmi_rdata_o: out std_logic_vector(3 downto 0);
        lmmi_rdata_valid_o: out std_logic;
        hs_rx_data_o: out std_logic_vector(31 downto 0);
        hs_rx_data_sync_o: out std_logic_vector(1 downto 0);
        clk_p_io: inout std_logic;
        clk_n_io: inout std_logic;
        data_p_io: inout std_logic_vector(1 downto 0);
        data_n_io: inout std_logic_vector(1 downto 0);
        pd_dphy_i: in std_logic;
        clk_byte_o: out std_logic;
        ready_o: out std_logic
    );
	end component;
	
	component mipi_cross_clk_fifo is
    port(
        wr_clk_i: in std_logic;
        rd_clk_i: in std_logic;
        rst_i: in std_logic;
        rp_rst_i: in std_logic;
        wr_en_i: in std_logic;
        rd_en_i: in std_logic;
        wr_data_i: in std_logic_vector(33 downto 0);
        full_o: out std_logic;
        empty_o: out std_logic;
        rd_data_o: out std_logic_vector(33 downto 0)
    );
	end component;

begin

	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			StartDelayCntxDP <= 0;
			DPhyPDxSP <= '1';
			DPhySyncRstxSP <= '1';
			DPhyLmmiRstNxSP <= '0';
			FifoValidxSP <= (others => '0');
			StatexDP <= sWaitFSSync;
			ByteCntxDP <= 0;
		elsif (rising_edge(ClkxCI)) then
			StartDelayCntxDP <= StartDelayCntxDN;
			DPhyPDxSP <= DPhyPDxSN;
			DPhySyncRstxSP <= DPhySyncRstxSN;
			DPhyLmmiRstNxSP <= DPhyLmmiRstNxSN;
			FifoValidxSP <= FifoValidxSN;
			StatexDP <= StatexDN;
			ByteCntxDP <= ByteCntxDN ;
		end if;
		if (rising_edge(ClkxCI)) then
			PixDataxDP <= PixDataxDN;
			PixDataPrexDP <= PixDataPrexDN;
		end if;
	end process;

	-- reset signals for D-PHY
	StartDelayCntxDN <= StartDelayCntxDP + 1 when StartDelayCntxDP < MAX_START_DELAY else MAX_START_DELAY;
	DPhySyncRstxSN <= '1' when StartDelayCntxDP < 10000 else '0';
	DPhyPDxSN <= '1' when StartDelayCntxDP < 2000 else '0';
	DPhyLmmiRstNxSN <= '0' when StartDelayCntxDP < 11000 else '1';
	DPhyClkxCN <= not DPhyClkxC;
	
	g_memless : if BIT_DEPTH=8 generate -- RAW8 decoder
	
		p_memless : process (all)
		begin
			-- if new word available in cross clock FIFO, read it
			if FifoEmptyxS = '1' then
				FifoRdEnxS <= '0';
				FifoValidxSN(1) <= '0';
			else
				FifoRdEnxS <= '1';
				FifoValidxSN(1) <= '1';
			end if;
			FifoValidxSN(0) <= FifoValidxSP(1);
			
			-- decoder state machine
			StatexDN <= StatexDP;
			ByteCntxDN <= ByteCntxDP; 
			PixDataxDO <= PixDataxDP;
			PixDataxDN <= PixDataxDP;
			PixDataPrexDN <= PixDataPrexDP;
			PixDataValidxSO <= '0';
			InLinexSO <= '0';
			InFramexSO <= '0';
			case StatexDP is
				when sWaitFSSync => -- wait for frame start sync
					if FifoValidxSP(0) = '1' and FifoSyncxS = "11" then -- TBD: what happens if lanes are out of sync??
						StatexDN <= sFSDI;
					end if;
				when sFSDI => -- check frame start data identifier
					if FifoValidxSP(0) = '1' and FifoPDatxD(7 downto 0) = x"00" then
						StatexDN <= sWaitLSSync;
					elsif FifoValidxSP(0) = '1' then -- unexpected data identifier
						StatexDN <= sWaitFSSync; 
					end if;
				when sWaitLSSync => -- wait for line start sync
					InFramexSO <= '1';
					if FifoValidxSP(0) = '1' and FifoSyncxS = "11" then
						StatexDN <= sLSDI;
					end if;
				when sLSDI => -- check line start data identifier
					InFramexSO <= '1';
					if FifoValidxSP(0) = '1' then
						if FifoPDatxD(7 downto 0) = x"2A" then -- correct data identifier 0x2A == RAW8, 0x2B == RAW10, 0x2C == RAW12
							StatexDN <= sReadLDataFirst;
						elsif FifoPDatxD(7 downto 0) = x"01" then -- frame end data identifier
							StatexDN <= sWaitFSSync;
						else -- unexpected data identifier
							StatexDN <= sWaitFSSync;
						end if;
					end if;
					ByteCntxDN <= N_LINE_BYTES -1;
					
				when sReadLDataFirst =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 7 downto  0) <= FifoPDatxD( 7 downto  0);-- 1st pixel
						PixDataxDN(15 downto  8) <= FifoPDatxD(23 downto 16);-- 2nd pixel
						PixDataxDN(23 downto 16) <= FifoPDatxD(15 downto  8);-- 3rd pixel
						PixDataxDN(31 downto 24) <= FifoPDatxD(31 downto 24);-- 4th pixel
						ByteCntxDN <= ByteCntxDP - 1;
						StatexDN <= sReadLData0;
					end if;

				when sReadLData0 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 7 downto  0) <= FifoPDatxD( 7 downto  0);-- 1st pixel
						PixDataxDN(15 downto  8) <= FifoPDatxD(23 downto 16);-- 2nd pixel
						PixDataxDN(23 downto 16) <= FifoPDatxD(15 downto  8);-- 3rd pixel
						PixDataxDN(31 downto 24) <= FifoPDatxD(31 downto 24);-- 4th pixel
						PixDataValidxSO <= '1';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData0;
						end if;
					end if;

				when sReadLDataLast =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					PixDataValidxSO <= '1';
					StatexDN <= sWaitLSSync;
					
				when others =>
					StatexDN <= sWaitFSSync;
			end case;
				
		end process;
	
	elsif BIT_DEPTH=10 generate  -- RAW10 decoder
		p_memless : process (all)
		begin
			if FifoEmptyxS = '1' then
				FifoRdEnxS <= '0';
				FifoValidxSN(1) <= '0';
			else
				FifoRdEnxS <= '1';
				FifoValidxSN(1) <= '1';
			end if;
			FifoValidxSN(0) <= FifoValidxSP(1);
			StatexDN <= StatexDP;
			ByteCntxDN <= ByteCntxDP; 
			PixDataxDO <= PixDataxDP;
			PixDataxDN <= PixDataxDP;
			PixDataPrexDN <= PixDataPrexDP;
			PixDataValidxSO <= '0';
			InLinexSO <= '0';
			InFramexSO <= '0';
			
			case StatexDP is
				when sWaitFSSync => -- wait for frame start sync
					if FifoValidxSP(0) = '1' and FifoSyncxS = "11" then -- what happens if lanes are out of sync??
						StatexDN <= sFSDI;
					end if;
				when sFSDI => -- check frame start data identifier
					if FifoValidxSP(0) = '1' and FifoPDatxD(7 downto 0) = x"00" then
						StatexDN <= sWaitLSSync;
					elsif FifoValidxSP(0) = '1' then -- unexpected data identifier
						StatexDN <= sWaitFSSync; 
					end if;
				when sWaitLSSync => -- wait for line start sync
					InFramexSO <= '1';
					if FifoValidxSP(0) = '1' and FifoSyncxS = "11" then
						StatexDN <= sLSDI;
					end if;
				when sLSDI => -- check line start data identifier
					InFramexSO <= '1';
					if FifoValidxSP(0) = '1' then
						if FifoPDatxD(7 downto 0) = x"2B" then -- correct data identifier 0x2A == RAW8, 0x2B == RAW10, 0x2C == RAW12
							StatexDN <= sReadLDataFirst;
						elsif FifoPDatxD(7 downto 0) = x"01" then -- frame end data identifier
							StatexDN <= sWaitFSSync;
						else -- unexpected data identifier
							StatexDN <= sWaitFSSync;
						end if;
					end if;
					ByteCntxDN <= N_LINE_BYTES -1;
				when sReadLDataFirst =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 9 downto  2) <= FifoPDatxD( 7 downto  0);-- 1st pixel MSB
						PixDataxDN(19 downto 12) <= FifoPDatxD(23 downto 16);-- 2nd pixel MSB
						PixDataxDN(29 downto 22) <= FifoPDatxD(15 downto  8);-- 3rd pixel MSB
						PixDataxDN(39 downto 32) <= FifoPDatxD(31 downto 24);-- 4th pixel MSB
						ByteCntxDN <= ByteCntxDP - 1;
						StatexDN <= sReadLData1;
					end if;
				when sReadLData0 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 9 downto  2) <= FifoPDatxD( 7 downto  0);-- 1st pixel MSB
						PixDataxDN(19 downto 12) <= FifoPDatxD(23 downto 16);-- 2nd pixel MSB
						PixDataxDN(29 downto 22) <= FifoPDatxD(15 downto  8);-- 3rd pixel MSB
						PixDataxDN(39 downto 32) <= FifoPDatxD(31 downto 24);-- 4th pixel MSB
						PixDataValidxSO <= '1';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData1;
						end if;
					end if;
				when sReadLData1 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 1 downto  0) <= FifoPDatxD( 1 downto  0);-- 1st pixel LSB
						PixDataxDN(11 downto 10) <= FifoPDatxD( 3 downto  2);-- 2nd pixel LSB
						PixDataxDN(21 downto 20) <= FifoPDatxD( 5 downto  4);-- 3rd pixel LSB
						PixDataxDN(31 downto 30) <= FifoPDatxD( 7 downto  6);-- 4th pixel LSB
						PixDataPrexDN( 7 downto  0) <= FifoPDatxD(23 downto 16);-- 1st pixel MSB pre
						PixDataPrexDN(15 downto  8) <= FifoPDatxD(15 downto  8);-- 2nd pixel MSB pre
						PixDataPrexDN(23 downto 16) <= FifoPDatxD(31 downto 24);-- 3rd pixel MSB pre
						PixDataValidxSO <= '0';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData2;
						end if;
					end if;
				when sReadLData2 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 1 downto  0) <= FifoPDatxD(17 downto 16);-- 1st pixel LSB
						PixDataxDN(11 downto 10) <= FifoPDatxD(19 downto 18);-- 2nd pixel LSB
						PixDataxDN(21 downto 20) <= FifoPDatxD(21 downto 20);-- 3rd pixel LSB
						PixDataxDN(31 downto 30) <= FifoPDatxD(23 downto 22);-- 4th pixel LSB
						PixDataxDN( 9 downto  2) <= PixDataPrexDP( 7 downto  0);-- 1st pixel MSB
						PixDataxDN(19 downto 12) <= PixDataPrexDP(15 downto  8);-- 2nd pixel MSB
						PixDataxDN(29 downto 22) <= PixDataPrexDP(23 downto 16);-- 3rd pixel MSB
						PixDataxDN(39 downto 32) <= FifoPDatxD( 7 downto  0);-- 4th pixel MSB
						PixDataPrexDN( 7 downto  0) <= FifoPDatxD(15 downto  8);-- 1st pixel MSB pre
						PixDataPrexDN(15 downto  8) <= FifoPDatxD(31 downto 24);-- 2nd pixel MSB pre
						PixDataValidxSO <= '1';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData3;
						end if;
					end if;
				when sReadLData3 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 1 downto  0) <= FifoPDatxD( 9 downto  8);-- 1st pixel LSB
						PixDataxDN(11 downto 10) <= FifoPDatxD(11 downto 10);-- 2nd pixel LSB
						PixDataxDN(21 downto 20) <= FifoPDatxD(13 downto 12);-- 3rd pixel LSB
						PixDataxDN(31 downto 30) <= FifoPDatxD(15 downto 14);-- 4th pixel LSB
						PixDataxDN( 9 downto  2) <= PixDataPrexDP( 7 downto  0);-- 1st pixel MSB
						PixDataxDN(19 downto 12) <= PixDataPrexDP(15 downto  8);-- 2nd pixel MSB
						PixDataxDN(29 downto 22) <= FifoPDatxD( 7 downto  0);-- 3rd pixel MSB
						PixDataxDN(39 downto 32) <= FifoPDatxD(23 downto 16);-- 4th pixel MSB
						PixDataPrexDN( 7 downto  0) <= FifoPDatxD(31 downto 24);-- 1st pixel MSB pre
						PixDataValidxSO <= '1';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData4;
						end if;
					end if;
				when sReadLData4 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN( 1 downto  0) <= FifoPDatxD(25 downto 24);-- 1st pixel LSB
						PixDataxDN(11 downto 10) <= FifoPDatxD(27 downto 26);-- 2nd pixel LSB
						PixDataxDN(21 downto 20) <= FifoPDatxD(29 downto 28);-- 3rd pixel LSB
						PixDataxDN(31 downto 30) <= FifoPDatxD(31 downto 30);-- 4th pixel LSB
						PixDataxDN( 9 downto  2) <= PixDataPrexDP( 7 downto  0);-- 1st pixel MSB
						PixDataxDN(19 downto 12) <= FifoPDatxD( 7 downto  0);-- 2nd pixel MSB
						PixDataxDN(29 downto 22) <= FifoPDatxD(23 downto 16);-- 3rd pixel MSB
						PixDataxDN(39 downto 32) <= FifoPDatxD(15 downto  8);-- 4th pixel MSB
						PixDataValidxSO <= '1';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData0;
						end if;
					end if;
				when sReadLDataLast =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					PixDataValidxSO <= '1';
					StatexDN <= sWaitLSSync;
					
				when others =>
					StatexDN <= sWaitFSSync;
			end case;
				
		end process;
	
	
	elsif BIT_DEPTH=12 generate  -- RAW12 decoder
	
		p_memless : process (all)
		begin
			if FifoEmptyxS = '1' then
				FifoRdEnxS <= '0';
				FifoValidxSN(1) <= '0';
			else
				FifoRdEnxS <= '1';
				FifoValidxSN(1) <= '1';
			end if;
			FifoValidxSN(0) <= FifoValidxSP(1);
			StatexDN <= StatexDP;
			ByteCntxDN <= ByteCntxDP; 
			PixDataxDO <= PixDataxDP;
			PixDataxDN <= PixDataxDP;
			PixDataPrexDN <= PixDataPrexDP;
			PixDataValidxSO <= '0';
			InLinexSO <= '0';
			InFramexSO <= '0';
			
			case StatexDP is
				when sWaitFSSync => -- wait for frame start sync
					if FifoValidxSP(0) = '1' and FifoSyncxS = "11" then -- what happens if lanes are out of sync??
						StatexDN <= sFSDI;
					end if;
				when sFSDI => -- check frame start data identifier
					if FifoValidxSP(0) = '1' and FifoPDatxD(7 downto 0) = x"00" then
						StatexDN <= sWaitLSSync;
					elsif FifoValidxSP(0) = '1' then -- unexpected data identifier
						StatexDN <= sWaitFSSync; 
					end if;
				when sWaitLSSync => -- wait for line start sync
					InFramexSO <= '1';
					if FifoValidxSP(0) = '1' and FifoSyncxS = "11" then
						StatexDN <= sLSDI;
					end if;
				when sLSDI => -- check line start data identifier
					InFramexSO <= '1';
					if FifoValidxSP(0) = '1' then
						if FifoPDatxD(7 downto 0) = x"2C" then -- correct data identifier 0x2A == RAW8, 0x2B == RAW10, 0x2C == RAW12
							StatexDN <= sReadLDataFirst;
						elsif FifoPDatxD(7 downto 0) = x"01" then -- frame end data identifier
							StatexDN <= sWaitFSSync;
						else -- unexpected data identifier
							StatexDN <= sWaitFSSync;
						end if;
					end if;
					ByteCntxDN <= N_LINE_BYTES -1;
				when sReadLDataFirst =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN(11 downto  4) <= FifoPDatxD( 7 downto  0);-- 1st pixel MSB
						PixDataxDN( 3 downto  0) <= FifoPDatxD(11 downto  8);-- 1st pixel LSB
						PixDataxDN(23 downto 16) <= FifoPDatxD(23 downto 16);-- 2nd pixel MSB
						PixDataxDN(15 downto 12) <= FifoPDatxD(15 downto 12);-- 2nd pixel LSB
						PixDataxDN(35 downto 28) <= FifoPDatxD(31 downto 24);-- 3rd pixel MSB
						ByteCntxDN <= ByteCntxDP - 1;
						StatexDN <= sReadLData1;
					end if;
				when sReadLData0 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN(11 downto  4) <= FifoPDatxD( 7 downto  0);-- 1st pixel MSB
						PixDataxDN( 3 downto  0) <= FifoPDatxD(11 downto  8);-- 1st pixel LSB
						PixDataxDN(23 downto 16) <= FifoPDatxD(23 downto 16);-- 2nd pixel MSB
						PixDataxDN(15 downto 12) <= FifoPDatxD(15 downto 12);-- 2nd pixel LSB
						PixDataxDN(35 downto 28) <= FifoPDatxD(31 downto 24);-- 3rd pixel MSB
						PixDataValidxSO <= '1';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData1;
						end if;
					end if;
				when sReadLData1 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN(27 downto 24)   <= FifoPDatxD(19 downto 16);-- 3rd pixel LSB
						PixDataxDN(47 downto 40)   <= FifoPDatxD( 7 downto  0);-- 4th pixel MSB
						PixDataxDN(39 downto 36)   <= FifoPDatxD(23 downto 20);-- 4th pixel LSB
						PixDataPrexDN( 7 downto 0) <= FifoPDatxD(15 downto 8);-- 1st pixel MSB pre
						PixDataPrexDN(15 downto 8) <= FifoPDatxD(31 downto 24);-- 2nd pixel MSB pre
						PixDataValidxSO <= '0';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData2;
						end if;
					end if;
				when sReadLData2 =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					if FifoValidxSP(0) = '1' then
						PixDataxDN(11 downto  4) <= PixDataPrexDP( 7 downto  0);-- 1st pixel MSB
						PixDataxDN( 3 downto  0) <= FifoPDatxD( 3 downto  0);-- 1st pixel LSB
						PixDataxDN(23 downto 16) <= PixDataPrexDP(15 downto 8);-- 2nd pixel MSB
						PixDataxDN(15 downto 12) <= FifoPDatxD( 7 downto  4);-- 2nd pixel LSB
						PixDataxDN(35 downto 28) <= FifoPDatxD(23 downto 16);-- 3rd pixel MSB
						PixDataxDN(27 downto 24) <= FifoPDatxD(27 downto 24);-- 3rd pixel LSB
						PixDataxDN(47 downto 40) <= FifoPDatxD(15 downto  8);-- 4th pixel MSB
						PixDataxDN(39 downto 36) <= FifoPDatxD(31 downto 28);-- 4th pixel LSB
						PixDataValidxSO <= '1';
						if ByteCntxDP = 0 then
							StatexDN <= sReadLDataLast;
						else
							ByteCntxDN <= ByteCntxDP - 1;
							StatexDN <= sReadLData0;
						end if;
					end if;
				when sReadLDataLast =>
					InFramexSO <= '1';
					InLinexSO <= '1';
					PixDataValidxSO <= '1';
					StatexDN <= sWaitLSSync;
					
				when others =>
					StatexDN <= sWaitFSSync;
			end case;
				
		end process;
	end generate g_memless;
	
	DebugDataxDO(0) <= DPhyClkxC;
	DebugDataxDO(2 downto 1) <= DPhySyncxS;
	DebugDataxDO(3) <= '0';
	DebugDataxDO(11 downto 4) <= DPhyPDatxD(7 downto 0);
	--DebugDataxDO(11 downto 8) <= DPhyPDatxD(11 downto 8);

	mipi_dphy_rx_inst: mipi_dphy_rx
	-- synthesis loc="DPHY0"
	port map(
		sync_clk_i => ClkxCI,
		sync_rst_i => DPhySyncRstxSP,
		lmmi_clk_i => '0',
		lmmi_resetn_i => DPhyLmmiRstNxSP,
		lmmi_wdata_i => (others => '0'),
		lmmi_wr_rdn_i => '0',
		lmmi_offset_i => (others => '0'),
		lmmi_request_i => '0',
		lmmi_ready_o => open,
		lmmi_rdata_o => open,
		lmmi_rdata_valid_o => open,
		hs_rx_data_o => DPhyPDatxD,
		hs_rx_data_sync_o => DPhySyncxS,
		clk_p_io => MipiRxCkP,
		clk_n_io => MipiRxCkN,
		data_p_io => MipiRxP,
		data_n_io => MipiRxN,
		pd_dphy_i => DPhyPDxSP,
		clk_byte_o => DPhyClkxC,
		ready_o => DPhyReadyxS
	);
	mipi_cross_clk_fifo_inst : mipi_cross_clk_fifo 
	port map(
		wr_clk_i => DPhyClkxCN,
		rd_clk_i => ClkxCI,
		rst_i => ResetxRI,
		rp_rst_i => '0',
		wr_en_i => FifoWrEnxS,
		rd_en_i => FifoRdEnxS,
		wr_data_i(31 downto 0) => DPhyPDatxD(31 downto 0),
		wr_data_i(33 downto 32) => DPhySyncxS(1 downto 0),
		full_o => FifoFullxS,
		empty_o => FifoEmptyxS,
		rd_data_o(31 downto 0) => FifoPDatxD,
		rd_data_o(33 downto 32) => FifoSyncxS
	);
	
	FifoWrEnxS <= '1' when FifoFullxS = '0' else '0';
	
end architecture_mipi_rx;
