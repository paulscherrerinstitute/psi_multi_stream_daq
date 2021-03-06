------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------
-- Testbench generated by TbGen.py
------------------------------------------------------------
-- see Library/Python/TbGenerator

------------------------------------------------------------
-- Libraries
------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.psi_common_math_pkg.all;
	use work.psi_common_array_pkg.all;
	use work.psi_ms_daq_pkg.all;

library work;
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;

library work;
	use work.psi_ms_daq_daq_sm_tb_pkg.all;

library work;
	use work.psi_ms_daq_daq_sm_tb_case_single_simple.all;
	use work.psi_ms_daq_daq_sm_tb_case_priorities.all;
	use work.psi_ms_daq_daq_sm_tb_case_single_window.all;
	use work.psi_ms_daq_daq_sm_tb_case_multi_window.all;
	use work.psi_ms_daq_daq_sm_tb_case_enable.all;
	use work.psi_ms_daq_daq_sm_tb_case_irq.all;
	use work.psi_ms_daq_daq_sm_tb_case_timestamp.all;

------------------------------------------------------------
-- Entity Declaration
------------------------------------------------------------
entity psi_ms_daq_daq_sm_tb is
end entity;

------------------------------------------------------------
-- Architecture
------------------------------------------------------------
architecture sim of psi_ms_daq_daq_sm_tb is
	-- *** Fixed Generics ***
	constant Streams_g : positive := 4;
	constant StreamPrio_g : t_ainteger := (1, 2, 3, 1);
	constant StreamWidth_g : t_ainteger := (8, 16, 32, 64);
	constant Windows_g : positive := 8;
	constant MinBurstSize_g : positive := 512;
	constant MaxBurstSize_g : positive := 512;
	
	-- *** Not Assigned Generics (default values) ***
	
	-- *** Exported Generics ***
	constant Generics_c : Generics_t := (
		Dummy => true);
	
	-- *** TB Control ***
	signal TbRunning : boolean := True;
	signal NextCase : integer := -1;
	signal ProcessDone : std_logic_vector(0 to 3) := (others => '0');
	constant AllProcessesDone_c : std_logic_vector(0 to 3) := (others => '1');
	constant TbProcNr_control_c : integer := 0;
	constant TbProcNr_dma_cmd_c : integer := 1;
	constant TbProcNr_dma_resp_c : integer := 2;
	constant TbProcNr_ctx_c : integer := 3;
	
	-- *** DUT Signals ***
	signal Clk : std_logic := '1';
	signal Rst : std_logic := '0';
	signal GlbEna : std_logic := '1';
	signal StrEna : std_logic_vector(Streams_g-1 downto 0) := (others => '1');
	signal StrIrq : std_logic_vector(Streams_g-1 downto 0) := (others => '0');
	signal Inp_HasLast : std_logic_vector(Streams_g-1 downto 0) := (others => '0');
	signal Inp_Level : t_aslv16(Streams_g-1 downto 0) := (others => (others => '0'));
	signal Ts_Vld : std_logic_vector(Streams_g-1 downto 0) := (others => '0');
	signal Ts_Rdy : std_logic_vector(Streams_g-1 downto 0) := (others => '0');
	signal Ts_Data : t_aslv64(Streams_g-1 downto 0);
	signal Dma_Cmd : DaqSm2DaqDma_Cmd_t;
	signal Dma_Cmd_Vld : std_logic := '0';
	signal Dma_Resp : DaqDma2DaqSm_Resp_t := ( Size => (others => '0'), Trigger => '0', Stream => 0);
	signal Dma_Resp_Vld : std_logic := '0';
	signal Dma_Resp_Rdy : std_logic := '0';
	signal TfDone : std_logic := '0';
	signal CtxStr_Cmd : ToCtxStr_t;
	signal CtxStr_Resp : FromCtx_t := (others => (others => '0'));
	signal CtxWin_Cmd : ToCtxWin_t;
	signal CtxWin_Resp : FromCtx_t := (others => (others => '0'));
	signal StrLastWin : WinType_a(Streams_g-1 downto 0) := (others => (others => '0'));
	
begin
	------------------------------------------------------------
	-- DUT Instantiation
	------------------------------------------------------------
	i_dut : entity work.psi_ms_daq_daq_sm
		generic map (
			Streams_g => Streams_g,
			StreamPrio_g => StreamPrio_g,
			StreamWidth_g => StreamWidth_g,
			Windows_g => Windows_g,
			MinBurstSize_g => MinBurstSize_g,
			MaxBurstSize_g => MaxBurstSize_g
		)
		port map (
			Clk => Clk,
			Rst => Rst,
			GlbEna => GlbEna,
			StrEna => StrEna,
			StrIrq => StrIrq,
			StrLastWin => StrLastWin,
			Inp_HasLast => Inp_HasLast,
			Inp_Level => Inp_Level,
			Ts_Vld => Ts_Vld,
			Ts_Rdy => Ts_Rdy,
			Ts_Data => Ts_Data,
			Dma_Cmd => Dma_Cmd,
			Dma_Cmd_Vld => Dma_Cmd_Vld,
			Dma_Resp => Dma_Resp,
			Dma_Resp_Vld => Dma_Resp_Vld,
			Dma_Resp_Rdy => Dma_Resp_Rdy,
			TfDone => TfDone,
			CtxStr_Cmd => CtxStr_Cmd,
			CtxStr_Resp => CtxStr_Resp,
			CtxWin_Cmd => CtxWin_Cmd,
			CtxWin_Resp => CtxWin_Resp
		);
	
	------------------------------------------------------------
	-- Testbench Control !DO NOT EDIT!
	------------------------------------------------------------
	p_tb_control : process
	begin
		-- single_simple
		NextCase <= 0;
		wait until ProcessDone = AllProcessesDone_c;
		-- priorities
		NextCase <= 1;
		wait until ProcessDone = AllProcessesDone_c;
		-- single_window
		NextCase <= 2;
		wait until ProcessDone = AllProcessesDone_c;
		-- multi_window
		NextCase <= 3;
		wait until ProcessDone = AllProcessesDone_c;
		-- enable
		NextCase <= 4;
		wait until ProcessDone = AllProcessesDone_c;
		-- irq
		NextCase <= 5;
		wait until ProcessDone = AllProcessesDone_c;
		-- timestamp
		NextCase <= 6;
		wait until ProcessDone = AllProcessesDone_c;
		TbRunning <= false;
		wait;
	end process;
	
	------------------------------------------------------------
	-- Clocks !DO NOT EDIT!
	------------------------------------------------------------
	p_clock_Clk : process
		constant Frequency_c : real := real(200e6);
	begin
		while TbRunning loop
			wait for 0.5*(1 sec)/Frequency_c;
			Clk <= not Clk;
		end loop;
		wait;
	end process;
	
	
	------------------------------------------------------------
	-- Resets
	------------------------------------------------------------
	
	------------------------------------------------------------
	-- Processes !DO NOT EDIT!
	------------------------------------------------------------
	-- *** control ***
	p_control : process
	begin
		-- single_simple
		wait until NextCase = 0;
		ProcessDone(TbProcNr_control_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_simple.control(Clk, Rst, GlbEna, StrEna, StrIrq, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Rdy, Ts_Data, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_control_c) <= '1';
		-- priorities
		wait until NextCase = 1;
		ProcessDone(TbProcNr_control_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_priorities.control(Clk, Rst, GlbEna, StrEna, StrIrq, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Rdy, Ts_Data, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_control_c) <= '1';
		-- single_window
		wait until NextCase = 2;
		ProcessDone(TbProcNr_control_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_window.control(Clk, Rst, GlbEna, StrEna, StrIrq, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Rdy, Ts_Data, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_control_c) <= '1';
		-- multi_window
		wait until NextCase = 3;
		ProcessDone(TbProcNr_control_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_multi_window.control(Clk, Rst, GlbEna, StrEna, StrIrq, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Rdy, Ts_Data, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_control_c) <= '1';
		-- enable
		wait until NextCase = 4;
		ProcessDone(TbProcNr_control_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_enable.control(Clk, Rst, GlbEna, StrEna, StrIrq, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Rdy, Ts_Data, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_control_c) <= '1';
		-- irq
		wait until NextCase = 5;
		ProcessDone(TbProcNr_control_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_irq.control(Clk, Rst, GlbEna, StrEna, StrIrq, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Rdy, Ts_Data, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_control_c) <= '1';
		-- timestamp
		wait until NextCase = 6;
		ProcessDone(TbProcNr_control_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_timestamp.control(Clk, Rst, GlbEna, StrEna, StrIrq, Inp_HasLast, Inp_Level, Ts_Vld, Ts_Rdy, Ts_Data, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_control_c) <= '1';
		wait;
	end process;
	
	-- *** dma_cmd ***
	p_dma_cmd : process
	begin
		-- single_simple
		wait until NextCase = 0;
		ProcessDone(TbProcNr_dma_cmd_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_simple.dma_cmd(Clk, StrIrq, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_cmd_c) <= '1';
		-- priorities
		wait until NextCase = 1;
		ProcessDone(TbProcNr_dma_cmd_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_priorities.dma_cmd(Clk, StrIrq, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_cmd_c) <= '1';
		-- single_window
		wait until NextCase = 2;
		ProcessDone(TbProcNr_dma_cmd_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_window.dma_cmd(Clk, StrIrq, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_cmd_c) <= '1';
		-- multi_window
		wait until NextCase = 3;
		ProcessDone(TbProcNr_dma_cmd_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_multi_window.dma_cmd(Clk, StrIrq, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_cmd_c) <= '1';
		-- enable
		wait until NextCase = 4;
		ProcessDone(TbProcNr_dma_cmd_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_enable.dma_cmd(Clk, StrIrq, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_cmd_c) <= '1';
		-- irq
		wait until NextCase = 5;
		ProcessDone(TbProcNr_dma_cmd_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_irq.dma_cmd(Clk, StrIrq, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_cmd_c) <= '1';
		-- timestamp
		wait until NextCase = 6;
		ProcessDone(TbProcNr_dma_cmd_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_timestamp.dma_cmd(Clk, StrIrq, Dma_Cmd, Dma_Cmd_Vld, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_cmd_c) <= '1';
		wait;
	end process;
	
	-- *** dma_resp ***
	p_dma_resp : process
	begin
		-- single_simple
		wait until NextCase = 0;
		ProcessDone(TbProcNr_dma_resp_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_simple.dma_resp(Clk, StrIrq, Dma_Resp, Dma_Resp_Vld, Dma_Resp_Rdy, TfDone, StrLastWin, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_resp_c) <= '1';
		-- priorities
		wait until NextCase = 1;
		ProcessDone(TbProcNr_dma_resp_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_priorities.dma_resp(Clk, StrIrq, Dma_Resp, Dma_Resp_Vld, Dma_Resp_Rdy, TfDone, StrLastWin, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_resp_c) <= '1';
		-- single_window
		wait until NextCase = 2;
		ProcessDone(TbProcNr_dma_resp_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_window.dma_resp(Clk, StrIrq, Dma_Resp, Dma_Resp_Vld, Dma_Resp_Rdy, TfDone, StrLastWin, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_resp_c) <= '1';
		-- multi_window
		wait until NextCase = 3;
		ProcessDone(TbProcNr_dma_resp_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_multi_window.dma_resp(Clk, StrIrq, Dma_Resp, Dma_Resp_Vld, Dma_Resp_Rdy, TfDone, StrLastWin, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_resp_c) <= '1';
		-- enable
		wait until NextCase = 4;
		ProcessDone(TbProcNr_dma_resp_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_enable.dma_resp(Clk, StrIrq, Dma_Resp, Dma_Resp_Vld, Dma_Resp_Rdy, TfDone, StrLastWin, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_resp_c) <= '1';
		-- irq
		wait until NextCase = 5;
		ProcessDone(TbProcNr_dma_resp_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_irq.dma_resp(Clk, StrIrq, Dma_Resp, Dma_Resp_Vld, Dma_Resp_Rdy, TfDone, StrLastWin, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_resp_c) <= '1';
		-- timestamp
		wait until NextCase = 6;
		ProcessDone(TbProcNr_dma_resp_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_timestamp.dma_resp(Clk, StrIrq, Dma_Resp, Dma_Resp_Vld, Dma_Resp_Rdy, TfDone, StrLastWin, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_dma_resp_c) <= '1';
		wait;
	end process;
	
	-- *** ctx ***
	p_ctx : process
	begin
		-- single_simple
		wait until NextCase = 0;
		ProcessDone(TbProcNr_ctx_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_simple.ctx(Clk, CtxStr_Cmd, CtxStr_Resp, CtxWin_Cmd, CtxWin_Resp, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_ctx_c) <= '1';
		-- priorities
		wait until NextCase = 1;
		ProcessDone(TbProcNr_ctx_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_priorities.ctx(Clk, CtxStr_Cmd, CtxStr_Resp, CtxWin_Cmd, CtxWin_Resp, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_ctx_c) <= '1';
		-- single_window
		wait until NextCase = 2;
		ProcessDone(TbProcNr_ctx_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_single_window.ctx(Clk, CtxStr_Cmd, CtxStr_Resp, CtxWin_Cmd, CtxWin_Resp, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_ctx_c) <= '1';
		-- multi_window
		wait until NextCase = 3;
		ProcessDone(TbProcNr_ctx_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_multi_window.ctx(Clk, CtxStr_Cmd, CtxStr_Resp, CtxWin_Cmd, CtxWin_Resp, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_ctx_c) <= '1';
		-- enable
		wait until NextCase = 4;
		ProcessDone(TbProcNr_ctx_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_enable.ctx(Clk, CtxStr_Cmd, CtxStr_Resp, CtxWin_Cmd, CtxWin_Resp, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_ctx_c) <= '1';
		-- irq
		wait until NextCase = 5;
		ProcessDone(TbProcNr_ctx_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_irq.ctx(Clk, CtxStr_Cmd, CtxStr_Resp, CtxWin_Cmd, CtxWin_Resp, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_ctx_c) <= '1';
		-- timestamp
		wait until NextCase = 6;
		ProcessDone(TbProcNr_ctx_c) <= '0';
		work.psi_ms_daq_daq_sm_tb_case_timestamp.ctx(Clk, CtxStr_Cmd, CtxStr_Resp, CtxWin_Cmd, CtxWin_Resp, Generics_c);
		wait for 1 ps;
		ProcessDone(TbProcNr_ctx_c) <= '1';
		wait;
	end process;
	
	
end;
