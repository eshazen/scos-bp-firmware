--
-- simple UART receiver example
-- integer version
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


entity uart_new is

  generic (
    g_BAUD_DIV : integer := 115     -- Needs to be set correctly
                                    -- (can be 1 for simulation)
    );
  port (
    rst       : in  std_logic;          -- active high asynchronous reset
    RsRx      : in  std_logic;          -- serial input data
    ser_dat   : out std_logic_vector(7 downto 0);  -- serial output
    ser_valid : out std_logic;          -- serial data valid
    clk       : in  std_logic);         -- 100 MHz clock

end entity uart_new;


architecture arch of uart_new is

  -- calculate oversampling clock divider value
  constant BaudDiv : integer := g_BAUD_DIV;
  constant OVER_SAMPLE   : integer := 16;      -- over-sampling factor

  signal rst_n : std_logic;

  -- serial port signals
  signal baud_sample : std_logic;
  signal ser_sr      : std_logic_vector(9 downto 0);  -- serial shift register
  signal ser_busy    : std_logic;       -- '1' while shifting in a word
  signal valid_out   : std_logic;       -- serial valid out next clock
--  signal frameErr    : std_logic;       -- valid start and stop bits
  signal rx_last     : std_logic;

  -- counts from 0 to 15 for 16X oversampling
  signal sampCtr : integer range 0 to OVER_SAMPLE-1 := 0;

  -- counts from 0 to 9 for 8 bits + start + stop
  signal bitCtr : integer range 0 to 15 := 0;

  -- counts system clocks between oversampling intervals
  signal baudCtr : integer range 0 to BaudDiv-1 := 0;

begin  -- architecture arch

  rst_n <= not rst;

  process (clk, rst_n) is


  begin  -- process

    if rst_n = '0' then                 -- asynchronous reset (active low)
      sampCtr <= 0;
      baudCtr <= 0;
      bitCtr  <= 0;

      baud_sample <= '0';
      ser_busy    <= '0';
      valid_out   <= '0';
--      frameErr    <= '0';
      ser_sr      <= (others => '0');

    elsif clk'event and clk = '1' then  -- 100MHz rising clock edge

      valid_out <= '0';
      ser_valid <= valid_out;           -- delay 1 clock

      -- baud rate clock divider
      -- 
      if baudCtr = BaudDiv-1 then
        baudCtr     <= 0;
        baud_sample <= '1';
      else
        baudCtr     <= baudCtr + 1;
        baud_sample <= '0';
      end if;

      -- sample each 16X baud clock
      if baud_sample = '1' then

        rx_last <= RsRx;                -- copy input

        if ser_busy = '0' then          -- not receiving, scan for start bit

          if RsRx = '0' and rx_last = '1' then  -- start bit seen
            sampCtr  <= 0;
            bitCtr   <= 0;
            ser_busy <= '1';
          end if;

        else                            -- receiving, shift in bits

          if sampCtr = OVER_SAMPLE-1 then
            sampCtr <= 0;
          else
            sampCtr <= sampCtr + 1;     -- increment 16x counter
          end if;

          if sampCtr = OVER_SAMPLE/2 then
            bitCtr <= bitCtr + 1;                 -- yes, increment bit counter
            ser_sr <= RsRx & ser_sr(9 downto 1);  -- capture next bit
          end if;

          if bitCtr = 10 then           -- counted 10 bits (start+8+stop)
            ser_busy  <= '0';
            ser_dat   <= ser_sr(8 downto 1);  -- copy SR to output (skip start bit)
--            frameErr  <= ser_sr(9) = '1' and ser_sr(0) = '0';
            valid_out <= '1';
          end if;

        end if;

      end if;

    end if;
  end process;

end architecture arch;
