COMPONENT=TestSMAppC

SMDIR = ../SignalMap
#UTILDIR = $(TOSROOT)/../Programming/TinyOS/Utils

CFLAGS += -I$(SMDIR) \
		-I$(UTILDIR)
CFLAGS += -DCC2420_DEF_RFPOWER=3        #neteye 3, motelab 23, Indriya 11
CFLAGS += -DTOSH_DATA_LENGTH=114
CFLAGS += -DCC2420_DEF_CHANNEL=26


include $(MAKERULES)

