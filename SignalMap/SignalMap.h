/*
 * @ author: Xiaohui Liu (whulxh@gmail.com)
 * 
 * @ created: 12/28/2011
 */
 
#ifndef SIGNAL_MAP_H
#define SIGNAL_MAP_H

enum {
	SM_SIZE = 20,
	INVALID_GAIN = 255,
	SHIFT_BIT_3 = 3,
};

//signal map header containing tx power level
typedef nx_struct {
	nx_uint8_t power_level;
	// number of entries in the footer
	nx_uint8_t footer_entry_cnts;
} sm_header_t;

//signal map footer containing neighbor and inbound gain, used to compute outbound gain
typedef nx_struct {
	nx_am_addr_t nb;
	//power gain to a neighbor
	nx_uint8_t inbound_gain;
} sm_footer_t;

//signal map entry
typedef struct {
	am_addr_t nb;
	bool valid;
	uint8_t inbound_gain;
	uint8_t outbound_gain;
} sm_entry_t;

#endif