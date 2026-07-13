-----------------------------------------------------------------------------
-- Frame buffer unit
--
-- Stores a slice of a raw frame in LRAM memory. Allows for adding frames to
-- facilitate calculation of the mean frame to get spatial heterogenity.
--
-- BU Neurophotonics Center 2026
-- bzim@bu.edu
------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity frame_buf is
generic (
	BIT_DEPTH		: integer := 12
);
port (
    ClkxCI          : in std_logic;
    ResetxRI        : in std_logic;
    PixDatxDI       : in std_logic_vector(4*BIT_DEPTH-1 downto 0);
    PixDatValidxSI  : in std_logic;
    InFramexSI      : in std_logic;
    TrigxSI         : in std_logic;
	SliceSelxDI     : in std_logic_vector(7 downto 0);
	SumCntxDI		: in std_logic_vector(7 downto 0); -- number of frames to be summed
    UartRdyxSI      : in std_logic;
    PDatxDO         : out std_logic_vector(7 downto 0);
    PDatValidxSO    : out std_logic
);
end frame_buf;
architecture architecture_frame_buf of frame_buf is

	constant N_SLICES : integer := 12;
	constant N_SLICESEL_BITS : integer := 4;
	constant N_WORDS : integer := (1600/4) * 480/N_SLICES ; -- 4 pix per word, 480 lines per image
	constant N_BYTES_PER_WORD : integer := 8;

	-- input signal registers (for speed)
	signal PixDatValidxSP, PixDatValidxSN : std_logic;
	signal PixDatxDP, PixDatxDN : std_logic_vector(PixDatxDI'range);
	signal InFramexSP, InFramexSN : std_logic;
	signal InFrameLastxSP, InFrameLastxSN : std_logic; 
    signal TrigxSP, TrigxSN : std_logic;
	signal SliceSelxDP, SliceSelxDN : std_logic_vector(N_SLICESEL_BITS-1 downto 0);

	-- main FSM signals
    type fsmstatetype is (sIdle, sResetFIFO, sLoadFIFO, sWaitFrame, sWaitSlice, sStoreSlice, sLoadWord, sShiftOutByte, sWaitIdle);
	signal StatexDP, StatexDN : fsmstatetype;

	signal SumCntxDP, SumCntxDN : integer range 0 to 255;
    signal WrAddrxDP, WrAddrxDN : integer range 0 to N_WORDS-1;
    signal RdAddrxDP, RdAddrxDN : integer range 0 to N_WORDS-1;
	signal WordCntxDP, WordCntxDN : integer range 0 to (N_SLICES-1)*N_WORDS;
	signal ByteCntxDP, ByteCntxDN : integer range 0 to N_BYTES_PER_WORD-1;
	
	-- LRAM output registers (for speed)
	type memout_type is array (0 to 1) of std_logic_vector(63 downto 0);
    signal MemOutxDP, MemOutxDN : memout_type;
	
	signal MemInxD : std_logic_vector(MemOutxDP(0)'range);
	
	-- Main frame buffer memory
	type frame_mem_type is array (0 to N_WORDS-1) of std_logic_vector(MemOutxDP(0)'range);
    signal MemxDP, MemxDN : frame_mem_type;
	-- Specify use of large_ram/LRAM vs block_ram for framebuffer. Note LRAM is limited in speed and aspect ratio.
	attribute syn_ramstyle : string;
	attribute syn_ramstyle of MemxDP : signal is "large_ram";--"block_ram";
	
    -- Output signals
	signal ShiftOutRegxDP, ShiftOutRegxDN : std_logic_vector(MemOutxDP(0)'range);
	signal PDatxDP, PDatxDN : std_logic_vector(7 downto 0);
	signal PDatValidxSP, PDatValidxSN : std_logic;
	
	-- Read FIFO related --
	-- LRAM read FIFO implemented to overcome latency introduced by double registering output
	constant N_FIFO_ADDR_BITS : integer := 4;
	constant N_FIFO_WORDS : integer := 2**N_FIFO_ADDR_BITS;
	constant FIFO_ALMOST_EMPTY_TRSH : integer := 5;
	constant FIFO_ALMOST_FULL_TRSH : integer := N_FIFO_WORDS-4;
	
	type fifo_fsmstatetype is (sIdle, sWrite);
	signal FIFOStatexDP, FIFOStatexDN : fifo_fsmstatetype;
	
	type fifo_mem_type is array (0 to N_FIFO_WORDS-1) of std_logic_vector(MemOutxDP(0)'range);
    signal FIFOMemxDP, FIFOMemxDN : fifo_mem_type;
	
	signal FIFOWrAddrxDP, FIFOWrAddrxDN : unsigned(N_FIFO_ADDR_BITS-1 downto 0);
	signal FIFORdAddrxDP, FIFORdAddrxDN : unsigned(N_FIFO_ADDR_BITS-1 downto 0);
	
	signal FIFOResetxS : std_logic;
	signal FIFOWrEnxSP, FIFOWrEnxSN : std_logic_vector(1 downto 0);
	signal FIFORdEnxS : std_logic;
	
	signal FIFOOutxD : std_logic_vector(MemOutxDP(0)'range);
	
	signal FIFOBytesAvailablexD : unsigned(FIFORdAddrxDP'range);
	--signal FIFOFullxS : std_logic; 
	--signal FIFOEmptyxS : std_logic;
	signal FIFOAlmostEmptyxS : std_logic;
	signal FIFOAlmostFullxS : std_logic;
	

begin
	assert N_SLICESEL_BITS <= 8 severity error;
	assert N_SLICES <= (2**N_SLICESEL_BITS) severity error;
	assert BIT_DEPTH <= 16 severity error;

    p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then
			StatexDP <= sWaitIdle;
            TrigxSP <= '0';
			SliceSelxDP <= (others => '0');
            InFrameLastxSP <= '0';
			SumCntxDP <= 0;
            WrAddrxDP <= 0;
            RdAddrxDP <= 0;
			WordCntxDP <= 0;
			PDatxDP <= (others => '0');
			PDatValidxSP <= '0';
			MemOutxDP <= (others => (others => '0'));
			
			FIFOStatexDP <= sIdle;
			FIFOWrEnxSP <= (others => '0');
		elsif (rising_edge(ClkxCI)) then
			StatexDP <= StatexDN;
            TrigxSP <= TrigxSN;
			SliceSelxDP <= SliceSelxDN;
            InFrameLastxSP <= InFrameLastxSN;
			SumCntxDP <= SumCntxDN;
            WrAddrxDP <= WrAddrxDN;
            RdAddrxDP <= RdAddrxDN;
			WordCntxDP <= WordCntxDN;
			PDatxDP <= PDatxDN;
			PDatValidxSP <= PDatValidxSN;
			MemOutxDP <= MemOutxDN;
			
			FIFOStatexDP <= FIFOStatexDN;
			FIFOWrEnxSP <= FIFOWrEnxSN;
		end if;
		if (rising_edge(ClkxCI)) then
			MemxDP <= MemxDN;
			ByteCntxDP <= ByteCntxDN;
			ShiftOutRegxDP <= ShiftOutRegxDN;
			PixDatxDP <= PixDatxDN;
			PixDatValidxSP <= PixDatValidxSN;
			InFramexSP <= InFramexSN;
			
			FIFOMemxDP <= FIFOMemxDN;
			FIFOWrAddrxDP <= FIFOWrAddrxDN;
			FIFORdAddrxDP <= FIFORdAddrxDN;
		end if;
	end process;
    
	PixDatxDN <= PixDatxDI;
	PixDatValidxSN <= PixDatValidxSI;
	
	InFramexSN <= InFramexSI;
    InFrameLastxSN <= InFramexSP;
    TrigxSN <= TrigxSI;
	SliceSelxDN <= SliceSelxDI(N_SLICESEL_BITS-1 downto 0);
	PDatxDO <= PDatxDP;
	PDatValidxSO <= PDatValidxSP;
   
    p_memless : process(all)
	variable MemWrEnxS : std_logic;
    begin
        MemWrEnxS := '0';
		FIFORdEnxS <= '0';
		FIFOResetxS <= '0';
        PDatValidxSN <= '0';
		SumCntxDN <= SumCntxDP;
        WrAddrxDN <= WrAddrxDP;
        --
		WordCntxDN <= WordCntxDP;
		ByteCntxDN <= ByteCntxDP;
		ShiftOutRegxDN <= ShiftOutRegxDP;
		PDatxDN <= ShiftOutRegxDP(7 downto 0);
        StatexDN <= StatexDP;
        case StatexDP is -- main FSM
            when sIdle =>
				FIFOResetxS <= '1';
				SumCntxDN <= 0;
                if TrigxSP = '1' then 
                    StatexDN <= sWaitFrame;
                end if;
			
			when sResetFIFO =>
				FIFOResetxS <= '1';
				StatexDN <= sLoadFIFO;
			
			when sLoadFIFO =>
				-- load words into fifo to be ready to sum/read
				WordCntxDN <= N_WORDS;
				if FIFOAlmostEmptyxS = '0' then
					if SumCntxDP >= to_integer(unsigned(SumCntxDI)) then
						StatexDN <= sLoadWord;
					else
						SumCntxDN <= SumCntxDP+1;
						StatexDN <= sWaitFrame;
					end if;
				end if;	
            
            when sWaitFrame =>
				WordCntxDN <= to_integer(unsigned(SliceSelxDP)) * N_WORDS;
                WrAddrxDN <= 0;
                if InFrameLastxSP = '0' and InFramexSP = '1' then
                    StatexDN <= sWaitSlice;
                end if;
				
			when sWaitSlice =>
				WrAddrxDN <= 0;
				if WordCntxDP = 0 then
					StatexDN <= sStoreSlice;
				elsif PixDatValidxSP = '1' then
					WordCntxDN <= WordCntxDP -1;
				end if;
                
            when sStoreSlice =>
                if PixDatValidxSP = '1' then
					if WrAddrxDP < N_WORDS-1 then
						WrAddrxDN <= WrAddrxDP +1;
					else
						FIFOResetxS <= '1';
						StatexDN <= sResetFIFO;
					end if;
                    MemWrEnxS := '1';
					FIFORdEnxS <= '1';
                end if;
                if InFramexSP = '0' then
                    StatexDN <= sLoadWord;
                end if;
				
			when sLoadWord =>
				FIFORdEnxS <= '1';
				ByteCntxDN <= N_BYTES_PER_WORD -1;
				WordCntxDN <= WordCntxDP -1;
				ShiftOutRegxDN <= FIFOOutxD;
				StatexDN <= sShiftOutByte;
				
			when sShiftOutByte =>
				if UartRdyxSI = '1' then
					PDatValidxSN <= '1';
					if ByteCntxDP = 0 then
						if WordCntxDP = 0 then
							StatexDN <= sWaitIdle;
						else
							StatexDN <= sLoadWord;
						end if;						
					else
						-- shift
						ShiftOutRegxDN(ShiftOutRegxDN'left-8 downto 0) <= ShiftOutRegxDP(ShiftOutRegxDN'left downto 8);
						ByteCntxDN <= ByteCntxDP -1;
					end if;
                end if;
                
            when sWaitIdle =>
                if TrigxSP = '0' and InFrameLastxSP = '0' then
                    StatexDN <= sIdle;
                end if;
            
            when others =>
                StatexDN <= sWaitIdle;
        end case;
		
		if SumCntxDP = 0 then -- first pass
			for ipix in 0 to 3 loop
				MemInxD((ipix+1)*16-1 downto ipix*16) <= std_logic_vector(resize(unsigned(PixDatxDP((ipix+1)*BIT_DEPTH-1 downto ipix*BIT_DEPTH)), 16));
			end loop;
		else -- on subsequent passes build pixel sum
			for ipix in 0 to 3 loop
				MemInxD((ipix+1)*16-1 downto ipix*16) <= std_logic_vector(resize(unsigned(PixDatxDP((ipix+1)*BIT_DEPTH-1 downto ipix*BIT_DEPTH)), 16)
														+ unsigned(FIFOOutxD((ipix+1)*16-1 downto ipix*16)));
			end loop;
		end if;
		 
		MemxDN <= MemxDP;
		if MemWrEnxS = '1' then
			MemxDN(WrAddrxDP) <= MemInxD;
		end if;
		MemOutxDN(1) <= MemxDP(RdAddrxDP);
		MemOutxDN(0) <= MemOutxDP(1);
		
    end process;
	
	-- Read FIFO related --
	p_memless_fifo : process(all)
	begin
		FIFOBytesAvailablexD <= FIFOWrAddrxDP - FIFORdAddrxDP;
		
		--if FIFORdAddrxDP = FIFOWrAddrxDP then
			--FIFOEmptyxS <= '1';
		--else
			--FIFOEmptyxS <= '0';
		--end if
		
		if FIFOBytesAvailablexD < FIFO_ALMOST_EMPTY_TRSH then
			FIFOAlmostEmptyxS <= '1';
		else
			FIFOAlmostEmptyxS <= '0';
		end if;
		
		--if (FIFOWrAddrxDP+1) = FIFORdAddrxDP then
			--FIFOFullxS <= '1';
		--else
			--FIFOFullxS <= '0';
		--end if;
		
		if FIFOBytesAvailablexD > FIFO_ALMOST_FULL_TRSH then
			FIFOAlmostFullxS <= '1';
		else
			FIFOAlmostFullxS <= '0';
		end if;
		
		FIFOWrEnxSN(1) <= '0';
		FIFOWrEnxSN(0) <= FIFOWrEnxSP(1);
		FIFOWrAddrxDN <= FIFOWrAddrxDP;
		RdAddrxDN <= RdAddrxDP;
		FIFOStatexDN <= FIFOStatexDP;
		case FIFOStatexDP is -- FIFO FSM
            when sIdle =>
				if FIFOResetxS = '1' then
					RdAddrxDN <= 0;
				elsif FIFOAlmostEmptyxS = '1' and RdAddrxDP < N_WORDS-1 then
					FIFOWrEnxSN(1) <= '1';
					RdAddrxDN <= RdAddrxDP +1;
					FIFOStatexDN <= sWrite;
				end if;
			when sWrite =>
				if FIFOResetxS = '1' then
					RdAddrxDN <= 0;
					FIFOStatexDN <= sIdle;
				elsif RdAddrxDP = N_WORDS-1 then
					-- last word
					FIFOWrEnxSN(1) <= '1';
					FIFOStatexDN <= sIdle;
				elsif FIFOAlmostFullxS = '1' then 
					FIFOStatexDN <= sIdle;
				else
					FIFOWrEnxSN(1) <= '1';
					RdAddrxDN <= RdAddrxDP +1;
				end if;

			when others =>
				FIFOStatexDN <= sIdle;
		end case;
		
		-- FIFO read port
		if FIFOResetxS = '1' then
			FIFORdAddrxDN <= (others => '0');
		elsif FIFORdEnxS = '1' then
			FIFORdAddrxDN <= FIFORdAddrxDP+1;
		else
			FIFORdAddrxDN <= FIFORdAddrxDP;
		end if;
		
		-- FIFO write port
		FIFOMemxDN <= FIFOMemxDP;
		if FIFOResetxS = '1' then
			FIFOWrAddrxDN <= (others => '0');
		elsif FIFOWrEnxSP(0) = '1' then
			FIFOWrAddrxDN <= FIFOWrAddrxDP +1;
			FIFOMemxDN(to_integer(FIFOWrAddrxDP)) <= MemOutxDP(0);
		end if;
		FIFOOutxD <= FIFOMemxDP(to_integer(FIFORdAddrxDP));
	end process p_memless_fifo;
   
end architecture_frame_buf;
