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
package psi_ms_daq_input_tb_case_single_frame is
	
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
	shared variable Samples_v	: integer;
		
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_input_tb_case_single_frame is
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
		wait for 100 ns;
		wait until rising_edge(Str_Clk);
		
		-- Single 3 QWORD frame, trigger at the end
		print(">> Single 3 QWORD frame, trigger at the end");
		Samples_v := 3*64/Generics_c.StreamWidth_g;
		ApplyStrData(Samples_v, Samples_v-1, 100, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;
		
		-- Frame shortened by trigger
		if Generics_c.StreamWidth_g /= 64 then
			print(">> Frame shortened by trigger");
			Samples_v := 3*64/Generics_c.StreamWidth_g - 1;
			ApplyStrData(Samples_v, Samples_v-1, 101, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
			while not CheckDone_v loop
				wait until rising_edge(Str_Clk);
			end loop;
			CheckDone_v := false;
		end if;
		
		-- Single Sample Frame
		print(">> Single sample frame");
		Samples_v := 1;
		ApplyStrData(Samples_v, Samples_v-1, 102, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;	

		-- 5 Samples, 3 Post Trigger
		print(">> 5 Samples, 3 Post Trigger");
		wait for 100 ns;
		Samples_v := 5;
		ApplyStrData(5, 1, 103, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;		
		
		-- 5 Samples, 1 Post Trigger
		print(">> 5 Samples, 1 Post Trigger");
		wait for 100 ns;
		Samples_v := 5;
		ApplyStrData(5, 3, 104, Generics_c, Str_Clk, Str_Vld, Str_Rdy, Str_Data, Str_Trig, Str_Ts);
		while not CheckDone_v loop
			wait until rising_edge(Str_Clk);
		end loop;
		CheckDone_v := false;			
		
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
		PostTrigSpls <= std_logic_vector(to_unsigned(0, 32));
		Daq_Rdy <= '0';
		
		-- Single 3 QWORD frame, trigger at the end
		wait for 1 us;
		assert unsigned(Daq_Level) = 3 report "###ERROR###: 3QW, Trigger at end: Level incorrect" severity error;
		assert Daq_HasLast = '1' report "###ERROR###: 3QW, Trigger at end: HastTlast incorrect" severity error;
		CheckAcqData (Samples_v, 100, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckDone_v := true;
		
		-- Frame shortened by trigger
		wait for 1 us;
		if Generics_c.StreamWidth_g /= 64 then
			assert unsigned(Daq_Level) = 3 report "###ERROR###: Shortened: Level incorrect" severity error;
			assert Daq_HasLast = '1' report "###ERROR###: Shortened: HastTlast incorrect" severity error;
			CheckAcqData (Samples_v, 101, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
			CheckDone_v := true;
		end if;
		
		-- Single Sample Frame
		wait for 1 us;
		assert unsigned(Daq_Level) = 1 report "###ERROR###: Single Sample: Level incorrect" severity error;
		assert Daq_HasLast = '1' report "###ERROR###: Single Sample: HastTlast incorrect" severity error;
		CheckAcqData (Samples_v, 102, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckDone_v := true;

		-- 5 Samples, 3 Post Trigger
		PostTrigSpls <= std_logic_vector(to_unsigned(3, 32));	
		wait for 1 us;		
		assert Daq_HasLast = '1' report "###ERROR###: 5 Samples 3 Post, Trigger at end: HastTlast incorrect" severity error;
		CheckAcqData (5, 103, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckDone_v := true;
		
		-- 5 Samples, 1 Post Trigger
		PostTrigSpls <= std_logic_vector(to_unsigned(1, 32));	
		wait for 1 us;
		assert Daq_HasLast = '1' report "###ERROR###: 5 Samples 1 Post, Trigger at end: HastTlast incorrect" severity error;
		CheckAcqData (5, 104, Generics_c, FrameType_Trigger_c, Clk, Daq_Vld, Daq_Rdy, Daq_Data, Ts_Vld, Ts_Rdy, Ts_Data);
		CheckDone_v := true;		
		
	end procedure;
	
end;
