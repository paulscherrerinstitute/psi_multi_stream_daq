------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------
-- Libraries
------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.psi_common_math_pkg.all;
	use work.psi_common_logic_pkg.all;
	use work.psi_common_array_pkg.all;
	use work.psi_ms_daq_pkg.all;

library work;
	use work.psi_ms_daq_daq_sm_tb_pkg.all;

library work;
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_daq_sm_tb_case_enable is
	
	procedure control (
		signal Clk : in std_logic;
		signal Rst : inout std_logic;
		signal GlbEna : inout std_logic;
		signal StrEna : inout std_logic_vector;
		signal StrIrq : in std_logic_vector;
		signal Inp_HasLast : inout std_logic_vector;
		signal Inp_Level : inout t_aslv16;
		signal Ts_Vld : inout std_logic_vector;
		signal Ts_Rdy : in std_logic_vector;
		signal Ts_Data : inout t_aslv64;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t);
		
	procedure dma_cmd (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t);
		
	procedure dma_resp (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Resp : inout DaqDma2DaqSm_Resp_t;
		signal Dma_Resp_Vld : inout std_logic;
		signal Dma_Resp_Rdy : in std_logic;
		signal TfDone : inout std_logic;
		signal StrLastWin : in WinType_a(Streams_g-1 downto 0);
		constant Generics_c : Generics_t);
		
	procedure ctx (
		signal Clk : in std_logic;
		signal CtxStr_Cmd : in ToCtxStr_t;
		signal CtxStr_Resp : inout FromCtx_t;
		signal CtxWin_Cmd : in ToCtxWin_t;
		signal CtxWin_Resp : inout FromCtx_t;
		constant Generics_c : Generics_t);
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_daq_sm_tb_case_enable is
	procedure control (
		signal Clk : in std_logic;
		signal Rst : inout std_logic;
		signal GlbEna : inout std_logic;
		signal StrEna : inout std_logic_vector;
		signal StrIrq : in std_logic_vector;
		signal Inp_HasLast : inout std_logic_vector;
		signal Inp_Level : inout t_aslv16;
		signal Ts_Vld : inout std_logic_vector;
		signal Ts_Rdy : in std_logic_vector;
		signal Ts_Data : inout t_aslv64;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t) is
	begin
		print(">> -- enable --");		
		
		-- Disabled stream does not react (global)
		print(">> Disabled stream does not react (global)");
		InitTestCase(Clk, Rst);
		GlbEna	<= '0';
		wait for 100 ns;
		TestCase := 0;
		ConfigureAuto(	WinSize => 4096*2, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);		
		for i in 0 to 3 loop
			Inp_Level(i) <= LvlThreshold_c;
		end loop;
		wait for 1 us;
		for i in 0 to 3 loop
			Inp_Level(i) <= (others => '0');	
		end loop;
		GlbEna <= '1';
		ControlWaitCompl(Clk);			
		
		-- Disabled stream does not react (per stream)
		print(">> Disabled stream does not react (per stream)");
		InitTestCase(Clk, Rst);
		TestCase := 1;
		ConfigureAuto(	WinSize => 4096*2, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);		
		for i in 0 to 3 loop
			StrEna(i) <= '0';
			wait for 20 ns;
			Inp_Level(i) <= LvlThreshold_c;
			wait for 1 us;
			Inp_Level(i) <= (others => '0');
			StrEna(i) <= '1';
		end loop;
		ControlWaitCompl(Clk);	
		
		-- Disabled stream does not influence arbitration
		print(">> Disabled stream does not react (per stream)");
		InitTestCase(Clk, Rst);
		TestCase := 2;
		ConfigureAuto(	WinSize => 4096*2, Ringbuf => '0', Overwrite => '1', Wincnt => 2, Wincur => 0);	
		StrEna(0) <= '0';
		wait for 20 ns;
		Inp_Level(0) <= LvlThreshold_c;
		wait for 200 ns;
		Inp_Level(1) <= LvlThreshold_c;
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0)	<= (others => '0');
		Inp_Level(1)	<= (others => '0');
		StrEna(0) <= '1';
		ControlWaitCompl(Clk);	
		
		-- Start with Sample 0, Window 0 after enable (global)
		print(">> Start with Sample 0, Window 0 after enable (global)");
		InitTestCase(Clk, Rst);
		TestCase := 3;
		for i in 0 to 2 loop
			Inp_Level(0) <= LvlThreshold_c;
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
			Inp_Level(0) <= (others => '0');		
			wait for 500 ns;
			Inp_Level(1) <= LvlThreshold_c;
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
			Inp_Level(1) <= (others => '0');
			wait for 500 ns;
			-- Shortly disable al lstreams after first access
			if i = 1 then
				GlbEna <= '0';
				wait for 20 ns;
				GlbEna <= '1';
				wait for 20 ns;
			end if;
		end loop;
		ControlWaitCompl(Clk);	
		
		-- Start with Sample 0, Window 0 after enable (per stream)
		-- only reset stream 0
		print(">> Start with Sample 0, Window 0 after enable (per stream)");
		InitTestCase(Clk, Rst);
		TestCase := 4;
		for i in 0 to 2 loop
			Inp_Level(0) <= LvlThreshold_c;
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
			Inp_Level(0) <= (others => '0');		
			wait for 500 ns;
			Inp_Level(1) <= LvlThreshold_c;
			wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
			Inp_Level(1) <= (others => '0');
			wait for 500 ns;
			-- Shortly disable al lstreams after first access
			if i = 1 then
				StrEna(0) <= '0';
				wait for 20 ns;
				StrEna(0) <= '1';
				wait for 20 ns;
			end if;
		end loop;	
		ControlWaitCompl(Clk);			
		
		-- 4k Boundary (is 4k boundary reset correctly for the first sample)
		print(">> 4k Boundary");
		InitTestCase(Clk, Rst);
		TestCase := 5;
		Inp_Level(0) <= LvlThreshold_c;
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');			
		StrEna(0) <= '0';
		wait for 20 ns;
		StrEna(0) <= '1';
		wait for 20 ns;		
		Inp_Level(0) <= LvlThreshold_c;
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		wait until rising_edge(Clk) and Dma_Cmd_Vld = '1';
		Inp_Level(0) <= (others => '0');			
		ControlWaitCompl(Clk);		
		
	end procedure;
	
	procedure dma_cmd (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Cmd : in DaqSm2DaqDma_Cmd_t;
		signal Dma_Cmd_Vld : in std_logic;
		constant Generics_c : Generics_t) is
		variable StartTime_v : time;
	begin
		-- Disabled stream does not react (global)
		WaitForCase(0,  Clk);
		StartTime_v	:= now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, Dma_Cmd_Vld, "Unexpected DMA command");
			wait until rising_edge(Clk);
		end loop;							
		ProcDone(2)	:= '1';			
		
		-- Disabled stream does not react (per stream)
		WaitForCase(1,  Clk);
		for str in 0 to 3 loop
			StartTime_v	:= now;
			while now < StartTime_v + 1 us loop
				StdlCompare(0, Dma_Cmd_Vld, "Unexpected DMA command");
				wait until rising_edge(Clk);
			end loop;	
		end loop;
		ProcDone(2)	:= '1';			
		
		-- Disabled stream does not influence arbitration
		WaitForCase(2,  Clk);
		-- Win0
		ExpectDmaCmdAuto(	Stream	=> 1, MaxSize => 4096, Msg => "Wr0.0",
							Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);									
		ProcDone(2)	:= '1';				
		
		-- Start with Sampe 0, Window 0 after enable (global)
		WaitForCase(3,  Clk);
		-- First after reset
		ExpectDmaCmd(	Stream => 0, Address => 16#01200000#, MaxSize => 4096, Msg=>"0.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmd(	Stream => 1, Address => 16#01210000#, MaxSize => 4096, Msg=>"0.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);				
		-- Normal
		ExpectDmaCmd(	Stream => 0, Address => 16#01208000#, MaxSize => 4096, Msg=>"1.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmd(	Stream => 1, Address => 16#01218000#, MaxSize => 4096, Msg=>"1.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		-- First after disable
		ExpectDmaCmd(	Stream => 0, Address => 16#01200000#, MaxSize => 4096, Msg=>"2.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmd(	Stream => 1, Address => 16#01210000#, MaxSize => 4096, Msg=>"2.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);							
		ProcDone(2)	:= '1';
		
		-- Start with Sampe 0, Window 0 after enable (per stream)
		WaitForCase(4,  Clk);
		-- First after reset
		ExpectDmaCmd(	Stream => 0, Address => 16#01200000#, MaxSize => 4096, Msg=>"0.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmd(	Stream => 1, Address => 16#01210000#, MaxSize => 4096, Msg=>"0.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);				
		-- Normal
		ExpectDmaCmd(	Stream => 0, Address => 16#01208000#, MaxSize => 4096, Msg=>"1.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		ExpectDmaCmd(	Stream => 1, Address => 16#01218000#, MaxSize => 4096, Msg=>"1.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		-- First after disable for stream 0
		ExpectDmaCmd(	Stream => 0, Address => 16#01200000#, MaxSize => 4096, Msg=>"2.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		-- Stream 1 continues normally
		ExpectDmaCmd(	Stream => 1, Address => 16#01218000#, MaxSize => 4096, Msg=>"2.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);							
		ProcDone(2)	:= '1';		
		
		-- 4k Boundary
		WaitForCase(5,  Clk);
		-- First after reset
		ExpectDmaCmd(	Stream => 0, Address => 16#01200800#, MaxSize => 2048, Msg=>"0.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);				
		-- Normal
		ExpectDmaCmd(	Stream => 0, Address => 16#01208000#, MaxSize => 4096, Msg=>"0.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		-- First after disable for stream 0
		ExpectDmaCmd(	Stream => 0, Address => 16#01200800#, MaxSize => 2048, Msg=>"1.0",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);	
		-- Normal
		ExpectDmaCmd(	Stream => 0, Address => 16#01208000#, MaxSize => 4096, Msg=>"1.1",
						Clk	=> Clk,	Dma_Cmd	=> Dma_Cmd,	Dma_Vld	=> Dma_Cmd_Vld);							
		ProcDone(2)	:= '1';			
		
	end procedure;
	
	procedure dma_resp (
		signal Clk : in std_logic;
		signal StrIrq : in std_logic_vector;
		signal Dma_Resp : inout DaqDma2DaqSm_Resp_t;
		signal Dma_Resp_Vld : inout std_logic;
		signal Dma_Resp_Rdy : in std_logic;
		signal TfDone : inout std_logic;
		signal StrLastWin : in WinType_a(Streams_g-1 downto 0);
		constant Generics_c : Generics_t) is
	begin
		-- Disabled stream does not react (global)
		WaitForCase(0,  Clk);
		ProcDone(1)	:= '1';
		
		-- Disabled stream does not react (per stream)
		WaitForCase(1,  Clk);
		ProcDone(1)	:= '1';		
		
		-- Disabled stream does not influence arbitration
		WaitForCase(2,  Clk);
		ApplyDmaRespAuto(	Stream => 1, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);							
		ProcDone(1)	:= '1';		
		
		-- Start with Sampe 0, Window 0 after enable (global)
		WaitForCase(3,  Clk);
		for i in 0 to 2 loop
			ApplyDmaResp(	Stream => 0, Size => 4096, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
			ApplyDmaResp(	Stream => 1, Size => 4096, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		end loop;
		ProcDone(1)	:= '1';
		
		-- Start with Sampe 0, Window 0 after enable (per stream)
		WaitForCase(4,  Clk);
		for i in 0 to 2 loop
			ApplyDmaResp(	Stream => 0, Size => 4096, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
			ApplyDmaResp(	Stream => 1, Size => 4096, Trigger => '0',
							Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
		end loop;
		ProcDone(1)	:= '1';	

		-- 4k Boundary
		WaitForCase(5,  Clk);
		for i in 0 to 1 loop
			for k in 0 to 1 loop
				ApplyDmaResp(	Stream => 0, Size => 2048+k*2048, Trigger => '0',
								Clk	=> Clk,	Dma_Resp => Dma_Resp, Dma_Resp_Vld => Dma_Resp_Vld,	Dma_Resp_Rdy => Dma_Resp_Rdy);
			end loop;
		end loop;
		ProcDone(1)	:= '1';	
		
	end procedure;
	
	procedure ctx (
		signal Clk : in std_logic;
		signal CtxStr_Cmd : in ToCtxStr_t;
		signal CtxStr_Resp : inout FromCtx_t;
		signal CtxWin_Cmd : in ToCtxWin_t;
		signal CtxWin_Resp : inout FromCtx_t;
		constant Generics_c : Generics_t) is
		variable StartTime_v : time;
		variable CurPtr_v	: integer;
		variable BufStart_v	: integer;
		variable NextPtr_v	: integer;
		variable WinNext_v	: integer;
		variable SplWinBefore_v	: integer;
		variable SplWinAfter_v	: integer;
		variable TfSize_v		: integer;
	begin
		-- Disabled stream does not react (global)
		WaitForCase(0, Clk);
		StartTime_v := now;
		while now < StartTime_v + 1 us loop
			StdlCompare(0, CtxStr_Cmd.WenLo, "CtxStr_Cmd.WenLo high unexpectedly");
			StdlCompare(0, CtxStr_Cmd.WenHi, "CtxStr_Cmd.WenHi high unexpectedly");
			StdlCompare(0, CtxWin_Cmd.WenLo, "CtxWin_Cmd.WenLo high unexpectedly");
			StdlCompare(0, CtxWin_Cmd.WenHi, "CtxWin_Cmd.WenHi high unexpectedly");
			StdlCompare(0, CtxWin_Cmd.Rd, 	 "CtxWin_Cmd.Rd high unexpectedly");
			wait until rising_edge(Clk);
		end loop;		
		ProcDone(0)	:= '1';		
		
		-- Disabled stream does not react (per stream)
		WaitForCase(1, Clk);
		for str in 0 to 3 loop
			StartTime_v := now;
			while now < StartTime_v + 1 us loop
				StdlCompare(0, CtxStr_Cmd.WenLo, "CtxStr_Cmd.WenLo high unexpectedly");
				StdlCompare(0, CtxStr_Cmd.WenHi, "CtxStr_Cmd.WenHi high unexpectedly");
				StdlCompare(0, CtxWin_Cmd.WenLo, "CtxWin_Cmd.WenLo high unexpectedly");
				StdlCompare(0, CtxWin_Cmd.WenHi, "CtxWin_Cmd.WenHi high unexpectedly");
				StdlCompare(0, CtxWin_Cmd.Rd, 	 "CtxWin_Cmd.Rd high unexpectedly");
				wait until rising_edge(Clk);
			end loop;
		end loop;
		ProcDone(0)	:= '1';			
		
		-- Disabled stream does not influence arbitration
		WaitForCase(2, Clk);
		ExpCtxFullBurstAuto(	Stream => 1, Msg => "Wr0",
								Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);						
		ProcDone(0)	:= '1';			
		
		-- Start with Sampe 0, Window 0 after enable (global)
		WaitForCase(3, Clk);
		for i in 0 to 2 loop
			for str in 0 to 1 loop
				-- Read for calculation of access
				BufStart_v	:= 16#01200000# + 16#00010000#*str;
				CurPtr_v	:= BufStart_v + 16#8000#;
				if i = 1 then
					NextPtr_v := CurPtr_v + 4096;
					WinNext_v := 2;
					SplWinBefore_v := 4096/(StreamWidth_g(str)/8);
				else
					NextPtr_v := BufStart_v + 4096;
					WinNext_v := 0;
					SplWinBefore_v := 0;
				end if;				
				SplWinAfter_v := SplWinBefore_v + 4096/(StreamWidth_g(str)/8);
				ExpCtxRead(	Stream 		=> Str,
							BufStart 	=> BufStart_v,
							WinSize		=> 16#00004000#,
							Overwrite	=> '1',
							Ptr			=> CurPtr_v,
							Wincnt		=> 4,
							Wincur		=> 2,
							WinSel		=> WinNext_v,
							SamplesWin	=> SplWinBefore_v,
							Msg			=> "a" & to_string(i) & "." & to_string(str),
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
				-- Read for update
				ExpCtxRead(	Stream 		=> Str,
							BufStart 	=> BufStart_v,
							WinSize		=> 16#00004000#,
							Overwrite	=> '1',
							Ptr			=> CurPtr_v,
							Wincnt		=> 4,
							Wincur		=> WinNext_v,
							WinSel		=> WinNext_v,
							SamplesWin	=> SplWinBefore_v,
							Msg			=> "b" & to_string(i) & "." & to_string(str),
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);				

				-- Write of update
				ExpCtxWrite(	Stream 		=> Str,
								BufStart 	=> BufStart_v,
								WinSize		=> 16#00004000#,
								Overwrite	=> '1',
								Ptr			=> NextPtr_v,
								Wincnt		=> 4,
								Wincur		=> WinNext_v,
								WinNext		=> WinNext_v,
								SamplesWin	=> SplWinAfter_v,
								WinLast		=> NextPtr_v-StreamWidth_g(str)/8,
								Msg			=> "" & to_string(i) & "." & to_string(str),
								Clk			=> Clk, CtxStr_Cmd => CtxStr_Cmd, CtxWin_Cmd => CtxWin_Cmd);
			end loop;
		end loop;
		ProcDone(0)	:= '1';
		
		-- Start with Sampe 0, Window 0 after enable (per stream)
		WaitForCase(4, Clk);
		for i in 0 to 2 loop
			for str in 0 to 1 loop
				-- Read for calculation of access
				BufStart_v	:= 16#01200000# + 16#00010000#*str;
				CurPtr_v	:= BufStart_v + 16#8000#;
				if (i = 0) or (i = 2 and str = 0) then 
					NextPtr_v := BufStart_v + 4096;
					WinNext_v := 0;
					SplWinBefore_v := 0;
				else
					NextPtr_v := CurPtr_v + 4096;
					WinNext_v := 2;
					SplWinBefore_v := 4096/(StreamWidth_g(str)/8);
				end if;				
				SplWinAfter_v := SplWinBefore_v + 4096/(StreamWidth_g(str)/8);
				ExpCtxRead(	Stream 		=> Str,
							BufStart 	=> BufStart_v,
							WinSize		=> 16#00004000#,
							Overwrite	=> '1',
							Ptr			=> CurPtr_v,
							Wincnt		=> 4,
							Wincur		=> 2,
							WinSel		=> WinNext_v,
							SamplesWin	=> SplWinBefore_v,
							Msg			=> "a" & to_string(i) & "." & to_string(str),
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
				-- Read for update
				ExpCtxRead(	Stream 		=> Str,
							BufStart 	=> BufStart_v,
							WinSize		=> 16#00004000#,
							Overwrite	=> '1',
							Ptr			=> CurPtr_v,
							Wincnt		=> 4,
							Wincur		=> WinNext_v,
							WinSel		=> WinNext_v,
							SamplesWin	=> SplWinBefore_v,
							Msg			=> "b" & to_string(i) & "." & to_string(str),
							Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);				

				-- Write of update
				ExpCtxWrite(	Stream 		=> Str,
								BufStart 	=> BufStart_v,
								WinSize		=> 16#00004000#,
								Overwrite	=> '1',
								Ptr			=> NextPtr_v,
								Wincnt		=> 4,
								Wincur		=> WinNext_v,
								WinNext		=> WinNext_v,
								SamplesWin	=> SplWinAfter_v,
								WinLast		=> NextPtr_v-StreamWidth_g(str)/8,
								Msg			=> "" & to_string(i) & "." & to_string(str),
								Clk			=> Clk, CtxStr_Cmd => CtxStr_Cmd, CtxWin_Cmd => CtxWin_Cmd);
			end loop;
		end loop;
		ProcDone(0)	:= '1';

		-- 4k Boundary
		WaitForCase(5, Clk);
		for i in 0 to 3 loop
			-- Read for calculation of access
			BufStart_v	:= 16#01200800#;
			CurPtr_v	:= 16#01208000#;
			-- If first after reset/enable
			if (i = 0) or (i = 2) then 
				TfSize_v := 2048;
				NextPtr_v := BufStart_v + TfSize_v;
				WinNext_v := 0;
				SplWinBefore_v := 0;
			else
				TfSize_v := 4096;
				NextPtr_v := CurPtr_v + TfSize_v;
				WinNext_v := 2;
				SplWinBefore_v := 4096/(StreamWidth_g(0)/8);
			end if;				
			SplWinAfter_v := SplWinBefore_v + TfSize_v/(StreamWidth_g(0)/8);
			ExpCtxRead(	Stream 		=> 0,
						BufStart 	=> BufStart_v,
						WinSize		=> 16#00004000#,
						Overwrite	=> '1',
						Ptr			=> CurPtr_v,
						Wincnt		=> 4,
						Wincur		=> 2,
						WinSel		=> WinNext_v,
						SamplesWin	=> SplWinBefore_v,
						Msg			=> "a" & to_string(i),
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);
			-- Read for update
			ExpCtxRead(	Stream 		=> 0,
						BufStart 	=> BufStart_v,
						WinSize		=> 16#00004000#,
						Overwrite	=> '1',
						Ptr			=> CurPtr_v,
						Wincnt		=> 4,
						Wincur		=> WinNext_v,
						WinSel		=> WinNext_v,
						SamplesWin	=> SplWinBefore_v,
						Msg			=> "b" & to_string(i),
						Clk => Clk, CtxStr_Cmd => CtxStr_Cmd, CtxStr_Resp => CtxStr_Resp, CtxWin_Cmd => CtxWin_Cmd, CtxWin_Resp => CtxWin_Resp);				

			-- Write of update
			ExpCtxWrite(	Stream 		=> 0,
							BufStart 	=> BufStart_v,
							WinSize		=> 16#00004000#,
							Overwrite	=> '1',
							Ptr			=> NextPtr_v,
							Wincnt		=> 4,
							Wincur		=> WinNext_v,
							WinNext		=> WinNext_v,
							SamplesWin	=> SplWinAfter_v,
							WinLast		=> NextPtr_v-StreamWidth_g(0)/8,
							Msg			=> "c" & to_string(i),
							Clk			=> Clk, CtxStr_Cmd => CtxStr_Cmd, CtxWin_Cmd => CtxWin_Cmd);
		end loop;
		ProcDone(0)	:= '1';	
		
	end procedure;
	
end;
