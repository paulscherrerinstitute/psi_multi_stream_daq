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

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_input_tb_case_always_trig is
	
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
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_case_always_trig is
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
		print(">> Trigger always set");
		wait for 100 ns;
		wait until rising_edge(Str_Clk);
		
		-- Apply Input data
		Str_Trig <= '1';
		Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
		Str_Vld <= '1';
		for SplCnt in 0 to 17 loop
			Str_Vld <= '1';
			Str_Ts <= std_logic_vector(to_unsigned(SplCnt, Str_Ts'length));
			Str_Data <= std_logic_vector(to_unsigned(SplCnt, Generics_c.StreamWidth_g));			
			wait until rising_edge(Str_Clk);
			if Generics_c.VldPulsed_g then
				Str_Vld <= '0';
				-- Remove trigger after last sample of test, otherwise it stays latched and affects the next testcase
				if SplCnt = 17 then
					Str_Trig <= '0';
				end if;
				Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
				Str_Data <= std_logic_vector(to_unsigned(0, Generics_c.StreamWidth_g));	
				wait until rising_edge(Str_Clk);
			end if;
		end loop;
		Str_Vld <= '0';
		Str_Trig <= '0';
		Str_Ts <= std_logic_vector(to_unsigned(0, Str_Ts'length));
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
		PostTrigSpls <= std_logic_vector(to_unsigned(8, 32));
		Daq_Rdy <= '0';
		
		-- Wait until iniput done
		wait for 1 us;
		wait until rising_edge(Clk);
		
		-- check if frames are recorded back to back without loss
		CheckAcqData (9, 0, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data, false);		
		CheckAcqData (9, 9, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data, false, 9);		
	end procedure;
	
end;
