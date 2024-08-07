------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Description
------------------------------------------------------------------------------
-- This component calculates a binary division of two fixed point values.

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.psi_common_math_pkg.all;
use work.psi_common_logic_pkg.all;
use work.psi_common_array_pkg.all;
use work.psi_ms_daq_pkg.all;

------------------------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------------------------
-- $$ testcases=aligned,unaligned,no_data_read,input_empty,empty_timeout,cmd_full,data_full,errors $$
-- $$ processes=control,input,mem_cmd,mem_dat $$
-- $$ tbpkg=work.psi_tb_txt_util,work.psi_tb_compare_pkg,work.psi_tb_activity_pkg $$
entity psi_ms_daq_daq_dma is
  generic(
    Streams_g      : positive range 1 to 32 := 4; -- $$ constant=4 $$
    IntDataWidth_g : positive               := 64 -- $$ constant=64 $$
  );
  port(
    -- Control signals
    Clk            : in  std_logic;     -- $$ type=clk; freq=200e6; proc=control,input,mem_dat,mem_cmd $$				
    Rst            : in  std_logic;     -- $$ type=rst; clk=Clk; proc=control $$

    -- DAQ Statemachione Connections
    DaqSm_Cmd      : in  DaqSm2DaqDma_Cmd_t; -- $$ proc=control $$					
    DaqSm_Cmd_Vld  : in  std_logic;     -- $$ proc=control $$	
    DaqSm_Resp     : out DaqDma2DaqSm_Resp_t; -- $$ proc=control $$	
    DaqSm_Resp_Vld : out std_logic;     -- $$ proc=control $$	
    DaqSm_Resp_Rdy : in  std_logic;     -- $$ proc=control $$	
    DaqSm_HasLast  : out std_logic_vector(Streams_g - 1 downto 0); -- $$ proc=control $$

    -- Input handling connections
    Inp_Vld        : in  std_logic_vector(Streams_g - 1 downto 0); -- $$ proc=input $$	
    Inp_Rdy        : out std_logic_vector(Streams_g - 1 downto 0); -- $$ proc=input $$	
    Inp_Data       : in  Input2Daq_Data_a(Streams_g - 1 downto 0)(Data(IntDataWidth_g-1 downto 0), Bytes(log2ceil(IntDataWidth_g/8) downto 0)); -- $$ proc=input $$

    -- Memory interface connections
    Mem_CmdAddr    : out std_logic_vector(31 downto 0); -- $$ proc=mem_cmd $$	
    Mem_CmdSize    : out std_logic_vector(31 downto 0); -- $$ proc=mem_cmd $$	
    Mem_CmdVld     : out std_logic;     -- $$ proc=mem_cmd $$	
    Mem_CmdRdy     : in  std_logic;     -- $$ proc=mem_cmd $$	
    Mem_DatData    : out std_logic_vector(IntDataWidth_g-1 downto 0); -- $$ proc=mem_dat $$
    Mem_DatVld     : out std_logic;     -- $$ proc=mem_dat $$	
    Mem_DatRdy     : in  std_logic      -- $$ proc=mem_dat $$	
  );
end entity;

------------------------------------------------------------------------------
-- Architecture Declaration
------------------------------------------------------------------------------
architecture rtl of psi_ms_daq_daq_dma is

  -- Constants
  constant BufferFifoDepth_c : integer := 32;

  -- Number of bits to encode stream is at least 1 (otherwise the special case for one stream would require separate code).
  -- .. The overhead generated by this is regarded as aceptable (better wasting a few LUTs than much development time)
  constant StreamBits_c : integer := max(log2ceil(Streams_g), 1);
  constant IntDataBytes_c : positive := IntDataWidth_g/8;
  constant BytesWidth_c   : positive := log2ceil(IntDataBytes_c);

  -- Component Connection Signals
  signal CmdFifo_Level_Dbg : std_logic_vector(StreamBits_c downto 0);
  signal CmdFifo_InData    : std_logic_vector(DaqSm2DaqDma_Cmd_Size_c - 1 downto 0);
  signal CmdFifo_OutData   : std_logic_vector(DaqSm2DaqDma_Cmd_Size_c - 1 downto 0);
  signal CmdFifo_Cmd       : DaqSm2DaqDma_Cmd_t;
  signal CmdFifo_Vld       : std_logic;
  signal RspFifo_Level_Dbg : std_logic_vector(StreamBits_c downto 0);
  signal RspFifo_InData    : std_logic_vector(DaqDma2DaqSm_Resp_Size_c - 1 downto 0);
  signal RspFifo_OutData   : std_logic_vector(DaqDma2DaqSm_Resp_Size_c - 1 downto 0);
  signal DatFifo_Level_Dbg : std_logic_vector(log2ceil(BufferFifoDepth_c) downto 0);
  signal DatFifo_AlmFull   : std_logic;
  signal Rem_RdBytes       : std_logic_vector(BytesWidth_c - 1 downto 0);
  signal Rem_Data          : std_logic_vector(IntDataWidth_g - 1 downto 0);
  signal Rem_Trigger       : std_logic;
  signal Rem_Last          : std_logic;
  signal Rem_Data_Fifo_In  : std_logic_vector(BytesWidth_c + IntDataWidth_g + 1 downto 0);
  signal Rem_Data_Fifo_Out : std_logic_vector(BytesWidth_c + IntDataWidth_g + 1 downto 0);

  -- Types
  type State_t is (Idle_s, RemRd1_s, RemRd2_s, Transfer_s, Done_s, Cmd_s);

  -- Two process method
  type two_process_r is record
    CmdFifo_Rdy  : std_logic;
    RspFifo_Vld  : std_logic;
    RspFifo_Data : DaqDma2DaqSm_Resp_t;
    Mem_DataVld  : std_logic;
    StreamStdlv  : std_logic_vector(StreamBits_c - 1 downto 0);
    RemWen       : std_logic;
    RemWrBytes   : std_logic_vector(BytesWidth_c - 1 downto 0);
    RemData      : std_logic_vector(IntDataWidth_g - 1 downto 0);
    RemTrigger   : std_logic;
    RemLast      : std_logic;
    RemWrTrigger : std_logic;
    RemWrLast    : std_logic;
    State        : State_t;
    HndlMaxSize  : unsigned(15 downto 0);
    RdBytes      : unsigned(15 downto 0);
    WrBytes      : unsigned(15 downto 0);
    HndlStream   : integer range 0 to MaxStreams_c - 1;
    HndlAddress  : std_logic_vector(31 downto 0);
    UpdateLast   : std_logic;
    HndlSft      : unsigned(BytesWidth_c-1 downto 0);
    FirstDma     : std_logic_vector(Streams_g - 1 downto 0);
    Mem_CmdVld   : std_logic;
    Trigger      : std_logic;
    Last         : std_logic;
    DataSft      : std_logic_vector(2*IntDataWidth_g - 1 downto 0);
    NextDone     : std_logic;
    DataWritten  : std_logic;
    HasLast      : std_logic_vector(Streams_g - 1 downto 0);
  end record;
  signal r, r_next : two_process_r;

begin
  --------------------------------------------
  -- Combinatorial Process
  --------------------------------------------
  p_comb : process(r, DaqSm_Cmd, DaqSm_Cmd_Vld, DaqSm_Resp_Rdy, Inp_Vld, Inp_Data, Mem_CmdRdy, Mem_DatRdy, CmdFifo_Cmd, CmdFifo_Vld, DatFifo_AlmFull, Rem_RdBytes, Rem_Data, Rem_Trigger, Rem_Last)
    variable v          : two_process_r;
    variable ThisByte_v : std_logic_vector(7 downto 0);
    variable RemSft_v   : integer range 0 to 7;
  begin
    -- *** Hold variables stable ***
    v := r;

    -- *** Default Values ***
    v.CmdFifo_Rdy := '0';
    Inp_Rdy       <= (others => '0');
    v.Mem_DataVld := '0';
    v.RspFifo_Vld := '0';
    v.RemWen      := '0';
    v.UpdateLast  := '0';

    -- *** State Machine ***
    case r.State is

      when Idle_s =>
        v.HndlMaxSize := unsigned(CmdFifo_Cmd.MaxSize);
        v.HndlStream  := CmdFifo_Cmd.Stream;
        v.StreamStdlv := std_logic_vector(to_unsigned(CmdFifo_Cmd.Stream, v.StreamStdlv'length));
        v.HndlAddress := CmdFifo_Cmd.Address;
        v.Trigger     := '0';
        v.Last        := '0';
        if CmdFifo_Vld = '1' then
          v.CmdFifo_Rdy := '1';
          v.State       := RemRd1_s;
        end if;

      when RemRd1_s =>
        v.State := RemRd2_s;

      when RemRd2_s =>
        -- Prevent RAM data from before reset to have an influence
        v.WrBytes                := (others => '0');
        if r.FirstDma(r.HndlStream) = '1' then
          v.HndlSft    := (others => '0');
          v.RdBytes    := (others => '0');
          v.DataSft    := (others => '0');
          v.RemTrigger := '0';
          v.RemLast    := '0';
        else
          v.HndlSft                := unsigned(Rem_RdBytes);
          v.DataSft(2*IntDataWidth_g - 1 downto IntDataWidth_g) := Rem_Data;
          v.RdBytes                := resize(unsigned(Rem_RdBytes), v.RdBytes'length);
          v.RemTrigger             := Rem_Trigger;
          v.RemLast                := Rem_Last;
        end if;
        v.FirstDma(r.HndlStream) := '0';
        v.State                  := Transfer_s;
        v.NextDone               := '0';
        v.DataWritten            := '0';

      when Transfer_s =>
        -- TF done because of maximum size reached
        if r.WrBytes >= r.HndlMaxSize then
          v.State := Done_s;
        elsif DatFifo_AlmFull = '0' then
          if r.NextDone = '0' and Inp_Vld(r.HndlStream) = '1' and r.RemLast = '0' then
            v.RdBytes := r.RdBytes + unsigned(Inp_Data(r.HndlStream).Bytes);
          end if;
          v.WrBytes := r.WrBytes + IntDataBytes_c;
          -- Combinatorial handling because of fall-through interface at input
          if r.RdBytes < r.HndlMaxSize and r.NextDone = '0' and r.RemLast = '0' then
            Inp_Rdy(r.HndlStream) <= '1';
          end if;
          -- Handling of last frame
          if (Inp_Data(r.HndlStream).Last = '1') or (r.RemLast = '1') then
            -- Do one more word if not all data can be transferred in the current beat (NextDone = 1)
            if (r.HndlSft + unsigned(Inp_Data(r.HndlStream).Bytes) <= IntDataBytes_c) or (r.RemLast = '1') then
              v.State := Done_s;
            else
              v.NextDone := '1';
            end if;
            if (Inp_Data(r.HndlStream).IsTrig = '1') or (r.RemTrigger = '1') then
              v.Trigger := '1';
            end if;
            v.Last := '1';
          end if;
          if r.NextDone = '1' or Inp_Vld(r.HndlStream) = '0' then
            v.State := Done_s;
          end if;
          -- Data handling
          v.DataSft(IntDataWidth_g - 1 downto 0)                                                     := r.DataSft(2*IntDataWidth_g - 1 downto IntDataWidth_g);
          v.DataSft(8 * to_integer(r.HndlSft) + IntDataWidth_g - 1 downto 8 * to_integer(r.HndlSft)) := Inp_Data(r.HndlStream).Data;
          if Inp_Vld(r.HndlStream) = '1' or r.HndlSft /= 0 then
            v.Mem_DataVld := '1';
            v.DataWritten := '1';
          end if;
        end if;

      when Done_s =>
        RemSft_v       := to_integer(resize(r.HndlMaxSize, 3));
        v.RemWrTrigger := '0';
        v.RemWrLast    := '0';
        if r.HndlMaxSize < r.RdBytes then
          v.RemWrBytes            := std_logic_vector(resize(r.RdBytes - r.HndlMaxSize, v.RemWrBytes'length));
          v.RdBytes               := r.HndlMaxSize;
          v.RemWrTrigger          := r.Trigger;
          v.RemWrLast             := r.Last;
          v.HasLast(r.HndlStream) := r.Last;
        else
          v.RemWrBytes            := (others => '0');
          v.HasLast(r.HndlStream) := '0';
        end if;
        v.RemData      := v.DataSft(8 * RemSft_v + IntDataWidth_g - 1 downto 8 * RemSft_v);
        v.State        := Cmd_s;
        if r.DataWritten = '1' then
          v.Mem_CmdVld := '1';
        end if;
        v.RemWen       := '1';

      when Cmd_s =>
        if Mem_CmdRdy = '1' or r.Mem_CmdVld = '0' then
          v.State               := Idle_s;
          v.Mem_CmdVld          := '0';
          v.RspFifo_Vld         := '1';
          v.RspFifo_Data.Size   := std_logic_vector(r.RdBytes);
          -- Only mark as trigger if all samples are completely written to memory (no remaining samples in REM RAM)
          if (unsigned(r.RemWrBytes) = 0) and (r.Trigger = '1') then
            v.RspFifo_Data.Trigger := '1';
          else
            v.RspFifo_Data.Trigger := '0';
          end if;
          v.RspFifo_Data.Stream := r.HndlStream;
        end if;
      when others => null;
    end case;

    -- *** Assign to signal ***
    r_next <= v;

  end process;

  -- *** Registered Outputs ***
  Mem_CmdAddr                                             <= r.HndlAddress;
  Mem_CmdSize(r.RdBytes'range)                            <= std_logic_vector(r.RdBytes);
  Mem_CmdSize(Mem_CmdSize'high downto r.RdBytes'high + 1) <= (others => '0');
  Mem_CmdVld                                              <= r.Mem_CmdVld;
  DaqSm_HasLast                                           <= r.HasLast;

  --------------------------------------------
  -- Sequential Process
  --------------------------------------------
  p_seq : process(Clk)
  begin
    if rising_edge(Clk) then
      r <= r_next;
      if Rst = '1' then
        r.CmdFifo_Rdy <= '0';
        r.RspFifo_Vld <= '0';
        r.Mem_DataVld <= '0';
        r.RemWen      <= '0';
        r.State       <= Idle_s;
        r.FirstDma    <= (others => '1');
        r.Mem_CmdVld  <= '0';
        r.HasLast     <= (others => '0');
      end if;
    end if;
  end process;

  --------------------------------------------
  -- Component Instantiation
  --------------------------------------------
  -- *** Command FIFO ***
  CmdFifo_InData <= DaqSm2DaqDma_Cmd_ToStdlv(DaqSm_Cmd);
  i_fifocmd : entity work.psi_common_sync_fifo
    generic map(
      width_g        => DaqSm2DaqDma_Cmd_Size_c,
      depth_g        => 2**StreamBits_c,
      ram_style_g    => "distributed",
      ram_behavior_g => "RBW"
    )
    port map(
      clk_i       => Clk,
      rst_i       => Rst,
      dat_i       => CmdFifo_InData,
      vld_i       => DaqSm_Cmd_Vld,
      dat_o       => CmdFifo_OutData,
      vld_o       => CmdFifo_Vld,
      rdy_i       => r.CmdFifo_Rdy,
      out_level_o => CmdFifo_Level_Dbg
    );
  CmdFifo_Cmd    <= DaqSm2DaqDma_Cmd_FromStdlv(CmdFifo_OutData);

  -- *** Response FIFO ***
  -- Ready not required for system reasons: There is never more commands open than streams.
  RspFifo_InData <= DaqDma2DaqSm_Resp_ToStdlv(r.RspFifo_Data);
  i_fiforsp : entity work.psi_common_sync_fifo
    generic map(
      width_g        => DaqDma2DaqSm_Resp_Size_c,
      depth_g        => 2**StreamBits_c,
      ram_style_g    => "distributed",
      ram_behavior_g => "RBW"
    )
    port map(
      clk_i       => Clk,
      rst_i       => Rst,
      dat_i       => RspFifo_InData,
      vld_i       => r.RspFifo_Vld,
      dat_o       => RspFifo_OutData,
      vld_o       => DaqSm_Resp_Vld,
      rdy_i       => DaqSm_Resp_Rdy,
      out_level_o => RspFifo_Level_Dbg
    );
  DaqSm_Resp     <= DaqDme2DaqSm_Resp_FromStdlv(RspFifo_OutData);

  -- *** Buffer FIFO ***
  -- This FIFO allows buffering data for the time the state machine requires to react on a "memory interface not ready for more data" situation.
  -- As a result, the backpressure must not handled in the complete pipeline of this block.
  -- Rdy is not required since the data pipeline is stopped based on the almost full flag
  i_fifodata : entity work.psi_common_sync_fifo
    generic map(
      width_g          => IntDataWidth_g,
      depth_g          => BufferFifoDepth_c,
      alm_full_on_g    => true,
      alm_full_level_g => BufferFifoDepth_c / 2,
      ram_style_g      => "distributed",
      ram_behavior_g   => "RBW"
    )
    port map(
      clk_i       => Clk,
      rst_i       => Rst,
      dat_i       => r.DataSft(IntDataWidth_g-1 downto 0),
      vld_i       => r.Mem_DataVld,
      dat_o       => Mem_DatData,
      vld_o       => Mem_DatVld,
      rdy_i       => Mem_DatRdy,
      out_level_o => DatFifo_Level_Dbg,
      alm_full_o  => DatFifo_AlmFull
    );

  -- *** Remaining Data RAM ***
  Rem_Data_Fifo_In(BytesWidth_c + IntDataWidth_g + 1)                       <= r.RemWrLast;
  Rem_Data_Fifo_In(BytesWidth_c + IntDataWidth_g)                           <= r.RemWrTrigger;
  Rem_Data_Fifo_In(BytesWidth_c + IntDataWidth_g - 1 downto IntDataWidth_g) <= r.RemWrBytes;
  Rem_Data_Fifo_In(IntDataWidth_g - 1 downto 0)                             <= r.RemData;

  i_remram : entity work.psi_common_sdp_ram
    generic map(
      depth_g        => 2**StreamBits_c,
      width_g        => 1 + 1 + BytesWidth_c + IntDataWidth_g,
      is_async_g     => false,
      ram_style_g    => "distributed",
      ram_behavior_g => "RBW"
    )
    port map(
      wr_clk_i               => Clk,
      rd_clk_i               => Rst,
      wr_addr_i              => r.StreamStdlv,
      wr_i                   => r.RemWen,
      wr_dat_i               => Rem_Data_Fifo_In,
      rd_addr_i              => r.StreamStdlv,
      rd_dat_o               => Rem_Data_Fifo_Out
    );

    Rem_Last    <= Rem_Data_Fifo_Out(BytesWidth_c + IntDataWidth_g + 1);
    Rem_Trigger <= Rem_Data_Fifo_Out(BytesWidth_c + IntDataWidth_g);
    Rem_RdBytes <= Rem_Data_Fifo_Out(BytesWidth_c + IntDataWidth_g - 1 downto IntDataWidth_g);
    Rem_Data    <= Rem_Data_Fifo_Out(IntDataWidth_g - 1 downto 0);

end;
