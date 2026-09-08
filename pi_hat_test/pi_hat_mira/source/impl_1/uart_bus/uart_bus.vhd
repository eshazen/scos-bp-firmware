------------------------------------------------------------------------
-- uart_bus.vhd  uart server for control/debug
--
-- receive 4-byte packets encoding 2-bit function and 16-bit data
-- first byte is 0x24 (ASCII "$")
-- b0,b1,b2 are ASCII 40-7f with bits 0-5 containing data
--
-- These (3) 6-bit fields are concatenated to make an 18-bit word.
-- Bits 0-15 are data, 16,17 are control
-- 
--  --------- b0 ---------  --------- b1 ---------  --------- b2 ---------
--  7  6  5  4  3  2  1  0  7  6  5  4  3  2  1  0  7  6  5  4  3  2  1  0
--  -  -  k1 k0 15 14 13 12 -  - 11 10  9  8  7  6  -  -  5  4  3  2  1  0
-- 
-- Control bits are decoded as follows:
-- 
-- k1 k0  function
--  0  0  read 16-bit word
--  0  1  write 16-bit word
--  1  0  reserved
--  1  1  reserved
--
-- Read means to return the data presented on msg_tx_data to the client
-- Write means to present the data received on msg_rx_data
--
-- the 2-bit function code is always echoed.
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity uart_bus is

  generic (
    BAUD_16_DIV : integer := 52);       -- 52 for 115200 baud with 96MHz clock

  port (
    clk          : in  std_logic;                      -- system clock
    rst          : in  std_logic;                      -- active high reset (optional)
    uart_ser_tx  : out std_logic;                      -- UART output
    uart_ser_rx  : in  std_logic;                      -- UART input
    --
    msg_rx_data  : out std_logic_vector(15 downto 0);  -- received data
    msg_rx_func  : out std_logic_vector(1 downto 0);   -- received function code
    msg_rx_valid : out std_logic;                      -- received data valid
    --
    msg_tx_data  : in  std_logic_vector(15 downto 0)   -- data to transmit on function "00"
    );

end entity uart_bus;

architecture arch of uart_bus is

  component uart_bus_tx is
    generic (
      BAUD_16_DIV : integer);
    port (
      clk         : in  std_logic;
      rst         : in  std_logic;
      uart_ser_tx : out std_logic;
      msg_valid   : in  std_logic;
      msg_done    : out std_logic;
      msg_func    : in  std_logic_vector(1 downto 0);
      msg_data    : in  std_logic_vector(15 downto 0));
  end component uart_bus_tx;

  component uart_bus_rx is
    generic (
      BAUD_16_DIV : integer);
    port (
      clk         : in  std_logic;
      rst         : in  std_logic;
      uart_ser_rx : in  std_logic;
      msg_valid   : out std_logic;
      msg_func    : out std_logic_vector(1 downto 0);
      msg_data    : out std_logic_vector(15 downto 0));
  end component uart_bus_rx;

  signal rx_valid, rx_valid_r : std_logic;
  signal msg_done             : std_logic;

  signal func, rx_func : std_logic_vector(1 downto 0);
  signal data, rx_data : std_logic_vector(15 downto 0);

  signal reply : std_logic;

begin  -- architecture arch

  proc : process (clk, rst) is
  begin  -- process proc
    if clk'event and clk = '1' then     -- rising clock edge

      -- delay valid output by a couple of clocks
      rx_valid_r   <= rx_valid;
      msg_rx_valid <= rx_valid_r;

      reply <= '0';

      -- got a packet, send return packet
      if rx_valid = '1' then
        func        <= rx_func;         --always echo the function
        msg_rx_func <= rx_func;         --send func and...
        msg_rx_data <= rx_data;         --data to ports
        reply       <= '1';             --start a reply
        if rx_func = "01" then          --function "01" is write
          data <= rx_data;              --echo the data
        else
          data <= msg_tx_data;             --else read from the port
        end if;
      end if;

    end if;
  end process proc;

  uart_bus_rx_1 : entity work.uart_bus_rx
    generic map (
      BAUD_16_DIV => BAUD_16_DIV)
    port map (
      clk         => clk,
      rst         => rst,
      uart_ser_rx => uart_ser_rx,
      msg_valid   => rx_valid,
      msg_func    => rx_func,
      msg_data    => rx_data);

  uart_bus_tx_1 : entity work.uart_bus_tx
    generic map (
      BAUD_16_DIV => BAUD_16_DIV*16)
    port map (
      clk         => clk,
      rst         => rst,
      uart_ser_tx => uart_ser_tx,
      msg_valid   => rx_valid,
      msg_done    => msg_done,
      msg_func    => func,
      msg_data    => data);

end architecture arch;
