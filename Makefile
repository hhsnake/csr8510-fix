# kbuild part: used by DKMS after select-variant.sh has copied the right
# btusb.c + headers into this directory.
ifneq ($(KERNELRELEASE),)

obj-m := btusb.o

# Distro kernels (e.g. Ubuntu HWE) backport later HCI API changes into an older
# release, so a symbol's presence can't be inferred from the kernel version.
# Probe the target kernel's headers and let src/*/btusb.c #ifdef on the result.
# HCI_PRIMARY (with dev_type/HCI_AMP) was removed in 6.10; HCI_QUIRK_VALID_LE_STATES
# was inverted to HCI_QUIRK_BROKEN_LE_STATES in 6.11.
_hci_h := $(srctree)/include/net/bluetooth/hci.h
ccflags-$(shell grep -qw HCI_PRIMARY $(_hci_h) 2>/dev/null && echo y) += -DHAVE_HCI_PRIMARY
ccflags-$(shell grep -qw HCI_QUIRK_VALID_LE_STATES $(_hci_h) 2>/dev/null && echo y) += -DHAVE_HCI_QUIRK_VALID_LE_STATES

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
