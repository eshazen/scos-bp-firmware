-- uart_bus_tx.vhd   send a 4-byte packet in uart_bus format
--
-- send message to client:
--   $abc
-- where a, b, c are any byte (in principle in range 0x40-0x7f)
-- with the low 6 bits carrying data for a total of 18 bits
--
-- outputs 16 bits of data on msg_data, 2 bits of function on msg_func
-- msg_valid is one clock wide and above are valid on both edges
--

library ieee;
use ieee.std_logic_1164.all;

-- the baud rate is <clock_freq> / (BAUD_16_DIV*16)
-- for 96MHz clock and 115200 baud should be 52
-- for simulation should be 10

entity uart_bus_tx is

  generic (
    BAUD_16_DIV : integer := 10
    );

  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    uart_ser_tx : out std_logic;
    msg_valid   : in  std_logic;
    msg_done    : out std_logic;
    msg_func    : in  std_logic_vector(1 downto 0);
    msg_data    : in  std_logic_vector(15 downto 0)
    );

end entity uart_bus_tx;

architecture arch of uart_bus_tx is

  signal ser_dat            : std_logic_vector(7 downto 0);
  signal ser_valid          : std_logic;
  signal clock              : std_logic;
  signal tx_active, tx_done : std_logic;
  signal rx_valid           : std_logic;
  signal rx_dat             : std_logic_vector(7 downto 0);

  type msg_t is array (0 to 2) of std_logic_vector(7 downto 0);

  signal rx_msg : msg_t;
  signal tx_msg : msg_t;

  signal msg0, msg1, msg2 : std_logic_vector(7 downto 0);

  type state_type is (IDLE, HEADER, BYTE0, BYTE1, BYTE2, LAST);
  signal state : state_type := IDLE;

  component uart_tx is
    generic (
      g_CLKS_PER_BIT : integer);
    port (
      i_Clk       : in  std_logic;
      i_TX_DV     : in  std_logic;
      i_TX_Byte   : in  std_logic_vector(7 downto 0);
      o_TX_Active : out std_logic;
      o_TX_Serial : out std_logic;
      o_TX_Done   : out std_logic);
  end component uart_tx;

begin  -- architecture arch

  -- advance to next state only when data received
  fsm1 : process (clk, rst) is
  begin  -- process fsm
    if clk'event and clk = '1' then     -- rising clock edge

      ser_valid <= '0';
      msg_done <= '0';

      case state is
        when IDLE =>
          if msg_valid = '1' then
            state     <= BYTE0;
            ser_dat   <= X"24";
            ser_valid <= '1';
          end if;

        when BYTE0 =>
          if tx_done = '1' then
            state     <= BYTE1;
            ser_dat   <= "01" & msg_func & msg_data(15 downto 12);
            ser_valid <= '1';

          end if;
        when BYTE1 =>
          if tx_done = '1' then
            ser_dat   <= "01" & msg_data(11 downto 6);
            ser_valid <= '1';
            state     <= BYTE2;
          end if;

        when BYTE2 =>
          if tx_done = '1' then
            ser_dat   <= "01" & msg_data(5 downto 0);
            ser_valid <= '1';
            state     <= LAST;
          end if;

        when LAST =>
          if tx_done = '1' then
            state <= IDLE;
            msg_done <= '1';
          end if;

        when others => null;
      end case;


    end if;
  end process fsm1;


  uart_tx_2 : entity work.uart_tx
    generic map (
      g_CLKS_PER_BIT => BAUD_16_DIV)
    port map (
      i_Clk       => clk,
      i_TX_DV     => ser_valid,
      i_TX_Byte   => ser_dat,
      o_TX_Active => tx_active,
      o_TX_Serial => uart_ser_tx,
      o_TX_Done   => tx_done);

end architecture arch;
