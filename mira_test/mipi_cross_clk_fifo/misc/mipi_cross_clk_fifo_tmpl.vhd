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

__: mipi_cross_clk_fifo port map(
    wr_clk_i=>,
    rd_clk_i=>,
    rst_i=>,
    rp_rst_i=>,
    wr_en_i=>,
    rd_en_i=>,
    wr_data_i=>,
    full_o=>,
    empty_o=>,
    rd_data_o=>
);
