#ifndef TEST_SM_H
#define TEST_SM_H

enum {
	TX_FLAG = 0,
	RX_FLAG = 1,
	DBG_FLAG = 2,
	AM_RADIO_COUNT_MSG = 6,
};

typedef nx_struct radio_count_msg {
  nx_uint16_t counter;
} radio_count_msg_t;

#endif
