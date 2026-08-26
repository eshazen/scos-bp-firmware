-----------------------------------------------------------------------------
-- Top level unit
--
-- Firmware to acquire raw image slices and real-time pre-processing for
-- speckle contrast optical spectroscopy from a AMS MIRA220 sensor.
--
-- BU Neurophotonics Center 2026
-- bzim@bu.edu
--
-- Start edits for custom Pi Hat board
------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

entity mira_test_top is
  port (
    Clk48xCI : in std_logic;
--    ResetxRI : in std_logic; -- no hardware reset

    -- Image sensor interface
    MipiRxP    : inout std_logic_vector(1 downto 0);
    MipiRxN    : inout std_logic_vector(1 downto 0);
    MipiRxCkP  : inout std_logic;
    MipiRxCkN  : inout std_logic;
    CCISCLxSIO : inout std_logic;       -- sensor I2C
    CCISDAxSIO : inout std_logic;       -- sensor I2C

--    -- FTDI UART USB interface (not used for SPI)
--    UartRTSntoFPGAxDI : in  std_logic;
--    UartCTSntoFTDIxDO : out std_logic;
--    UartFPGAtoFTDIxDO : out std_logic;
--    UartFTDItoFPGAxDI : in  std_logic;

    -- SPI Raspberry Pi 0 interface
    SpiRPi0SCKxSI  : in  std_logic;
    SpiRPi0CSnxSI  : in  std_logic;
    SpiRPi0MISOxDO : out std_logic;
    SpiRPi0MOSIxDI : in  std_logic;

    -- Misc / Debug
    LEDxSO : out std_logic_vector(1 downto 0)
    );
end mira_test_top;

architecture architecture_mira_test_top of mira_test_top is

  constant FW_VER              : integer := 1;
  constant BIT_DEPTH           : integer := 10;    -- Image data bit depth. Supported: 8,10,12. Mira config must match.
  constant UART_CLK_DIV        : integer := 8;     -- Determines UART baud rate. 96 / 8 = 12 MBPS
  constant N_CFG_REG_ADDR_BITS : integer := 4;     -- Determines number of available config registers, 2**N
  constant N_CMD_BYTES         : integer := 2;     -- Number of bytes to read/write config register.
  constant N_COLS              : integer := 1600;  -- Number of columns in image. Mira config must match.
  constant N_LINES             : integer := 480;   -- Number of rows/lines in image. Mira config must match.
--  constant IFACE_TYPE          : string  := "SPI";  -- Interface to computer. Select "UART" or "SPI".

  signal ResetxRI : std_logic := '0';   -- bogus reset never active

  signal ClkxC     : std_logic;
  signal PLLLockxS : std_logic;

  signal ClkCntxDP, ClkCntxDN : integer range 0 to 47999999;  -- only for blinking LED
  -- ## Configuration Register related ##
  type cfgreg_type is array (0 to N_CFG_REG_ADDR_BITS**2-1) of std_logic_vector(7 downto 0);
  signal CfgRegxDP, CfgRegxDN : cfgreg_type;

  type cfgfsmsreg_type is array (0 to N_CMD_BYTES-1) of std_logic_vector(7 downto 0);
  signal CfgFSMSRegxDP, CfgFSMSRegxDN : cfgfsmsreg_type;

  type cfgfsmstate_type is (sIdle, sRxBytes, sDecodeCmd, sTxHeader, sTxReg);
  signal CfgStatexDP, CfgStatexDN : cfgfsmstate_type;

  signal CfgByteCntxDP, CfgByteCntxDN : integer range 0 to N_CMD_BYTES-1;
  signal CfgPDatOutxD                 : std_logic_vector(7 downto 0);
  signal CfgPDatOutValidxS            : std_logic;
  signal RdyForCfgPDatxS              : std_logic;
  signal CfgPDatInxD                  : std_logic_vector(7 downto 0);
  signal CfgPDatInValidxS             : std_logic;

  -- ## Pixel Data related ##
  signal PixDataxD      : std_logic_vector(4*BIT_DEPTH-1 downto 0);  -- 2 MIPI lanes * 16x gearing = up to 4 pixels per clock
  signal PixDataValidxS : std_logic;
  signal InFramexS      : std_logic;
  signal InLinexS       : std_logic;

  -- ## UART / SPI / Control logic related ##
  signal PDatOutTxRdyxS : std_logic;
  signal PDatOutValidxS : std_logic;
  signal PDatOutxD      : std_logic_vector(7 downto 0);

  signal FrameTrigxS      : std_logic;
  signal RdyForFrameDatxS : std_logic;
  signal FrameDatxD       : std_logic_vector(7 downto 0);
  signal FrameDatValidxS  : std_logic;

  signal ProcDatxD       : std_logic_vector(7 downto 0);
  signal ProcDatValidxS  : std_logic;
  signal RdyForProcDatxS : std_logic;
  signal RunProcxS       : std_logic;
  signal ResetFIFOxS     : std_logic;

  signal SpiRPi0MISOxD : std_logic;

  component main_pll is
    port(
      clki_i  : in  std_logic;
      clkop_o : out std_logic;
      lock_o  : out std_logic
      );
  end component;

begin
  -- ensure <=7 bit address for cfg reg. high bit is r/w
  assert N_CFG_REG_ADDR_BITS < 8 severity error;

  -- ## configuration register related ##

  -- Configuration Register Map -- CfgReg
  -- ( 0) - Status Bits: (0) Run Img Processing, (1) Trigger Raw Frame, (7) Reset FIFOs
  -- ( 1) - Select Data Souce: 0x00 CfgReg, 0x01 Img Processing, 0x02 Raw Frame
  -- ( 2) - Img Processing : Dark level subtraction value
  -- ( 3) - Spare
  -- ( 4) - Spare
  -- ( 5) - Raw Frame: Index of image slice to be acquired
  -- ( 6) - Raw Frame: Number of frames to be summed
  -- ( 7) - Spare
  -- ( 8) - I2C: (0) SCL force, (1) SDA force, (2) SCL read, (3) SDA read
  -- ( 9) - Spare
  -- (10) - Spare
  -- (11) - Spare
  -- (12) - Spare
  -- (13) - Spare
  -- (14) - Bit Depth setting of this bitstream - read only
  -- (15) - Firmware version - read only

  -- FSM used to write/read configuration registers
  p_cfg_memzing : process (ClkxC, ResetxRI)
  begin
    if (ResetxRI = '1') then
      CfgStatexDP   <= sIdle;
      CfgFSMSRegxDP <= (others => (others => '0'));
      CfgRegxDP     <= (others => (others => '0'));
      CfgByteCntxDP <= 0;
    elsif (rising_edge(ClkxC)) then
      CfgStatexDP   <= CfgStatexDN;
      CfgFSMSRegxDP <= CfgFSMSRegxDN;
      CfgRegxDP     <= CfgRegxDN;
      CfgByteCntxDP <= CfgByteCntxDN;
    end if;
  end process;

  p_cfg_memless : process(all)
  begin
    CfgStatexDN       <= CfgStatexDP;
    CfgFSMSRegxDN     <= CfgFSMSRegxDP;
    CfgRegxDN         <= CfgRegxDP;
    CfgByteCntxDN     <= CfgByteCntxDP;
    CfgPDatOutxD      <= x"FE";
    CfgPDatOutValidxS <= '0';

    case CfgStatexDP is
      when sIdle =>
        CfgByteCntxDN <= N_CMD_BYTES-1;
        if (CfgPDatInValidxS = '1' and CfgPDatInxD = x"FE") then             -- all commands must start with 0xFE
          CfgStatexDN <= sRxBytes;
        end if;
      when sRxBytes =>
        if CfgPDatInValidxS = '1' then
          CfgByteCntxDN <= CfgByteCntxDP -1;
          CfgFSMSRegxDN <= CfgFSMSRegxDP(1 to N_CMD_BYTES-1) & CfgPDatInxD;  -- shift in byte
          if CfgByteCntxDP = 0 then
            CfgStatexDN <= sDecodeCmd;
          end if;
        end if;
      when sDecodeCmd =>
        if CfgFSMSRegxDP(0)(7) = '1' then                                    -- write register
          CfgRegxDN(to_integer(unsigned(CfgFSMSRegxDP(0)(N_CFG_REG_ADDR_BITS-1 downto 0)))) <= CfgFSMSRegxDP(1);
          CfgStatexDN                                                                       <= sIdle;
        else                            -- read register
          CfgStatexDN <= sTxHeader;
        end if;
      when sTxHeader =>
        CfgPDatOutxD <= x"FD";          -- all replies start with 0xFD
        if RdyForCfgPDatxS = '1' then
          CfgPDatOutValidxS <= '1';
          CfgStatexDN       <= sTxReg;
        end if;
      when sTxReg =>                    -- send out the requested configuration byte/register
        CfgPDatOutxD <= CfgRegxDP(to_integer(unsigned(CfgFSMSRegxDP(0)(N_CFG_REG_ADDR_BITS-1 downto 0))));
        if RdyForCfgPDatxS = '1' then
          CfgPDatOutValidxS <= '1';
          CfgStatexDN       <= sIdle;
        end if;

      when others =>
        CfgStatexDN <= sIdle;
    end case;

    -- Define constant/read-only registers or bits in registers
    CfgRegxDN(8)(2) <= CCISCLxSIO;      -- SCL readback value
    CfgRegxDN(8)(3) <= CCISDAxSIO;      -- SDA readback values
    CfgRegxDN(14)   <= std_logic_vector(to_unsigned(BIT_DEPTH, 8));
    CfgRegxDN(15)   <= std_logic_vector(to_unsigned(FW_VER, 8));
  end process;

  -- bit-bang I2C output, controlled by rapidly changing configuration register 8
  CCISCLxSIO <= '0' when CfgRegxDP(8)(0) = '0' else 'Z';
  CCISDAxSIO <= '0' when CfgRegxDP(8)(1) = '0' else 'Z';
  -- ## Data acquisition MUX ##
  -- this MUX selects which datastream is sent to the computer 
  p_acq_mux_memless : process(all)
  begin

    RunProcxS   <= CfgRegxDP(0)(0);
    FrameTrigxS <= CfgRegxDP(0)(1);
    ResetFIFOxS <= CfgRegxDP(0)(7);

    RdyForCfgPDatxS  <= '0';
    RdyForProcDatxS  <= '0';
    RdyForFrameDatxS <= '0';

    case CfgRegxDP(1) is
      when x"00" =>                     -- readback from CfgReg
        RdyForCfgPDatxS <= PDatOutTxRdyxS;
        PDatOutValidxS  <= CfgPDatOutValidxS;
        PDatOutxD       <= CfgPDatOutxD;
      when x"01" =>                     -- data from process_image 
        RdyForProcDatxS <= PDatOutTxRdyxS;
        PDatOutValidxS  <= ProcDatValidxS;
        PDatOutxD       <= ProcDatxD;
      when x"02" =>                     -- data from frame buffer
        RdyForFrameDatxS <= PDatOutTxRdyxS;
        PDatOutValidxS   <= FrameDatValidxS;
        PDatOutxD        <= FrameDatxD;
      when others =>                    -- same as x"00"
        RdyForCfgPDatxS <= PDatOutTxRdyxS;
        PDatOutValidxS  <= CfgPDatOutValidxS;
        PDatOutxD       <= CfgPDatOutxD;
    end case;
  end process;


  -- process just for blinking LED
  p_memzing : process (ClkxC, ResetxRI)
  begin
    if (ResetxRI = '1') then
      ClkCntxDP <= 0;
    elsif (rising_edge(ClkxC)) then
      ClkCntxDP <= ClkCntxDN;
    end if;
  end process;

  -- debug signals
  ClkCntxDN <= ClkCntxDP + 1 when ClkCntxDP < 47999999 else 0;
  LEDxSO(0) <= '0'           when ClkCntxDP < 12000000 else '1';
  LEDxSO(1) <= not CfgRegxDP(10)(0);

  -- ## component instances ##
  mipi_rx_inst : entity work.mipi_rx
    generic map(
      BIT_DEPTH => BIT_DEPTH,
      N_COLS    => N_COLS
      )
    port map(
      ClkxCI          => ClkxC,
      ResetxRI        => ResetxRI,
      MipiRxP         => MipiRxP,
      MipiRxN         => MipiRxN,
      MipiRxCkP       => MipiRxCkP,
      MipiRxCkN       => MipiRxCkN,
      PixDataxDO      => PixDataxD,
      PixDataValidxSO => PixDataValidxS,
      InLinexSO       => InLinexS,
      InFramexSO      => InFramexS,
      DebugDataxDO    => open
      );

  process_image_inst : entity work.process_image
    generic map(
      BIT_DEPTH => BIT_DEPTH,
      N_COLS    => N_COLS
      )
    port map(
      ClkxCI   => ClkxC,
      ResetxRI => ResetxRI,
      RunxSI   => RunProcxS,

      -- pixel data input
      PixValxDI     => PixDataxD,
      PixDarkValxDI => CfgRegxDP(2),
      PixValidxSI   => PixDataValidxS,
      FrameValidxSI => InFramexS,
      LineValidxSI  => InLinexS,

      -- processed data output
      PDatxDO              => ProcDatxD,
      PDatValidxSO         => ProcDatValidxS,
      RdyForPDatxSI        => RdyForProcDatxS,
      -- debug
      PDatValidFromProcxSO => open
      );

  frame_buf_inst : entity work.frame_buf
    generic map(
      BIT_DEPTH => BIT_DEPTH,
      N_COLS    => N_COLS,
      N_LINES   => N_LINES
      )
    port map(
      ClkxCI   => ClkxC,
      ResetxRI => ResetxRI,

      -- pixel data input
      PixDatxDI      => PixDataxD,
      PixDatValidxSI => PixDataValidxS,
      InFramexSI     => InFramexS,
      TrigxSI        => FrameTrigxS,

      -- control signals
      SliceSelxDI => CfgRegxDP(5),
      SumCntxDI   => CfgRegxDP(6),

      -- processed data output
      UartRdyxSI   => RdyForFrameDatxS,
      PDatxDO      => FrameDatxD,
      PDatValidxSO => FrameDatValidxS
      );


  spi_rxtx : entity work.spi_rxtx_with_fifo
    port map (
      ClkxCI         => ClkxC,
      ResetxRI       => ResetxRI,
      ResetTxFIFOxSI => ResetFIFOxS,
      CSnxSI         => SpiRPi0CSnxSI,
      MISOxDO        => SpiRPi0MISOxD,
      MOSIxDI        => SpiRPi0MOSIxDI,
      SCKxSI         => SpiRPi0SCKxSI,
      BuffFullxSO    => open,
      BuffEmptyxSO   => PDatOutTxRdyxS,
      ParDatRdyxSI   => PDatOutValidxS,
      ParDatxDI      => PDatOutxD,
      ParDatxDO      => CfgPDatInxD,
      ParDatRdyxSO   => CfgPDatInValidxS,
      RxIndxSO       => open,
      TxIndxSO       => open
      );
  SpiRPi0MISOxDO <= SpiRPi0MISOxD;

  main_pll_inst : main_pll port map(
    clki_i  => Clk48xCI,
    clkop_o => ClkxC,
    lock_o  => PLLLockxS
    );

end architecture_mira_test_top;
