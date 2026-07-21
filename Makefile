# kbuild part: used by DKMS after select-variant.sh has copied the right
# btusb.c + headers into this directory.
ifneq ($(KERNELRELEASE),)

obj-m := btusb.o

# Downstream kernels (e.g. Ubuntu) backport HCI quirks that same-version
# vanilla kernels (e.g. Fedora) lack. The ACTIONS_SEMI block in btusb.c uses a
# couple of them; enable those set_bit() calls only when the enum actually
# exists in this kernel's headers.
_hci_h := $(srctree)/include/net/bluetooth/hci.h
ccflags-$(shell grep -qw HCI_QUIRK_BROKEN_EXT_CREATE_CONN $(_hci_h) 2>/dev/null && echo y) += -DHAVE_HCI_QUIRK_BROKEN_EXT_CREATE_CONN
ccflags-$(shell grep -qw HCI_QUIRK_BROKEN_WRITE_AUTH_PAYLOAD_TIMEOUT $(_hci_h) 2>/dev/null && echo y) += -DHAVE_HCI_QUIRK_BROKEN_WRITE_AUTH_PAYLOAD_TIMEOUT

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
