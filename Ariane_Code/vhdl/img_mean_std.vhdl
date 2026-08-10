-- Calculates the sum of pixel values and the sum of the pixel values squared
-- for tiles of an image.

-- Initial version: 2026-01-01
-- Bernhard Zimmermann - bzim@bu.edu
-- Boston University Neurophotonics Center

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity img_mean_std is
port (
    ClkxCI          : in std_logic;
    ResetxRI        : in std_logic;
    PixValxDI       : in std_logic_vector(15 downto 0);
	PixValidxSI		: in std_logic;
    FrameValidxSI   : in std_logic;
    LineValidxSI    : in std_logic;
	
    PixSumxDO       : out std_logic_vector(31 downto 0);
    PixSqSumxDO     : out std_logic_vector(31 downto 0);
    PDatValidxSO    : out std_logic
);
end img_mean_std;
architecture architecture_img_mean_std of img_mean_std is

    constant TILE_SIZE_X : integer := 16;
    constant TILE_SIZE_Y : integer := 16;
    constant N_TILES_X : integer := 640/TILE_SIZE_X;
    constant MEAN_DARK_VAL : integer := 55;

	-- memory to store intermediate results for each tile
    type tile_mem_type is array (0 to N_TILES_X-1) of std_logic_vector(31 downto 0);
    signal SumMemxDP : tile_mem_type;
    signal SumSqMemxDP : tile_mem_type;
	-- memory output registers
    signal SumMemOutxDP : std_logic_vector(31 downto 0);
    signal SumSqMemOutxDP : std_logic_vector(31 downto 0);
	-- memory pointers
	signal WrAddrxD : integer range 0 to N_TILES_X-1;
    signal RdAddrxD : integer range 0 to N_TILES_X-1;
	-- misc memory signals
	signal MemWrEnxS : std_logic;
    signal SumMemInxD : std_logic_vector(31 downto 0);
    signal SumSqMemInxD : std_logic_vector(31 downto 0);
	
	-- accumulators
    signal SumRegxDP, SumRegxDN : unsigned(31 downto 0);
    signal SumSqRegxDP, SumSqRegxDN : unsigned(31 downto 0);
   
	-- counters
    signal PixCntxDP, PixCntxDN : integer range 0 to TILE_SIZE_X-1;
    signal TileCntxDP, TileCntxDN : integer range 0 to N_TILES_X;
    signal LineCntxDP, LineCntxDN : integer range 0 to TILE_SIZE_Y-1;
	
	-- output valid signal
	signal PDatValidxSP, PDatValidxSN : std_logic;

    -- input registers / pre-compute
    signal PixValPrexDP, PixValPrexDN : unsigned(PixValxDI'range);
	signal PixValxDP, PixValxDN : unsigned(PixValxDI'range);
	signal PixValSqxDP, PixValSqxDN : unsigned((1+2*PixValxDI'high) downto 0);
	
    signal FrameValidPrexSP, FrameValidPrexSN : std_logic;
	signal FrameValidxSP, FrameValidxSN : std_logic;
	signal FrameValidLastxSP, FrameValidLastxSN : std_logic; 
    signal LineValidPrexSP, LineValidPrexSN : std_logic;
    signal LineValidxSP, LineValidxSN : std_logic;
	signal LineValidLastxSP, LineValidLastxSN : std_logic;
	signal PixValidPrexSP, PixValidPrexSN : std_logic; 
	signal PixValidxSP, PixValidxSN : std_logic;     


begin
   -- architecture body
    p_memzing : process (ClkxCI, ResetxRI, MemWrEnxS)
	begin
		if (ResetxRI = '1') then
			PixValidPrexSP <= '0';
			PixValidxSP <= '0';
            FrameValidLastxSP <= '0';
            LineValidLastxSP <= '0';
            FrameValidxSP <= '0';
            LineValidxSP <= '0';
            FrameValidPrexSP <= '0';
            LineValidPrexSP <= '0';
            PixCntxDP <= 0;
            TileCntxDP <= 0;
            LineCntxDP <= 0;
            SumRegxDP <= (others => '0');
            SumSqRegxDP <= (others => '0');
            PDatValidxSP <= '0';
			
			SumMemxDP <= (others => (others => '0'));
			SumSqMemxDP <= (others => (others => '0'));
            SumMemOutxDP <= (others => '0');
            SumSqMemOutxDP <= (others => '0');
            PixValPrexDP <= (others => '0');
            PixValxDP <= (others => '0');
            PixValSqxDP <= (others => '0');
			
		elsif (rising_edge(ClkxCI)) then
			PixValidPrexSP <= PixValidPrexSN;
			PixValidxSP <= PixValidxSN;
            FrameValidLastxSP <= FrameValidLastxSN;
            LineValidLastxSP <= LineValidLastxSN;
            FrameValidxSP <= FrameValidxSN;
            LineValidxSP <= LineValidxSN;
            FrameValidPrexSP <= FrameValidPrexSN;
            LineValidPrexSP <= LineValidPrexSN;
            PixCntxDP <= PixCntxDN;
            TileCntxDP <= TileCntxDN;
            LineCntxDP <= LineCntxDN;
            SumRegxDP <= SumRegxDN;
            SumSqRegxDP <= SumSqRegxDN;
            PDatValidxSP <= PDatValidxSN;
			
			if MemWrEnxS = '1' then
                SumMemxDP(WrAddrxD) <= SumMemInxD;
                SumSqMemxDP(WrAddrxD) <= SumSqMemInxD;
            end if;
            SumMemOutxDP <= SumMemxDP(RdAddrxD);
            SumSqMemOutxDP <= SumSqMemxDP(RdAddrxD);
            PixValPrexDP <= PixValPrexDN;
            PixValxDP <= PixValxDN;
            PixValSqxDP <= PixValSqxDN;
		end if;
	end process;
    
    -- input registers / pre-compute
    PixValPrexDN <= unsigned(PixValxDI) - to_unsigned(MEAN_DARK_VAL, PixValxDI'length);
	PixValidPrexSN <= PixValidxSI;
    FrameValidPrexSN <= FrameValidxSI;
    LineValidPrexSN <= LineValidxSI;
    
    PixValxDN <= PixValPrexDP;
	PixValidxSN <= PixValidPrexSP;
    FrameValidxSN <= FrameValidPrexSP;
    LineValidxSN <= LineValidPrexSP;
    PixValSqxDN <= PixValPrexDP * PixValPrexDP;
        
    FrameValidLastxSN <= FrameValidxSP;
    LineValidLastxSN <= LineValidxSP;

    SumMemInxD <= std_logic_vector(SumRegxDP + PixValxDP);
    SumSqMemInxD <= std_logic_vector(SumSqRegxDP + PixValSqxDP);
    WrAddrxD <= TileCntxDP when TileCntxDP < N_TILES_X else N_TILES_X-1;
	RdAddrxD <= 0 when TileCntxDP = N_TILES_X-1 or TileCntxDP = N_TILES_X else TileCntxDP + 1;

    PixSumxDO <= std_logic_vector(SumRegxDP);
    PixSqSumxDO <= std_logic_vector(SumSqRegxDP);
	PDatValidxSO <= PDatValidxSP;

   
    p_memless : process(PixCntxDP, TileCntxDP, LineCntxDP, SumRegxDP, PixValxDP, PixValidxSP, SumSqRegxDP,  PixValSqxDP, 
        FrameValidxSP, FrameValidLastxSP, LineValidxSP, LineValidLastxSP, SumMemOutxDP, SumSqMemOutxDP)
    begin
        PixCntxDN <= PixCntxDP;
        TileCntxDN <= TileCntxDP;
        LineCntxDN <= LineCntxDP;

        SumRegxDN <= SumRegxDP;
        SumSqRegxDN <= SumSqRegxDP;

        MemWrEnxS <= '0';
        PDatValidxSN <= '0';

        if FrameValidxSP = '0' then
            -- outside of frame, reset counters
            PixCntxDN <= 0;
            TileCntxDN <= N_TILES_X;
            LineCntxDN <= 0;
        else
            if FrameValidLastxSP = '0' then
                -- new frame started
                -- send frame header
                PDatValidxSN <= '1';
                SumRegxDN <= to_unsigned(1000,32);
                SumSqRegxDN <= to_unsigned(1000,32);
            end if;
		end if;

		if PixValidxSP = '1' then
			if PixCntxDP = 0 then
				PixCntxDN <= PixCntxDP +1;
				if LineCntxDP = 0 then
					-- first pixel in tile, reset sums
					SumRegxDN(PixValxDP'high downto 0) <= PixValxDP;
					SumRegxDN(SumRegxDN'high downto PixValxDP'high+1) <= (others => '0');
					SumSqRegxDN <= PixValSqxDP;
				else
					-- not first line, load partial sums from memory
					SumRegxDN <= unsigned(SumMemOutxDP) + PixValxDP;
					SumSqRegxDN <= unsigned(SumSqMemOutxDP) + PixValSqxDP;
				end if;
				if TileCntxDP = N_TILES_X then
					-- special handling for first tile in line
					TileCntxDN <= 0;
				end if;
			elsif PixCntxDP = TILE_SIZE_X-1 then
				-- last pixel in tile for this line
				PixCntxDN <= 0;
				if TileCntxDP < N_TILES_X then
					TileCntxDN <= TileCntxDP + 1;
				end if;
				MemWrEnxS <= '1';
				if LineCntxDP = TILE_SIZE_Y-1 then
					-- last pixel in tile overall
					-- output result to next stage
					PDatValidxSN <= '1';
				end if; 
				SumRegxDN <= SumRegxDP + PixValxDP;
				SumSqRegxDN <= SumSqRegxDP + PixValSqxDP;
			else
				PixCntxDN <= PixCntxDP +1;
				SumRegxDN <= SumRegxDP + PixValxDP;
				SumSqRegxDN <= SumSqRegxDP + PixValSqxDP;
			end if; 
		end if; 
		if LineValidxSP = '0' then
			if LineValidLastxSP = '1' then
				-- just finished reading a line
				if LineCntxDP = TILE_SIZE_Y-1 then
					LineCntxDN <= 0;
				else
					LineCntxDN <= LineCntxDP+1;
				end if;
			end if;
			PixCntxDN <= 0;
			TileCntxDN <= N_TILES_X;
		end if;

    end process;
   
end architecture_img_mean_std;
