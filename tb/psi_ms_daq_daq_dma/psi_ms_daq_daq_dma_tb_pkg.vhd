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
	use work.psi_tb_txt_util.all;
	use work.psi_tb_compare_pkg.all;
	use work.psi_tb_activity_pkg.all;

------------------------------------------------------------
-- Package Header
------------------------------------------------------------
package psi_ms_daq_daq_dma_tb_pkg is
	
	-- *** Generics Record ***
	type Generics_t is record
		Dummy : boolean; -- required since empty records are not allowed
	end record;
	
	------------------------------------------------------------
	-- Not exported Generics
	------------------------------------------------------------
	constant Streams_g : positive := 4;

	------------------------------------------------------------
	-- Procedures
	------------------------------------------------------------	
	type EndType_s is (Trigger_s, Timeout_s, NoData_s, NoEnd_s);
	procedure ApplyCmd(			Stream 			: in	integer;
								Address			: in	integer;
								MaxSize			: in	integer;
						signal 	DaqSm_Cmd 		: out 	DaqSm2DaqDma_Cmd_t;
						signal 	DaqSm_Cmd_Vld 	: out 	std_logic;
						signal 	Clk				: in 	std_logic);
						
	procedure CheckResp(		Stream 			: in	integer;
								Size			: in	integer;
								EndType			: in	EndType_s;
						signal DaqSm_Resp 		: in DaqDma2DaqSm_Resp_t;
						signal DaqSm_Resp_Vld 	: in std_logic;
						signal DaqSm_Resp_Rdy 	: out std_logic;
						signal 	Clk				: in 	std_logic);
						
	procedure ApplyData(		Stream 		: in	integer;
								Bytes		: in	integer;	
								EndType		: in	EndType_s;
						signal 	Inp_Vld 	: out 	std_logic_vector;
						signal 	Inp_Rdy 	: in 	std_logic_vector;
						signal 	Inp_Data 	: out 	Input2Daq_Data_a;
						signal	Clk			: in	std_logic;
								Offset		: in	integer	:= 0);
						
	procedure CheckMemData(			Bytes		: in	integer;
									RdyDelay	: in	integer	:= 0;
							signal 	Mem_DatData : in 	std_logic_vector;
							signal 	Mem_DatVld 	: in 	std_logic;
							signal 	Mem_DatRdy 	: out 	std_logic;
							signal 	Clk			: in	std_logic;
									Offset		: in	integer	:= 0;
									Msg			: in	string := "");	

	procedure CheckMemCmd(			Address		: in	integer;
									Bytes		: in	integer;
									RdyDelay	: in	integer	:= 0;
							signal	Mem_CmdAddr : in 	std_logic_vector;
							signal	Mem_CmdSize : in 	std_logic_vector;
							signal	Mem_CmdVld 	: in 	std_logic;
							signal	Mem_CmdRdy 	: out 	std_logic;
							signal 	Clk			: in	std_logic;
									Msg			: in	string := "");		

	shared variable TestCase_v 	: integer := -1;
	shared variable ProcDone_V	: std_logic_vector(0 to 2);
	
	procedure InitCase(	signal 	Clk		: in	std_logic;
						signal	Rst		: out	std_logic);
						
	procedure InitSubCase(CaseNr	: in		integer);
						
	procedure WaitForCase(			CaseNr	: in		integer;
							signal 	Clk		: in		std_logic);
							
	procedure WaitAllProc(	signal	Clk		: in		std_logic);
	
end package;

------------------------------------------------------------
-- Package Body
------------------------------------------------------------
package body psi_ms_daq_daq_dma_tb_pkg is

	procedure ApplyCmd(			Stream 			: in	integer;
								Address			: in	integer;
								MaxSize			: in	integer;
						signal DaqSm_Cmd 		: out 	DaqSm2DaqDma_Cmd_t;
						signal DaqSm_Cmd_Vld 	: out 	std_logic;
						signal Clk				: in 	std_logic) is
	begin
		wait until rising_edge(Clk);
		DaqSm_Cmd_Vld	<= '1';
		DaqSm_Cmd.Address	<= std_logic_vector(to_unsigned(Address, 32));
		DaqSm_Cmd.MaxSize	<= std_logic_vector(to_unsigned(MaxSize, 16));
		DaqSm_Cmd.Stream	<= Stream;
		wait until rising_edge(Clk);
		DaqSm_Cmd_Vld	<= '0';
	end procedure;
	
	procedure CheckResp(		Stream 			: in	integer;
								Size			: in	integer;
								EndType			: in	EndType_s;
						signal DaqSm_Resp 		: in 	DaqDma2DaqSm_Resp_t;
						signal DaqSm_Resp_Vld 	: in 	std_logic;
						signal DaqSm_Resp_Rdy 	: out 	std_logic;
						signal 	Clk				: in 	std_logic) is
	begin
		DaqSm_Resp_Rdy <= '1';
		wait until rising_edge(Clk) and DaqSm_Resp_Vld = '1';
		if Trigger_s = EndType then
			StdlCompare(1, DaqSm_Resp.Trigger, "CHEK_RESP: Response has not set TRIGGER");
		else
			StdlCompare(0, DaqSm_Resp.Trigger, "CHEK_RESP: Response has not cleared TRIGGER");
		end if;
		StdlvCompareInt(Size, DaqSm_Resp.Size, "CHEK_RESP: Wrong size in response");
		IntCompare(Stream, DaqSm_Resp.Stream, "CHEK_RESP: Wrong stream number in response");
		wait until rising_edge(Clk);
		StdlCompare(0, DaqSm_Resp_Vld, "CHEK_RESP: Response valid did not go low");		
	end procedure;
	
	procedure ApplyData(		Stream 		: in	integer;
								Bytes		: in	integer;	
								EndType		: in	EndType_s;
						signal 	Inp_Vld 	: out 	std_logic_vector;
						signal 	Inp_Rdy 	: in 	std_logic_vector;
						signal 	Inp_Data 	: out 	Input2Daq_Data_a;
						signal	Clk			: in	std_logic;
								Offset		: in	integer	:= 0) is
		variable DataCnt_v	: unsigned(7 downto 0) := to_unsigned(Offset, 8);
	begin
		assert EndType = NoEnd_s or EndType = Trigger_s or EndType = Timeout_s 
			report "###ERROR###: APPLY_DATA: EndType not yet implemented" severity error;
		-- Empty frame handling
		if Bytes = 0 then
			Inp_Data(Stream).Data <= X"AAAA_BBBB_CCCC_DDDD";
			Inp_Data(Stream).Bytes <= "0000";
			if EndType = Timeout_s then
				Inp_Data(Stream).Last <= '1';
				Inp_Data(Stream).IsTo <= '1';			
			else
				report "###ERROR###: APPLY_DATA: empty frames only supported for timeout" severity error;
			end if;
			wait until rising_edge(Clk) and Inp_Rdy(Stream) = '1';
			Inp_Vld(Stream) 		<= '0';
		-- Normal operation
		else
			Inp_Vld(Stream) 		<= '1';
			for dw in 0 to (Bytes+7)/8-1 loop
				for byte in 0 to 7 loop
					if dw*8+byte >= Bytes then
						Inp_Data(Stream).Data(8*(byte+1)-1 downto 8*byte)	<= (others => '0');
					else
						Inp_Data(Stream).Data(8*(byte+1)-1 downto 8*byte)	<= std_logic_vector(DataCnt_v);
						DataCnt_v := DataCnt_v + 1;
					end if;
				end loop;
				Inp_Data(Stream).Last <= '0';
				Inp_Data(Stream).IsTo <= '0';
				Inp_Data(Stream).IsTrig <= '0';			
				if dw = (Bytes+7)/8-1 then
					if EndType = Trigger_s then
						Inp_Data(Stream).Last <= '1';
						Inp_Data(Stream).IsTrig <= '1';
					elsif EndType = Timeout_s then
						Inp_Data(Stream).Last <= '1';
						Inp_Data(Stream).IsTo <= '1';					
					end if;
				end if;

				if Bytes-dw*8 > 8 then
					Inp_Data(Stream).Bytes <= std_logic_vector(to_unsigned(8, 4));
				else
					Inp_Data(Stream).Bytes <= std_logic_vector(to_unsigned(Bytes-dw*8, 4));
				end if;
				wait until rising_edge(Clk) and Inp_Rdy(Stream) = '1';
			end loop;
			Inp_Vld(Stream) 		<= '0';	
		end if;
	end procedure;
	
	procedure CheckMemData(			Bytes		: in	integer;
									RdyDelay	: in	integer	:= 0;
							signal 	Mem_DatData : in 	std_logic_vector;
							signal 	Mem_DatVld 	: in 	std_logic;
							signal 	Mem_DatRdy 	: out 	std_logic;
							signal 	Clk			: in	std_logic;
									Offset		: in	integer	:= 0;
									Msg			: in	string := "") is
		variable DataCnt_v	: integer := Offset;
	begin
		for dw in 0 to (Bytes+7)/8-1 loop
			if RdyDelay > 0 then
				Mem_DatRdy <= '0';
				for i in 0 to RdyDelay loop
					wait until rising_edge(Clk);
				end loop;				
			end if;
			Mem_DatRdy <= '1';
			wait until rising_edge(Clk) and Mem_DatVld = '1';
			Mem_DatRdy <= '0';
			for byte in 0 to 7 loop
				if dw*8+byte >= Bytes then
					-- nothing to compare
				else
					StdlvCompareInt (DataCnt_v, Mem_DatData(8*(byte+1)-1 downto 8*byte), "MEM_DATA: Wrong Data QW[" & to_string(dw) & "] Byte [" & to_string(byte) & "] - " & Msg, false); 
					DataCnt_v := (DataCnt_v + 1) mod 256;
				end if;
			end loop;		
		end loop;
	end procedure;
	
	procedure CheckMemCmd(			Address		: in	integer;
									Bytes		: in	integer;
									RdyDelay	: in	integer	:= 0;
							signal	Mem_CmdAddr : in 	std_logic_vector;
							signal	Mem_CmdSize : in 	std_logic_vector;
							signal	Mem_CmdVld 	: in 	std_logic;
							signal	Mem_CmdRdy 	: out 	std_logic;
							signal 	Clk			: in	std_logic;
									Msg			: in	string := "") is
	begin
		if RdyDelay > 0 then
			Mem_CmdRdy <= '0';
		else
			Mem_CmdRdy <= '1';
		end if;
		wait until rising_edge(Clk) and Mem_CmdVld = '1';
		if RdyDelay > 0 then
			for i in 0 to RdyDelay loop
				wait until rising_edge(Clk);
			end loop;				
		end if;
		Mem_CmdRdy <= '1';	
		StdlCompare(1, Mem_CmdVld, "MEM CMD: Mem_CmdVld did not stay high - " & Msg);
		StdlvCompareInt(Address, Mem_CmdAddr, "MEM_CMD: Wrong Address - " & Msg, false);
		StdlvCompareInt(Bytes, Mem_CmdSize, "MEM_CMD: Wrong Size - " & Msg, false);
		wait until rising_edge(Clk);
		wait for 1 ns;
		Mem_CmdRdy <= '0';	
		StdlCompare(0, Mem_CmdVld, "MEM_CMD: Mem_CmdVld did not go low - " & Msg);
	end procedure;
	
	procedure InitCase(	signal 	Clk		: in	std_logic;
						signal	Rst		: out	std_logic) is
	begin
		ProcDone_V := (others => '0');
		TestCase_v := -1;
		wait until rising_edge(Clk);
		Rst <= '1';
		wait until rising_edge(Clk);
		Rst <= '0';
		wait until rising_edge(Clk);
	end procedure;
	
	procedure InitSubCase(CaseNr	: in		integer) is
	begin
		ProcDone_V := (others => '0');
		TestCase_v := CaseNr;
	end procedure;
	
	procedure WaitForCase(			CaseNr	: in		integer;
							signal 	Clk		: in		std_logic) is
	begin
		while CaseNr /= TestCase_v loop
			wait until rising_edge(Clk);
		end loop;
	end procedure;
	
	procedure WaitAllProc(	signal	Clk		: in		std_logic) is
	begin
		while signed(ProcDone_V) /= -1 loop
			wait until rising_edge(Clk);
		end loop;
	end procedure;
	

end;
