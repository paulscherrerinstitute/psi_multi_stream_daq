------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------
-- Description
------------------------------------------------------------
-- Stream 2 works in siingle recording mode. The data is arriving
-- in bursts (samples back-to-back withing bursts) and does
-- contain trigger events at the really begining (sample 0).
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
	use work.psi_ms_daq_axi_tb_pkg.all;
	use work.psi_tb_axi_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_axi_tb_str2_pkg is

	constant PrintStr2_c			: boolean	:= PrintDefault_c;

	-- Memory
	constant Str2BufStart_c			: integer	:= 16#3000#;
	constant Str2WinSize_c			: integer	:= 256;
	constant Str2Windows_c			: integer	:= 3;
	constant Str2PostTrig_c			: integer 	:= 127;
	alias Memory2 : t_aslv8(0 to Str2WinSize_c*Str2Windows_c) is Memory(Str2BufStart_c to Str2BufStart_c+Str2WinSize_c*Str2Windows_c);	
	
	--------------------------------------------------------
	-- Persistent State
	--------------------------------------------------------
	shared variable Str2FrameCnt	: integer := 0;
	shared variable Str2SplCnt		: integer := 0;
	shared variable Str2WinCheck 	: integer := 0;
	shared variable Str2ExpFrame	: integer := 0;
	shared variable Stream2Armed_v : boolean := false;

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str2Data(		signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(15 downto 0));
							
	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str2Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r);	

	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str2Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);	

	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str2Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);							
							
							
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_axi_tb_str2_pkg is

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str2Data(		signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(15 downto 0)) is
	begin
		while now < 8.5 us loop
			wait until rising_edge(clk);
		end loop;
		for i in 0 to 19 loop
			vld <= '1';
			Str2SplCnt := 0;
			trig <= '1';
			for k in 0 to 199 loop
				data <= std_logic_vector(to_unsigned(Str2FrameCnt*256+Str2SplCnt, 16));
				Str2SplCnt := Str2SplCnt + 1;
				wait until rising_edge(clk);
				trig <= '0';
			end loop;
			Str2FrameCnt := Str2FrameCnt + 1;
			vld <= '0';
			wait for 1 us;
			wait until rising_edge(clk);
		end loop;
	end procedure;

	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str2Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r) is
		variable v : integer;
		variable curwin : integer;
		variable lastwin : integer;
		variable wincnt : integer;
		variable spladdr : integer;
		variable splNr : integer;
		variable valRead : unsigned(15 downto 0);
		variable splInWin : integer;
		variable isTrig : boolean;
	begin	
		print("------------ Stream 2 Handler ------------", PrintStr2_c);
		HlGetMaxLvl(2, clk, rqst, rsp, v);
		print("MAXLVL: " & to_string(v), PrintStr2_c);
		HlGetPtr(2, clk, rqst, rsp, v);
		print("PTR: " & to_string(v), PrintStr2_c);		
		HlGetCurWin(2, clk, rqst, rsp, curwin);
		print("CURWIN: " & to_string(curwin), PrintStr2_c);
		-- Calculate window to read
		if curwin = 0 then
			curwin := Str2Windows_c-1;
		else
			curwin := curwin-1;
		end if;
		-- Read window data		
		-- Check if recording is finished
		HlIsTrigWin(2, curwin, clk, rqst, rsp, isTrig);
		-- Check if window is fully written to memory
		HlGetLastWin(2, clk, rqst, rsp, lastwin);
		-- Execute
		if not isTrig then
			print("Skipped: not a trigger window", PrintStr2_c);
		elsif curwin /= lastwin then
			print("Skipped: not written to memory yet " & str(curwin) & " " & str(lastwin), PrintStr2_c);
		else
			-- Check Data (last 128 samples)
			splNr := Str2PostTrig_c;
			while splNr >= 0 loop
				print("check window " & to_string(curwin), PrintStr2_c);
				HlGetWinLast(2, curwin, clk, rqst, rsp, spladdr);
				print("WINLAST: " & to_string(spladdr), PrintStr2_c);
				while (splNr >= 0) and (spladdr >= Str2BufStart_c+curwin*Str2WinSize_c) loop
					StdlvCompareInt(splNr, Memory(spladdr), "Stream2: Sample " & to_string(Str2ExpFrame) & ":" & to_string(splNr) & " wrong CNT [addr=" & str(spladdr) & "]", false);
					StdlvCompareInt(Str2ExpFrame, Memory(spladdr+1), "Stream2: Sample " & to_string(Str2ExpFrame) & ":" & to_string(splNr) & " wrong FRAME [addr=" & str(spladdr) & "]", false);
					spladdr := spladdr - 2;
					splNr := splNr - 1;
				end loop;
				-- Next Window
				if curwin = 0 then
					curwin := Str2Windows_c-1;
				else
					curwin := curwin-1;
				end if;
			end loop;
			Str2WinCheck := Str2WinCheck + 1;				
		end if;
		print("", PrintStr2_c);		
	end procedure;

	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str2Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
	begin
		HlCheckMaxLvl(2, 0, clk, rqst, rsp);
		HlSetPostTrig(2, Str2PostTrig_c, clk, rqst, rsp);
		HlSetMode(2, VAL_MODE_RECM_SINGLE, clk, rqst, rsp);
		HlConfStream(	str => 2, bufstart => Str2BufStart_c, ringbuf => false, overwrite => true, wincnt => Str2Windows_c, winsize => Str2WinSize_c, 
						clk => clk, rqst => rqst, rsp => rsp);
	end procedure;

	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str2Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
	begin
		-- ARM Stream 2 after 3 bursts
		if ((Str2FrameCnt = 2) or (Str2FrameCnt = 12)) and 
			(Str2SplCnt >= 80) and (Str2SplCnt <= 150) and not Stream2Armed_v then
			Stream2Armed_v := true;
			HlSetMode(2, VAL_MODE_RECM_SINGLE + VAL_MODE_ARM, clk, rqst, rsp);
			Str2ExpFrame := Str2FrameCnt + 1;
		elsif Str2FrameCnt = 11 then
			Stream2Armed_v := false;
		end if;
	end;	
		
end;
