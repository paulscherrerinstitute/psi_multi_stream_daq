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

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
entity psi_ms_daq_axi_if is
  generic(
    IntDataWidth_g          : positive                 := 64;
    AxiDataWidth_g          : natural range 64 to 1024 := 64;
    AxiMaxBeats_g           : natural range 1 to 256   := 256;
    AxiMaxOpenTrasactions_g : natural range 1 to 8     := 8;
    MaxOpenCommands_g       : positive                 := 16;
    DataFifoDepth_g         : natural                  := 1024;
    AxiFifoDepth_g          : natural                  := 1024;
    RamBehavior_g           : string                   := "RBW"
  );
  port(
    -- Control Signals
    Clk           : in  std_logic;
    Rst_n         : in  std_logic;
    -- Write Command
    Cmd_Addr      : in  std_logic_vector(31 downto 0);
    Cmd_Size      : in  std_logic_vector(31 downto 0);
    Cmd_Vld       : in  std_logic;
    Cmd_Rdy       : out std_logic;
    -- Write Data
    Dat_Data      : in  std_logic_vector(IntDataWidth_g - 1 downto 0);
    Dat_Vld       : in  std_logic;
    Dat_Rdy       : out std_logic;
    -- Response
    Done          : out std_logic;
    -- AXI Address Write Channel
    M_Axi_AwAddr  : out std_logic_vector(31 downto 0);
    M_Axi_AwLen   : out std_logic_vector(7 downto 0);
    M_Axi_AwSize  : out std_logic_vector(2 downto 0);
    M_Axi_AwBurst : out std_logic_vector(1 downto 0);
    M_Axi_AwLock  : out std_logic;
    M_Axi_AwCache : out std_logic_vector(3 downto 0);
    M_Axi_AwProt  : out std_logic_vector(2 downto 0);
    M_Axi_AwValid : out std_logic;
    M_Axi_AwReady : in  std_logic                                     := '0';
    -- AXI Write Data Channel                                                           					
    M_Axi_WData   : out std_logic_vector(AxiDataWidth_g - 1 downto 0);
    M_Axi_WStrb   : out std_logic_vector(AxiDataWidth_g / 8 - 1 downto 0);
    M_Axi_WLast   : out std_logic;
    M_Axi_WValid  : out std_logic;
    M_Axi_WReady  : in  std_logic                                     := '0';
    -- AXI Write Response Channel                                                      
    M_Axi_BResp   : in  std_logic_vector(1 downto 0)                  := (others => '0');
    M_Axi_BValid  : in  std_logic                                     := '0';
    M_Axi_BReady  : out std_logic;
    -- AXI Read Address Channel                                               
    M_Axi_ArAddr  : out std_logic_vector(31 downto 0);
    M_Axi_ArLen   : out std_logic_vector(7 downto 0);
    M_Axi_ArSize  : out std_logic_vector(2 downto 0);
    M_Axi_ArBurst : out std_logic_vector(1 downto 0);
    M_Axi_ArLock  : out std_logic;
    M_Axi_ArCache : out std_logic_vector(3 downto 0);
    M_Axi_ArProt  : out std_logic_vector(2 downto 0);
    M_Axi_ArValid : out std_logic;
    M_Axi_ArReady : in  std_logic                                     := '0';
    -- AXI Read Data Channel                                                      
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
architecture rtl of psi_ms_daq_axi_if is
  signal Rst : std_logic;

  subtype CommandAddrRng_c is natural range 31 downto 0;
  subtype CommandSizeRng_c is natural range 63 downto 32;
  constant WrCmdWidth_c : integer := CommandSizeRng_c'high + 1;
  signal InfoFifoIn     : std_logic_vector(WrCmdWidth_c - 1 downto 0);
  signal InfoFifoOut    : std_logic_vector(WrCmdWidth_c - 1 downto 0);
  signal WrCmdFifo_Vld  : std_logic;
  signal WrCmdFifo_Rdy  : std_logic;
  signal WrCmdFifo_Addr : std_logic_vector(31 downto 0);
  signal WrCmdFifo_Size : std_logic_vector(31 downto 0);
  signal DoneI          : std_logic;
  signal ErrorI         : std_logic;

begin
  Rst <= not Rst_n;

  InfoFifoIn(CommandAddrRng_c) <= Cmd_Addr;
  InfoFifoIn(CommandSizeRng_c) <= Cmd_Size;

  i_wrinfo_fifo : entity work.psi_common_sync_fifo
    generic map(
      width_g     => WrCmdWidth_c,
      depth_g     => MaxOpenCommands_g,
      ram_style_g => "distributed"
    )
    port map(
      clk_i => Clk,
      rst_i => Rst,
      dat_i => InfoFifoIn,
      vld_i => Cmd_Vld,
      rdy_o => Cmd_Rdy,
      dat_o => InfoFifoOut,
      vld_o => WrCmdFifo_Vld,
      rdy_i => WrCmdFifo_Rdy
    );

  WrCmdFifo_Addr <= InfoFifoOut(CommandAddrRng_c);
  WrCmdFifo_Size <= InfoFifoOut(CommandSizeRng_c);

  i_axi : entity work.psi_common_axi_master_full
    generic map(
      axi_addr_width_g             => 32,
      axi_data_width_g             => AxiDataWidth_g,
      axi_max_beats_g              => AxiMaxBeats_g,
      axi_max_open_trasactions_g   => AxiMaxOpenTrasactions_g,
      user_transaction_size_bits_g => 32,
      data_fifo_depth_g            => DataFifoDepth_g,
      data_width_g                 => IntDataWidth_g,
      impl_read_g                  => false,
      impl_write_g                 => true,
      ram_behavior_g               => RamBehavior_g
    )
    port map(
      -- Control Signals
      m_axi_aclk       => Clk,
      m_axi_aresetn    => Rst_n,
      -- User Command Interface Write
      cmd_wr_addr_i    => WrCmdFifo_Addr,
      cmd_wr_size_i    => WrCmdFifo_Size,
      cmd_wr_low_lat_i => '0',
      cmd_wr_vld_i     => WrCmdFifo_Vld,
      cmd_wr_rdy_o     => WrCmdFifo_Rdy,
      -- User Command Interface Read (unused)
      cmd_rd_addr_i    => (others => '0'),
      cmd_rd_size_o    => (others => '0'),
      cmd_rd_low_lat_i => '0',
      cmd_rd_vld_i     => '0',
      cmd_rd_rdy_o     => open,
      -- Write Data
      wr_dat_i         => Dat_Data,
      wr_vld_i         => Dat_Vld,
      wr_rdy_o         => Dat_Rdy,
      -- Read Data (unused)
      rd_dat_o         => open,
      rd_vld_o         => open,
      rd_rdy_i         => '0',
      -- Response
      wr_done_o        => DoneI,
      wr_error_o       => ErrorI,
      rd_done_o        => open,
      rd_error_o       => open,
      -- AXI Address Write Channel
      m_axi_awaddr     => M_Axi_AwAddr,
      m_axi_awlen      => M_Axi_AwLen,
      m_axi_awsize     => M_Axi_AwSize,
      m_axi_awburst    => M_Axi_AwBurst,
      m_axi_awlock     => M_Axi_AwLock,
      m_axi_awcache    => M_Axi_AwCache,
      m_axi_awprot     => M_Axi_AwProt,
      m_axi_awvalid    => M_Axi_AwValid,
      m_axi_awready    => M_Axi_AwReady,
      -- AXI Write Data Channel 
      m_axi_wdata      => M_Axi_WData,
      m_axi_wstrb      => M_Axi_WStrb,
      m_axi_wlast      => M_Axi_WLast,
      m_axi_wvalid     => M_Axi_WValid,
      m_axi_wready     => M_Axi_WReady,
      -- AXI Write Response Channel                                                      
      m_axi_bresp      => M_Axi_BResp,
      m_axi_bvalid     => M_Axi_BValid,
      m_axi_bready     => M_Axi_BReady,
      -- AXI Read Address Channel                                               
      m_axi_araddr     => M_Axi_ArAddr,
      m_axi_arlen      => M_Axi_ArLen,
      m_axi_arsize     => M_Axi_ArSize,
      m_axi_arburst    => M_Axi_ArBurst,
      m_axi_arlock     => M_Axi_ArLock,
      m_axi_arcache    => M_Axi_ArCache,
      m_axi_arprot     => M_Axi_ArProt,
      m_axi_arvalid    => M_Axi_ArValid,
      m_axi_arready    => M_Axi_ArReady,
      -- AXI Read Data Channel                                                      
      m_axi_rdata      => M_Axi_RData,
      m_axi_rresp      => M_Axi_RResp,
      m_axi_rlast      => M_Axi_RLast,
      m_axi_rvalid     => M_Axi_RValid,
      m_axi_rready     => M_Axi_RReady
    );

  Done <= DoneI or ErrorI;

end;
