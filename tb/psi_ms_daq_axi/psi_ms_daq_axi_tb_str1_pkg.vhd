------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------
-- Description
------------------------------------------------------------
-- Stream 1 works in manual recording mode. The data is arriving
-- in bursts (samples back-to-back withing bursts) and does
-- not contain any trigger events.
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
package psi_ms_daq_axi_tb_str1_pkg is

	constant PrintStr1_c			: boolean	:= PrintDefault_c;

	-- Memory
	constant Str1BufStart_c			: integer	:= 16#2000#;
	constant Str1WinSize_c			: integer	:= 500;
	constant Str1Windows_c			: integer	:= 1;
	alias Memory1 : t_aslv8(0 to Str1WinSize_c*Str1Windows_c) is Memory(Str1BufStart_c to Str1BufStart_c+Str1WinSize_c*Str1Windows_c);
	
	--------------------------------------------------------
	-- Persistent State
	--------------------------------------------------------
	shared variable Str1WinCheck 	: integer 	:= 0;
	shared variable Str1DataCnt		: integer	:= 0;

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str1Data(		signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(15 downto 0));
							
	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str1Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r);	

	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str1Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);	

	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str1Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r);							
														
							
							
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_axi_tb_str1_pkg is

	--------------------------------------------------------
	-- Data Generation
	--------------------------------------------------------
	procedure Str1Data(	signal clk	: in	std_logic;
							signal vld	: out	std_logic;
							signal trig	: out	std_logic;
							signal data : out	std_logic_vector(15 downto 0)) is
	begin
		while now < 10 us loop
			wait until rising_edge(clk);
		end loop;
		for i in 0 to 19 loop
			vld <= '1';
			for k in 0 to 49 loop
				data <= std_logic_vector(to_unsigned(Str1DataCnt, 16));
				Str1DataCnt := Str1DataCnt + 1;
				wait until rising_edge(clk);
			end loop;
			vld <= '0';
			wait for 1 us;
			wait until rising_edge(clk);
		end loop;
	end procedure;

	--------------------------------------------------------
	-- IRQ Handler
	--------------------------------------------------------
	procedure Str1Handler(	signal	clk			: in	std_logic;
							signal	rqst		: out 	axi_ms_r;
							signal	rsp			: in	axi_sm_r) is
		variable v : integer;
		variable curwin : integer;
		variable wincnt : integer;
		variable winlast : integer;
		variable valRead : unsigned(15 downto 0);
	begin	
		print("------------ Stream 1 Handler ------------", PrintStr1_c);
		HlGetMaxLvl(1, clk, rqst, rsp, v);
		print("MAXLVL: " & to_string(v), PrintStr1_c);
		HlGetPtr(1, clk, rqst, rsp, v);
		print("PTR: " & to_string(v), PrintStr1_c);	
		HlGetCurWin(1, clk, rqst, rsp, curwin);		
		print("CURWIN: " & to_string(curwin), PrintStr1_c);
		IntCompare(0, curwin, "Stream1: CURWIN wrong");
		-- Check window content
		HlGetWinCnt(1, 0, clk, rqst, rsp, wincnt);	
		print("WINCNT: " & to_string(wincnt), PrintStr1_c);	
		IntCompare(250, wincnt, "Stream1:WINCNT wrong");
		HlGetWinLast(1, 0, clk, rqst, rsp, winlast);	
		print("WINLAST: " & to_string(winlast), PrintStr1_c);	
		IntCompare(16#2000#+498, winlast, "Stream1:WINLAST wrong");		
		for spl in 0 to 249 loop 
			valRead(7 downto 0)		:= unsigned(Memory1(spl*2));
			valRead(15 downto 8)	:= unsigned(Memory1(spl*2+1));
			-- first 100 samples are before arming
			StdlvCompareInt (spl+100, std_logic_vector(valRead), "Stream1:Wrong value", false);			
		end loop;
		print("", PrintStr1_c);	
		Str1WinCheck := Str1WinCheck + 1;		
	end procedure;	
	
	--------------------------------------------------------
	-- Setup
	--------------------------------------------------------
	procedure Str1Setup(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
	begin
		HlCheckMaxLvl(1, 0, clk, rqst, rsp);
		HlSetPostTrig(1, 250, clk, rqst, rsp);
		HlSetMode(1, VAL_MODE_RECM_MANUAL, clk, rqst, rsp);
		HlConfStream(	str => 1, bufstart => Str1BufStart_c, ringbuf => false, overwrite => false, wincnt => Str1Windows_c, winsize => Str1WinSize_c, 
						clk => clk, rqst => rqst, rsp => rsp);
	end procedure;
	
	--------------------------------------------------------
	-- Update
	--------------------------------------------------------
	procedure Str1Update(	signal clk			: in	std_logic;
							signal rqst			: out	axi_ms_r;
							signal rsp			: in	axi_sm_r) is
		variable Stream1Armed_v : boolean := false;
	begin
		-- ARM recorder at required point in time
		if Str1DataCnt = 99 and not Stream1Armed_v then
			Stream1Armed_v := true;
			HlSetMode(1, VAL_MODE_RECM_MANUAL + VAL_MODE_ARM, clk, rqst, rsp);
		end if;
	end;	
		
end;
