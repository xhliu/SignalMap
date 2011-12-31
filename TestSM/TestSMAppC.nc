#include "TestSM.h"

/**
 * @author Xiaohui Liu
 * @date   12/29/2011
 */

configuration TestSMAppC {}
implementation {
	components MainC, TestSMC as App, LedsC;
	components new AMSenderC(AM_RADIO_COUNT_MSG);
	components new AMReceiverC(AM_RADIO_COUNT_MSG);
	components new TimerMilliC();
	components ActiveMessageC;
	
	components SignalMapP as SM;
	components CC2420ActiveMessageC;
	components CC2420ControlC;
	//components UartLogC;
	
	App.Boot -> MainC.Boot;
	App.AMControl -> ActiveMessageC;
	App.Leds -> LedsC;
	App.MilliTimer -> TimerMilliC;

	//wire SignalMapP
	SM.SubSend -> AMSenderC;	
	SM.SubReceive -> AMReceiverC;
	SM.SubPacket -> AMSenderC;
	SM.SubAMPacket -> AMSenderC;
	SM.CC2420Packet -> CC2420ActiveMessageC;
	SM.ReadRssi -> CC2420ControlC;
	MainC.SoftwareInit -> SM;
	//SM.UartLog -> UartLogC;
	
	App.Send -> SM;	
	App.Receive -> SM;
	App.Packet -> SM;
	App.AMPacket -> AMSenderC;
	App.SignalMap -> SM;
	//App.UartLog -> UartLogC;
}


