/*############################################################################
#  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
#  All rights reserved.
#  Authors: Oliver Bruendler
############################################################################*/

#include "psi_ms_daq.h"
#include <stdlib.h>

//*******************************************************************************
// Types
//*******************************************************************************
typedef struct {
	uint8_t	nr;
	bool isConfigured;
	uint8_t widthBytes;
	uint8_t windows;
	int8_t lastProcWin;
	uint32_t irqCalledWin;
	PsiMsDaqn_WinIrq_f* irqFctWin;
	PsiMsDaqn_StrIrq_f* irqFctStr;
	void* irqArg;
	PsiMsDaq_IpHandle ipHandle;
	uint32_t bufStart;
	uint32_t winSize;
	uint32_t postTrig;
}PsiMsDaq_StrInst_t;


typedef struct {
	uint32_t baseAddr;
	uint8_t maxStreams;
	uint8_t maxWindows;
	uint32_t strAddrOffs;
	PsiMsDaq_StrInst_t* streams;
	PsiMsDaq_DataCopy_f* memcpyFct;
	PsiMsDaq_RegWrite_f* regWrFct;
	PsiMsDaq_RegRead_f* regRdFct;
} PsiMsDaq_Inst_t;

//*******************************************************************************
// Macros
//*******************************************************************************
#define SAFE_CALL(fctCall) { \
		PsiMsDaq_RetCode_t r = fctCall; \
		if (PsiMsDaq_RetCode_Success != r) {return r;}}

//*******************************************************************************
// Private Functions
//*******************************************************************************
void PsiMsDaq_DataCopy_Standard(void* dst, void* src, size_t n)
{
	memcpy(dst, src, n);
}

void PsiMsDaq_RegWrite_Standard(const uint32_t addr, const uint32_t value)
{
	volatile uint32_t* addr_p = (volatile uint32_t *)(size_t)addr;
	*addr_p = value;
}

uint32_t PsiMsDaq_RegRead_Standard(const uint32_t addr)
{
	volatile uint32_t* addr_p = (volatile uint32_t *)(size_t)addr;
	return *addr_p;
}

PsiMsDaq_RetCode_t CheckStrDisabled(	PsiMsDaq_IpHandle ipHandle,
										const uint8_t streamNr)
{
	uint32_t strEna;
	SAFE_CALL(PsiMsDaq_RegRead(ipHandle, PSI_MS_DAQ_REG_STRENA, &strEna));
	if (strEna & (1 << streamNr)) {
		return PsiMsDaq_RetCode_StrNotDisabled;
	}
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t CheckStrNr(	PsiMsDaq_IpHandle ipHandle,
								const uint8_t streamNr)
{
	PsiMsDaq_Inst_t* inst_p = (PsiMsDaq_Inst_t*) ipHandle;
	if (streamNr >= inst_p->maxStreams) {
		return PsiMsDaq_RetCode_IllegalStrNr;
	}
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t CheckWinNr(	PsiMsDaq_StrHandle strHandle,
								const uint8_t winNr)
{
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHandle;
	if (winNr >= inst_p->windows) {
		return PsiMsDaq_RetCode_IllegalWinNr;
	}
	return PsiMsDaq_RetCode_Success;
}

uint32_t Log2(const uint32_t x)
{
	uint32_t v = x;
	uint32_t r = 0;
	while (v > 1) {
		v = v/2;
		r = r+1;
	}
	return r;
}

uint32_t Log2Ceil(const uint32_t x)
{
	if (0 == x) {
		return 0;
	}
	return Log2(x);
}

uint32_t Pow(const uint32_t x, const uint32_t y)
{
	uint32_t r = x;
	for (uint32_t i = 1; i < y; i ++) {
		r *= x;
	}
	return r;
}



//*******************************************************************************
// IP Wide Functions
//*******************************************************************************
PsiMsDaq_IpHandle PsiMsDaq_Init(	const uint32_t baseAddr,
									const uint8_t maxStreams,
									const uint8_t maxWindows,
									const PsiMsDaq_AccessFct_t* const accessFct_p)
{
	//Initialization and allocation
	PsiMsDaq_Inst_t* inst_p = (PsiMsDaq_Inst_t*) malloc(sizeof(PsiMsDaq_Inst_t));
	inst_p->baseAddr = baseAddr;
	inst_p->streams = (PsiMsDaq_StrInst_t*) malloc(sizeof(PsiMsDaq_StrInst_t)*maxStreams);
	inst_p->maxWindows = maxWindows;
	inst_p->maxStreams = maxStreams;
	inst_p->strAddrOffs = Pow(2, Log2Ceil(maxWindows))*0x10;
	//Standard access functions
	if (NULL == accessFct_p) {
		inst_p->memcpyFct = PsiMsDaq_DataCopy_Standard;
		inst_p->regWrFct = PsiMsDaq_RegWrite_Standard;
		inst_p->regRdFct = PsiMsDaq_RegRead_Standard;
	}
	else {
		inst_p->memcpyFct = accessFct_p->dataCopy;
		inst_p->regWrFct = accessFct_p->regWrite;
		inst_p->regRdFct = accessFct_p->regRead;
	}
	//Disable complete IP (all streams, IRQs, etc.)
	PsiMsDaq_RegWrite(inst_p, PSI_MS_DAQ_REG_GCFG, 0);
	PsiMsDaq_RegWrite(inst_p, PSI_MS_DAQ_REG_STRENA, 0);
	PsiMsDaq_RegWrite(inst_p, PSI_MS_DAQ_REG_IRQENA, 0);
	PsiMsDaq_RegWrite(inst_p, PSI_MS_DAQ_REG_IRQVEC, 0xFFFFFFFF);
	//Reset values for all streams
	for (int str = 0; str < maxStreams; str++) {
		//Clear stream maximum level
		PsiMsDaq_RegWrite(inst_p, PSI_MS_DAQ_REG_MAXLVL(str), 0);
		//Mark windows as free
		for (int win = 0; win < maxWindows; win++) {
			PsiMsDaq_RegWrite(inst_p, PSI_MS_DAQ_WIN_WINCNT(str, win, inst_p->strAddrOffs), 0);
		}
		//Initialize data structure
		inst_p->streams[str].nr = str;
		inst_p->streams[str].isConfigured = false;
		inst_p->streams[str].irqFctWin = NULL;
		inst_p->streams[str].irqFctStr = NULL;
		inst_p->streams[str].irqArg = NULL;
		inst_p->streams[str].ipHandle = (PsiMsDaq_IpHandle) inst_p;
		inst_p->streams[str].lastProcWin = -1;
		inst_p->streams[str].irqCalledWin = 0;
	}
	//Set general Enables (never touched later)
	PsiMsDaq_RegWrite(inst_p, PSI_MS_DAQ_REG_GCFG, PSI_MS_DAQ_REG_GCFG_BIT_ENA | PSI_MS_DAQ_REG_GCFG_BIT_IRQENA);
	return (PsiMsDaq_IpHandle) inst_p;
}

PsiMsDaq_RetCode_t PsiMsDaq_GetStrHandle(	PsiMsDaq_IpHandle ipHandle,
											const uint8_t streamNr,
											PsiMsDaq_StrHandle* const strHndl_p)
{
	//Pointer Cast
	PsiMsDaq_Inst_t* inst_p = (PsiMsDaq_Inst_t*) ipHandle;
	//Checks
	SAFE_CALL(CheckStrNr(ipHandle, streamNr));
	//Implementation
	*strHndl_p = (PsiMsDaq_StrHandle) &inst_p->streams[streamNr];
	//Done
	return PsiMsDaq_RetCode_Success;
}

void PsiMsDaq_HandleIrq(PsiMsDaq_IpHandle ipHandle)
{
	//Pointer Cast
	PsiMsDaq_Inst_t* inst_p = (PsiMsDaq_Inst_t*) ipHandle;

	//Check which stream caused the IRQ and acknowledge it
	uint32_t strWithIrq;
	PsiMsDaq_RegRead(ipHandle, PSI_MS_DAQ_REG_IRQVEC, &strWithIrq);
	PsiMsDaq_RegWrite(ipHandle, PSI_MS_DAQ_REG_IRQVEC, strWithIrq);

	//Call handler for all streams with new windows pending
	for (int str = 0; str < inst_p->maxStreams; str++) {
		//Get stream handle
		PsiMsDaq_StrInst_t* str_p = &inst_p->streams[str];
		PsiMsDaq_StrHandle strHandle = (PsiMsDaq_StrHandle) str_p;

		//Continue if stream has no IRQ pending
		if (0 == (strWithIrq & (1 << str))){
			continue;
		}

		//IRQ Handling Type: Stream
		if (NULL != str_p->irqFctStr) {
			str_p->irqFctStr(strHandle, str_p->irqArg);
		}


		//IRQ Handling Type: Window
		if (NULL != str_p->irqFctWin) {

			uint8_t lastWin;
			PsiMsDaq_Str_GetLastWrittenWin(strHandle, &lastWin);

			//Call user callbacks for new windows
			int8_t win = str_p->lastProcWin;
			do {
				//Check if new data arrived and clear stream IRQ
				PsiMsDaq_RegWrite(ipHandle, PSI_MS_DAQ_REG_IRQVEC, (1 << str));
				PsiMsDaq_Str_GetLastWrittenWin(strHandle, &lastWin);
				//Choose next window
				win = (win + 1) % str_p->windows;
				//Stopp if this window was not yet marked as free by the user
				if (str_p->irqCalledWin & (1 << win)) {
					break;
				}
				str_p->irqCalledWin |= (1 << win);
				//Call user IRQ
				PsiMsDaq_WinInfo_t winInfo;
				winInfo.ipHandle = ipHandle;
				winInfo.strHandle = strHandle;
				winInfo.winNr = win;
				if (str_p->irqFctWin != NULL) {
					str_p->irqFctWin(winInfo, str_p->irqArg);
				}
				//Update State
				str_p->lastProcWin = win;
			} while (win != lastWin);
		}
	}


}


//*******************************************************************************
// Stream Related Functions
//*******************************************************************************
PsiMsDaq_RetCode_t PsiMsDaq_Str_Configure(	PsiMsDaq_StrHandle strHndl,
											PsiMsDaq_StrConfig_t* const config_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	PsiMsDaq_IpHandle ipHandle = inst_p->ipHandle;
	PsiMsDaq_Inst_t* ipInst_p = (PsiMsDaq_Inst_t*) ipHandle;
	const uint8_t strNr = inst_p->nr;
	//Checks
	if (0 != (config_p->streamWidthBits % 8)){
		return PsiMsDaq_RetCode_IllegalStrWidth;
	}
	if (config_p->winCnt > ipInst_p->maxWindows) {
		return PsiMsDaq_RetCode_IllegalWinCnt;
	}
	if (0 != (config_p->winSize % (config_p->streamWidthBits/8))) {
		return PsiMsDaq_RetCode_WinSizeMustBeMultipleOfSamples;
	}
	SAFE_CALL(CheckStrDisabled(ipHandle, strNr));
	//Set register values
	SAFE_CALL(PsiMsDaq_RegWrite(ipHandle,
								PSI_MS_DAQ_REG_POSTTRIG(strNr),
								config_p->postTrigSamples));
	SAFE_CALL(PsiMsDaq_RegSetField(	ipHandle,
									PSI_MS_DAQ_REG_MODE(strNr),
									PSI_MS_DAQ_REG_MODE_LSB_RECM,
									PSI_MS_DAQ_REG_MODE_MSB_RECM,
									config_p->recMode));
	SAFE_CALL(PsiMsDaq_RegSetBit( 	ipHandle,
									PSI_MS_DAQ_CTX_SCFG(strNr),
									PSI_MS_DAQ_CTX_SCFG_BIT_RINGBUF,
									config_p->winAsRingbuf));
	SAFE_CALL(PsiMsDaq_RegSetBit( 	ipHandle,
									PSI_MS_DAQ_CTX_SCFG(strNr),
									PSI_MS_DAQ_CTX_SCFG_BIT_OVERWRITE,
									config_p->winOverwrite));
	SAFE_CALL(PsiMsDaq_RegWrite(ipHandle,
								PSI_MS_DAQ_CTX_BUFSTART(strNr),
								config_p->bufStartAddr));
	SAFE_CALL(PsiMsDaq_RegWrite(ipHandle,
								PSI_MS_DAQ_CTX_WINSIZE(strNr),
								config_p->winSize));
	SAFE_CALL(PsiMsDaq_RegSetField(	ipHandle,
									PSI_MS_DAQ_CTX_SCFG(strNr),
									PSI_MS_DAQ_CTX_SCFG_LSB_WINCNT,
									PSI_MS_DAQ_CTX_SCFG_MSB_WINCNT,
									config_p->winCnt-1));
	//Set data structure values
	inst_p->widthBytes = config_p->streamWidthBits/8;
	inst_p->isConfigured = true;
	inst_p->windows = config_p->winCnt;
	inst_p->bufStart = config_p->bufStartAddr;
	inst_p->postTrig = config_p->postTrigSamples;
	inst_p->winSize = config_p->winSize;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_SetEnable(	PsiMsDaq_StrHandle strHndl,
											const bool enable)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	PsiMsDaq_IpHandle ipHandle = inst_p->ipHandle;
	const uint8_t strNr = inst_p->nr;
	//Implementation
	const uint32_t msk = (1 << strNr);
	SAFE_CALL(PsiMsDaq_RegSetBit(ipHandle, PSI_MS_DAQ_REG_STRENA, msk, enable));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_SetIrqCallbackWin(	PsiMsDaq_StrHandle strHndl,
													PsiMsDaqn_WinIrq_f* irqCb,
													void* arg_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Checks
	if (NULL != inst_p->irqFctStr) {
		return PsiMsDaq_RetCode_IrqSchemesWinAndStrAreExclusive;
	}
	//Implementation
	inst_p->irqFctWin = irqCb;
	inst_p->irqArg = arg_p;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_SetIrqCallbackStr(	PsiMsDaq_StrHandle strHndl,
													PsiMsDaqn_StrIrq_f* irqCb,
													void* arg_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Checks
	if (NULL != inst_p->irqFctWin) {
		return PsiMsDaq_RetCode_IrqSchemesWinAndStrAreExclusive;
	}
	//Implementation
	inst_p->irqFctStr = irqCb;
	inst_p->irqArg = arg_p;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_SetIrqEnable(	PsiMsDaq_StrHandle strHndl,
												const bool irqEna)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	PsiMsDaq_IpHandle ipHandle = inst_p->ipHandle;
	const uint8_t strNr = inst_p->nr;
	//Implementation
	const uint32_t msk = (1 << strNr);
	SAFE_CALL(PsiMsDaq_RegSetBit(ipHandle, PSI_MS_DAQ_REG_IRQENA, msk, irqEna));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_Arm(PsiMsDaq_StrHandle strHndl)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	PsiMsDaq_IpHandle ipHandle = inst_p->ipHandle;
	const uint8_t strNr = inst_p->nr;
	//Implementation
	SAFE_CALL(PsiMsDaq_RegSetBit(ipHandle, PSI_MS_DAQ_REG_MODE(strNr), PSI_MS_DAQ_REG_MODE_BIT_ARM, true));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_GetMaxLvl(	PsiMsDaq_StrHandle strHndl,
											uint32_t* const maxLvl_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	PsiMsDaq_IpHandle ipHandle = inst_p->ipHandle;
	const uint8_t strNr = inst_p->nr;
	//Implementation
	SAFE_CALL(PsiMsDaq_RegRead(ipHandle, PSI_MS_DAQ_REG_MAXLVL(strNr), maxLvl_p));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_GetFreeWindows(	PsiMsDaq_StrHandle strHndl,
												uint8_t* const freeWindows_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	PsiMsDaq_IpHandle ipHandle = inst_p->ipHandle;
	PsiMsDaq_Inst_t* ip_p = (PsiMsDaq_Inst_t*) ipHandle;
	const uint8_t strNr = inst_p->nr;
	//Implementation (looping is not very efficient but safe and simple)
	uint8_t freeWin = 0;
	for (int win = inst_p->windows-1; win > 0; win--) {
		uint32_t cnt;
		SAFE_CALL(PsiMsDaq_RegGetField(	ipHandle,
										PSI_MS_DAQ_WIN_WINCNT(strNr, win, ip_p->strAddrOffs),
										PSI_MS_DAQ_WIN_WINCNT_LSB_CNT,
										PSI_MS_DAQ_WIN_WINCNT_MSB_CNT,
										&cnt))
		if (0 == cnt) {
			freeWin++;
		}
	}
	*freeWindows_p = freeWin;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_GetUsedWindows(	PsiMsDaq_StrHandle strHndl,
												uint8_t* const usedWindows_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	uint8_t freeWin;
	SAFE_CALL(PsiMsDaq_Str_GetFreeWindows(strHndl, &freeWin));
	*usedWindows_p = inst_p->windows-freeWin;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_GetTotalWindows(	PsiMsDaq_StrHandle strHndl,
													uint8_t* const windows_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	*windows_p = inst_p->windows;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_GetIpHandle(	PsiMsDaq_StrHandle strHndl,
												PsiMsDaq_IpHandle* ipHandle_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	*ipHandle_p = inst_p->ipHandle;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_GetStrNr(	PsiMsDaq_StrHandle strHndl,
											uint8_t* strNr_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	*strNr_p = inst_p->nr;
	//Done
	return PsiMsDaq_RetCode_Success;
}

//*******************************************************************************
// Window Related Functions
//*******************************************************************************
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetNoOfBytes(	PsiMsDaq_WinInfo_t winInfo,
													uint32_t* const noOfBytes_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* str_p = (PsiMsDaq_StrInst_t*) winInfo.strHandle;
	//Implementation
	uint32_t samples;
	SAFE_CALL(PsiMsDaq_StrWin_GetNoOfSamples(winInfo, &samples));
	*noOfBytes_p = samples*str_p->widthBytes;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetNoOfSamples(	PsiMsDaq_WinInfo_t winInfo,
													uint32_t* const noOfSamples_p)
{
	//Pointer Case
	PsiMsDaq_Inst_t* ip_p = (PsiMsDaq_Inst_t*)winInfo.ipHandle;
	PsiMsDaq_StrInst_t* str_p = (PsiMsDaq_StrInst_t*)winInfo.strHandle;
	//Setup
	uint8_t strNr;
	SAFE_CALL(PsiMsDaq_Str_GetStrNr(winInfo.strHandle, &strNr));
	//Checks
	SAFE_CALL(CheckStrNr(winInfo.ipHandle, strNr))
	SAFE_CALL(CheckWinNr(winInfo.strHandle, winInfo.winNr))
	//Implementation
	uint32_t noOfBytes;
	SAFE_CALL(PsiMsDaq_RegGetField(	winInfo.ipHandle,
									PSI_MS_DAQ_WIN_WINCNT(strNr, winInfo.winNr, ip_p->strAddrOffs),
									PSI_MS_DAQ_WIN_WINCNT_LSB_CNT,
									PSI_MS_DAQ_WIN_WINCNT_MSB_CNT,
									&noOfBytes));
	*noOfSamples_p = noOfBytes / str_p->widthBytes;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetPreTrigSamples(	PsiMsDaq_WinInfo_t winInfo,
														uint32_t* const preTrigSamples_p)
{
	//Setup
	PsiMsDaq_StrInst_t* str_p = (PsiMsDaq_StrInst_t*) winInfo.strHandle;
	PsiMsDaq_Inst_t* ip_p = (PsiMsDaq_Inst_t*)winInfo.ipHandle;
	//Checks
	bool containsTrig;
	SAFE_CALL(PsiMsDaq_RegGetBit(	winInfo.ipHandle,
									PSI_MS_DAQ_WIN_WINCNT(str_p->nr, winInfo.winNr, ip_p->strAddrOffs),
									PSI_MS_DAQ_WIN_WINCNT_BIT_ISTRIG,
									&containsTrig))
	if (!containsTrig) {
		return PsiMsDaq_RetCode_NoTrigInWin;
	}
	//Implementation
	uint32_t samples;
	SAFE_CALL(PsiMsDaq_StrWin_GetNoOfSamples(winInfo, &samples));
	*preTrigSamples_p = samples-str_p->postTrig;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetTimestamp(	PsiMsDaq_WinInfo_t winInfo,
													uint64_t* const timestamp_p)
{
	//Setup
	uint8_t strNr;
	SAFE_CALL(PsiMsDaq_Str_GetStrNr(winInfo.strHandle, &strNr));
	PsiMsDaq_Inst_t* ip_p = (PsiMsDaq_Inst_t*)winInfo.ipHandle;
	//Checks
	bool containsTrig;
	SAFE_CALL(PsiMsDaq_RegGetBit(	winInfo.ipHandle,
									PSI_MS_DAQ_WIN_WINCNT(strNr, winInfo.winNr, ip_p->strAddrOffs),
									PSI_MS_DAQ_WIN_WINCNT_BIT_ISTRIG,
									&containsTrig))
	if (!containsTrig) {
		return PsiMsDaq_RetCode_NoTrigInWin;
	}
	//Implementation
	uint32_t tsLo;
	uint32_t tsHi;
	SAFE_CALL(PsiMsDaq_RegRead(winInfo.ipHandle, PSI_MS_DAQ_WIN_TSLO(strNr, winInfo.winNr, ip_p->strAddrOffs), &tsLo));
	SAFE_CALL(PsiMsDaq_RegRead(winInfo.ipHandle, PSI_MS_DAQ_WIN_TSHI(strNr, winInfo.winNr, ip_p->strAddrOffs), &tsHi));
	*timestamp_p = (((uint64_t)tsHi) << 32) + tsLo;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetDataUnwrapped(	PsiMsDaq_WinInfo_t winInfo,
														const uint32_t preTrigSamples,
														const uint32_t postTrigSamples,	//including trigger
														void* const buffer_p,
														const size_t bufferSize)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* str_p = (PsiMsDaq_StrInst_t*) winInfo.strHandle;
	PsiMsDaq_Inst_t* ip_p = (PsiMsDaq_Inst_t*) winInfo.ipHandle;

	//Setup
	const uint32_t samples = preTrigSamples+postTrigSamples;
	const uint32_t bytes = samples*str_p->widthBytes;
	uint32_t preTrig;
	SAFE_CALL(PsiMsDaq_StrWin_GetPreTrigSamples(winInfo, &preTrig));

	//Checks
	if (bufferSize < bytes) {
		return PsiMsDaq_RetCode_BufferTooSmall;
	}
	if (postTrigSamples > str_p->postTrig) {
		return PsiMsDaq_RetCode_MorePostTrigThanConfigured;
	}
	if (preTrigSamples > preTrig) {
		return PsiMsDaq_RetCode_MorePreTrigThanAvailable;
	}

	//Calculate window addresses
	const uint32_t winStart = str_p->bufStart + str_p->winSize*winInfo.winNr;
	const uint32_t winLast = winStart + str_p->winSize - 1;

	//Calculate address of last byte and trigger byte (with regard to wrapping)
	uint32_t lastSplAddr;
	SAFE_CALL(PsiMsDaq_StrWin_GetLastSplAddr(winInfo, &lastSplAddr));
	uint32_t trigByteAddr = lastSplAddr - (str_p->postTrig+1)*str_p->widthBytes;	//+1 because trigger is not included in postTrigger
	if (trigByteAddr < winStart) {
		trigByteAddr += str_p->winSize;
	}
	uint32_t lastByteAddr = trigByteAddr + postTrigSamples*str_p->widthBytes + str_p->widthBytes-1;
	if (lastByteAddr > winLast) {
		lastByteAddr -= str_p->winSize;
	}


	//If all bytes are written without wrap, copy directly
	const uint32_t firstByteLinear = lastByteAddr - bytes + 1;
	if (firstByteLinear >= winStart) {
		ip_p->memcpyFct(buffer_p, (void*)(size_t)firstByteLinear, bytes);
	}
	//Do unwrapping else
	else {
		const uint32_t secondChunkSize = lastByteAddr - winStart + 1;
		const uint32_t firstChunkSize = bytes-secondChunkSize;
		const uint32_t firstChunkStartAddr = winLast-firstChunkSize+1;
		ip_p->memcpyFct(buffer_p, (void*)(size_t)firstChunkStartAddr, firstChunkSize);
		ip_p->memcpyFct(buffer_p+firstChunkSize, (void*)(size_t)winStart, secondChunkSize);
	}

	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_StrWin_MarkAsFree(	PsiMsDaq_WinInfo_t winInfo)
{
	//Setup
	uint8_t strNr;
	SAFE_CALL(PsiMsDaq_Str_GetStrNr(winInfo.strHandle, &strNr));
	PsiMsDaq_Inst_t* ip_p = (PsiMsDaq_Inst_t*) winInfo.ipHandle;
	PsiMsDaq_StrInst_t* str_p = (PsiMsDaq_StrInst_t*) winInfo.strHandle;
	//Implementation
	str_p->irqCalledWin &= ~(1 << winInfo.winNr);
	SAFE_CALL(PsiMsDaq_RegWrite(winInfo.ipHandle, PSI_MS_DAQ_WIN_WINCNT(strNr, winInfo.winNr, ip_p->strAddrOffs), 0));
	//Done
	return PsiMsDaq_RetCode_Success;
}


PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetLastSplAddr(	PsiMsDaq_WinInfo_t winInfo,
													uint32_t* const lastSplAddr_p)
{
	//Setup
	uint8_t strNr;
	SAFE_CALL(PsiMsDaq_Str_GetStrNr(winInfo.strHandle, &strNr));
	PsiMsDaq_Inst_t* ip_p = (PsiMsDaq_Inst_t*) winInfo.ipHandle;
	//Implementation
	SAFE_CALL(PsiMsDaq_RegRead(winInfo.ipHandle, PSI_MS_DAQ_WIN_LAST(strNr, winInfo.winNr, ip_p->strAddrOffs), lastSplAddr_p));
	//Done
	return PsiMsDaq_RetCode_Success;
}



//*******************************************************************************
// Advanced Functions (only required for close control)
//*******************************************************************************

PsiMsDaq_RetCode_t PsiMsDaq_Str_IsRecording(	PsiMsDaq_StrHandle strHndl,
												bool* const isRecording_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	SAFE_CALL(PsiMsDaq_RegGetBit(	inst_p->ipHandle,
									PSI_MS_DAQ_REG_MODE(inst_p->nr),
									PSI_MS_DAQ_REG_MODE_BIT_REC,
									isRecording_p));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_CurrentWin(	PsiMsDaq_StrHandle strHndl,
											uint8_t* const currentWin_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	uint32_t field;
	SAFE_CALL(PsiMsDaq_RegGetField(	inst_p->ipHandle,
									PSI_MS_DAQ_CTX_SCFG(inst_p->nr),
									PSI_MS_DAQ_CTX_SCFG_LSB_WINCUR,
									PSI_MS_DAQ_CTX_SCFG_MSB_WINCUR,
									&field))
	*currentWin_p = field;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_CurrentPtr(	PsiMsDaq_StrHandle strHndl,
											uint32_t* const currentPtr_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	SAFE_CALL(PsiMsDaq_RegRead(inst_p->ipHandle, PSI_MS_DAQ_CTX_PTR(inst_p->nr), currentPtr_p));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_Str_GetLastWrittenWin(	PsiMsDaq_StrHandle strHndl,
													uint8_t* const lastWrittenWin_p)
{
	//Pointer Cast
	PsiMsDaq_StrInst_t* inst_p = (PsiMsDaq_StrInst_t*) strHndl;
	//Implementation
	uint32_t reg;
	SAFE_CALL(PsiMsDaq_RegRead(inst_p->ipHandle, PSI_MS_DAQ_REG_LASTWIN(inst_p->nr), &reg));
	*lastWrittenWin_p = reg;
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_RegWrite(	PsiMsDaq_IpHandle ipHandle,
										const uint32_t addr,
										const uint32_t value)
{
	//Cast pointer
	PsiMsDaq_Inst_t* inst_p = (PsiMsDaq_Inst_t*)ipHandle;
	//Execute access
	inst_p->regWrFct(inst_p->baseAddr+addr, value);
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_RegRead(	PsiMsDaq_IpHandle ipHandle,
										const uint32_t addr,
										uint32_t* const value_p)
{
	//Cast pointer
	PsiMsDaq_Inst_t* inst_p = (PsiMsDaq_Inst_t*)ipHandle;
	//Execute access
	*value_p = inst_p->regRdFct(inst_p->baseAddr+addr);
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_RegSetField(	PsiMsDaq_IpHandle ipHandle,
											const uint32_t addr,
											const uint8_t lsb,
											const uint8_t msb,
											const uint32_t value)
{
	//Execute access
	uint32_t reg;
	uint32_t msk = (1 << (msb+1))-1;
	uint32_t mskSft = msk << lsb;
	uint32_t valSft = ((value & msk) << lsb);
	SAFE_CALL(PsiMsDaq_RegRead(ipHandle, addr, &reg));
	reg &= ~mskSft;
	reg |= valSft;
	SAFE_CALL(PsiMsDaq_RegWrite(ipHandle, addr, reg));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_RegGetField(	PsiMsDaq_IpHandle ipHandle,
											const uint32_t addr,
											const uint8_t lsb,
											const uint8_t msb,
											uint32_t* const value_p)
{
	//Execute access
	uint32_t reg;
	uint32_t msk = (1 << (msb+1))-1;
	SAFE_CALL(PsiMsDaq_RegRead(ipHandle, addr, &reg));
	*value_p = (reg >> lsb) & msk;
	//Done
	return PsiMsDaq_RetCode_Success;
}



PsiMsDaq_RetCode_t PsiMsDaq_RegSetBit(	PsiMsDaq_IpHandle ipHandle,
											const uint32_t addr,
											const uint32_t mask,
											const bool value)
{
	//Execute access
	uint32_t reg;
	SAFE_CALL(PsiMsDaq_RegRead(ipHandle, addr, &reg));
	reg &= ~mask;
	if (value) {
		reg |= mask;
	}
	SAFE_CALL(PsiMsDaq_RegWrite(ipHandle, addr, reg));
	//Done
	return PsiMsDaq_RetCode_Success;
}

PsiMsDaq_RetCode_t PsiMsDaq_RegGetBit(	PsiMsDaq_IpHandle ipHandle,
										const uint32_t addr,
										const uint32_t mask,
										bool* const value_p)
{
	//Execute access
	uint32_t reg;
	SAFE_CALL(PsiMsDaq_RegRead(ipHandle, addr, &reg));
	*value_p = (0 != (reg & mask));
	//Done
	return PsiMsDaq_RetCode_Success;
}
