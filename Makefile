# kbuild part: used by DKMS after select-variant.sh has copied the right
# btusb.c + headers into this directory.
ifneq ($(KERNELRELEASE),)

obj-m := btusb.o

# Convenience part: "make" in the repo root builds the module for the
# running kernel without DKMS (for a quick one-off test).
else

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	./select-variant.sh
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
	rm -f btusb.c btbcm.h btintel.h btmrvl_drv.h btmrvl_sdio.h btmtk.h \
	      btqca.h btrtl.h h4_recv.h hci_uart.h

endif
