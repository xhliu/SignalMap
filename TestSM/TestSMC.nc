#include "Timer.h"
#include "TestSM.h"
 
/**
 * @author Xiaohui Liu (whulxh@gmail.com)
 * @date   12/29/2011
 * @description: test signal map
 */

module TestSMC @safe() {
	uses {
		interface Leds;
		interface Boot;
		interface Timer<TMilli> as MilliTimer;
		
		interface SMSend as Send;
		interface Receive;
		interface Packet;
		interface AMPacket;
		
		interface SignalMap;
		
		interface SplitControl as AMControl;
#ifdef DEBUG		
		interface UartLog;
#endif
	}
}
implementation {

message_t packet;

bool locked;
uint16_t counter = 0;

event void Boot.booted() {
	call AMControl.start();
}

event void AMControl.startDone(error_t err) {
	if (err == SUCCESS) {
		call MilliTimer.startPeriodic(250);
	} else {
		call AMControl.start();
	}
}

event void AMControl.stopDone(error_t err) {
// do nothing
}

event void MilliTimer.fired() {
	counter++;
	
	if (locked) {
		return;
	} else {
		radio_count_msg_t* rcm = (radio_count_msg_t*)call Packet.getPayload(&packet, sizeof(radio_count_msg_t));
		if (rcm == NULL) {
			return;
		}
		rcm->counter = counter;
		// specify power
		if (call Send.send(AM_BROADCAST_ADDR, &packet, sizeof(radio_count_msg_t), 3) == SUCCESS) {
			dbg("TestSMC", "packet %hhu sent %f\n", counter, log10f(10));
			//call UartLog.logEntry(TX_FLAG, rcm->counter, 0, 0);
			locked = TRUE;
		}
	}
}

event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
	//radio_count_msg_t *m = (radio_count_msg_t *)call Packet.getPayload(msg, len);
	//am_addr_t nb = call AMPacket.source(msg);
	dbg("TestSMC", "packet %hhu received, gain <%u, %u>\n", m->counter, call SignalMap.getInboundGain(nb), call SignalMap.getOutboundGain(nb));
	//call UartLog.logEntry(RX_FLAG, nb, call SignalMap.getInboundGain(nb), call SignalMap.getOutboundGain(nb));
	return msg;
}

event void Send.sendDone(message_t* bufPtr, error_t error) {
	if (&packet == bufPtr) {
		locked = FALSE;
	}
}

}




