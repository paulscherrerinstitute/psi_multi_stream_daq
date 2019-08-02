------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------
-- Description
------------------------------------------------------------

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
package psi_ms_daq_axi_tb_str3_pkg is

	constant PrintStr3_c			: boolean	:= PrintDefault_c;

	-- Memory
	constant Str3BufStart_c			: integer	:= 16#4000#;
	constant Str3WinSize_c			: integer	:= 1024;
	constant Str3Windows_c			: integer	:= 3;
	constant Str3PostTrig_c			: integer 	:= 9;
	constant Str3TrigPos_c			: integer	:= 100;
	alias Memory3 : t_aslv8(0 to Str3WinSize_c*Str3Windows_c) is Memory(Str3BufStart_c to Str3BufStart_c+Str3WinSize_c*Str3Windows_c);	
	
	--------------------------------------------------------
	-- Persistent State
	--------------------------------------------------------
	shared variable Str3ExpFrame	: integer := 0;
	shared variable Str3FrameCnt	: integer := 0;
	shared variable Str3SplCnt		: integer := 0;
	shared variable Str3WinCheck 	: integer := 0;
	shared variable Stream3Armed_v 	: boolean := false;

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str3Data(		signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(31 downto 0));
							
	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str3Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r);	

	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str3Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);	

	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str3Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);							
							
							
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_axi_tb_str3_pkg is

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str3Data(		signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(31 downto 0)) is
	begin
		while now < 8 us loop
			wait until rising_edge(clk);
		end loop;
		for i in 0 to 9 loop
			vld <= '1';
			Str3SplCnt := 0;
			for k in 0 to 999 loop
				data <= std_logic_vector(to_unsigned(Str3FrameCnt*2**16+Str3SplCnt, 32));				
				if Str3SplCnt = Str3TrigPos_c then
					trig <= '1';
				else
					trig <= '0';
				end if;
				Str3SplCnt := Str3SplCnt + 1;
				wait until rising_edge(clk);
			end loop;
			Str3FrameCnt := Str3FrameCnt + 1;
			vld <= '0';
			wait for 1 us;
			wait until rising_edge(clk);
		end loop;
	end procedure;

	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str3Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r) is
		variable v : integer;
		variable curwin : integer;
		variable wincnt : integer;
		variable winlast : integer;
		variable spladdr : integer;
		variable splNr : integer;
		variable valRead : unsigned(15 downto 0);
		variable splInWin : integer;
		variable isRecording : boolean;
	begin	
		print("------------ Stream 3 Handler ------------", PrintStr3_c);
		HlGetMaxLvl(3, clk, rqst, rsp, v);
		print("MAXLVL: " & to_string(v), PrintStr3_c);
		HlGetPtr(3, clk, rqst, rsp, v);
		print("PTR: " & to_string(v), PrintStr3_c);		
		HlGetCurWin(3, clk, rqst, rsp, curwin);
		print("CURWIN: " & to_string(curwin), PrintStr3_c);
		-- Calculate window to read
		if curwin = 0 then
			curwin := Str3Windows_c-1;
		else
			curwin := curwin-1;
		end if;		
		-- Check Data from this frame
		splNr := Str3TrigPos_c+Str3PostTrig_c;
		-- Read window data (Post-Trigger, from this window)
		print("check post-trigger", PrintStr3_c);
		HlGetWinLast(3, curwin, clk, rqst, rsp, winlast);
		print("WINLAST: " & to_string(winlast), PrintStr3_c);
		spladdr := winlast;
		while splNr >= 0 loop	
			StdlvCompareInt(splNr, Memory(spladdr+1) & Memory(spladdr), "Stream3: Sample " & to_string(Str3ExpFrame) & ":" & to_string(splNr) & " wrong CNT", false);
			StdlvCompareInt(Str3ExpFrame, Memory(spladdr+3) & Memory(spladdr+2), "Stream3: Sample " & to_string(Str3ExpFrame) & ":" & to_string(splNr) & " wrong FRAME", false);
			-- Wraparound
			if spladdr = Str3BufStart_c+curwin*Str3WinSize_c then
				spladdr := Str3BufStart_c+(curwin+1)*Str3WinSize_c-4;
			-- Normal Counting
			else
				spladdr := spladdr - 4;
			end if;
			splNr := splNr - 1;
		end loop;
		-- Read window data (Pre-Trigger, from last window)
		print("check pre-trigger", PrintStr3_c);
		splNr := 999;
		while spladdr /= winlast loop
			StdlvCompareInt(splNr, Memory(spladdr+1) & Memory(spladdr), "Stream3: Sample " & to_string(Str3ExpFrame-1) & ":" & to_string(splNr) & " wrong CNT", false);
			StdlvCompareInt(Str3ExpFrame-1, Memory(spladdr+3) & Memory(spladdr+2), "Stream3: Sample " & to_string(Str3ExpFrame-1) & ":" & to_string(splNr) & " wrong FRAME", false);
			-- Wraparound
			if spladdr = Str3BufStart_c+curwin*Str3WinSize_c then
				spladdr := Str3BufStart_c+(curwin+1)*Str3WinSize_c-4;
			-- Normal Counting
			else
				spladdr := spladdr - 4;
			end if;
			splNr := splNr - 1;
		end loop;			
		
		Str3WinCheck := Str3WinCheck + 1;				
		print("", PrintStr3_c);		
	end procedure;

	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str3Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
	begin
		HlCheckMaxLvl(3, 0, clk, rqst, rsp); 
		HlSetPostTrig(3, Str3PostTrig_c, clk, rqst, rsp);
		HlSetMode(3, VAL_MODE_RECM_TRIGMASK, clk, rqst, rsp);
		HlConfStream(	str => 3, bufstart => Str3BufStart_c, ringbuf => true, overwrite => true, wincnt => Str3Windows_c, winsize => Str3WinSize_c, 
						clk => clk, rqst => rqst, rsp => rsp);
	end procedure;

	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str3Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
	begin
		if ((Str3FrameCnt = 2) or (Str3FrameCnt = 7))
			and not Stream3Armed_v then
			HlSetMode(3, VAL_MODE_RECM_TRIGMASK + VAL_MODE_ARM, clk, rqst, rsp);
			Stream3Armed_v := true;
			Str3ExpFrame := Str3FrameCnt;			
		elsif Str3FrameCnt = 6 then
			Stream3Armed_v := false;
		end if;
	end procedure;	
		
end;
