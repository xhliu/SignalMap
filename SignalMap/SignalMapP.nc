/* *
 * @ author: Xiaohui Liu (whulxh@gmail.com) 
 * @ created: 12/28/2011
 * @ description: implement signal map, which offers signal gain from and to a neighbor
 */
#include <math.h>
#include "SignalMap.h"

module SignalMapP {
	provides {
		interface SMSend as Send;
		interface Receive;
		interface Packet;
		
		interface Init;
		
		interface SignalMap;
	};
	
	uses {
		interface AMSend as SubSend;
		interface Receive as SubReceive;
		interface Packet as SubPacket;
		interface AMPacket as SubAMPacket;
		
		interface CC2420Packet;
		interface Read<uint16_t> as ReadRssi;
		
		//interface UartLog;
	};
}

implementation {

am_addr_t my_ll_addr;

// signal map
sm_entry_t signalMap[SM_SIZE];

// if there is not enough room in the packet to put all the signal map entries, in order to do round robin we need to remember which entry
// we sent in the last beacon
uint8_t prevSentIdx = 0;

// get the link estimation header in the packet
sm_header_t* getHeader(message_t* m) {
	return (sm_header_t*)call SubPacket.getPayload(m, sizeof(sm_header_t));
}

// get the signal map footer (neighbor entries) in the packet
// @param len: payload length to upper layer
sm_footer_t* getFooter(message_t* m, uint8_t len) {
	// To get a footer at offset "len", the payload must be len + sizeof large.
	return (sm_footer_t*)(len + (uint8_t *)call Packet.getPayload(m, len + sizeof(sm_footer_t)));
}

// add the header footer in the packet. Call iust before sending the packet
uint8_t addLinkEstHeaderAndFooter(message_t *msg, uint8_t len, uint8_t power_level) {
	uint8_t i, j, k;
	uint8_t maxEntries, newPrevSentIdx;
	uint8_t newlen;
	sm_header_t * ONE hdr;
	sm_footer_t * ONE footer;
	sm_entry_t *se;

	hdr = getHeader(msg);
	footer = getFooter(msg, len);	
	maxEntries = ((call SubPacket.maxPayloadLength() - len - sizeof(sm_header_t)) / sizeof(sm_footer_t));
	dbg("LI", "Max payload is: %d, maxEntries is: %d\n", call SubPacket.maxPayloadLength(), maxEntries);

	// add footer
	j = 0;
	newPrevSentIdx = 0;
	for (i = 0; i < SM_SIZE && j < maxEntries; i++) {
	  	k = (prevSentIdx + i + 1) % SM_SIZE;
	  	se = &signalMap[k];
	  	
	  	if (se->valid) {
	  		footer[j].nb = se->nb;
	  		footer[j].inbound_gain = se->inbound_gain;
	  		j++;	  		
	  		newPrevSentIdx = k;
	  	}
	}
	prevSentIdx = newPrevSentIdx;
	
	// add header
	hdr->power_level = power_level;
	hdr->footer_entry_cnts = j;
	newlen = sizeof(sm_header_t) + len + j * sizeof(sm_footer_t);
	dbg("LI", "newlen2 = %d\n", newlen);
	return newlen;
}

// find the index to the entry for neighbor ll_addr
uint8_t findIdx(am_addr_t nb) {
	uint8_t i;
	sm_entry_t *se;
	
	for (i = 0; i < SM_SIZE; i++) {
		se = &signalMap[i];
		if (se->valid && se->nb == nb)
			return i;
	}
	return i;
}

// find an empty slot in the neighbor table
uint8_t findEmptyIdx() {
	uint8_t i;
	sm_entry_t *se;
	
	for (i = 0; i < SM_SIZE; i++) {
		se = &signalMap[i];
		if (!se->valid)
			return i;
	}
	return i;
}

// initialize the signal map in the very beginning
void initSignalMap() {
	uint8_t i;
	sm_entry_t *se;
	
	for (i = 0; i < SM_SIZE; i++) {
		se = &signalMap[i];
		se->valid = FALSE;
	}
}

// update inbound gain of a neighbor
error_t updateInboundGain(am_addr_t nb, uint8_t gain) {
	sm_entry_t *se;
	uint8_t idx = findIdx(nb);
	
	if (idx < SM_SIZE) {
		se = &signalMap[idx];
		if (se->inbound_gain != INVALID_GAIN)	
			se->inbound_gain = se->inbound_gain - (se->inbound_gain >> SHIFT_BIT_3) + (gain >> SHIFT_BIT_3);
		else
			se->inbound_gain = gain;
		return SUCCESS;
	} else {
		return FAIL;
	}
}



// initialize the link estimator
command error_t Init.init() {
	dbg("LI", "Link estimator init\n");
	initSignalMap();
	my_ll_addr = call SubAMPacket.address();
	return SUCCESS;
}

/* *
 * * Interface SignalMap
 * */
// query the gain from the neighbor
// return INVALID_GAIN if neighbor is not found or neighbor found but gain unknown
command uint8_t SignalMap.getInboundGain(am_addr_t nb) {
	uint8_t idx;
	sm_entry_t *se;
	
	idx = findIdx(nb);
	if (idx < SM_SIZE) {
		se = &signalMap[idx];
		return se->inbound_gain;
	} else {
		return INVALID_GAIN;
	}
}

// query the gain to the neighbor
command uint8_t SignalMap.getOutboundGain(am_addr_t nb) {
	uint8_t idx;
	sm_entry_t *se;
	
	idx = findIdx(nb);
	if (idx < SM_SIZE) {
		se = &signalMap[idx];
		return se->outbound_gain;
	} else {
		return INVALID_GAIN;
	}
}


/* *
 * * Interface Send
 * */
// slap the header and footer before sending the message
// @param power_level: which power level is used to transmit the packet
command error_t Send.send(am_addr_t addr, message_t* msg, uint8_t len, uint8_t power_level) {
	uint8_t newlen;
	newlen = addLinkEstHeaderAndFooter(msg, len, power_level);
	dbg("LITest", "%s packet of length %hhu became %hhu\n", __FUNCTION__, len, newlen);
	return (call SubSend.send(addr, msg, newlen));
}

// done sending the message that originated by the user of this component
event void SubSend.sendDone(message_t* msg, error_t error ) {
	signal Send.sendDone(msg, error);
}

// cascade the calls down
command uint8_t Send.cancel(message_t* msg) {
	return call SubSend.cancel(msg);
}

command uint8_t Send.maxPayloadLength() {
	return call Packet.maxPayloadLength();
}

command void* Send.getPayload(message_t* msg, uint8_t len) {
	return call Packet.getPayload(msg, len);
}


/* *
 * compute gain
 */
uint8_t tx_power_level;
int8_t rssi;
am_addr_t neighbor;

// convert power level into actual power in dBm
// return -127 if conversion fails
int8_t level2Power(uint8_t power_level) {
	switch (power_level) {
		case 3: 	return -25;
		case 7: 	return -15;
		case 11:	return -10;
		case 15:	return -7;
		case 19:	return -5;
		case 23:	return -3;
		case 27:	return -1;
		case 31:	return 0;
		// should not reach here
		default:	return -127;
	}
}

// RSSI - "noise"
inline float dbmDiff(float x, float y) {
	//return 10 * log10f(powf(10, x / 10) - powf(10, y / 10));	// takes ~60 ms
	return 4.3429 * logf(expf(0.23026 * x) - expf(0.23026 * y));	// takes ~24 ms
}


event void ReadRssi.readDone(error_t result, uint16_t val) {
	uint8_t gain = 0;
	int8_t noise;
	int8_t tx_signal, rx_signal;
	
	if (SUCCESS == result) {
		noise = ((int8_t)(val - 127) & 0xFF) - (int8_t)45;
		rx_signal = dbmDiff(rssi, noise);
		tx_signal = level2Power(tx_power_level);
		if (tx_signal >= rx_signal) {
			gain = tx_signal - rx_signal;
			updateInboundGain(neighbor, gain);
		}
		//call UartLog.logTxRx(DBG_FLAG, result, neighbor, noise, val, rx_signal, tx_power_level, gain, rssi);
	}
}

// called when signal map generated packet or packets from upper layer that are wired to pass through
// signal map is received
void processReceivedMessage(message_t *msg, void *payload, uint8_t len) {
	uint8_t i, idx;
	sm_entry_t *se;
	
	//int8_t rssi;
	sm_header_t* hdr = getHeader(msg);
	sm_footer_t *footer = getFooter(msg, call Packet.payloadLength(msg));
	
	uint8_t footer_entry_cnts = hdr->footer_entry_cnts;
	am_addr_t nb = call SubAMPacket.source(msg);
	
	// read "noise floor" w/o this neighbor tx
	if (SUCCESS == call ReadRssi.read()) {
		// packet RSSI, including "noise"
		rssi = call CC2420Packet.getRssi(msg) - 45;
		tx_power_level = hdr->power_level;
		neighbor = nb;
	}
	
	// update signal map
	// if found
	//		update
	// else
	// 		if exists empty entry
	//			initialize
	idx = findIdx(nb);
	if (idx < SM_SIZE) {
		se = &signalMap[idx];
		// update outbound gain only; inbound is updated in ReadRssi.readDone
		for (i = 0; i < footer_entry_cnts; i++) {
			//contains my outbound gain
			if (footer[i].nb == my_ll_addr) {
				se->outbound_gain = footer[i].inbound_gain;
				break;
			}
		}
	} else {
		idx = findEmptyIdx();
		if (idx < SM_SIZE) {
			se = &signalMap[idx];
			// initialize
			se->nb = nb;
			se->valid = TRUE;
			se->inbound_gain = INVALID_GAIN;
			se->outbound_gain = INVALID_GAIN;
			
			// outbound
			for (i = 0; i < footer_entry_cnts; i++) {
				//contains my outbound gain
				if (footer[i].nb == my_ll_addr) {
					se->outbound_gain = footer[i].inbound_gain;
					break;
				}
			}			
		}
	}
}

// new messages are received here
// update the signal map with the header and footer in the message, then signal the user of this component
event message_t* SubReceive.receive(message_t* msg, void* payload, uint8_t len) {
	dbg("LI", "Received upper packet. Will signal up\n");
	processReceivedMessage(msg, payload, len);
	return signal Receive.receive(msg, call Packet.getPayload(msg, call Packet.payloadLength(msg)), call Packet.payloadLength(msg));
}


/* *
 * * Interface Packet
 * */
command void Packet.clear(message_t* msg) {
	call SubPacket.clear(msg);
}

// subtract the space occupied by the signal map header and footer from the incoming payload size
command uint8_t Packet.payloadLength(message_t* msg) {
	sm_header_t *hdr = getHeader(msg);
	return (call SubPacket.payloadLength(msg) - sizeof(sm_header_t) - sizeof(sm_footer_t) * hdr->footer_entry_cnts);
}

// account for the space used by header and footer while setting the payload length
command void Packet.setPayloadLength(message_t* msg, uint8_t len) {
	sm_header_t *hdr = getHeader(msg);
	call SubPacket.setPayloadLength(msg, len + sizeof(sm_header_t) + sizeof(sm_footer_t) * hdr->footer_entry_cnts);
}

command uint8_t Packet.maxPayloadLength() {
	return (call SubPacket.maxPayloadLength() - sizeof(sm_header_t));
}

// application payload pointer is iust past the link estimation header
command void* Packet.getPayload(message_t* msg, uint8_t len) {
	void* payload = call SubPacket.getPayload(msg, len + sizeof(sm_header_t));
	if (payload != NULL) {
		payload += sizeof(sm_header_t);
	}
	return payload;
}

}