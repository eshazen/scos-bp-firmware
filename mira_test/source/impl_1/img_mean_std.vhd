-----------------------------------------------------------------------------
-- Calculates the sum of pixel values and the sum of the pixel values squared
-- for tiles of an image.

-- Initial version: 2026-01-01
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center
-----------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity img_mean_std is
generic(
	BIT_DEPTH	: integer := 12
);
port (
    ClkxCI          : in std_logic;
    ResetxRI        : in std_logic;
    PixValxDI       : in std_logic_vector(4*BIT_DEPTH-1 downto 0);
	PixDarkValxDI	: in std_logic_vector(7 downto 0);
	PixValidxSI		: in std_logic;
    FrameValidxSI   : in std_logic;
    LineValidxSI    : in std_logic;
	
    PixSumxDO       : out std_logic_vector(31 downto 0);
    PixSqSumxDO     : out std_logic_vector(31 downto 0);
    PDatValidxSO    : out std_logic
);
end img_mean_std;
architecture architecture_img_mean_std of img_mean_std is

    constant N_PIX_PER_CLK : integer := 4;
	constant TILE_SIZE_X : integer := 64 / N_PIX_PER_CLK;
    constant TILE_SIZE_Y : integer := 60;
    constant N_TILES_X : integer := 1600 /TILE_SIZE_X/N_PIX_PER_CLK;
	constant N_BITS_SUM : integer := BIT_DEPTH + 12; -- ceil(log2(64*60)) = 12
	constant N_BITS_SUM_SQ : integer := BIT_DEPTH*2 + 12;

	-- memory input signals
	signal MemWrEnxS : std_logic_vector(N_TILES_X-1 downto 0);
	signal MemInitxS : std_logic_vector(N_TILES_X-1 downto 0);
	-- memory to store intermediate results for each tile
    type tile_mem_type is array (0 to N_TILES_X-1) of unsigned(N_BITS_SUM-1 downto 0);
    signal SumMemxDP, SumMemxDN : tile_mem_type;
	type tile_mem_sq_type is array (0 to N_TILES_X-1) of unsigned(N_BITS_SUM_SQ-1 downto 0);
    signal SumSqMemxDP, SumSqMemxDN : tile_mem_sq_type;
	-- memory output registers
    signal SumOutxDP, SumOutxDN : unsigned(N_BITS_SUM-1 downto 0);
    signal SumSqOutxDP, SumSqOutxDN : unsigned(N_BITS_SUM_SQ-1 downto 0);
	-- memory pointers
    signal RdAddrxDP, RdAddrxDN : integer range 0 to N_TILES_X-1;
	  
	-- counters
    signal PixCntxDP, PixCntxDN : integer range 0 to TILE_SIZE_X-1;
    signal TileCntxDP, TileCntxDN : integer range 0 to N_TILES_X-1;
    signal LineCntxDP, LineCntxDN : integer range 0 to TILE_SIZE_Y-1;
	
	-- output valid signal
	signal SumMemRdEnxSP, SumMemRdEnxSN : std_logic;
	signal SumOutValidxSP, SumOutValidxSN : std_logic;
	signal TxHeaderxS : std_logic;

    -- input registers / pre-compute
	type pix_val_type is array (0 to N_PIX_PER_CLK-1) of unsigned(BIT_DEPTH-1 downto 0);
    signal PixValPrexDP, PixValPrexDN : pix_val_type;
	signal PixValxDP, PixValxDN : pix_val_type;
	type pix_val_sq_type is array (0 to N_PIX_PER_CLK-1) of unsigned(2*BIT_DEPTH-1 downto 0);
	signal PixValSqxDP, PixValSqxDN : pix_val_sq_type;
	
	signal PixValCombxDP, PixValCombxDN : unsigned(N_BITS_SUM-1 downto 0);
	signal PixValSqCombxDP, PixValSqCombxDN : unsigned(N_BITS_SUM_SQ-1 downto 0);
	
	signal PixValidxSP, PixValidxSN : std_logic_vector(2 downto 0);  
	signal FrameValidxSP, FrameValidxSN : std_logic_vector(PixValidxSP'range); 
	signal FrameValidLastxSP, FrameValidLastxSN : std_logic; 
    signal LineValidxSP, LineValidxSN : std_logic_vector(PixValidxSP'range); 
	signal LineValidLastxSP, LineValidLastxSN : std_logic;



begin
   -- architecture body
    p_memzing : process (ClkxCI, ResetxRI)
	begin
		if (ResetxRI = '1') then

			PixValidxSP <= (others => '0');
            FrameValidLastxSP <= '0';
            LineValidLastxSP <= '0';
            FrameValidxSP <= (others => '0');
            LineValidxSP <= (others => '0');

            PixCntxDP <= 0;
            TileCntxDP <= 0;
            LineCntxDP <= 0;

            SumMemRdEnxSP <= '0';
			SumOutValidxSP <= '0';
			
			RdAddrxDP <= 0;
			SumMemxDP <= (others => (others => '0'));
			SumSqMemxDP <= (others => (others => '0'));

            SumOutxDP <= (others => '0');
            SumSqOutxDP <= (others => '0');
            PixValPrexDP <= (others => (others => '0'));
            PixValxDP <= (others => (others => '0'));
            PixValSqxDP <= (others => (others => '0'));
			PixValCombxDP <= (others => '0');
			PixValSqCombxDP <= (others => '0');
			
		elsif (rising_edge(ClkxCI)) then
			PixValidxSP <= PixValidxSN;
            FrameValidLastxSP <= FrameValidLastxSN;
            LineValidLastxSP <= LineValidLastxSN;
            FrameValidxSP <= FrameValidxSN;
            LineValidxSP <= LineValidxSN;
            PixCntxDP <= PixCntxDN;
            TileCntxDP <= TileCntxDN;
            LineCntxDP <= LineCntxDN;
			
            SumMemRdEnxSP <= SumMemRdEnxSN;
			SumOutValidxSP <= SumOutValidxSN;
			
			RdAddrxDP <= RdAddrxDN;
			
			SumMemRdEnxSP <= SumMemRdEnxSN;
			SumOutValidxSP <= SumOutValidxSN;
			
			SumMemxDP <= SumMemxDN;
			SumSqMemxDP <= SumSqMemxDN;
			SumOutxDP <= SumOutxDN;
			SumSqOutxDP <= SumSqOutxDN;
			
            PixValPrexDP <= PixValPrexDN;
            PixValxDP <= PixValxDN;
            PixValSqxDP <= PixValSqxDN;
			PixValCombxDP <= PixValCombxDN;
			PixValSqCombxDP <= PixValSqCombxDN;
		end if;
	end process;
    
    -- input registers / pre-compute
	pix_in_gen : for ii in 0 to N_PIX_PER_CLK-1 generate
		PixValPrexDN(ii) <= unsigned(PixValxDI((ii+1)*BIT_DEPTH-1 downto ii*BIT_DEPTH)) - unsigned(PixDarkValxDI);
		PixValSqxDN(ii) <= PixValPrexDP(ii) * PixValPrexDP(ii);
	end generate pix_in_gen;
	PixValxDN <= PixValPrexDP;
	PixValCombxDN <= resize(PixValxDP(0), PixValCombxDN'length) + resize(PixValxDP(1), PixValCombxDN'length) + resize(PixValxDP(2), PixValCombxDN'length) + resize(PixValxDP(3), PixValCombxDN'length);
	PixValSqCombxDN <= resize(PixValSqxDP(0), PixValSqCombxDN'length) + resize(PixValSqxDP(1), PixValSqCombxDN'length) + resize(PixValSqxDP(2), PixValSqCombxDN'length) + resize(PixValSqxDP(3), PixValSqCombxDN'length);
	
	PixValidxSN(PixValidxSN'high) <= PixValidxSI;
	PixValidxSN(PixValidxSN'high-1 downto 0) <= PixValidxSP(PixValidxSN'high downto 1);
	FrameValidxSN(PixValidxSN'high) <= FrameValidxSI;
	FrameValidxSN(PixValidxSN'high-1 downto 0) <= FrameValidxSP(PixValidxSN'high downto 1);
	LineValidxSN(PixValidxSN'high) <= LineValidxSI;
	LineValidxSN(PixValidxSN'high-1 downto 0) <= LineValidxSP(PixValidxSN'high downto 1);
    FrameValidLastxSN <= FrameValidxSP(0);
    LineValidLastxSN <= LineValidxSP(0);
	
	-- main accumulators
	main_acc : for ii in 0 to N_TILES_X-1 generate
		SumMemxDN(ii) <= PixValCombxDP when MemInitxS(ii) = '1' else
						PixValCombxDP + SumMemxDP(ii) when MemWrEnxS(ii) = '1' else
						SumMemxDP(ii);
		SumSqMemxDN(ii) <= PixValSqCombxDP when MemInitxS(ii) = '1' else
						PixValSqCombxDP + SumSqMemxDP(ii) when MemWrEnxS(ii) = '1' else
						SumSqMemxDP(ii);
	end generate main_acc;

	-- output registers
	RdAddrxDN <= TileCntxDP;
	SumOutxDN <= to_unsigned(16#fffe#, SumOutxDN'length) when TxHeaderxS = '1' else SumMemxDP(RdAddrxDP);
	SumSqOutxDN <= to_unsigned(16#ffff#, SumSqOutxDN'length) when TxHeaderxS = '1' else SumSqMemxDP(RdAddrxDP);
	SumOutValidxSN <= '1' when TxHeaderxS = '1' or SumMemRdEnxSP = '1' else '0';
	PDatValidxSO <= SumOutValidxSP;
	
    PixSumxDO <= std_logic_vector(resize(SumOutxDP, PixSumxDO'length));
	g_pixsqsum_out : if (BIT_DEPTH=8 or BIT_DEPTH=10) generate
		PixSqSumxDO <= std_logic_vector(resize(SumSqOutxDP, PixSqSumxDO'length));
	elsif BIT_DEPTH=12 generate
		-- if dealing with RAW12, truncate 4 LSBs to fit in uint32
		PixSqSumxDO <= std_logic_vector(SumSqOutxDP(N_BITS_SUM_SQ-1 downto N_BITS_SUM_SQ-32));
	else generate
		assert false report "BIT_DEPTH not supported" severity error;
	end generate g_pixsqsum_out;
	
   
	p_memless : process(all)
    begin
        PixCntxDN <= PixCntxDP;
        TileCntxDN <= TileCntxDP;
        LineCntxDN <= LineCntxDP;
		MemInitxS <= (others => '0');
		MemWrEnxS <= (others => '0');
		SumMemRdEnxSN <= '0';
		TxHeaderxS <= '0';

        if FrameValidxSP(0) = '0' then
            -- outside of frame, reset counters
            PixCntxDN <= 0;
            TileCntxDN <= 0;
            LineCntxDN <= 0;
        else
            if FrameValidLastxSP = '0' then
                -- new frame started
                -- send frame header
                TxHeaderxS <= '1';
            end if;
		end if;

		if PixValidxSP(0) = '1' then
			if PixCntxDP = 0 then
				PixCntxDN <= PixCntxDP +1;
				if LineCntxDP = 0 then
					-- first pixel in tile, reset sums
					MemInitxS(TileCntxDP) <= '1';
				else
					-- not first line, load partial sums from memory
					MemWrEnxS(TileCntxDP) <= '1';
				end if;
			elsif PixCntxDP >= TILE_SIZE_X-1 then
				-- last pixel in tile for this line
				PixCntxDN <= 0;
				MemWrEnxS(TileCntxDP) <= '1';
				if TileCntxDP >= N_TILES_X-1 then
					TileCntxDN <= 0;
				else
					TileCntxDN <= TileCntxDP + 1;
				end if;
				if LineCntxDP >= TILE_SIZE_Y-1 then
					-- last pixel in tile overall
					-- output result to next stage
					SumMemRdEnxSN <= '1';
				end if; 
			else
				PixCntxDN <= PixCntxDP +1;
				MemWrEnxS(TileCntxDP) <= '1';
			end if; 
		end if; 
		if LineValidxSP(0) = '0' then
			if LineValidLastxSP = '1' then
				-- just finished reading a line
				if LineCntxDP >= TILE_SIZE_Y-1 then
					LineCntxDN <= 0;
				else
					LineCntxDN <= LineCntxDP+1;
				end if;
			end if;
			PixCntxDN <= 0;
			TileCntxDN <= 0;
		end if;

    end process;
   
end architecture_img_mean_std;
