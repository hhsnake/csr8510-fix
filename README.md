# csr8510-fix

Patched Linux `btusb` driver for **fake CSR8510 A10 / CSR 4.0–5.x clone USB
Bluetooth dongles** (`0a12:0001`), packaged as DKMS so it is rebuilt
automatically on every kernel update. Kernels 5.15 – 7.0+.

## Is this your device?

You are in the right place if `lsusb` / `dmesg` shows:

```
ID 0a12:0001 Cambridge Silicon Radio, Ltd Bluetooth Dongle (HCI mode)
usb: Product: CSR8510 A10, idVendor=0a12, idProduct=0001, bcdDevice=25.20
Bluetooth: hci0: CSR: Setting up dongle with HCI ver=9 rev=3120
Bluetooth: hci0: LMP ver=9 subver=22bb; manufacturer=10
```

and Bluetooth fails with any of:

```
Bluetooth: hci0: CSR: Local version failed (-32)
Bluetooth: hci0: command 0x1001 tx timeout
Bluetooth: hci0: Opcode 0x0c25 failed: -110
Can't init device hci0: Connection timed out (110)
```

These are cheap clone chips (Barrot 8041a02 and similar, usually sold as a
"Bluetooth 5.0/5.1/5.3 USB adapter" — e.g. ORICO BTA-403, Орбита OT-PCB13
and countless no-name AliExpress dongles) that pretend to be a real CSR
chip but return malformed HCI responses. Known fake `bcdDevice` values:
`0x0100, 0x0134, 0x1915, 0x2520, 0x7558, 0x8891`. The stock kernel already
detects them (*"Unbranded CSR clone detected"*) but its workarounds are not
enough for this hardware. This patch additionally:

* pads the undersized HCI Command Complete responses (`Read Voice Setting`
  0x0c25, `Read Transmit Power Level` 0x0c2d, `Read Page Scan Type` 0x0c46)
  so HCI init survives;
* fixes the fragile USB runtime-PM suspend workaround;
* auto-recovers from init failures and command timeouts with a USB reset
  instead of leaving the controller stuck.

Only detected fake devices are affected — real CSR hardware is untouched.

## Install

### Ubuntu / Debian

```bash
sudo apt install dkms linux-headers-$(uname -r)
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

### Fedora

```bash
sudo dnf install dkms kernel-devel-$(uname -r)
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

The module is installed to `/lib/modules/<ver>/updates/dkms/` (takes
precedence over the stock module, nothing in the kernel is overwritten)
and rebuilt automatically by DKMS on every kernel update.

Verify:

```bash
dkms status csr8510-fix                # -> installed
modinfo -F filename btusb            # -> .../updates/dkms/btusb.ko(.zst)
journalctl -kf | grep -iE 'bluetooth|csr'   # then plug in the dongle
```

Uninstall (returns to the stock driver):

```bash
sudo ./uninstall.sh
```

## Supported kernels

| Variant | Used for kernels | Tested on |
|---|---|---|
| `src/5.15` | < 5.19      | 5.15.0-185-generic (Ubuntu 22.04) |
| `src/5.19` | 5.19 – 6.1  | 5.19.0-50-generic (Ubuntu 22.04) |
| `src/6.2`  | 6.2 – 6.4   | 6.2.0-39-generic (Ubuntu 22.04) |
| `src/6.5`  | 6.5 – 6.7   | 6.5.0-45-generic (Ubuntu 22.04) |
| `src/6.8`  | 6.8 – 6.10  | 6.8.0-94, 6.8.0-134-generic (Ubuntu 22.04) |
| `src/6.11` | 6.11 – 6.13 | 6.11.0-29-generic (Ubuntu 24.04); 6.11.4-301.fc41 (Fedora 41) |
| `src/6.14` | 6.14 – 6.16 | 6.14.0-37-generic (Ubuntu 24.04) |
| `src/6.17` | ≥ 6.17      | 6.17.0-35-generic, 7.0.0-14-generic (Ubuntu 24.04); 6.17.10-100.fc41 (Fedora 41); 6.19.10-300.fc44, 7.1.4-200.fc44 (Fedora 44) |

The right variant is picked automatically at build time. Untested versions
in between get the nearest variant and usually build fine; if the build
fails, check `/var/lib/dkms/csr8510-fix/<version>/build/make.log` and open
an issue.

## Building your own kernel instead?

Apply the matching diff from [`patches/`](patches/):

```bash
cd linux-<version>
patch -p1 < .../patches/csr8510-fix-6.17.patch
```

## Troubleshooting

* **Secure Boot**: the module is signed automatically if DKMS MOK signing
  is set up; otherwise enroll a key (`man mokutil`) or disable Secure Boot.
* **Two Bluetooth adapters** — a built-in controller may interfere;
  disable it for testing: `rfkill list`, then `rfkill block <id>`.
* **`module verification failed ... tainting kernel`** in dmesg is harmless
  on machines without Secure Boot — it only means the module is unsigned.

## Questions & feedback

Bug reports, questions and suggestions are welcome in
[GitHub Issues](https://github.com/hhsnake/csr8510-fix/issues).
When reporting, please attach the output of `uname -r`,
`lsusb | grep 0a12` and `journalctl -k | grep -iE 'bluetooth|csr'`.

## License

GPL-2.0 (same as the Linux kernel — `btusb.c` is derived from kernel
sources). See [LICENSE](LICENSE).
