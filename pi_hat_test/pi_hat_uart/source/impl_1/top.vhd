-----------------------------------------------------------------------------
-- uart_bus test for Pi Hat
------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity top is
  port (
    Clk48xCI   : IN  std_logic;
--    ResetxRI   : IN  std_logic;

    -- Misc / Debug
    LED0 : out std_logic;
    LED1 : out std_logic;

    -- UART
    UART_Rx_Pin : in std_logic;
    UART_Tx_Pin : out std_logic
    );
end top;

architecture architecture_top of top is

  signal pre : unsigned(19 downto 0);
  signal ctr : unsigned(13 downto 0);
  signal PLLock : std_logic;
  signal rst_n : std_logic;

  signal clk : std_logic;

  signal ResetxRI : std_logic;

  signal serial_rx : std_logic;
  signal ser_rx_dat : std_logic_vector(7 downto 0);
  signal ser_rx_valid : std_logic;

  component my_pll is
    port (
      clki_i  : in  std_logic;
      rstn_i  : in  std_logic;
      clkop_o : out std_logic;
      lock_o  : out std_logic);
  end component my_pll;

  component uart_bus is
    generic (
      BAUD_16_DIV : integer);
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      uart_ser_tx  : out std_logic;
      uart_ser_rx  : in  std_logic;
      msg_rx_data  : out std_logic_vector(15 downto 0);
      msg_rx_func  : out std_logic_vector(1 downto 0);
      msg_rx_valid : out std_logic;
      msg_tx_data  : in  std_logic_vector(15 downto 0));
  end component uart_bus;

  signal msg_rx_data  : std_logic_vector(15 downto 0);
  signal msg_rx_func  : std_logic_vector(1 downto 0);
  signal msg_rx_valid : std_logic;
  signal msg_tx_data  : std_logic_vector(15 downto 0);

begin

  ResetxRI <= '0';                      -- no reset, rely on FPGA

  -- process just for blinking LED
  p_memzing : process (clk, ResetxRI)
  begin
    if (ResetxRI = '1') then
      pre <= (others => '0');
      ctr <= (others => '0');
    elsif (rising_edge(clk)) then
      pre <= pre + 1;
      if pre(19) = '1' then
        pre <= (others => '0');                   
        ctr <= ctr + 1;
        msg_rx_data(14 downto 1) <= std_logic_vector(ctr);
      end if;
    end if;
  end process;

  LED0 <= msg_rx_data(0);
  LED1 <= ctr(6);

  rst_n <= not ResetxRI;

  pll1 : my_pll port map(
    clki_i=> Clk48xCI,
    rstn_i=> rst_n,
    clkop_o=> clk,
    lock_o=> PLLock);

  uart_bus_1: entity work.uart_bus
    generic map (
      BAUD_16_DIV => 52)
    port map (
      clk          => clk,
      rst          => ResetxRI,
      uart_ser_tx  => UART_Tx_Pin,
      uart_ser_rx  => UART_Rx_Pin,
      msg_rx_data  => msg_rx_data,
      msg_rx_func  => msg_rx_func,
      msg_rx_valid => msg_rx_valid,
      msg_tx_data  => msg_tx_data);

end architecture_top;
