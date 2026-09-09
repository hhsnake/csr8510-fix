# csr8510-fix

Patched Linux `btusb` driver for **fake CSR8510 A10 / CSR 4.0–5.x clone USB
Bluetooth dongles** (`0a12:0001`), packaged as DKMS so it is rebuilt
automatically on every kernel update. Kernels 5.15 – 7.1+.

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
Bluetooth: hci0: Opcode 0x0c03 failed: -110
or
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
* auto-recovers with a USB reset from init failures and command timeouts,
  including a dongle that answers nothing at all — not even the very first
  `Reset` (0x0c03) — instead of leaving the controller stuck;
* hides the Bluetooth LE support these clones advertise but do not
  implement, so desktop Bluetooth stacks stop aborting discovery on the LE
  half — see [Advertised LE that does not work](#advertised-le-that-does-not-work).

There is also a second, quieter failure mode with no error at all in the
usual places: the adapter comes up looking perfectly healthy, but the
desktop's Bluetooth panel never finds a single device, while
`bluetoothctl scan on` from a terminal finds them immediately. See
[Advertised LE that does not work](#advertised-le-that-does-not-work).

Only detected fake devices are affected — real CSR hardware is untouched.

## Install

### Ubuntu / Debian

```bash
sudo apt install git dkms linux-headers-$(uname -r)
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

### Fedora

```bash
sudo dnf install git dkms kernel-devel-$(uname -r)
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

### RED OS 7 / RED OS 8

The running kernel comes from the `kernel-lt` package, so the Fedora line above
fails: `kernel-devel-$(uname -r)` does not exist and `dnf` answers *"Совпадений
не найдено"*. Derive the name from the installed kernel instead — this form works
on any RPM distribution, whatever its kernel package is called:

```bash
K=$(rpm -qf --qf '%{NAME}' /boot/vmlinuz-$(uname -r))
sudo dnf install git dkms gcc make bc elfutils-libelf-devel bluez \
  "$K-devel-$(uname -r)"
sudo systemctl enable --now bluetooth
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

### Arch Linux

```bash
sudo pacman -S git dkms linux-headers bluez-utils
sudo systemctl enable --now bluetooth
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

### CachyOS

```bash
sudo pacman -S --needed git dkms bluez bluez-utils \
  "$(pacman -Qoq /usr/lib/modules/$(uname -r)/vmlinuz)-headers"
sudo systemctl enable --now bluetooth
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

### SteamOS

System -> Konsole. The root filesystem is read-only and ships without a
package database, so it has to be opened up first:

```bash
sudo steamos-readonly disable
sudo pacman-key --init
sudo pacman-key --populate
sudo pacman -Sy

K=$(pacman -Qoq /usr/lib/modules/$(uname -r)/vmlinuz)
sudo pacman -S --needed git dkms gcc make bc bluez bluez-utils "$K" "$K-headers"
sudo systemctl enable --now bluetooth
sudo reboot
```

After the reboot System -> Konsole:

```bash
git clone https://github.com/hhsnake/csr8510-fix.git
cd csr8510-fix
sudo ./install.sh
```

> **SteamOS updates remove the module.** The system updates by replacing
> the whole root image (A/B slots), so `/usr/lib/modules`, `/usr/src` and
> the `steamos-readonly disable` state are all reset. Re-run `install.sh`
> after each system update, or keep the built `.ko` on `/home` — that
> partition survives updates — and load it from a systemd unit.

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
| `src/5.19` | 5.19 – 6.1  | 5.19.0-50-generic (Ubuntu 22.04); 6.1.175-1.el7.3 (RED OS 7.3.7) |
| `src/6.2`  | 6.2 – 6.4   | 6.2.0-39-generic (Ubuntu 22.04) |
| `src/6.5`  | 6.5 – 6.7   | 6.5.0-45-generic (Ubuntu 22.04) |
| `src/6.8`  | 6.8 – 6.10  | 6.8.0-94, 6.8.0-134-generic (Ubuntu 22.04) |
| `src/6.11` | 6.11 – 6.13 | 6.11.0-29-generic (Ubuntu 24.04); 6.11.4-301.fc41 (Fedora 41); 6.12.92-1.red80 (RED OS 8.0.3) |
| `src/6.14` | 6.14 – 6.16 | 6.14.0-37-generic (Ubuntu 24.04); 6.16.12-valve24.5-1-neptune-616 (SteamOS 3.8.14) |
| `src/6.17` | ≥ 6.17      | 6.17.0-35-generic, 7.0.0-14-generic (Ubuntu 24.04); 6.17.10-100.fc41 (Fedora 41); 6.19.10-300.fc44, 7.1.4-200.fc44 (Fedora 44); 7.1.4-arch1-1, 6.18.39-1-lts, 7.1.4-zen1-1 (Arch), 7.1.8-1-cachyos |

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

## Advertised LE that does not work

These clones report Bluetooth LE in their local features and then fail every
LE command:

```
Bluetooth: hci0: Opcode 0x2005 failed: -32     # LE Set Random Address
Bluetooth: hci0: Opcode 0x200b failed: -32     # LE Set Scan Parameters
```

Desktop Bluetooth stacks start discovery in dual mode, so the failing LE half
aborts the whole scan and nothing is ever found — while `bluetoothctl scan on`
still works, because it falls back to BR/EDR. Nothing looks broken: `hciconfig`
shows `UP RUNNING` with a valid BD address, and the controller answers
everything else. That combination makes the fault read as a desktop bug rather
than a controller one.

The driver therefore clears the LE feature bits for these clones while the
`Read Local Features` response is still in flight, so the core brings the
controller up as BR/EDR-only and never sends an LE command. Nothing usable is
lost: the LE this hides was never functional.

Only devices matching `0a12:0001` **and** detected as fake are affected. Other
adapters in the same machine keep full LE support.

To keep the advertised LE — for instance to test a clone whose LE does work:

```bash
# /etc/modprobe.d/csr8510-fix.conf
options btusb csr_disable_le=0
```

**Alternative without this driver.** The same end state can be reached by
forcing bluetoothd to BR/EDR. Note this is a *global* setting: it disables LE
for every controller on the host, including a working built-in one.

```ini
# /etc/bluetooth/main.conf
[General]
# this clone advertises LE but does not implement it
ControllerMode = bredr
```

```bash
sudo systemctl restart bluetooth
```

## Troubleshooting

* **Nothing is found after installing, although the adapter looks fine** —
  reloading the module (which `install.sh` does at the end) rebinds the
  driver without re-enumerating the device, so the receive-issue
  workaround is skipped. The dongle then comes up `UP RUNNING` with a
  valid BD address and finds nothing. **Unplug it and plug it back in.**
  A USB reset or `systemctl restart bluetooth` is not enough: the
  controller ignores an in-band `Reset` (0x0c03).
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
