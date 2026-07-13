
-- GHDL commands analyze/elaborate/run:
-- ghdl -a -fsynopsys img_mean_std.vhdl
-- ghdl -a -fsynopsys img_mean_std_tb.vhdl
-- ghdl -e -fsynopsys img_mean_std_tb.vhdl
-- ghdl -r -fsynopsys img_mean_std_tb.vhdl

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;
 
entity img_mean_std_tb is
 
end img_mean_std_tb;
  
architecture behave of img_mean_std_tb is

    constant clk_period : time := 10 ns;

    component img_mean_std is
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
    end component img_mean_std;

    file file_VECTORS : text;
    file file_RESULTS : text;

    signal ClkxC : std_logic;
    signal ResetxR : std_logic;
    signal PixValxD : std_logic_vector(15 downto 0);
	signal PixValidxS : std_logic;
    signal FrameValidxS : std_logic;
    signal LineValidxS : std_logic;
    signal PixSumxD : std_logic_vector(31 downto 0);
    signal PixSqSumxD : std_logic_vector(31 downto 0);
    signal PDatValidxS : std_logic;

begin
    process
        variable v_ILINE     : line;
        variable v_OLINE     : line;
        variable v_FRAME_VALID : std_logic;
        variable v_LINE_VALID : std_logic;
		variable v_PIX_VALID : std_logic;
        variable v_PIX_VAL : std_logic_vector(15 downto 0);
        variable v_SPACE     : character;
        
    begin
        report("Starting simulation img_mean_std_tb");
        file_open(file_VECTORS, "input_vectors.txt",  read_mode);
        file_open(file_RESULTS, "output_results.txt", write_mode);
        ResetxR <= '1';
        ClkxC <= '0';
        wait for clk_period/2;
        ClkxC <= '1';
        wait for clk_period/2;
        ResetxR <= '0';
        ClkxC <= '0';

        while not endfile(file_VECTORS) loop
            readline(file_VECTORS, v_ILINE);
            read(v_ILINE, v_FRAME_VALID);
            read(v_ILINE, v_SPACE);           -- read in the space character
            read(v_ILINE, v_LINE_VALID);
            read(v_ILINE, v_SPACE);           -- read in the space character
			read(v_ILINE, v_PIX_VALID);
            read(v_ILINE, v_SPACE);           -- read in the space character
            read(v_ILINE, v_PIX_VAL);          
        
            -- Pass the variable to a signal 
            FrameValidxS <= v_FRAME_VALID;
            LineValidxS <= v_LINE_VALID;
			PixValidxS <= v_PIX_VALID;
            PixValxD <= v_PIX_VAL;
            ClkxC <= '0';
            wait for clk_period/2;
            ClkxC <= '1';
            wait for clk_period/2;

            if PDatValidxS = '1' then
                 --write(v_OLINE, v_FRAME_VALID);
                 --write(v_OLINE, v_SPACE);
                 --write(v_OLINE, v_LINE_VALID);
                 --write(v_OLINE, v_SPACE);
				 --write(v_OLINE, v_PIX_VALID);
                 --write(v_OLINE, v_SPACE);
                 --write(v_OLINE, v_SPACE);
                 --write(v_OLINE, PDatValidxS, right, 1);
                 --write(v_OLINE, v_SPACE);
                write(v_OLINE, to_integer(unsigned(PixSumxD)), right, 10);
                write(v_OLINE, v_SPACE);
                write(v_OLINE, to_integer(unsigned(PixSqSumxD)), right, 10);
                writeline(file_RESULTS, v_OLINE);
            end if;
        end loop;
 
        file_close(file_VECTORS);
        file_close(file_RESULTS);
        
        report("End simulation.");
        wait;
    end process;


    img_mean_std_inst : img_mean_std
        port map(
            ClkxCI          => ClkxC,
            ResetxRI        => ResetxR,
            PixValxDI       => PixValxD,
			PixValidxSI		=> PixValidxS,
            FrameValidxSI   => FrameValidxS,
            LineValidxSI    => LineValidxS,

            PixSumxDO       => PixSumxD,
            PixSqSumxDO     => PixSqSumxD,
            PDatValidxSO    => PDatValidxS
        );
end behave;