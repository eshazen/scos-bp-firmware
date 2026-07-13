-- Firmware for NN22_ControlBoard00
-- UART transmitter

-- Initial version: 2022-12-27
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library pmi;
use pmi.components.all;

entity uart_tx is
	generic (
		TX_CLK_DIV : integer := 16 -- 96/16 = 6 MBPS
	);
	port (
		ClkxCI 	 	    : in std_logic;
		ResetxRI 	    : in std_logic;
		CTSnxSI		    : in std_logic;
		SerDatxDO 	    : out std_logic;
		UartRdyxSO      : out std_logic;
		ParDatValidxSI  : in std_logic;
		ParDatxDI 	    : in std_logic_vector(7 downto 0)
	);
end uart_tx;

architecture behavioral of uart_tx is
	type fsmstatetype is (sWaitCTS, sLoad, sTxBits, sTxStop);
	signal StatexDP, StatexDN : fsmstatetype;
	
	signal SRegxDP, SRegxDN  : std_logic_vector(8 downto 0);
	signal SerDatxDP, SerDatxDN : std_logic;
	
	signal ClkCntxDP, ClkCntxDN : integer range 0 to TX_CLK_DIV-1;
	signal BitCntxDP, BitCntxDN: integer range 0 to 8;
	
	signal CTSnSRegxDP, CTSnSRegxDN : std_logic_vector(2 downto 0);
	
	signal FifoRdEnxS : std_logic;
	signal FifoEmptyxS : std_logic;
	signal FifoAlmostFullxS : std_logic;
	signal FifoDatOutxD : std_logic_vector(7 downto 0);
	 
	component pmi_fifo is
	 generic (
		 pmi_data_width : integer := 8;
		 pmi_data_depth : integer := 256;
		 pmi_full_flag : integer := 256;
		 pmi_empty_flag : integer := 0;
		 pmi_almost_full_flag : integer := 252;
		 pmi_almost_empty_flag : integer := 4;
		 pmi_regmode : string := "reg";
		 pmi_family : string := "common" ;
		 module_type : string := "pmi_fifo";
		 pmi_implementation : string := "EBR"
	 );
	 port (
		 Data : in std_logic_vector(pmi_data_width-1 downto 0);
		 Clock: in std_logic;
		 WrEn: in std_logic;
		 RdEn: in std_logic;
		 Reset: in std_logic;
		 Q : out std_logic_vector(pmi_data_width-1 downto 0);
		 Empty: out std_logic;
		 Full: out std_logic;
		 AlmostEmpty: out std_logic;
		 AlmostFull: out std_logic
	 );
	end component pmi_fifo;
	
begin
	
	p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then 
			StatexDP <= sWaitCTS;
			ClkCntxDP <= 0;
			BitCntxDP <= 0;
			SRegxDP <= (others => '0');
			SerDatxDP <= '0';
			CTSnSRegxDP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
			ClkCntxDP <= ClkCntxDN;
			BitCntxDP <= BitCntxDN;
			SRegxDP <= SRegxDN;
			SerDatxDP <= SerDatxDN;
			CTSnSRegxDP <= CTSnSRegxDN;
		end if;  
	end process;
	
	CTSnSRegxDN <= CTSnxSI & CTSnSRegxDP(CTSnSRegxDP'high downto 1);
	SerDatxDO <= SerDatxDP;
	
	p_memless : process(all)
	begin
		StatexDN <= StatexDP;
		ClkCntxDN <= ClkCntxDP +1;
		BitCntxDN <= BitCntxDP;
		SerDatxDN <= '1';
		FifoRdEnxS <= '0';
		SRegxDN <= SRegxDP;
		case StatexDP is
            when sWaitCTS =>
                if CTSnSRegxDP(0) = '0' and FifoEmptyxS = '0' then
					FifoRdEnxS <= '1';
					StatexDN <= sLoad;
				end if;
                
			when sLoad =>
                ClkCntxDN <= 0;
				BitCntxDN <= 0;
				SRegxDN <= FifoDatOutxD & '0';
				StatexDN <= sTxBits;

			when sTxBits =>
				SerDatxDN <= SRegxDP(0);
				if ClkCntxDP = TX_CLK_DIV-1 then
					ClkCntxDN <= 0;
					BitCntxDN <= BitCntxDP +1;
					SRegxDN <= SRegxDP(8) & SRegxDP(8 downto 1); -- right shift
					if BitCntxDP = 8 then
						StatexDN <= sTxStop;
					end if;
				end if;
                
			when sTxStop =>
				if ClkCntxDP = TX_CLK_DIV-1 then
					StatexDN <= sWaitCTS;
				end if;
                
			when others =>
				StatexDN <= sWaitCTS;
		end case;
   end process;
   
   uart_tx_fifo : pmi_fifo
	generic map (
	  pmi_data_width        => 8, -- integer       
	  pmi_data_depth        => 2047, -- integer       
	  pmi_almost_full_flag  => 2000, -- integer (pmi_almost_full_flag MUST be LESS than pmi_data_depth)       
	  pmi_almost_empty_flag => 0, -- integer		
	  pmi_regmode           => "noreg", -- "reg"|"noreg"    	
	  pmi_family            => "LIFCL", -- "LIFCL"|"LFD2NX"|"LFCPNX"|"LFMXO5"|"UT24C"|"UT24CP"|"common"
	  pmi_implementation    => "HARD_IP"  -- "LUT"|"EBR"|"HARD_IP"
	)
	port map (
	  Data         => ParDatxDI,  -- I:
	  Clock        => ClkxCI,   -- I:
	  WrEn         => ParDatValidxSI,  -- I:
	  RdEn         => FifoRdEnxS,  -- I:
	  Reset        => ResetxRI,  -- I:
	  Q            => FifoDatOutxD,  -- O:
	  Empty        => FifoEmptyxS,  -- O:
	  Full         => open,  -- O:
	  AlmostEmpty  => open,  -- O:
	  AlmostFull   => FifoAlmostFullxS   -- O:
	);
	
	UartRdyxSO <= not FifoAlmostFullxS;
	
end behavioral;