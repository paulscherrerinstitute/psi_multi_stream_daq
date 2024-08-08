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
use work.psi_common_logic_pkg.all;
use work.psi_ms_daq_pkg.all;

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
entity psi_ms_daq_reg_axi is
  generic(
    Streams_g         : integer range 1 to 32;
    MaxWindows_g      : integer range 1 to 32;
    AxiSlaveIdWidth_g : integer
  );
  port(
    -- AXI Control Signals
    S_Axi_Aclk    : in  std_logic;
    S_Axi_Aresetn : in  std_logic;
    -- AXI Read address channel
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
    -- AXI Read data channel
    S_Axi_RId     : out std_logic_vector(AxiSlaveIdWidth_g - 1 downto 0);
    S_Axi_RData   : out std_logic_vector(31 downto 0);
    S_Axi_RResp   : out std_logic_vector(1 downto 0);
    S_Axi_RLast   : out std_logic;
    S_Axi_RValid  : out std_logic;
    S_Axi_RReady  : in  std_logic;
    -- AXI Write address channel
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
    -- AXI Write data channel
    S_Axi_WData   : in  std_logic_vector(31 downto 0);
    S_Axi_WStrb   : in  std_logic_vector(3 downto 0);
    S_Axi_WLast   : in  std_logic;
    S_Axi_WValid  : in  std_logic;
    S_Axi_WReady  : out std_logic;
    -- AXI Write response channel
    S_Axi_BId     : out std_logic_vector(AxiSlaveIdWidth_g - 1 downto 0);
    S_Axi_BResp   : out std_logic_vector(1 downto 0);
    S_Axi_BValid  : out std_logic;
    S_Axi_BReady  : in  std_logic;
    -- Control Signals (AXI-S Clk)
    Arm           : out std_logic_vector(Streams_g - 1 downto 0);
    IsArmed       : in  std_logic_vector(Streams_g - 1 downto 0);
    IsRecording   : in  std_logic_vector(Streams_g - 1 downto 0);
    PostTrig      : out t_aslv32(Streams_g - 1 downto 0);
    RecMode       : out t_aslv2(Streams_g - 1 downto 0);
    ToDisable     : out std_logic_vector(Streams_g - 1 downto 0);
    FrameTo       : out std_logic_vector(Streams_g - 1 downto 0);
    IrqOut        : out std_logic;
    AWCache       : out std_logic_vector(3 downto 0);
    AWProt        : out std_logic_vector(2 downto 0);
    ARCache       : out std_logic_vector(3 downto 0);
    ARProt        : out std_logic_vector(2 downto 0);
    -- Memory Interfae Clock domain control singals
    ClkMem        : in  std_logic;
    RstMem        : in  std_logic;
    -- Context Memory Interface (MemClk)
    CtxStr_Cmd    : in  ToCtxStr_t;
    CtxStr_Resp   : out FromCtx_t;
    CtxWin_Cmd    : in  ToCtxWin_t;
    CtxWin_Resp   : out FromCtx_t;
    -- Logic Interface (MemClk)
    StrIrq        : in  std_logic_vector(Streams_g - 1 downto 0);
    StrLastWin    : in  WinType_a(Streams_g - 1 downto 0);
    StrEna        : out std_logic_vector(Streams_g - 1 downto 0);
    GlbEna        : out std_logic;
    InLevel       : in  t_aslv16(Streams_g - 1 downto 0)
  );
end entity;

architecture rtl of psi_ms_daq_reg_axi is
  -- Two process method
  type two_process_r is record
    Reg_Gcfg_Ena       : std_logic;
    Reg_Gcfg_IrqEna    : std_logic;
    Reg_IrqVec         : std_logic_vector(Streams_g - 1 downto 0);
    Reg_IrqEna         : std_logic_vector(Streams_g - 1 downto 0);
    Reg_StrEna         : std_logic_vector(Streams_g - 1 downto 0);
    Reg_AcpCfg_ARProt  : std_logic_vector(2 downto 0);
    Reg_AcpCfg_ARCache : std_logic_vector(3 downto 0);
    Reg_AcpCfg_AWProt  : std_logic_vector(2 downto 0);
    Reg_AcpCfg_AWCache : std_logic_vector(3 downto 0);
    Reg_PostTrig       : t_aslv32(Streams_g - 1 downto 0);
    Reg_Mode_Recm      : t_aslv2(Streams_g - 1 downto 0);
    Reg_Mode_Arm       : std_logic_vector(Streams_g - 1 downto 0);
    Reg_Mode_ToDisable : std_logic_vector(Streams_g - 1 downto 0);
    Reg_Mode_FrameTo   : std_logic_vector(Streams_g - 1 downto 0);
    Irq                : std_logic;
    RegRdval           : std_logic_vector(31 downto 0);
    AddrReg            : std_logic_vector(15 downto 0);
    MaxLvlClr          : std_logic_vector(Streams_g - 1 downto 0);
  end record;
  signal r, r_next : two_process_r;

  constant DwWrite_c : std_logic_vector(3 downto 0) := "1111";

  constant DepthCtxStr_c    : integer := Streams_g * 32 / 8;
  constant CtxStrAddrHigh_c : integer := log2ceil(Streams_g * 32) - 1;
  signal CtxStr_WeLo        : std_logic;
  signal CtxStr_WeHi        : std_logic;
  signal CtxStr_Rdval       : std_logic_vector(63 downto 0);
  signal CtxStr_AddrB       : std_logic_vector(log2ceil(DepthCtxStr_c) - 1 downto 0);
  signal AddrCtxStr         : boolean;

  constant DepthCtxWin_c    : integer := Streams_g * MaxWindows_g * 16 / 8;
  constant CtxWinAddrHigh_c : integer := log2ceil(Streams_g * MaxWindows_g * 16) - 1;
  signal CtxWin_WeLo        : std_logic;
  signal CtxWin_WeHi        : std_logic;
  signal CtxWin_Rdval       : std_logic_vector(63 downto 0);
  signal CtxWin_AddrB       : std_logic_vector(log2ceil(DepthCtxWin_c) - 1 downto 0);
  signal AddrCtxWin         : boolean;

  -- High active reset
  signal A_Axi_Areset : std_logic;

  -- Maximum Level Latching
  signal MaxLevel : t_aslv16(Streams_g - 1 downto 0);

  -- Clock Crossing Signals
  signal StrIrq_Sync      : std_logic_vector(Streams_g - 1 downto 0);
  signal StrLastWin_Sync  : WinType_a(Streams_g - 1 downto 0);
  signal MaxLevel_Sync    : t_aslv16(Streams_g - 1 downto 0);
  signal MaxLevelClr_Sync : std_logic_vector(Streams_g - 1 downto 0);

  -- Axi Accesses
  signal AccAddr     : std_logic_vector(15 downto 0);
  signal AccAddrOffs : std_logic_vector(15 downto 0);
  signal AccWr       : std_logic_vector(3 downto 0);
  signal AccWrData   : std_logic_vector(31 downto 0);
  signal AccRdData   : std_logic_vector(31 downto 0);
  signal RegWrVal    : t_aslv32(0 to 15);
  signal RegRdVal    : t_aslv32(0 to 15) := (others => (others => '0'));
  signal RegWr       : std_logic_vector(15 downto 0);
begin
  A_Axi_Areset <= not S_Axi_Aresetn;

  --------------------------------------------
  -- Combinatorial Process
  --------------------------------------------
  p_comb : process(r, AccAddr, AccWr, AccWrData, StrIrq_Sync, IsArmed, IsRecording, CtxStr_Rdval, CtxWin_Rdval, MaxLevel, StrLastWin_Sync, RegWr, RegWrVal)
    variable v        : two_process_r;
    variable Stream_v : integer range 0 to Streams_g - 1;
  begin
    -- *** Hold variables stable ***
    v := r;

    -- *** General Register Accesses ***
    -- GCFG
    if RegWr(16#00# / 4) = '1' then
      v.Reg_Gcfg_Ena    := RegWrVal(16#00# / 4)(0);
      v.Reg_Gcfg_IrqEna := RegWrVal(16#00# / 4)(8);
    end if;
    RegRdVal(16#00# / 4)(0) <= r.Reg_Gcfg_Ena;
    RegRdVal(16#00# / 4)(8) <= r.Reg_Gcfg_IrqEna;

    -- GSTAT
    if RegWr(16#04# / 4) = '1' then
      null;
    end if;
    RegRdVal(16#04# / 4) <= (others => '0');

    -- IRQVEC
    if RegWr(16#10# / 4) = '1' then
      v.Reg_IrqVec := r.Reg_IrqVec and (not RegWrVal(16#10# / 4)(Streams_g - 1 downto 0));
    end if;
    RegRdVal(16#10# / 4)(Streams_g - 1 downto 0) <= r.Reg_IrqVec;

    -- IRQENA
    if RegWr(16#14# / 4) = '1' then
      v.Reg_IrqEna := RegWrVal(16#14# / 4)(Streams_g - 1 downto 0);
    end if;
    RegRdVal(16#14# / 4)(Streams_g - 1 downto 0) <= r.Reg_IrqEna;

    -- STRENA
    if RegWr(16#20# / 4) = '1' then
      v.Reg_StrEna := RegWrVal(16#20# / 4)(Streams_g - 1 downto 0);
    end if;
    RegRdVal(16#20# / 4)(Streams_g - 1 downto 0) <= r.Reg_StrEna;

    -- STRENA
    if RegWr(16#24# / 4) = '1' then
      v.Reg_AcpCfg_ARProt  := RegWrVal(16#24# / 4)( 2 downto  0);
      v.Reg_AcpCfg_ARCache := RegWrVal(16#24# / 4)( 7 downto  4);
      v.Reg_AcpCfg_AWProt  := RegWrVal(16#24# / 4)(10 downto  8);
      v.Reg_AcpCfg_AWCache := RegWrVal(16#24# / 4)(15 downto 12);
    end if;
    RegRdVal(16#24# / 4)( 2 downto  0) <= r.Reg_AcpCfg_ARProt;
    RegRdVal(16#24# / 4)( 7 downto  4) <= r.Reg_AcpCfg_ARCache;
    RegRdVal(16#24# / 4)(10 downto  8) <= r.Reg_AcpCfg_AWProt;
    RegRdVal(16#24# / 4)(15 downto 12) <= r.Reg_AcpCfg_AWCache;

    -- *** Stream Register Accesses ***
    v.RegRdval     := (others => '0');
    v.Reg_Mode_Arm := (others => '0');
    v.MaxLvlClr    := (others => '0');
    if AccAddr(15 downto 9) = X"0" & "001" then
      Stream_v := work.psi_common_math_pkg.min(to_integer(unsigned(AccAddr(8 downto 4))), Streams_g - 1);

      -- MAXLVLn
      if AccAddr(3 downto 0) = X"0" then
        if AccWr = DwWrite_c then
          v.MaxLvlClr(Stream_v) := '1';
        end if;
        v.RegRdval(15 downto 0) := MaxLevel(Stream_v);
      end if;

      -- POSTTRIGn
      if AccAddr(3 downto 0) = X"4" then
        if AccWr = DwWrite_c then
          v.Reg_PostTrig(Stream_v) := AccWrData;
        end if;
        v.RegRdval := r.Reg_PostTrig(Stream_v);
      end if;

      -- MODEn / LASTWINn
      if AccAddr(3 downto 0) = X"8" then
        if AccWr(0) = '1' then
          v.Reg_Mode_Recm(Stream_v) := AccWrData(1 downto 0);
        end if;
        if AccWr(1) = '1' then
          v.Reg_Mode_Arm(Stream_v) := AccWrData(8);
        end if;
        if AccWr(3) = '1' then
          v.Reg_Mode_ToDisable(Stream_v) := AccWrData(24);
          v.Reg_Mode_FrameTo(Stream_v)   := AccWrData(25);
        end if;
        v.RegRdval(1 downto 0) := r.Reg_Mode_Recm(Stream_v);
        v.RegRdval(8)          := IsArmed(Stream_v);
        v.RegRdval(16)         := IsRecording(Stream_v);
        v.RegRdval(24)         := r.Reg_Mode_ToDisable(Stream_v);
        v.RegRdval(25)         := r.Reg_Mode_FrameTo(Stream_v);
      end if;

      -- LASTWINn
      if AccAddr(3 downto 0) = X"C" then
        -- LASTWINn
        v.RegRdval(MaxWindowsBits_c - 1 downto 0) := StrLastWin_Sync(Stream_v);
      end if;

    end if;

    -- *** Read Data MUX ***
    v.AddrReg := AccAddr;
    AccRdData <= (others => '0');
    if r.AddrReg(15 downto 12) = X"0" then
      AccRdData <= r.RegRdval;
    elsif r.AddrReg(15 downto 12) = X"1" then
      -- High-low dword in different memories
      if r.AddrReg(2) = '0' then
        AccRdData <= CtxStr_Rdval(31 downto 0);
      else
        AccRdData <= CtxStr_Rdval(63 downto 32);
      end if;
    elsif r.AddrReg(15 downto 14) = "01" then
      -- High-low dword in different memories
      if r.AddrReg(2) = '0' then
        AccRdData <= CtxWin_Rdval(31 downto 0);
      else
        AccRdData <= CtxWin_Rdval(63 downto 32);
      end if;
    end if;

    -- *** IRQ Handling ***
    for i in 0 to Streams_g - 1 loop
      if (StrIrq_Sync(i) = '1') and (r.Reg_StrEna(i) = '1') then
        v.Reg_IrqVec(i) := '1';
      end if;
    end loop;
    if ((r.Reg_IrqVec and r.Reg_IrqEna) /= zeros_vector(Streams_g)) and (r.Reg_Gcfg_IrqEna = '1') then
      v.Irq := '1';
    else
      v.Irq := '0';
    end if;

    -- *** Assign to signal ***
    r_next <= v;

  end process;

  -- *** Registered Outputs ***
  IrqOut    <= r.Irq;
  PostTrig  <= r.Reg_PostTrig;
  Arm       <= r.Reg_Mode_Arm;
  RecMode   <= r.Reg_Mode_Recm;
  ToDisable <= r.Reg_Mode_ToDisable;
  FrameTo   <= r.Reg_Mode_FrameTo;
  ARProt    <= r.Reg_AcpCfg_ARProt;
  ARCache   <= r.Reg_AcpCfg_ARCache;
  AWProt    <= r.Reg_AcpCfg_AWProt;
  AWCache   <= r.Reg_AcpCfg_AWCache;

  --------------------------------------------
  -- Sequential Process
  --------------------------------------------
  p_seq : process(S_Axi_Aclk)
  begin
    if rising_edge(S_Axi_Aclk) then
      r <= r_next;
      if A_Axi_Areset = '1' then
        r.Reg_Gcfg_Ena       <= '0';
        r.Reg_Gcfg_IrqEna    <= '0';
        r.Reg_IrqVec         <= (others => '0');
        r.Reg_IrqEna         <= (others => '0');
        r.Reg_StrEna         <= (others => '0');
        r.Reg_AcpCfg_ARProt  <= (others => '0');
        r.Reg_AcpCfg_ARCache <= (others => '0');
        r.Reg_AcpCfg_AWProt  <= (others => '0');
        r.Reg_AcpCfg_AWCache <= (others => '0');
        r.Irq                <= '0';
        r.Reg_PostTrig       <= (others => (others => '0'));
        r.Reg_Mode_Recm      <= (others => (others => '0'));
        r.Reg_Mode_Arm       <= (others => '0');
        r.Reg_Mode_ToDisable <= (others => '0');
        r.Reg_Mode_FrameTo   <= (others => '0');
      end if;
    end if;
  end process;

  --------------------------------------------
  -- Maximum Level Latching (MemClk)
  --------------------------------------------
  p_maxlvl : process(ClkMem)
  begin
    if rising_edge(ClkMem) then
      if RstMem = '1' then
        MaxLevel <= (others => (others => '0'));
      else
        -- Latch maximum level
        for i in 0 to Streams_g - 1 loop
          if MaxLevelClr_Sync(i) = '1' then
            MaxLevel(i) <= (others => '0');
          elsif unsigned(InLevel(i)) > unsigned(MaxLevel(i)) then
            MaxLevel(i) <= InLevel(i);
          end if;
        end loop;
      end if;
    end if;
  end process;

  --------------------------------------------
  -- Component Instantiations
  --------------------------------------------

  -- *** AXI Interface ***
  i_axi : entity work.psi_common_axi_slave_ipif
    generic map(
      num_reg_g        => 16,
      rst_val_g        => (0  => (others => '0'), 1 => (others => '0'), 2 => (others => '0'), 3 => (others => '0'),
                           4  => (others => '0'), 5 => (others => '0'), 6 => (others => '0'), 7 => (others => '0'),
                           8  => (others => '0'), 9 => (others => '0'), 10 => (others => '0'), 11 => (others => '0'),
                           12 => (others => '0'), 13 => (others => '0'), 14 => (others => '0'), 15 => (others => '0')),
      use_mem_g        => true,
      axi_id_width_g   => AxiSlaveIdWidth_g,
      axi_addr_width_g => 16
    )
    port map(
      s_axi_aclk    => S_Axi_Aclk,
      s_axi_aresetn => S_Axi_Aresetn,
      s_axi_arid    => S_Axi_ArId,
      s_axi_araddr  => S_Axi_ArAddr,
      s_axi_arlen   => S_Axi_Arlen,
      s_axi_arsize  => S_Axi_ArSize,
      s_axi_arburst => S_Axi_ArBurst,
      s_axi_arlock  => S_Axi_ArLock,
      s_axi_arcache => S_Axi_ArCache,
      s_axi_arprot  => S_Axi_ArProt,
      s_axi_arvalid => S_Axi_ArValid,
      s_axi_arready => S_Axi_ArReady,
      s_axi_rid     => S_Axi_RId,
      s_axi_rdata   => S_Axi_RData,
      s_axi_rresp   => S_Axi_RResp,
      s_axi_rlast   => S_Axi_RLast,
      s_axi_rvalid  => S_Axi_RValid,
      s_axi_rready  => S_Axi_RReady,
      s_axi_awid    => S_Axi_AwId,
      s_axi_awaddr  => S_Axi_AwAddr,
      s_axi_awlen   => S_Axi_AwLen,
      s_axi_awsize  => S_Axi_AwSize,
      s_axi_awburst => S_Axi_AwBurst,
      s_axi_awlock  => S_Axi_AwLock,
      s_axi_awcache => S_Axi_AwCache,
      s_axi_awprot  => S_Axi_AwProt,
      s_axi_awvalid => S_Axi_AwValid,
      s_axi_awready => S_Axi_AwReady,
      s_axi_wdata   => S_Axi_WData,
      s_axi_wstrb   => S_Axi_WStrb,
      s_axi_wlast   => S_Axi_WLast,
      s_axi_wvalid  => S_Axi_WValid,
      s_axi_wready  => S_Axi_WReady,
      s_axi_bid     => S_Axi_BId,
      s_axi_bresp   => S_Axi_BResp,
      s_axi_bvalid  => S_Axi_BValid,
      s_axi_bready  => S_Axi_BReady,
      o_reg_rd      => open,
      i_reg_rdata   => RegRdVal,
      o_reg_wr      => RegWr,
      o_reg_wdata   => RegWrVal,
      o_mem_addr    => AccAddrOffs,
      o_mem_wr      => AccWr,
      o_mem_wdata   => AccWrData,
      i_mem_rdata   => AccRdData
    );

  AccAddr <= std_logic_vector(unsigned(AccAddrOffs) + 16 * 4);

  -- *** Clock Crossings ***
  blk_cc_irq : block
  begin
    g_in : for i in 0 to Streams_g - 1 generate

      i_cc_irq : entity work.psi_common_simple_cc
        generic map(
          width_g => log2ceil(MaxWindows_c)
        )
        port map(
          a_clk_i => ClkMem,
          a_rst_i => RstMem,
          a_dat_i => StrLastWin(i),
          a_vld_i => StrIrq(i),
          b_clk_i => S_Axi_Aclk,
          b_rst_i => A_Axi_Areset,
          b_dat_o => StrLastWin_Sync(i),
          b_vld_o => StrIrq_Sync(i)
        );
    end generate;
  end block;

  blk_cc_mem_out : block
    signal ccIn, ccOut : std_logic_vector(Streams_g downto 0);
  begin
    -- Input Assembly
    ccIn(Streams_g - 1 downto 0) <= r.Reg_StrEna;
    ccIn(Streams_g)              <= r.Reg_Gcfg_Ena;

    -- Instantiation
    i_cc_mem_out : entity work.psi_common_bit_cc
      generic map(
        width_g => Streams_g + 1
      )
      port map(
        dat_i => ccIn,
        clk_i => ClkMem,
        dat_o => ccOut
      );

    -- Output assembly
    StrEna <= ccOut(Streams_g - 1 downto 0);
    GlbEna <= ccOut(Streams_g);
  end block;

  i_cc_mem_out_pulse : entity work.psi_common_pulse_cc
    generic map(
      num_pulses_g => Streams_g
    )
    port map(
      a_clk_i => S_Axi_Aclk,
      a_rst_i => A_Axi_Areset,
      a_dat_i => r.MaxLvlClr,
      b_clk_i => ClkMem,
      b_rst_i => RstMem,
      b_dat_o => MaxLevelClr_Sync
    );

  -- *** Stream Context Memory ***
  -- Signal Assembly
  AddrCtxStr   <= AccAddr(15 downto 12) = X"1";
  CtxStr_WeLo  <= '1' when AccWr = DwWrite_c and AddrCtxStr and AccAddr(2) = '0' else '0';
  CtxStr_WeHi  <= '1' when AccWr = DwWrite_c and AddrCtxStr and AccAddr(2) = '1' else '0';
  CtxStr_AddrB <= std_logic_vector(to_unsigned(CtxStr_Cmd.Stream, log2ceil(Streams_g))) & CtxStr_Cmd.Sel;

  -- Memory is split organized as 64 bit memory for historical reasons (Tosca TMEM is 64-bit)

  -- Low DWORD memory
  i_mem_ctx_lo : entity work.psi_common_tdp_ram
    generic map(
      depth_g    => DepthCtxStr_c,
      width_g    => 32,
      behavior_g => "RBW"
    )
    port map(
      a_clk_i  => S_Axi_Aclk,
      a_addr_i => AccAddr(CtxStrAddrHigh_c downto 3),
      a_wr_i   => CtxStr_WeLo,
      a_dat_i  => AccWrData,
      a_dat_o  => CtxStr_Rdval(31 downto 0),
      b_clk_i  => ClkMem,
      b_addr_i => CtxStr_AddrB,
      b_wr_i   => CtxStr_Cmd.WenLo,
      b_dat_i  => CtxStr_Cmd.WdatLo,
      b_dat_o  => CtxStr_Resp.RdatLo
    );

  -- High DWORD memory
  i_mem_ctx_hi : entity work.psi_common_tdp_ram
    generic map(
      depth_g    => DepthCtxStr_c,
      width_g    => 32,
      behavior_g => "RBW"
    )
    port map(
      a_clk_i  => S_Axi_Aclk,
      a_addr_i => AccAddr(CtxStrAddrHigh_c downto 3),
      a_wr_i   => CtxStr_WeHi,
      a_dat_i  => AccWrData,
      a_dat_o  => CtxStr_Rdval(63 downto 32),
      b_clk_i  => ClkMem,
      b_addr_i => CtxStr_AddrB,
      b_wr_i   => CtxStr_Cmd.WenHi,
      b_dat_i  => CtxStr_Cmd.WdatHi,
      b_dat_o  => CtxStr_Resp.RdatHi
    );

  -- *** Window Context Memory ***
  -- Signal Assembly
  AddrCtxWin   <= AccAddr(15 downto 14) = "01";
  CtxWin_WeLo  <= '1' when AccWr = DwWrite_c and AddrCtxWin and AccAddr(2) = '0' else '0';
  CtxWin_WeHi  <= '1' when AccWr = DwWrite_c and AddrCtxWin and AccAddr(2) = '1' else '0';
  CtxWin_AddrB <= std_logic_vector(to_unsigned(CtxWin_Cmd.Stream, log2ceil(Streams_g))) & std_logic_vector(to_unsigned(CtxWin_Cmd.Window, log2ceil(MaxWindows_g))) & CtxWin_Cmd.Sel;

  -- Memory is split organized as 64 bit memory for historical reasons (Tosca TMEM is 64-bit)

  -- Low DWORD memory
  i_mem_win_lo : entity work.psi_common_tdp_ram
    generic map(
      depth_g    => DepthCtxWin_c,
      width_g    => 32,
      behavior_g => "RBW"
    )
    port map(
      a_clk_i  => S_Axi_Aclk,
      a_addr_i => AccAddr(CtxWinAddrHigh_c downto 3),
      a_wr_i   => CtxWin_WeLo,
      a_dat_i  => AccWrData,
      a_dat_o  => CtxWin_Rdval(31 downto 0),
      b_clk_i  => ClkMem,
      b_addr_i => CtxWin_AddrB,
      b_wr_i   => CtxWin_Cmd.WenLo,
      b_dat_i  => CtxWin_Cmd.WdatLo,
      b_dat_o  => CtxWin_Resp.RdatLo
    );

  -- High DWORD memory
  i_mem_win_hi : entity work.psi_common_tdp_ram
    generic map(
      depth_g    => DepthCtxWin_c,
      width_g    => 32,
      behavior_g => "RBW"
    )
    port map(
      a_clk_i  => S_Axi_Aclk,
      a_addr_i => AccAddr(CtxWinAddrHigh_c downto 3),
      a_wr_i   => CtxWin_WeHi,
      a_dat_i  => AccWrData,
      a_dat_o  => CtxWin_Rdval(63 downto 32),
      b_clk_i  => ClkMem,
      b_addr_i => CtxWin_AddrB,
      b_wr_i   => CtxWin_Cmd.WenHi,
      b_dat_i  => CtxWin_Cmd.WdatHi,
      b_dat_o  => CtxWin_Resp.RdatHi
    );

end architecture;
