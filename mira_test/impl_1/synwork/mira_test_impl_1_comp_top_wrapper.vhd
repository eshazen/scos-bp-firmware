--
-- Synopsys
-- Vhdl wrapper for top level design, written on Wed Jul 29 01:25:43 2026
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wrapper_for_mira_test_top is
   port (
      Clk48xCI : in std_logic;
      ResetxRI : in std_logic;
      MipiRxP : in std_logic_vector(1 downto 0);
      MipiRxN : in std_logic_vector(1 downto 0);
      MipiRxCkP : in std_logic;
      MipiRxCkN : in std_logic;
      CCISCLxSIO : in std_logic;
      CCISDAxSIO : in std_logic;
      UartRTSntoFPGAxDI : in std_logic;
      UartCTSntoFTDIxDO : out std_logic;
      UartFPGAtoFTDIxDO : out std_logic;
      UartFTDItoFPGAxDI : in std_logic;
      SpiRPi0SCKxSI : in std_logic;
      SpiRPi0CSnxSI : in std_logic;
      SpiRPi0MISOxDO : out std_logic;
      SpiRPi0MOSIxDI : in std_logic;
      DebugDataxDO : out std_logic_vector(3 downto 0);
      LEDxSO : out std_logic_vector(13 downto 0)
   );
end wrapper_for_mira_test_top;

architecture architecture_mira_test_top of wrapper_for_mira_test_top is

component mira_test_top
 port (
   Clk48xCI : in std_logic;
   ResetxRI : in std_logic;
   MipiRxP : inout std_logic_vector (1 downto 0);
   MipiRxN : inout std_logic_vector (1 downto 0);
   MipiRxCkP : inout std_logic;
   MipiRxCkN : inout std_logic;
   CCISCLxSIO : inout std_logic;
   CCISDAxSIO : inout std_logic;
   UartRTSntoFPGAxDI : in std_logic;
   UartCTSntoFTDIxDO : out std_logic;
   UartFPGAtoFTDIxDO : out std_logic;
   UartFTDItoFPGAxDI : in std_logic;
   SpiRPi0SCKxSI : in std_logic;
   SpiRPi0CSnxSI : in std_logic;
   SpiRPi0MISOxDO : out std_logic;
   SpiRPi0MOSIxDI : in std_logic;
   DebugDataxDO : out std_logic_vector (3 downto 0);
   LEDxSO : out std_logic_vector (13 downto 0)
 );
end component;

signal tmp_Clk48xCI : std_logic;
signal tmp_ResetxRI : std_logic;
signal tmp_MipiRxP : std_logic_vector (1 downto 0);
signal tmp_MipiRxN : std_logic_vector (1 downto 0);
signal tmp_MipiRxCkP : std_logic;
signal tmp_MipiRxCkN : std_logic;
signal tmp_CCISCLxSIO : std_logic;
signal tmp_CCISDAxSIO : std_logic;
signal tmp_UartRTSntoFPGAxDI : std_logic;
signal tmp_UartCTSntoFTDIxDO : std_logic;
signal tmp_UartFPGAtoFTDIxDO : std_logic;
signal tmp_UartFTDItoFPGAxDI : std_logic;
signal tmp_SpiRPi0SCKxSI : std_logic;
signal tmp_SpiRPi0CSnxSI : std_logic;
signal tmp_SpiRPi0MISOxDO : std_logic;
signal tmp_SpiRPi0MOSIxDI : std_logic;
signal tmp_DebugDataxDO : std_logic_vector (3 downto 0);
signal tmp_LEDxSO : std_logic_vector (13 downto 0);

begin

tmp_Clk48xCI <= Clk48xCI;

tmp_ResetxRI <= ResetxRI;

tmp_MipiRxP <= MipiRxP;

tmp_MipiRxN <= MipiRxN;

tmp_MipiRxCkP <= MipiRxCkP;

tmp_MipiRxCkN <= MipiRxCkN;

tmp_CCISCLxSIO <= CCISCLxSIO;

tmp_CCISDAxSIO <= CCISDAxSIO;

tmp_UartRTSntoFPGAxDI <= UartRTSntoFPGAxDI;

UartCTSntoFTDIxDO <= tmp_UartCTSntoFTDIxDO;

UartFPGAtoFTDIxDO <= tmp_UartFPGAtoFTDIxDO;

tmp_UartFTDItoFPGAxDI <= UartFTDItoFPGAxDI;

tmp_SpiRPi0SCKxSI <= SpiRPi0SCKxSI;

tmp_SpiRPi0CSnxSI <= SpiRPi0CSnxSI;

SpiRPi0MISOxDO <= tmp_SpiRPi0MISOxDO;

tmp_SpiRPi0MOSIxDI <= SpiRPi0MOSIxDI;

DebugDataxDO <= tmp_DebugDataxDO;

LEDxSO <= tmp_LEDxSO;



u1:   mira_test_top port map (
		Clk48xCI => tmp_Clk48xCI,
		ResetxRI => tmp_ResetxRI,
		MipiRxP => tmp_MipiRxP,
		MipiRxN => tmp_MipiRxN,
		MipiRxCkP => tmp_MipiRxCkP,
		MipiRxCkN => tmp_MipiRxCkN,
		CCISCLxSIO => tmp_CCISCLxSIO,
		CCISDAxSIO => tmp_CCISDAxSIO,
		UartRTSntoFPGAxDI => tmp_UartRTSntoFPGAxDI,
		UartCTSntoFTDIxDO => tmp_UartCTSntoFTDIxDO,
		UartFPGAtoFTDIxDO => tmp_UartFPGAtoFTDIxDO,
		UartFTDItoFPGAxDI => tmp_UartFTDItoFPGAxDI,
		SpiRPi0SCKxSI => tmp_SpiRPi0SCKxSI,
		SpiRPi0CSnxSI => tmp_SpiRPi0CSnxSI,
		SpiRPi0MISOxDO => tmp_SpiRPi0MISOxDO,
		SpiRPi0MOSIxDI => tmp_SpiRPi0MOSIxDI,
		DebugDataxDO => tmp_DebugDataxDO,
		LEDxSO => tmp_LEDxSO
       );
end architecture_mira_test_top;
