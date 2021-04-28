------------------------------------------------------------------------------
--  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
--  All rights reserved.
--  Authors: Oliver Bruendler
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Libraries
------------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	
library work;
	use work.psi_common_math_pkg.all;

------------------------------------------------------------------------------
-- Package Header
------------------------------------------------------------------------------
package psi_ms_daq_pkg is

    constant MemoryBusWidth_c : integer := 512;
    constant MemoryBusBytes_c : integer := MemoryBusWidth_c/8;
    constant MaxStreams_c     : integer := 32;
    constant MaxWindows_c     : integer := 32;
    constant MaxStreamsBits_c : integer := log2ceil(MaxStreams_c);
    constant MaxWindowsBits_c : integer := log2ceil(MaxWindows_c);
    constant MaxStreamWidth_c : integer := MemoryBusWidth_c;
	
	subtype RecMode_t is std_logic_vector(1 downto 0);
	constant RecMode_Continuous_c	: RecMode_t	:= std_logic_vector(to_unsigned(0, RecMode_t'length));
	constant RecMode_TriggerMask_c	: RecMode_t	:= std_logic_vector(to_unsigned(1, RecMode_t'length));
	constant RecMode_SingleShot_c	: RecMode_t	:= std_logic_vector(to_unsigned(2, RecMode_t'length));
	constant RecMode_ManuelMode_c	: RecMode_t	:= std_logic_vector(to_unsigned(3, RecMode_t'length));
	
	subtype WinType_t is std_logic_vector(MaxWindowsBits_c-1 downto 0);
	type WinType_a is array (natural range <>) of WinType_t;

    constant Input2Daq_Data_Bytes_Len : natural := log2(MemoryBusBytes_c)+1;
	type Input2Daq_Data_t is record
		Last		: std_logic;
		Data		: std_logic_vector(MemoryBusWidth_c-1 downto 0);
		Bytes		: std_logic_vector(Input2Daq_Data_Bytes_Len-1 downto 0); 
		IsTo		: std_logic;
		IsTrig		: std_logic;
	end record;
	type Input2Daq_Data_a is array (natural range <>) of Input2Daq_Data_t;
	
	type DaqSm2DaqDma_Cmd_t is record
		Address		: std_logic_vector(31 downto 0);
		MaxSize		: std_logic_vector(15 downto 0);
		Stream		: integer range 0 to MaxStreams_c-1;
	end record;
	constant DaqSm2DaqDma_Cmd_Size_c	: integer	:= 32+16+MaxStreamsBits_c;
	function DaqSm2DaqDma_Cmd_ToStdlv( rec : DaqSm2DaqDma_Cmd_t) return std_logic_vector;
	function DaqSm2DaqDma_Cmd_FromStdlv( stdlv : std_logic_vector) return DaqSm2DaqDma_Cmd_t;
	
	type DaqDma2DaqSm_Resp_t is record
		Size		: std_logic_vector(15 downto 0);
		Trigger		: std_logic;
		Stream		: integer range 0 to MaxStreams_c-1;
	end record;
	constant DaqDma2DaqSm_Resp_Size_c	: integer	:= 16+1+MaxStreamsBits_c;
	function DaqDma2DaqSm_Resp_ToStdlv( rec : DaqDma2DaqSm_Resp_t) return std_logic_vector;
	function DaqDme2DaqSm_Resp_FromStdlv( stdlv : std_logic_vector) return DaqDma2DaqSm_Resp_t;	
	
	type ToCtxStr_t is record
		Stream		: integer range 0 to MaxStreams_c-1;
		Sel			: std_logic_vector(1 downto 0);
		Rd 			: std_logic;
		WenLo		: std_logic;
		WenHi		: std_logic;
		WdatLo		: std_logic_vector(31 downto 0);
		WdatHi		: std_logic_vector(31 downto 0);
	end record;
	constant CtxStr_Sel_ScfgBufstart_c 	: std_logic_vector(1 downto 0)	:= "00";
	constant CtxStr_Sel_WinsizePtr_c	: std_logic_vector(1 downto 0)	:= "01";
	constant CtxStr_Sel_Winend_c		: std_logic_vector(1 downto 0)	:= "10";
	constant CtxStr_Sft_SCFG_RINGBUF_c		: integer						:= 0;
	constant CtxStr_Sft_SCFG_OVERWRITE_c	: integer						:= 8;
	constant CtxStr_Sft_SCFG_WINCNT_c		: integer						:= 16;
	constant CtxStr_Sft_SCFG_WINCUR_c		: integer						:= 24;	
	
	type ToCtxWin_t is record
		Stream		: integer range 0 to MaxStreams_c-1;
		Window		: integer range 0 to MaxWindows_c-1;
		Sel			: std_logic_vector(0 downto 0);
		Rd 			: std_logic;
		WenLo		: std_logic;
		WenHi		: std_logic;
		WdatLo		: std_logic_vector(31 downto 0);
		WdatHi		: std_logic_vector(31 downto 0);
	end record;
	constant CtxWin_Sel_WincntWinlast_c 	: std_logic_vector(0 downto 0)	:= "0";
	constant CtxWin_Sel_WinTs_c				: std_logic_vector(0 downto 0)	:= "1";
	
	type FromCtx_t is record
		RdatLo		: std_logic_vector(31 downto 0);
		RdatHi		: std_logic_vector(31 downto 0);
	end record;
	
	type TmemRqst_t is record
		ADD 		: std_logic_vector(23 downto 0);
		DATW		: std_logic_vector(63 downto 0);
		ENA			: std_logic;
		WE 			: std_logic_vector(7 downto 0);
		CS			: std_logic_vector(1 downto 0);
	end record;
	constant TmemRqst_init_c : TmemRqst_t	:= ((others => '0'), (others => '0'), '0', (others => '0'), (others => '0'));
	
	type TmemResp_t is record
		DATR 		: std_logic_vector(63 downto 0);
		BUSY		: std_logic;
		PIPE		: std_logic_vector(1 downto 0);
	end record;
  
end psi_ms_daq_pkg;	 

------------------------------------------------------------------------------
-- Package Body
------------------------------------------------------------------------------
package body psi_ms_daq_pkg is 
  
	-- *** DaqSm2DaqDma_Cmd ***
	function DaqSm2DaqDma_Cmd_ToStdlv( rec : DaqSm2DaqDma_Cmd_t) return std_logic_vector is
		variable stdlv : std_logic_vector(DaqSm2DaqDma_Cmd_Size_c-1 downto 0);
	begin
		stdlv(31 downto 0)			:= rec.Address;
		stdlv(47 downto 32)			:= rec.MaxSize;
		stdlv(stdlv'left downto 48)	:= std_logic_vector(to_unsigned(rec.Stream, MaxStreamsBits_c));
		return stdlv;
	end function;
	
	function DaqSm2DaqDma_Cmd_FromStdlv( stdlv : std_logic_vector) return DaqSm2DaqDma_Cmd_t is
		variable rec : DaqSm2DaqDma_Cmd_t;
	begin
		rec.Address := stdlv(31 downto 0);
		rec.MaxSize	:= stdlv(47 downto 32);
		rec.Stream	:= to_integer(unsigned(stdlv(stdlv'left downto 48)));
		return rec;
	end function;
	
	-- *** DaqDma2DaqSm_Resp ***
	function DaqDma2DaqSm_Resp_ToStdlv( rec : DaqDma2DaqSm_Resp_t) return std_logic_vector is
		variable stdlv : std_logic_vector(DaqDma2DaqSm_Resp_Size_c-1 downto 0);
	begin
		stdlv(15 downto 0)			:= rec.Size;
		stdlv(16)					:= rec.Trigger;
		stdlv(stdlv'left downto 17)	:= std_logic_vector(to_unsigned(rec.Stream, MaxStreamsBits_c));
		return stdlv;
	end function;
	
	function DaqDme2DaqSm_Resp_FromStdlv( stdlv : std_logic_vector) return DaqDma2DaqSm_Resp_t is
		variable rec : DaqDma2DaqSm_Resp_t;
	begin
		rec.Size 	:= stdlv(15 downto 0);
		rec.Trigger	:= stdlv(16);
		rec.Stream	:= to_integer(unsigned(stdlv(stdlv'left downto 17)));
		return rec;
	end function;
	
end psi_ms_daq_pkg;





