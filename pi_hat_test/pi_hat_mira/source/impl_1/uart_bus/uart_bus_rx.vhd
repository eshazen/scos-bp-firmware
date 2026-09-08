-- uart_bus_rx.vhd   receive 4-byte packet in uart_bus format
--
-- expects message from client:
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

entity uart_bus_rx is

  generic (
    BAUD_16_DIV : integer := 10
    );

  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    uart_ser_rx : in  std_logic;
    msg_valid   : out std_logic;
    msg_func    : out std_logic_vector(1 downto 0);
    msg_data    : out std_logic_vector(15 downto 0)
    );

end entity uart_bus_rx;

architecture arch of uart_bus_rx is

  signal ser_dat            : std_logic_vector(7 downto 0);
  signal ser_valid          : std_logic;
  signal clock              : std_logic;
  signal rx_valid           : std_logic;
  signal rx_dat             : std_logic_vector(7 downto 0);

  type msg_t is array (0 to 2) of std_logic_vector(7 downto 0);

  signal rx_msg : msg_t;

  signal msg_valid_0, msg_valid_1 : std_logic := '0';

  type state_type is (IDLE, HEADER, BYTE0, BYTE1, BYTE2);
  signal state : state_type := IDLE;

  component uart_rx is
    generic (
      g_BAUD_DIV : integer);
    port (
      rst       : in  std_logic;
      RsRx      : in  std_logic;
      ser_dat   : out std_logic_vector(7 downto 0);
      ser_valid : out std_logic;
      clk       : in  std_logic);
  end component uart_rx;

begin  -- architecture arch

  -- advance to next state only when data received
  fsm1 : process (clk, rst) is
  begin  -- process fsm
    if clk'event and clk = '1' then     -- rising clock edge

      -- produce a delayed msg_valid output 1 clock wide
      msg_valid_1 <= msg_valid_0;
      if msg_valid_1 = '0' and msg_valid_0 = '1' then
        msg_valid <= '1';
      else
        msg_valid <= '0';
      end if;

      msg_valid_0 <= '0';

      case state is
        when IDLE =>
          if rx_valid = '1' and rx_dat = X"24" then  -- check for '$'
            state <= BYTE0;
          end if;

        when BYTE0 =>
          if rx_valid = '1' then
            state     <= BYTE1;
            rx_msg(0) <= rx_dat;
          end if;

        when BYTE1 =>
          if rx_valid = '1' then
            rx_msg(1) <= rx_dat;
            state     <= BYTE2;
          end if;

        when BYTE2 =>
          if rx_valid = '1' then
            rx_msg(2)   <= rx_dat;
            msg_data    <= rx_msg(0)(3 downto 0) & rx_msg(1)(5 downto 0) & rx_dat(5 downto 0);
            msg_func    <= rx_msg(0)(5 downto 4);
            msg_valid_0 <= '1';
            state       <= IDLE;
          end if;

        when others => null;
      end case;


    end if;
  end process fsm1;

  uart_new_1 : entity work.uart_rx
    generic map (
      g_BAUD_DIV => BAUD_16_DIV)
    port map (
      rst       => rst,
      RsRx      => uart_ser_rx,
      ser_dat   => rx_dat,
      ser_valid => rx_valid,
      clk       => clk);

end architecture arch;
