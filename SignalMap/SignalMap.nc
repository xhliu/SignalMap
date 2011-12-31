/*
 * Xiaohui Liu (whulxh@gmail.com)
 * 12/28/2011
 */
 
interface SignalMap {
	//query the gain from the neighbor
	command uint8_t getInboundGain(am_addr_t nb);

	//query the gain to the neighbor
	command uint8_t getOutboundGain(am_addr_t nb);
}