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
	use work.psi_ms_daq_pkg.all;

library work;
	use work.psi_ms_daq_input_tb_pkg.all;

library work;
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;
	use work.psi_tb_activity_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_input_tb_case_modes is
	
	procedure stream (
		signal Str_Clk : in std_logic;
		signal Str_Vld : inout std_logic;
		signal Str_Rdy : in std_logic;
		signal Str_Data : inout std_logic_vector;
		signal Str_Trig : inout std_logic;
		signal Str_Ts : inout std_logic_vector;
		signal Clk : in std_logic;
		signal Arm : inout std_logic;
		signal IsArmed : in std_logic;
		constant Generics_c : Generics_t);
		
	procedure daq (
		signal Clk : in std_logic;
		signal PostTrigSpls : inout std_logic_vector;
		signal Mode : inout RecMode_t;
		signal Daq_Vld : in std_logic;
		signal Daq_Rdy : inout std_logic;
		signal Daq_Data : in Input2Daq_Data_t;
		signal Daq_Level : in std_logic_vector;
		signal Daq_HasLast : in std_logic;
		signal Ts_Vld : in std_logic;
		signal Ts_Rdy : inout std_logic;
		signal Ts_Data : in std_logic_vector;
		constant Generics_c : Generics_t);
		
	shared variable TestCase : integer := -1;
	shared variable StrDone  : boolean := false;
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_case_modes is
	procedure stream (
		signal Str_Clk : in std_logic;
		signal Str_Vld : inout std_logic;
		signal Str_Rdy : in std_logic;
		signal Str_Data : inout std_logic_vector;
		signal Str_Trig : inout std_logic;
		signal Str_Ts : inout std_logic_vector;
		signal Clk : in std_logic;
		signal Arm : inout std_logic;
		signal IsArmed : in std_logic;
		constant Generics_c : Generics_t) is
	begin
		
		-- Trigger Mask Mode
		while TestCase /= 0 loop
			wait until rising_edge(Str_Clk);
		end loop;
		wait for 100 ns;
		-- Recorded but trigger lost
		ApplyStrData(5, 1, 1, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		-- Received
		PulseSig(Arm, Clk);
		wait for 100 ns;
		ApplyStrData(4, 0, 2, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts, 5);
		-- Lost
		ApplyStrData(7, 3, 3, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);	
		StrDone := true;
		
		-- Single Shot Mode
		while TestCase /= 1 loop
			wait until rising_edge(Str_Clk);
		end loop;
		wait for 100 ns;
		-- Lost
		ApplyStrData(5, 1, 1, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		-- Received
		PulseSig(Arm, Clk);
		wait for 100 ns;
		ApplyStrData(6, 2, 2, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts, 5);
		-- Lost
		ApplyStrData(7, 3, 3, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts, 5+6);
		StrDone := true;

		-- Manual Mode
		while TestCase /= 2 loop
			wait until rising_edge(Str_Clk);
		end loop;
		wait for 100 ns;
		-- Lost
		ApplyStrData(5, 1, 1, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		-- Received (partially)
		Str_Ts <= std_logic_vector(to_unsigned(10, 64));
		PulseSig(Arm, Clk);
		wait for 100 ns;
		Str_Ts <= std_logic_vector(to_unsigned(0, 64));
		ApplyStrData(100, 80, 2, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts, 5);
		-- Lost
		ApplyStrData(7, 3, 3, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts, 5+6);			
		StrDone := true;		
		
	end procedure;
	
	procedure daq (
		signal Clk : in std_logic;
		signal PostTrigSpls : inout std_logic_vector;
		signal Mode : inout RecMode_t;
		signal Daq_Vld : in std_logic;
		signal Daq_Rdy : inout std_logic;
		signal Daq_Data : in Input2Daq_Data_t;
		signal Daq_Level : in std_logic_vector;
		signal Daq_HasLast : in std_logic;
		signal Ts_Vld : in std_logic;
		signal Ts_Rdy : inout std_logic;
		signal Ts_Data : in std_logic_vector;
		constant Generics_c : Generics_t) is
	begin
		-- Config
		PostTrigSpls <= std_logic_vector(to_unsigned(3, 32));
		Daq_Rdy <= '0';
		
		-- Trigger Mask Mode
		print(">> Trigger Mask Mode");	
		StrDone := false;
		Mode <= RecMode_TriggerMask_c;
		TestCase := 0;
		CheckAcqData (5+4, 2, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		wait for 100 ns;
		CheckAcqData (7, 3, Generics_c, FrameType_Timeout_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		while not StrDone loop
			wait until rising_edge(Clk);
		end loop;
		wait until rising_edge(Clk);
		StdlCompare(0, Daq_Vld, "Unexpected data is available");	
		
		
		-- Single Shot Mode
		print(">> Single Shot Mode");	
		StrDone := false;
		Mode <= RecMode_SingleShot_c;
		TestCase := 1;
		CheckAcqData (6, 2, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data, false, 5);
		while not StrDone loop
			wait until rising_edge(Clk);
		end loop;
		wait until rising_edge(Clk);
		StdlCompare(0, Daq_Vld, "Unexpected data is available");		
		
		-- Manual Mode
		PostTrigSpls <= std_logic_vector(to_unsigned(6, 32));
		print(">> Manual Mode");	
		StrDone := false;
		Mode <= RecMode_ManuelMode_c;
		TestCase := 2;
		CheckAcqData (7, 10, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data, false, 5);
		while not StrDone loop
			wait until rising_edge(Clk);
		end loop;
		wait until rising_edge(Clk);
		StdlCompare(0, Daq_Vld, "Unexpected data is available");			
		
		
	end procedure;
	
end;
