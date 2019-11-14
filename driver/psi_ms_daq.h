/*############################################################################
#  Copyright (c) 2019 by Paul Scherrer Institute, Switzerland
#  All rights reserved.
#  Authors: Oliver Bruendler
############################################################################*/

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

//*******************************************************************************
// Documentation
//*******************************************************************************
/**
* @mainpage
*
* @section ip_functionality IP Core Functionality
*
* The functionality of the IP-Core is not covered in detail here, however for using
* the driver it may beneficial to understand what the IP-Core does. To get this 
* information, refer to the <a href="../../psi_multi_stream_daq.pdf"><b>IP-Core documentation</b></a> 
*
* @section thread_safety Thread Safety
*
* The driver is not thread-safe in general. If API functions  are used in more
* than one thread (e.g. in main and IRQs), these API functions must be protected (e.g. by disabling IRQs
* while the function is executing).
*
* In the simplest case, the IP core is configured before IRQs are enabled and afterwards data is only read
* from IRQs. In this case, no protection is required.
*
* Why is the IRQ disabling not implemented in the driver itself? Well, what IRQs must be disabled depends
* on what IRQs the driver API is used from. There may also other protection schemes be used (e.g. mutexes of a RTOS).
* As a result there is not single true protection mechanism that can be implemented within the driver.
*
* @section irq_handling IRQ Handling
*
* The driver supports two ways of handling IRQs. One of them (<i>Window based IRQ</i>) is a bit more elaborate and easy to use
* but it only covers the case, that each recorded window is processed by software. This is true
* in general but the IP-core also allows special configurations where data can be overwritten
* even if it was not processed. Since the handling of IRQs becomes more specific in this case,
* a special IRQ handling scheme called <i>Stream based IRQ </i> is implemented. In this case the
* user is responsible for implementing all actions to be taken in IRQs.
*
* In all IRQ handling schemes, the user is responsible for calling the function PsiMsDaq_HandleIrq() whenever the IP core
* asserts its interrupt (level sensitive, high active).
*
* Only one IRQ handlig scheme can be used per stream (not both at the same time for the same stream).
*
* @subsection window_irq Window based IRQ
*
* In this handling scheme, the driver ensures that the user callback gets called exactly once for every window that is recorded. 
* Spurious interrupts (IRQs getting detected after the data was already processed) are suppressed by the driver. All information
* about the window which was completed is automatically passed to the user callback.
*
* This handling scheme only works if each window is really processed by the user and protected against being overwritten until
* the user acknowledged the processing. Implementationwise this means that window overwriting must be disable (config.overwrite = false)
* and that the user must acknowledge the processing of each window before new data can be recorded into it (by calling PsiMsDaq_StrWin_MarkAsFree()).
*
* Benefits of this scheme is simplicity, drawback is that the driver assumes that the user processes each window which may not 
* be the case in special cases.
*
* @subsection stream_irq Stream based IRQ
*
* In this handling scheme, the driver does only detect which stream fired an IRQ and calls the user callback function. 
* The callback function is called regardless of how many new windows were recorded. The user can do whatever processing
* of the IRQ he wants. This allows fine grained control over the IP core in special cases but it also means that the user
* is fully on his own. Therefore this option should only be used if there are good reasons for not using Window based IRQ.
*
* @section example_code Example Code
*
* This section contains a little code example to show how the driver is used.
*
* @code{.c}
* // *** Static Variables ***
* static PsiMsDaq_IpHandle daqHandle;
* static PsiMsDaq_StrHandle daqStrHandle;
* 
* // *** System ISR ***
* //ISR that is called by the OS/baremetal drivers if an IRQ is asserted
* void PsiMsDaqIrqHandler(void* arg)
* {
*    //We assume the handle to the psi_ms_daq driver is passed as callback argument
*    PsiMsDaq_IpHandle ipHandle = (PsiMsDaq_IpHandle) arg;
*    //Call IP-handling function
*    PsiMsDaq_HandleIrq(ipHandle);
* }
* 
* // *** IP User ISR ***
* void UserDaqIsr(PsiMsDaq_WinInfo_t winInfo, void* arg)
* {
*    //Invalidate cache, example code is for xilinx devices
*    Xil_DCacheInvalidateRange(<recodingLocation>, <recordingSize>);	 
*    //Get recorded data
*    PsiMsDaq_StrWin_GetDataUnwrapped(winInfo, <preTriggerSize>, <postTriggerSize>, <targetBuffer>, sizeof(<targetBuffer>));
*    //Acknowledge processing of the data
*    PsiMsDaq_StrWin_MarkAsFree(winInfo);
* }
*
* // *** Main function containing intialization ***
* int main()
* {
*    //Initialize IP
*    daqHandle = PsiMsDaq_Init(<baseAddress>, <streams>, <maxWindows>, NULL);
*    PsiMsDaq_GetStrHandle(daqHandle, 0, &daqStrHandle);
*    
*    //Configure Stream
*    PsiMsDaq_StrConfig_t cfg = {
*       .postTrigSamples = <postTriggerSamplesToRecord>,				
*       .recMode = <mode>,
*       .winAsRingbuf = true,
*       .winOverwrite = false,
*       .winCnt = <numberOfWindowsForThisStream>,
*       .bufStartAddr = <recodingLocation>,
*       .winSize = <sizePerWindow>, //in bytes
*       .streamWidthBits = <widthInBits>
*   };
*   PsiMsDaq_Str_Configure(daqStrHandle, &cfg);
*   //Register ballback
*   PsiMsDaq_Str_SetIrqCallbackWin(daqStrHandle, UserDaqIsr, NULL);
*   //Enable IRQ
*   PsiMsDaq_Str_SetIrqEnable(daqStrHandle, true);
*   //Enable recorder for stream
*   PsiMsDaq_Str_SetEnable(daqStrHandle, true);
*
*   //Wait in endless loop for IRQs comming in
*   while(1){};
* } 
* @endcode
*/

//*******************************************************************************
// Includes
//*******************************************************************************
#include <stdint.h>
#include <stdbool.h>
#include <string.h>

//*******************************************************************************
// Constants
//*******************************************************************************

/// @cond
//ACQCONF Registers - General
#define PSI_MS_DAQ_REG_GCFG					0x000
#define PSI_MS_DAQ_REG_GCFG_BIT_ENA			(1 << 0)
#define PSI_MS_DAQ_REG_GCFG_BIT_IRQENA		(1 << 8)
#define PSI_MS_DAQ_REG_GSTAT				0x004
#define PSI_MS_DAQ_REG_IRQVEC				0x010
#define PSI_MS_DAQ_REG_IRQENA				0x014
#define PSI_MS_DAQ_REG_STRENA				0x020
//ACQCONF Registers - Per Stream
#define PSI_MS_DAQ_REG_MAXLVL(n)			(0x200+0x10*(n))
#define PSI_MS_DAQ_REG_POSTTRIG(n)			(0x204+0x10*(n))
#define PSI_MS_DAQ_REG_MODE(n)				(0x208+0x10*(n))
#define PSI_MS_DAQ_REG_MODE_LSB_RECM		0
#define PSI_MS_DAQ_REG_MODE_MSB_RECM		1
#define PSI_MS_DAQ_REG_MODE_BIT_ARM			(1 << 8)
#define PSI_MS_DAQ_REG_MODE_BIT_REC			(1 << 16)
#define PSI_MS_DAQ_REG_LASTWIN(n)			(0x20C+0x10*(n))
//CTXMEM for Stream n
#define PSI_MS_DAQ_CTX_SCFG(n)				(0x1000+0x20*(n))
#define PSI_MS_DAQ_CTX_SCFG_BIT_RINGBUF		(1 << 0)
#define PSI_MS_DAQ_CTX_SCFG_BIT_OVERWRITE	(1 << 8)
#define PSI_MS_DAQ_CTX_SCFG_LSB_WINCNT		16
#define PSI_MS_DAQ_CTX_SCFG_MSB_WINCNT		20
#define PSI_MS_DAQ_CTX_SCFG_LSB_WINCUR		24
#define PSI_MS_DAQ_CTX_SCFG_MSB_WINCUR		28
#define PSI_MS_DAQ_CTX_BUFSTART(n)			(0x1004+0x20*(n))
#define PSI_MS_DAQ_CTX_WINSIZE(n)			(0x1008+0x20*(n))
#define PSI_MS_DAQ_CTX_PTR(n)				(0x100C+0x20*(n))
#define PSI_MS_DAQ_CTX_WINEND(n)			(0x1010+0x20*(n))
//WNDW Window w for Stream n
#define PSI_MS_DAQ_WIN_WINCNT(n, w, so)			(0x4000+(so)*(n)+0x10*(w))
#define PSI_MS_DAQ_WIN_WINCNT_LSB_CNT		0
#define PSI_MS_DAQ_WIN_WINCNT_MSB_CNT		30
#define PSI_MS_DAQ_WIN_WINCNT_BIT_ISTRIG	(1 << 31)
#define PSI_MS_DAQ_WIN_LAST(n, w, so)			(0x4004+(so)*(n)+0x10*(w))
#define PSI_MS_DAQ_WIN_TSLO(n, w, so)			(0x4008+(so)*(n)+0x10*(w))
#define PSI_MS_DAQ_WIN_TSHI(n, w, so)			(0x400C+(so)*(n)+0x10*(w))
/// @endcond

//*******************************************************************************
// Types
//*******************************************************************************

//*** Handles ***
typedef void* PsiMsDaq_IpHandle;	///< Handle to an instance of the driver for a complete IP
typedef void* PsiMsDaq_StrHandle;	///< Handle to a specific stream of the driver

//*** Functions for access to data of the IP core ***
/**
 * @brief	Copy used to copy data recorded to other memory locations in PsiMsDaq_StrWin_GetDataUnwrapped()
 *
 * @param	src		Source memory address (exactly the way the IP sees the address space)
 * @param	dst		Desitnation memory address (as the CPU sees it)
 * @param	n		Number of bytes to copy
 */
typedef void PsiMsDaq_DataCopy_f(void* dst, void* src, size_t n);

/**
 * @brief	Write an IP-register
 *
 * @param	addr	Address to write (byte address)
 * @param	value	Value to write
 */
typedef void PsiMsDaq_RegWrite_f(const uint32_t addr, const uint32_t value);

/**
 * @brief	Read an IP-register
 *
 * @param	addr	Address to read from (byte address)
 * @return	Read value
 */
typedef uint32_t PsiMsDaq_RegRead_f(const uint32_t addr);

/**
 * @brief	Window definition struct, used for more compact passing of common parameters
 * @note	This is not a handle and this struct is allocated on the stack, so it is only valid
 * 			until the function returns!
 */
typedef struct {
	uint8_t	winNr;					///< Window number
	PsiMsDaq_IpHandle ipHandle;		///< Handle of the IP the window belongs to
	PsiMsDaq_StrHandle strHandle;	///< Handle of the stream the window belongs to
}PsiMsDaq_WinInfo_t;

/**
 * @brief	Interrupt callback function for the window based IRQ scheme.
 * 			In this IRQ scheme, one callback function is called for each window that arrives.
 * 			This IRQ scheme is only usable if window-overwrite is disable (config.onverwrite = false).
 * 			After the window data is processed, it must be freed by calling PsiMsDaq_StrWin_MarkAsFree().
 *
 * @param	winInfo	Window information struct (allocated on stack!)
 * @param	arg		User argument list
 */
typedef void PsiMsDaqn_WinIrq_f(PsiMsDaq_WinInfo_t winInfo, void* arg);

/**
 * @brief	Interrupt callback function for the stream based IRQ scheme.
 * 			In this IRQ scheme, one callback function is called whenever the IP fires an IRQ.
 * 			This IRQ scheme is always usable but usually only required if window-overwrite is used (since the
 * 			more elaborate window based IRQ scheme is not usable in this case).
 *
 * @param	strHandle	Handle of the stream that fired the IRQ
 * @param	arg			User argument list
 */
typedef void PsiMsDaqn_StrIrq_f(PsiMsDaq_StrHandle strHandle, void* arg);

/**
 * @brief	Recorder mode (see documentation)
 */
typedef enum {
	PsiMsDaqn_RecMode_Continuous	= 0,	///< Continuous recording
	PsiMsDaqn_RecMode_TriggerMask	= 1,	///< Continuously record pre-trigger data but only detect triggers after PsiMsDaq_Str_Arm() was called
	PsiMsDaqn_RecMode_SingleShot	= 2,	///< Only record pre-trigger after PsiMsDaq_Str_Arm() was called and stop recording after one trigger
	PsiMsDaqn_RecMode_Manual		= 3 	///< Manaully control the recording by setting and clearing the arm bit
} PsiMsDaq_RecMode_t;

/**
 * @brief 	Stream configuration struct
 */
typedef struct {
	uint32_t postTrigSamples;	///< Number of post trigger samples (incl. Trigger sample)
	PsiMsDaq_RecMode_t recMode;	///< Recording mode
	bool winAsRingbuf;			///< Use individual windows as ring-buffers (true=ringbuffer mode, false=linear mode)
	bool winOverwrite;			///< If true, windows are overwritten even if they contain data. Usually set false here.
	uint8_t winCnt;				///< Number of windows to use
	uint32_t bufStartAddr;		///< Start address of the buffer for this stream
	uint32_t winSize;			///< Size of the windows
	uint16_t streamWidthBits;	///< Width od the stream in bits (must be a multiple of 8)
} PsiMsDaq_StrConfig_t;

/**
 * @brief	Memory access functions struct
 */
typedef struct {
	PsiMsDaq_DataCopy_f* dataCopy;	///< Data copy function to use
	PsiMsDaq_RegWrite_f* regWrite;	///< Register write function to use
	PsiMsDaq_RegRead_f* regRead;	///< Register read function to use
} PsiMsDaq_AccessFct_t;

/**
 * @brief Return codes
 */
typedef enum {
	PsiMsDaq_RetCode_Success	= 0,							///< No error, everything OK
	PsiMsDaq_RetCode_IllegalStrNr = -1,							///< Illegal stream number passed
	PsiMsDaq_RetCode_IllegalStrWidth = -2,						///< Illegal steram width selected
	PsiMsDaq_RetCode_StrNotDisabled = -3,						///< This function is only allowed if the stream is disbled but it was enabled
	PsiMsDaq_RetCode_IllegalWinCnt = -4,						///< Illegal window count passed
	PsiMsDaq_RetCode_IllegalWinNr = -5,							///< Illegal window number passed
	PsiMsDaq_RetCode_NoTrigInWin = -6,							///< This window does not contain a trigger as required for this function call
	PsiMsDaq_RetCode_BufferTooSmall = -7,						///< The buffer passed is too small to contain all data
	PsiMsDaq_RetCode_MorePostTrigThanConfigured = -8,			///< More post trigger data requested than configured to be recorded
	PsiMsDaq_RetCode_MorePreTrigThanAvailable = -9,				///< More pre-trigger data requested than available
	PsiMsDaq_RetCode_WinSizeMustBeMultipleOfSamples = -10,		///< Window size must be a multiple of the sample size
	PsiMsDaq_RetCode_IrqSchemesWinAndStrAreExclusive = -11		///< Only one IRQ scheme (...Str or ...Win) can be used
} PsiMsDaq_RetCode_t;

//*******************************************************************************
// IP Wide Functions
//*******************************************************************************

/**
* @brief 	Initialize the psi_ms_daq IP-Core
*
* @param 	baseAddr	Base address of the IP core to access
* @param 	maxStreams	Maximum number of streams supported by this IP (must match setting in Vivado IPI)
* @param 	maxWindows	Maximum number of windows per stream supported by this IP (must match setting in Vivado IPI)
* @param	accessFct_p	Memory access functions to use (pass NULL to use the default functions)
* @return	Driver Handle
*/
PsiMsDaq_IpHandle PsiMsDaq_Init(	const uint32_t baseAddr,
									const uint8_t maxStreams,
									const uint8_t maxWindows,
									const PsiMsDaq_AccessFct_t* const accessFct_p);


/**
 * @brief 	Get a handle to a specific stream number
 *
 * @param	ipHandle	Driver handle for the whole IP
 * @param	streamNr	Stream number to get handle for
 * @param	strHndl_p	Pointer to write the stream handle to
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_GetStrHandle(	PsiMsDaq_IpHandle ipHandle,
											const uint8_t streamNr,
											PsiMsDaq_StrHandle* const strHndl_p);


void PsiMsDaq_HandleIrq(PsiMsDaq_IpHandle inst_p);



//*******************************************************************************
// Stream Related Functions
//*******************************************************************************

/**
 * @brief	Configure stream.
 *
 * @param	strHndl		Driver handle for the stream
 * @param	config_p	Struct containing all settings
 * @return	Return Code
 *
 * @note	This function is only allwed if the corresponding stream is disabled
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_Configure(	PsiMsDaq_StrHandle strHndl,
											PsiMsDaq_StrConfig_t* const config_p);

/**
 * @brief	Enable/Disable a stream
 *
 * @param	strHndl		Driver handle for the stream
 * @param 	enable		true for enable, false for disable
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_SetEnable(	PsiMsDaq_StrHandle strHndl,
											const bool enable);

/**
 * @brief	Set window based interrupt callback function for a stream to be called whenever a new
 *          windows is recorded.
 *
 * @param	strHndl		Driver handle for the stream
 * @param	irqCb		Callback function. Pass NULL to unregister the callback.
 * @param 	arg_p		Arguments passed to the user callback function
 * @return	Return Code
 *
 * @note	Only one IRQ scheme (...Win or ...Str) can be used. Usually ...Win is
 *          used if window overwriting is disabled (config.overwrite = false) and ...Str
 *          otherwise.
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_SetIrqCallbackWin(	PsiMsDaq_StrHandle strHndl,
													PsiMsDaqn_WinIrq_f* irqCb,
													void* arg_p);

/**
 * @brief	Set stream based interrupt callback function for a stream to be called whenever a new
 *          windows is recorded. Usually PsiMsDaq_Str_SetIrqCallbackWin() is used instead of this
 *          function. So without special reasons, use PsiMsDaq_Str_SetIrqCallbackWin().
 *
 * @param	strHndl		Driver handle for the stream
 * @param	irqCb		Callback function. Pass NULL to unregister the callback.
 * @param 	arg_p		Arguments passed to the user callback function
 * @return	Return Code
 *
 * @note	Only one IRQ scheme (...Win or ...Str) can be used. Usually ...Win is
 *          used if window overwriting is disabled (config.overwrite = false) and ...Str
 *          otherwise.
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_SetIrqCallbackStr(	PsiMsDaq_StrHandle strHndl,
													PsiMsDaqn_StrIrq_f* irqCb,
													void* arg_p);

/**
 * @brief	Enable/Disable IRQ for a stream
 *
 * @param	strHndl		Driver handle for the stream
 * @param 	irqEna		true for enable, false for disable
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_SetIrqEnable(	PsiMsDaq_StrHandle strHndl,
												const bool irqEna);

/**
 * @brief	Arm the recorder for a given stream
 *
 * @param	strHndl		Driver handle for the stream
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_Arm(PsiMsDaq_StrHandle strHndl);


/**
 * @brief	Get maximum input buffer fill level
 *
 * @param	strHndl		Driver handle for the stream
 * @param	maxLvl_p	Pointer to write the level into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_GetMaxLvl(	PsiMsDaq_StrHandle strHndl,
											uint32_t* const maxLvl_p);
											
/**
 * @brief	Clear the maximum input buffer fill level
 *
 * @param	strHndl		Driver handle for the stream
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_ClrMaxLvl(	PsiMsDaq_StrHandle strHndl);

/**
 * @brief	Get the number of free windows.
 *
 * This function is implemented by looping over all windows and checking if they
 * contain any unacknowledged data. This is quite slow but the only safe approach.
 * So do not use this function excessively.
 *
 * @param	strHndl			Driver handle for the stream
 * @param	freeWindows_p	Pointer to write the number of free windows into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_GetFreeWindows(	PsiMsDaq_StrHandle strHndl,
												uint8_t* const freeWindows_p);

/**
 * @brief	Get the number of used (non-free) windows.
 *
 * This function is implemented by looping over all windows and checking if they
 * contain any unacknowledged data. This is quite slow but the only safe approach.
 * So do not use this function excessively.
 *
 * @param	strHndl			Driver handle for the stream
 * @param	usedWindows_p	Pointer to write the number of used windows into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_GetUsedWindows(	PsiMsDaq_StrHandle strHndl,
												uint8_t* const usedWindows_p);

/**
 * @brief	Get the number of windows configured to be used for a given stream
 *
 * @param	strHndl		Driver handle for the stream
 * @param	windows_p	Pointer to write the number of windows into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_GetTotalWindows(	PsiMsDaq_StrHandle strHndl,
													uint8_t* const windows_p);

/**
 * @brief	Get the IP Handle of the IP a stream belongs to
 *
 * @param	strHndl		Driver handle for the stream
 * @param 	ipHandle_p	Pointer to write the IP handle into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_GetIpHandle(	PsiMsDaq_StrHandle strHndl,
												PsiMsDaq_IpHandle* ipHandle_p);

/**
 * @brief	Get the stream number from a stream handle
 *
 * @param	strHndl		Driver handle for the stream
 * @param 	strNr_p		Pointer to write the stream number into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_GetStrNr(	PsiMsDaq_StrHandle strHndl,
											uint8_t* strNr_p);


//*******************************************************************************
// Window Related Functions
//*******************************************************************************

/**
 * @brief	Get number of valid and unacknowledged bytes in a window
 *
 * @param	winInfo			Window information
 * @param	noOfBytes_p		Pointer to write number of bytes into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetNoOfBytes(	PsiMsDaq_WinInfo_t winInfo,
													uint32_t* const noOfBytes_p);

/**
 * @brief	Get number of valid and unacknowledged samples in a window
 *
 * @param	winInfo			Window information
 * @param	noOfSamples_p	Pointer to write number of samples into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetNoOfSamples(	PsiMsDaq_WinInfo_t winInfo,
													uint32_t* const noOfSamples_p);

/**
 * @brief	Get the number of pre-trigger samples in a window (post trigger samples are known by config)
 *
 * @param	winInfo				Window information
 * @param	preTrigSamples_p	Pointer to write number of pre-trigger samples into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetPreTrigSamples(	PsiMsDaq_WinInfo_t winInfo,
														uint32_t* const preTrigSamples_p);

/**
 * @brief	Get the timestamp of a window
 *
 * @param	winInfo			Window information
 * @param	timestamp_p		Pointer to write the timestamp to
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetTimestamp(	PsiMsDaq_WinInfo_t winInfo,
													uint64_t* const timestamp_p);

/**
 * @brief	Get unwrapped copy of the data in a window.
 *
 * @param	winInfo			Window information
 * @param 	preTrigSamples	Number of pre trigger samples to read
 * @param 	postTrigSamples	Number of post trigger samples to read (including the trigger sample)
 * @param	buffer_p		Buffer to copy the data into
 * @param	bufferSize		Size of buffer_p
 * @return	Return Code
 *
 * @note	This function does not acknowledge the reading of the data. To do so, use PsiMsDaq_StrWin_MarkAsFree()
 */
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetDataUnwrapped(	PsiMsDaq_WinInfo_t winInfo,
														const uint32_t preTrigSamples,
														const uint32_t postTrigSamples,	//including trigger
														void* const buffer_p,
														const size_t bufferSize);

/**
 * @brief	Mark a window as free so it can receive new data. This function must be called after the window data is read
 *
 * @param	winInfo			Window information
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_MarkAsFree(	PsiMsDaq_WinInfo_t winInfo);

/**
 * @brief	Get the address of the last sample (not byte) written into a window
 *
 * @param	winInfo			Window information
 * @param	lastSplAddr_p	Pointer to write the address of the last sample into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_StrWin_GetLastSplAddr(	PsiMsDaq_WinInfo_t winInfo,
													uint32_t* const lastSplAddr_p);

//*******************************************************************************
// Advanced Functions (only required for close control)
//*******************************************************************************

/**
 * @brief	Check if the recorder of a given stream is currently recording data
 *
 * @param	strHndl			Driver handle for the stream
 * @param	isRecording_p	Pointer to write the result into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_IsRecording(	PsiMsDaq_StrHandle strHndl,
												bool* const isRecording_p);

/**
 * @brief	Get the currently used recorder window
 *
 * @param	strHndl			Driver handle for the stream
 * @param	currentWin_p	Pointer to write the result into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_CurrentWin(	PsiMsDaq_StrHandle strHndl,
											uint8_t* const currentWin_p);

/**
 * @brief	Get the current write pointer of the recording logic
 *
 * @param	strHndl			Driver handle for the stream
 * @param	currentPtr_p	Pointer to write the result into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_CurrentPtr(	PsiMsDaq_StrHandle strHndl,
											uint32_t* const currentPtr_p);

/**
 * @brief	Get the number of the last window that was written to memory completely
 *
 * @param	strHndl				Driver handle for the stream
 * @param	lastWrittenWin_p	Pointer to write the result into
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_Str_GetLastWrittenWin(	PsiMsDaq_StrHandle strHndl,
													uint8_t* const lastWrittenWin_p);

/**
 * @brief	Write to a register
 *
 * @param	ipHandle	Driver handle for the whole IP
 * @param	addr		Register address
 * @param	value		Value to write
 * @return	Return Code
 *
 * @note	This function should only be used for debugging purposes!
 *          Otherwise the driver might not work.
 */
PsiMsDaq_RetCode_t PsiMsDaq_RegWrite(	PsiMsDaq_IpHandle ipHandle,
										const uint32_t addr,
										const uint32_t value);

/**
 * @brief	Read a register
 *
 * @param	ipHandle	Driver handle for the whole IP
 * @param	addr		Register address
 * @param	value_p		Read value
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_RegRead(	PsiMsDaq_IpHandle ipHandle,
										const uint32_t addr,
										uint32_t* const value_p);

/**
 * @brief	Set a field in a register (RMW)
 *
 * @param	ipHandle	Driver handle for the whole IP
 * @param	addr		Register address
 * @param	lsb			Least significant bit number of the field
 * @param	msb			Most significant bit number of the field
 * @param	value		Value to write
 * @return	Return Code
 *
 * @note	This function should only be used for debugging purposes!
 *          Otherwise the driver might not work.
 */
PsiMsDaq_RetCode_t PsiMsDaq_RegSetField(	PsiMsDaq_IpHandle ipHandle,
											const uint32_t addr,
											const uint8_t lsb,
											const uint8_t msb,
											const uint32_t value);

/**
 * @brief	Read a field from a register
 *
 * @param	ipHandle	Driver handle for the whole IP
 * @param	addr		Register address
 * @param	lsb			Least significant bit number of the field
 * @param	msb			Most significant bit number of the field
 * @param	value_p		Read value
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_RegGetField(	PsiMsDaq_IpHandle ipHandle,
											const uint32_t addr,
											const uint8_t lsb,
											const uint8_t msb,
											uint32_t* const value_p);

/**
 * @brief	Set a bit in a register (RMW)
 *
 * @param	ipHandle	Driver handle for the whole IP
 * @param	addr		Register address
 * @param	mask		Bitmask
 * @param	value		Value to write
 * @return	Return Code
 *
 * @note	This function should only be used for debugging purposes!
 *          Otherwise the driver might not work.
 */
PsiMsDaq_RetCode_t PsiMsDaq_RegSetBit(	PsiMsDaq_IpHandle ipHandle,
										const uint32_t addr,
										const uint32_t mask,
										const bool value);

/**
 * @brief	Read a bit from a register
 *
 * @param	ipHandle	Driver handle for the whole IP
 * @param	addr		Register address
 * @param	mask		Bitmask
 * @param	value_p		Read value
 * @return	Return Code
 */
PsiMsDaq_RetCode_t PsiMsDaq_RegGetBit(	PsiMsDaq_IpHandle ipHandle,
										const uint32_t addr,
										const uint32_t mask,
										bool* const value_p);
										
#ifdef __cplusplus
}
#endif





