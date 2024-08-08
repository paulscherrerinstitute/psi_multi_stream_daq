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

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_input_tb_case_trig_in_posttrig is
	
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
		signal Daq_Data : in Input2Daq_Data_t(Data(IntDataWidth_g-1 downto 0), Bytes(log2ceil(IntDataWidth_g/8) downto 0));
		signal Daq_Level : in std_logic_vector;
		signal Daq_HasLast : in std_logic;
		signal Ts_Vld : in std_logic;
		signal Ts_Rdy : inout std_logic;
		signal Ts_Data : in std_logic_vector;
		constant Generics_c : Generics_t);
		
	shared variable CheckDone_v	: boolean := false;
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_case_trig_in_posttrig is
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
		-- Wait for config to be applied
		print(">> Trigger in Post Trigger (with space)");
		wait for 100 ns;
		wait until rising_edge(Str_Clk);
		
		-- Create frame which has a trigger inside the post-trigger period
		ApplyStrData(10, 4, 100, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		ApplyStrData(3, 1, 101, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts, 10);
		
		-- Create frame which has a trigger that is longer than one period
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;
		ApplyStrData(5, 4, 100, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		ApplyStrData(8, 0, 101, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts, 5);		
		
		
		
	end procedure;
	
	procedure daq (
		signal Clk : in std_logic;
		signal PostTrigSpls : inout std_logic_vector;
		signal Mode : inout RecMode_t;
		signal Daq_Vld : in std_logic;
		signal Daq_Rdy : inout std_logic;
		signal Daq_Data : in Input2Daq_Data_t(Data(IntDataWidth_g-1 downto 0), Bytes(log2ceil(IntDataWidth_g/8) downto 0));
		signal Daq_Level : in std_logic_vector;
		signal Daq_HasLast : in std_logic;
		signal Ts_Vld : in std_logic;
		signal Ts_Rdy : inout std_logic;
		signal Ts_Data : in std_logic_vector;
		constant Generics_c : Generics_t) is
	begin
		-- Config
		PostTrigSpls <= std_logic_vector(to_unsigned(8, 32));
		Daq_Rdy <= '0';
		
		-- Check trigger in post-trigger with space
		wait for 1 us;
		CheckAcqData (13, 100, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);	
		StdlvCompareInt(0, Daq_Level, "Trig in Posttrig (space): Level incorrect", false);		
		StdlCompare(0, Daq_HasLast, "Trig in Posttrig (space): HastTlast incorrec");
		StdlCompare(0, Ts_Vld, "Trig in Posttrig (space): Ts_Vld incorrect");
		CheckDone_v := true;
		
		-- Check trigger in post-trigger back to back
		wait for 1 us;
		CheckAcqData (13, 100, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);	
		StdlvCompareInt(0, Daq_Level, "Trig in Posttrig (back-to-back): Level incorrect", false);	
		StdlCompare(0, Daq_HasLast, "Trig in Posttrig (back-to-back): HastTlast incorrec");
		StdlCompare(0, Ts_Vld, "Trig in Posttrig (back-to-back): Ts_Vld incorrect");
		CheckDone_v := true;
				

		
	end procedure;
	
end;
