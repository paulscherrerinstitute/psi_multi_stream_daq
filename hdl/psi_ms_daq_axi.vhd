------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.psi_common_math_pkg.all;
use work.psi_common_array_pkg.all;
use work.psi_ms_daq_pkg.all;

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
entity psi_ms_daq_axi is
  generic(
    -- Streams
    Streams_g               : positive range 1 to 32   := 2;
    StreamWidth_g           : t_ainteger               := (16, 16);
    StreamPrio_g            : t_ainteger               := (1, 1);
    StreamBuffer_g          : t_ainteger               := (1024, 1024);
    StreamTimeout_g         : t_areal                  := (1.0e-3, 1.0e-3);
    StreamClkFreq_g         : t_areal                  := (100.0e6, 100.0e6);
    StreamTsFifoDepth_g     : t_ainteger               := (16, 16);
    StreamUseTs_g           : t_abool                  := (true, true);
    -- Recording
    MaxWindows_g            : positive range 1 to 32   := 16;
    MinBurstSize_g          : integer range 1 to 512   := 512;
    MaxBurstSize_g          : integer range 1 to 512   := 512;
    -- Axi
    AxiDataWidth_g          : natural range 64 to 1024 := 64;
    AxiMaxBurstBeats_g      : integer range 1 to 256   := 256;
    AxiMaxOpenTrasactions_g : natural range 1 to 8     := 8;
    AxiFifoDepth_g          : natural                  := 1024;
    -- Axi Slave
    AxiSlaveIdWidth_g       : integer                  := 0
  );
  port(
    -- Data Stream Input
    Str_Clk       : in  std_logic_vector(Streams_g - 1 downto 0);
    Str_Data      : in  t_aslv64(Streams_g - 1 downto 0);
    Str_Ts        : in  t_aslv64(Streams_g - 1 downto 0);
    Str_Vld       : in  std_logic_vector(Streams_g - 1 downto 0);
    Str_Rdy       : out std_logic_vector(Streams_g - 1 downto 0);
    Str_Trig      : in  std_logic_vector(Streams_g - 1 downto 0);
    -- Miscellaneous
    Irq           : out std_logic;
    -- AXI Slave Interface for Register Access
    S_Axi_Aclk    : in  std_logic;
    S_Axi_Aresetn : in  std_logic;
    S_Axi_ArId    : in  std_logic_vector(AxiSlaveIdWidth_g - 1 downto 0);
    S_Axi_ArAddr  : in  std_logic_vector(15 downto 0);
    S_Axi_Arlen   : in  std_logic_vector(7 downto 0);
    S_Axi_ArSize  : in  std_logic_vector(2 downto 0);
    S_Axi_ArBurst : in  std_logic_vector(1 downto 0);
    S_Axi_ArLock  : in  std_logic;
    S_Axi_ArCache : in  std_logic_vector(3 downto 0);
    S_Axi_ArProt  : in  std_logic_vector(2 downto 0);
    S_Axi_ArValid : in  std_logic;
    S_Axi_ArReady : out std_logic;
    S_Axi_RId     : out std_logic_vector(AxiSlaveIdWidth_g - 1 downto 0);
    S_Axi_RData   : out std_logic_vector(31 downto 0);
    S_Axi_RResp   : out std_logic_vector(1 downto 0);
    S_Axi_RLast   : out std_logic;
    S_Axi_RValid  : out std_logic;
    S_Axi_RReady  : in  std_logic;
    S_Axi_AwId    : in  std_logic_vector(AxiSlaveIdWidth_g - 1 downto 0);
    S_Axi_AwAddr  : in  std_logic_vector(15 downto 0);
    S_Axi_AwLen   : in  std_logic_vector(7 downto 0);
    S_Axi_AwSize  : in  std_logic_vector(2 downto 0);
    S_Axi_AwBurst : in  std_logic_vector(1 downto 0);
    S_Axi_AwLock  : in  std_logic;
    S_Axi_AwCache : in  std_logic_vector(3 downto 0);
    S_Axi_AwProt  : in  std_logic_vector(2 downto 0);
    S_Axi_AwValid : in  std_logic;
    S_Axi_AwReady : out std_logic;
    S_Axi_WData   : in  std_logic_vector(31 downto 0);
    S_Axi_WStrb   : in  std_logic_vector(3 downto 0);
    S_Axi_WLast   : in  std_logic;
    S_Axi_WValid  : in  std_logic;
    S_Axi_WReady  : out std_logic;
    S_Axi_BId     : out std_logic_vector(AxiSlaveIdWidth_g - 1 downto 0);
    S_Axi_BResp   : out std_logic_vector(1 downto 0);
    S_Axi_BValid  : out std_logic;
    S_Axi_BReady  : in  std_logic;
    -- AXI Master Interface for Memory Access
    M_Axi_Aclk    : in  std_logic;
    M_Axi_Aresetn : in  std_logic;
    M_Axi_AwAddr  : out std_logic_vector(31 downto 0);
    M_Axi_AwLen   : out std_logic_vector(7 downto 0);
    M_Axi_AwSize  : out std_logic_vector(2 downto 0);
    M_Axi_AwBurst : out std_logic_vector(1 downto 0);
    M_Axi_AwLock  : out std_logic;
    M_Axi_AwCache : out std_logic_vector(3 downto 0);
    M_Axi_AwProt  : out std_logic_vector(2 downto 0);
    M_Axi_AwValid : out std_logic;
    M_Axi_AwReady : in  std_logic                                     := '0';
    M_Axi_WData   : out std_logic_vector(AxiDataWidth_g - 1 downto 0);
    M_Axi_WStrb   : out std_logic_vector(AxiDataWidth_g / 8 - 1 downto 0);
    M_Axi_WLast   : out std_logic;
    M_Axi_WValid  : out std_logic;
    M_Axi_WReady  : in  std_logic                                     := '0';
    M_Axi_BResp   : in  std_logic_vector(1 downto 0)                  := (others => '0');
    M_Axi_BValid  : in  std_logic                                     := '0';
    M_Axi_BReady  : out std_logic;
    M_Axi_ArAddr  : out std_logic_vector(31 downto 0);
    M_Axi_ArLen   : out std_logic_vector(7 downto 0);
    M_Axi_ArSize  : out std_logic_vector(2 downto 0);
    M_Axi_ArBurst : out std_logic_vector(1 downto 0);
    M_Axi_ArLock  : out std_logic;
    M_Axi_ArCache : out std_logic_vector(3 downto 0);
    M_Axi_ArProt  : out std_logic_vector(2 downto 0);
    M_Axi_ArValid : out std_logic;
    M_Axi_ArReady : in  std_logic                                     := '0';
    M_Axi_RData   : in  std_logic_vector(AxiDataWidth_g - 1 downto 0) := (others => '0');
    M_Axi_RResp   : in  std_logic_vector(1 downto 0)                  := (others => '0');
    M_Axi_RLast   : in  std_logic                                     := '0';
    M_Axi_RValid  : in  std_logic                                     := '0';
    M_Axi_RReady  : out std_logic
  );
end entity;

------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of psi_ms_daq_axi is

  -- Config Arrays with correct size
  constant StreamWidth_c       : t_ainteger(0 to Streams_g - 1) := StreamWidth_g(0 to Streams_g - 1);
  constant StreamPrio_c        : t_ainteger(0 to Streams_g - 1) := StreamPrio_g(0 to Streams_g - 1);
  constant StreamBuffer_c      : t_ainteger(0 to Streams_g - 1) := StreamBuffer_g(0 to Streams_g - 1);
  constant StreamTimeout_c     : t_areal(0 to Streams_g - 1)    := StreamTimeout_g(0 to Streams_g - 1);
  constant StreamClkFreq_c     : t_areal(0 to Streams_g - 1)    := StreamClkFreq_g(0 to Streams_g - 1);
  constant StreamTsFifoDepth_c : t_ainteger(0 to Streams_g - 1) := StreamTsFifoDepth_g(0 to Streams_g - 1);
  constant StreamUseTs_c       : t_abool(0 to Streams_g - 1)    := StreamUseTs_g(0 to Streams_g - 1);

  -- Input/Statemachine Signals
  signal InpSm_HasTlast : std_logic_vector(Streams_g - 1 downto 0);
  signal InpSm_TsVld    : std_logic_vector(Streams_g - 1 downto 0);
  signal InpSm_TsRdy    : std_logic_vector(Streams_g - 1 downto 0);
  signal InpSm_Level    : t_aslv16(Streams_g - 1 downto 0);
  signal InpSm_TsData   : t_aslv64(Streams_g - 1 downto 0);

  -- Statemachine/Dma
  signal SmDma_Cmd     : DaqSm2DaqDma_Cmd_t;
  signal SmDma_CmdVld  : std_logic;
  signal DmaSm_Resp    : DaqDma2DaqSm_Resp_t;
  signal DmaSm_RespVld : std_logic;
  signal DmaSm_RespRdy : std_logic;
  signal DmaSm_HasLast : std_logic_vector(Streams_g - 1 downto 0);

  -- Input/Dma
  signal InpDma_Vld  : std_logic_vector(Streams_g - 1 downto 0);
  signal InpDma_Rdy  : std_logic_vector(Streams_g - 1 downto 0);
  signal InpDma_Data : Input2Daq_Data_a(Streams_g - 1 downto 0);

  -- Dma/Mem
  signal DmaMem_CmdAddr : std_logic_vector(31 downto 0);
  signal DmaMem_CmdSize : std_logic_vector(31 downto 0);
  signal DmaMem_CmdVld  : std_logic;
  signal DmaMem_CmdRdy  : std_logic;
  signal DmaMem_DatData : std_logic_vector(63 downto 0);
  signal DmaMem_DatVld  : std_logic;
  signal DmaMem_DatRdy  : std_logic;

  -- Mem/Statemachine
  signal MemSm_Done : std_logic;

  -- Configuration
  signal Cfg_StrEna   : std_logic_vector(Streams_g - 1 downto 0);
  signal Cfg_GlbEna   : std_logic;
  signal Cfg_PostTrig : t_aslv32(Streams_g - 1 downto 0);
  signal Cfg_Arm      : std_logic_vector(Streams_g - 1 downto 0);
  signal Cfg_RecMode  : t_aslv2(Streams_g - 1 downto 0);

  -- Status
  signal Stat_StrIrq      : std_logic_vector(Streams_g - 1 downto 0);
  signal Stat_StrLastWin  : WinType_a(Streams_g - 1 downto 0);
  signal Stat_IsArmed     : std_logic_vector(Streams_g - 1 downto 0);
  signal Stat_IsRecording : std_logic_vector(Streams_g - 1 downto 0);

  -- Context Memory Connections
  signal CtxStr_Cmd  : ToCtxStr_t;
  signal CtxStr_Resp : FromCtx_t;
  signal CtxWin_Cmd  : ToCtxWin_t;
  signal CtxWin_Resp : FromCtx_t;

  -- Others
  signal Sm_HasLast   : std_logic_vector(Streams_g - 1 downto 0);
  signal M_Axi_Areset : std_logic;      -- high active reset
  signal S_Axi_Areset : std_logic;      -- high active reset

begin

  M_Axi_Areset <= not M_Axi_Aresetn;
  S_Axi_Areset <= not S_Axi_Aresetn;

  --------------------------------------------
  -- Register Interface
  --------------------------------------------	
  i_reg : entity work.psi_ms_daq_reg_axi
    generic map(
      Streams_g         => Streams_g,
      MaxWindows_g      => MaxWindows_g,
      AxiSlaveIdWidth_g => AxiSlaveIdWidth_g
    )
    port map(
      S_Axi_Aclk    => S_Axi_Aclk,
      S_Axi_Aresetn => S_Axi_Aresetn,
      S_Axi_ArId    => S_Axi_ArId,
      S_Axi_ArAddr  => S_Axi_ArAddr,
      S_Axi_Arlen   => S_Axi_Arlen,
      S_Axi_ArSize  => S_Axi_ArSize,
      S_Axi_ArBurst => S_Axi_ArBurst,
      S_Axi_ArLock  => S_Axi_ArLock,
      S_Axi_ArCache => S_Axi_ArCache,
      S_Axi_ArProt  => S_Axi_ArProt,
      S_Axi_ArValid => S_Axi_ArValid,
      S_Axi_ArReady => S_Axi_ArReady,
      S_Axi_RId     => S_Axi_RId,
      S_Axi_RData   => S_Axi_RData,
      S_Axi_RResp   => S_Axi_RResp,
      S_Axi_RLast   => S_Axi_RLast,
      S_Axi_RValid  => S_Axi_RValid,
      S_Axi_RReady  => S_Axi_RReady,
      S_Axi_AwId    => S_Axi_AwId,
      S_Axi_AwAddr  => S_Axi_AwAddr,
      S_Axi_AwLen   => S_Axi_AwLen,
      S_Axi_AwSize  => S_Axi_AwSize,
      S_Axi_AwBurst => S_Axi_AwBurst,
      S_Axi_AwLock  => S_Axi_AwLock,
      S_Axi_AwCache => S_Axi_AwCache,
      S_Axi_AwProt  => S_Axi_AwProt,
      S_Axi_AwValid => S_Axi_AwValid,
      S_Axi_AwReady => S_Axi_AwReady,
      S_Axi_WData   => S_Axi_WData,
      S_Axi_WStrb   => S_Axi_WStrb,
      S_Axi_WLast   => S_Axi_WLast,
      S_Axi_WValid  => S_Axi_WValid,
      S_Axi_WReady  => S_Axi_WReady,
      S_Axi_BId     => S_Axi_BId,
      S_Axi_BResp   => S_Axi_BResp,
      S_Axi_BValid  => S_Axi_BValid,
      S_Axi_BReady  => S_Axi_BReady,
      IrqOut        => Irq,
      PostTrig      => Cfg_PostTrig,
      Arm           => Cfg_Arm,
      IsArmed       => Stat_IsArmed,
      IsRecording   => Stat_IsRecording,
      RecMode       => Cfg_RecMode,
      ClkMem        => M_Axi_Aclk,
      RstMem        => M_Axi_Areset,
      CtxStr_Cmd    => CtxStr_Cmd,
      CtxStr_Resp   => CtxStr_Resp,
      CtxWin_Cmd    => CtxWin_Cmd,
      CtxWin_Resp   => CtxWin_Resp,
      InLevel       => InpSm_Level,
      StrIrq        => Stat_StrIrq,
      StrLastWin    => Stat_StrLastWin,
      StrEna        => Cfg_StrEna,
      GlbEna        => Cfg_GlbEna
    );

  --------------------------------------------
  -- Input Logic Instantiation
  --------------------------------------------	
  g_input : for str in 0 to Streams_g - 1 generate
    signal InRst    : std_logic;
    signal StrInput : std_logic_vector(StreamWidth_c(str) - 1 downto 0);
  begin
    -- Reset if stream is disabled
    InRst    <= M_Axi_Areset or not Cfg_StrEna(str) or not Cfg_GlbEna;
    StrInput <= Str_Data(str)(StrInput'range);

    -- Instantiation
    i_input : entity work.psi_ms_daq_input
      generic map(
        StreamWidth_g       => StreamWidth_c(str),
        StreamBuffer_g      => StreamBuffer_c(str),
        StreamTimeout_g     => StreamTimeout_c(str),
        StreamClkFreq_g     => StreamClkFreq_c(str),
        StreamTsFifoDepth_g => StreamTsFifoDepth_c(str),
        StreamUseTs_g       => StreamUseTs_c(str)
      )
      port map(
        Str_Clk      => Str_Clk(str),
        Str_Vld      => Str_Vld(str),
        Str_Rdy      => Str_Rdy(str),
        Str_Data     => StrInput,
        Str_Trig     => Str_Trig(str),
        Str_Ts       => Str_Ts(str),
        ClkReg       => S_Axi_Aclk,
        RstReg       => S_Axi_Areset,
        PostTrigSpls => Cfg_PostTrig(str),
        Mode         => Cfg_RecMode(str),
        Arm          => Cfg_Arm(str),
        IsArmed      => Stat_IsArmed(str),
        IsRecording  => Stat_IsRecording(str),
        ClkMem       => M_Axi_Aclk,
        RstMem       => InRst,
        Daq_Vld      => InpDma_Vld(str),
        Daq_Rdy      => InpDma_Rdy(str),
        Daq_Data     => InpDma_Data(str),
        Daq_Level    => InpSm_Level(str),
        Daq_HasLast  => InpSm_HasTlast(str),
        Ts_Vld       => InpSm_TsVld(str),
        Ts_Rdy       => InpSm_TsRdy(str),
        Ts_Data      => InpSm_TsData(str)
      );
  end generate;

  --------------------------------------------
  -- Control State Machine
  --------------------------------------------
  -- Detect end-of frame in input buffer or DMA buffer
  Sm_HasLast <= InpSm_HasTlast or DmaSm_HasLast;

  -- Instantiation
  i_statemachine : entity work.psi_ms_daq_daq_sm
    generic map(
      Streams_g      => Streams_g,
      StreamPrio_g   => StreamPrio_c,
      StreamWidth_g  => StreamWidth_c,
      Windows_g      => MaxWindows_g,
      MinBurstSize_g => MinBurstSize_g,
      MaxBurstSize_g => MaxBurstSize_g
    )
    port map(
      Clk          => M_Axi_Aclk,
      Rst          => M_Axi_Areset,
      GlbEna       => Cfg_GlbEna,
      StrEna       => Cfg_StrEna,
      StrIrq       => Stat_StrIrq,
      StrLastWin   => Stat_StrLastWin,
      Inp_HasLast  => Sm_HasLast,
      Inp_Level    => InpSm_Level,
      Ts_Vld       => InpSm_TsVld,
      Ts_Rdy       => InpSm_TsRdy,
      Ts_Data      => InpSm_TsData,
      Dma_Cmd      => SmDma_Cmd,
      Dma_Cmd_Vld  => SmDma_CmdVld,
      Dma_Resp     => DmaSm_Resp,
      Dma_Resp_Vld => DmaSm_RespVld,
      Dma_Resp_Rdy => DmaSm_RespRdy,
      TfDone       => MemSm_Done,
      -- Context RAM connections
      CtxStr_Cmd   => CtxStr_Cmd,
      CtxStr_Resp  => CtxStr_Resp,
      CtxWin_Cmd   => CtxWin_Cmd,
      CtxWin_Resp  => CtxWin_Resp
    );

  --------------------------------------------
  -- DMA Engine
  --------------------------------------------	
  i_dma : entity work.psi_ms_daq_daq_dma
    generic map(
      Streams_g => Streams_g
    )
    port map(
      Clk            => M_Axi_Aclk,
      Rst            => M_Axi_Areset,
      DaqSm_Cmd      => SmDma_Cmd,
      DaqSm_Cmd_Vld  => SmDma_CmdVld,
      DaqSm_Resp     => DmaSm_Resp,
      DaqSm_Resp_Vld => DmaSm_RespVld,
      DaqSm_Resp_Rdy => DmaSm_RespRdy,
      DaqSm_HasLast  => DmaSm_HasLast,
      Inp_Vld        => InpDma_Vld,
      Inp_Rdy        => InpDma_Rdy,
      Inp_Data       => InpDma_Data,
      Mem_CmdAddr    => DmaMem_CmdAddr,
      Mem_CmdSize    => DmaMem_CmdSize,
      Mem_CmdVld     => DmaMem_CmdVld,
      Mem_CmdRdy     => DmaMem_CmdRdy,
      Mem_DatData    => DmaMem_DatData,
      Mem_DatVld     => DmaMem_DatVld,
      Mem_DatRdy     => DmaMem_DatRdy
    );

  --------------------------------------------
  -- Memory Interface
  --------------------------------------------	
  i_memif : entity work.psi_ms_daq_axi_if
    generic map(
      AxiDataWidth_g          => AxiDataWidth_g,
      AxiMaxBeats_g           => AxiMaxBurstBeats_g,
      AxiMaxOpenTrasactions_g => AxiMaxOpenTrasactions_g,
      MaxOpenCommands_g       => max(2, Streams_g), -- ISE tools implement memory as FFs for one stream. Reason is unkown, so we always implement two streams for resource optimization reasons.
      DataFifoDepth_g         => 1024,
      AxiFifoDepth_g          => AxiFifoDepth_g,
      RamBehavior_g           => "RBW"  -- Okay for Xilinx chips
    )
    port map(
      Clk           => M_Axi_Aclk,
      Rst_n         => M_Axi_Aresetn,
      Cmd_Addr      => DmaMem_CmdAddr,
      Cmd_Size      => DmaMem_CmdSize,
      Cmd_Vld       => DmaMem_CmdVld,
      Cmd_Rdy       => DmaMem_CmdRdy,
      Dat_Data      => DmaMem_DatData,
      Dat_Vld       => DmaMem_DatVld,
      Dat_Rdy       => DmaMem_DatRdy,
      Done          => MemSm_Done,
      M_Axi_AwAddr  => M_Axi_AwAddr,
      M_Axi_AwLen   => M_Axi_AwLen,
      M_Axi_AwSize  => M_Axi_AwSize,
      M_Axi_AwBurst => M_Axi_AwBurst,
      M_Axi_AwLock  => M_Axi_AwLock,
      M_Axi_AwCache => M_Axi_AwCache,
      M_Axi_AwProt  => M_Axi_AwProt,
      M_Axi_AwValid => M_Axi_AwValid,
      M_Axi_AwReady => M_Axi_AwReady,
      M_Axi_WData   => M_Axi_WData,
      M_Axi_WStrb   => M_Axi_WStrb,
      M_Axi_WLast   => M_Axi_WLast,
      M_Axi_WValid  => M_Axi_WValid,
      M_Axi_WReady  => M_Axi_WReady,
      M_Axi_BResp   => M_Axi_BResp,
      M_Axi_BValid  => M_Axi_BValid,
      M_Axi_BReady  => M_Axi_BReady,
      M_Axi_ArAddr  => M_Axi_ArAddr,
      M_Axi_ArLen   => M_Axi_ArLen,
      M_Axi_ArSize  => M_Axi_ArSize,
      M_Axi_ArBurst => M_Axi_ArBurst,
      M_Axi_ArLock  => M_Axi_ArLock,
      M_Axi_ArCache => M_Axi_ArCache,
      M_Axi_ArProt  => M_Axi_ArProt,
      M_Axi_ArValid => M_Axi_ArValid,
      M_Axi_ArReady => M_Axi_ArReady,
      M_Axi_RData   => M_Axi_RData,
      M_Axi_RResp   => M_Axi_RResp,
      M_Axi_RLast   => M_Axi_RLast,
      M_Axi_RValid  => M_Axi_RValid,
      M_Axi_RReady  => M_Axi_RReady
    );

end;

