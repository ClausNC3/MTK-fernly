Fernly - Fernvale Reversing OS
========================================

Fernly is a simple operating system designed for use in the reverse engineering
of the Fernvale CPU.  It will likely be disposed of when the system has been
understood well enough to implement a full operating system.


Setting up cross compilation
----------------------------
### Linux

    sudo apt update
    sudu apt upgrade
    sudo apt install git make gcc gcc-arm-none-eabi
    git clone https://github.com/ClausNC3/MTK-fernly.git


Building Fernly
---------------

To compile, simply run "make".  If you're cross-compiling, set CROSS_COMPILE to
the prefix of your cross compiler.  This is very similar to how to compile for Linux.

For example:

    cd MTK-fernly
    git checkout main
    make CROSS_COMPILE=arm-none-eabi-
    sudo cp 95-fernvale-simple.rules /etc/udev/rules.d/.


Running on MT6261 devices
-------------------------

To run the Fernly shell on an MT6261 device, follow the instructions below
except that the command would be:

    build/fernly-usb-loader -s /dev/fernvale build/stage1.bin build/firmware.bin

Stage1.bin uses Fernly's own USB serial I/O code instead of calling ROM
routines, allowing Fernly to load at address 0x70000000, the bottom of
RAM. This is helpful-bordering-on-necessary because of the size of Fernly
and the smaller RAM capacity of the MT6261 compared to the 6260. The ROM
routines can't load a program this low because that area is used for their
buffer memory and program variables.

To capture the contents of device ROM, run the command:

    build/fernly-usb-loader -w /dev/fernvale build/dump-rom-usb.bin

Capture the output to a text file, edit out the diagnostic lines from
fernly-usb-loader, prepend the one line:

    data = [

and append the six lines:

    ]
    
    f = open('rom.bin','wb')
    for s in data:
      f.write(chr(int(s,16)))
    f.close()

Save it as a file with a ".py" suffix and run it as a Python script.
It will save the binary rom image as the file "rom.bin".


Running Fernly
--------------

To run, connect the target device and run the following command:

    ./build/fernly-usb-loader -s /dev/fernvale ./build/usb-loader.bin ./build/firmware.bin

This will open up /dev/fernvale, load usb-loader.bin as a stage 1 bootloader,
and then load (and jump to) firmware.bin as stage 2.  Optionally, you can add
a stage 3 file by specifying it as an additional argument.

Many 3rd-party devices enter bootloader mode only for a short window (~1s)
after being connected to USB. A device almost certainly should be "off". Some
devices require that battery is removed, while some - don't. To accommodate
such cases, there's -w (wait) option. Run fernly-usb-loader, and only
then connect a device to USB. This will allow to try various combinations
mentioned above with greater comfort (you need to disconnect and poweroff
device after each try, and restart fernly-usb-loader).

    ./build/fernly-usb-loader -w -s /dev/ttyUSB0 ./build/usb-loader.bin ./build/firmware.bin

Linux Notes
-----------

Since Fernvale is based on a Mediatek chip, ModemManager will, by default,
try to treat it as a modem and make it available for network connections.
This is undesirable.

To work around this problem, create a udev rule under /etc/udev/rules.d/
called 98-fernvale.rules with the following contents:

    SUBSYSTEM=="tty", ATTRS{idVendor}=="0e8d",\
        ATTRS{idProduct}=="0003",\
        MODE="0660", SYMLINK+="fernvale"

    ACTION=="add|change", SUBSYSTEM=="usb",\
        ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="0e8d",\
        ATTRS{idProduct}=="0003",\
        ENV{ID_MM_DEVICE_IGNORE}="1"

OSX Notes
---------
The default OSX CDC matching seems to miss the Fernvale board. Use [fernvale-osx-codeless](https://github.com/jacobrosenthal/fernvale-osx-codeless) to get a com port.


SPI and Flashrom
----------------

Fernly includes a special 'flashrom' mode that allows for direct communication
with the flashrom program to manipulate the onboard SPI.  The protocol is
binary, and can be entered by issuing the following command:

    spi flashrom

Fernly will respond with a binary 0x05, indicating it is ready.

The format of the protocol is very simple.  The host writes the number of bytes
to write, then the number of bytes to read, and then writes the data to send
to the flash chip.  It then reads the requested number of bytes.  For
example, to send a 2-byte command '0xfe 0xfa' followed by a 3-byte response,
write the following data to the serial port:

| 02 03 fe fa |

Then read three bytes of data from the serial port.

A maximum of 255 bytes may be transmitted and received at one time, though
in practice these numbers may be smaller.

To exit 'spi flashrom' mode and return to fernly, read/write zero bytes.
That is, send the following packet:

| 00 00 |

See ROM-BACKUP.txt for user-level instructions how to backup/restore
FlashROM of your device.

Licensing
---------

Fernly is licensed under the BSD 2-clause license (see LICENSE).

Previous versions of fernly linked against division libraries taken from U-Boot,
which were licensed under GPL-2.  These files have been removed.

Instead, we supply a version of libgcc.a.  This file was extracted from a
standard gcc toolchain, specifically:

    https://code.google.com/p/yus-repo/downloads/detail?name=arm-none-eabi-4.6-armv5.tar.gz

It has not been modified, and its distribution here should be covered under
the "runtime exception".


Memory Map
----------

| 0x00000000 | 0x0fffffff | 0x0fffffff | PSRAM map, repeated and mirrored at 0x00800000 offsets               |
| ---------- | ---------- | ---------- | ----------------------------------- |
| 0x10000000 | 0x1fffffff | 0x0fffffff | Memory-mapped SPI chip              |
| ?????????? | ?????????? | ?????????? | ??????????????????????????????????? |
| 0x70000000 | 0x7000cfff |     0xcfff | On-chip SRAM (maybe cache?)         |
| ?????????? | ?????????? | ?????????? | ??????????????????????????????????? |
| 0x80000000 | 0x80000008 |       0x08 | Config block (chip version, etc.)   |
| 0x82000000 | 0x82d00000 | ?????????? | Modem system stuff                  |
| 0x83000000 | 0xa3090000 | ?????????? | Modem peripheral stuff              |
| 0x83020000 |            |            | TDMA unit                           |
| 0x83050000 |            |            | Frame Check Sequence unit           |
| 0x83060000 |            |            | GPRS cipher unit                    |
| 0x83070000 |            |            | Baseband serial interface           |
| 0x83080000 |            |            | Baseband parallel interface         |
| 0xa0000000 | 0xa0000008 |       0x08 | Config block (mirror?)              |
| 0xa0010000 | ?????????? | ?????????? | Power, config block                 |
| 0xa0020000 | 0xa0020e10 |     0x0e10 | GPIO control block                  |
| 0xa0030000 | 0xa0030040 |       0x40 | WDT block                           |
|            |            |            |   - 0x08 -> WDT register (?)        |
|            |            |            |   - 0x18 -> Boot src (?)            |
| 0xa0030800 | ?????????? | ?????????? | ????????????????????????????        |
| 0xa0040000 | ?????????? | ?????????? | ??????????????????????????????????? |
| 0xa0050000 | ?????????? | ?????????? | External memory block               |
| 0xa0060000 | ?????????? | ?????????? | IRQ Controller block                |
| 0xa0070000 | ========== | ========== | DMA Controller block                |
| 0xa0080000 | 0xa008005c |       0x5c | UART1 block                         |
| 0xa0090000 | 0xa009005c |       0x5c | UART2 block                         |
| 0xa00a0000 | ?????????? | ?????????? | ??????????????????????????????????? |
| 0xa00b0000 | 0xa00b006c |       0x6c | Bluetooth interface block           |
| 0xa00c0000 | 0xa00c002c |       0x2c | General purpose timer block         |
| 0xa00d0000 | 0xa00d0024 |       0x24 | Keypad scanner block                |
| 0xa00e0000 | 0xa00e0008 |       0x0c | PWM1 block                          |
| 0xa00f0000 | 0xa00f00b0 |       0xb0 | SIM1 interface block                |
| 0xa0100000 | 0xa01000b0 |       0xb0 | SIM2 interface block                |
| 0xa0110000 | ?????????? | ?????????? | SEJ/CHE (Security engine) block     |
| 0xa0120000 | 0xa0120074 |       0x74 | I2C block                           |
| 0xa0130000 | 0xa0130098 |       0x98 | SD1 block (MSDC)                    |
| 0xa0140000 | ?????????? | ?????????? | Serial flash block                  |
| 0xa0150000 | ?????????? | ?????????? | ?? MAYBE also SPI ????????????????? |
| 0xa0160000 | ?????????? | ?????????? | Die-to-die master interface         |
| 0xa0170000 | ?????????? | ?????????? | Analogue chip controller block      |
| 0xa0180000 | ?????????? | ?????????? | TOPSM block                         |
| 0xa0190000 | 0xa0190310 |       0x58 | HIF (DMA?) interface block          |
| 0xa01b0000 | 0xa01b0058 |       0x58 | NLI (arbiter) interface block       |
| 0xa01c0000 | ?????????? | ?????????? | EFuse block                         |
| 0xa01e0000 | ?????????? | ?????????? | SPI block                           |
| 0xa01f0000 | 0xa01f0060 |       0x60 | OS timer block                      |
| 0xa0210000 | ?????????? | ?????????? | More analog bits                    |
| 0xa0220000 | ?????????? | ?????????? | MBist block                         |
| 0xa0240000 | ?????????? | ?????????? | NAND flash block                    |
| 0xa0260000 | 0xa0260058 |       0x58 | FSPI (internal FM radio) block      |
| 0xa0270000 | 0xa0270098 |       0x98 | SD2 block                           |
| 0xa0400000 | ?????????? | ?????????? | IMGDMA block                        |
| 0xa0410000 | ?????????? | ?????????? | IDP RESZ CR2                        |
| 0xa0420000 | 0xa04201d8 |     0x01d8 | CAM interface block                 |
| 0xa0430000 | ?????????? | ?????????? | Serial camera block                 |
| 0xa0440000 | ?????????? | ?????????? | 2D graphics block                   |
| 0xa0450000 | ?????????? | ?????????? | LCD interface block                 |
| 0xa0460000 | ?????????? | ?????????? | Multimedia system BIST block        |
| 0xa0470000 | ?????????? | ?????????? | Multimedia colour config block      |
| 0xa0480000 | ?????????? | ?????????? | Multimedia system config block      |
| 0xa0500000 | ?????????? | ?????????? | ARM configuration block             |
| 0xa0510000 | ?????????? | ?????????? | Boot configuration block            |
| 0xa0520000 | ?????????? | ?????????? | Code decompression engine block     |
| 0xa0530000 | ?????????? | ?????????? | Level 1 cache block                 |
| 0xa0540000 | ?????????? | ?????????? | MPU config block                    |
| 0xa0700000 | ?????????? | ?????????? | Power management block. Write (val & 0xfe0f &#124; 0x140) to 0xa0700230 to power off. |
| 0xa0710000 | 0xa0710078 |       0x78 | RTC block                           |
| 0xa0720000 | ?????????? | ?????????? | Analogue baseband config block      |
| 0xa0730000 | 0xa0730100 |     ?????? | Analogue die config                 |
| 0xa0730104 | 0xa073104c |     ?????? | GPIO mode / pull control blocks     |
| 0xa074000c | 0xa0740014 |       0x0c | PWM2 block                          |
| 0xa0740018 | 0xa0740020 |       0x0c | PWM3 block                          |
| 0xa0750000 | 0xa075005c |       0x5c | ADCDET block                        |
| 0xa0760000 | ?????????? | ?????????? | Analogue IRQ controller             |
| 0xa0790000 | 0xa07900d8 |       0xd8 | ADC block                           |
| 0xa07a0000 | ?????????? | ?????????? | Analogue Die-to-die block           |
| 0xa0900000 | 0xa0900240 | ?????????? | USB block                           |
| 0xa0910000 | ?????????? | ?????????? | ??????????????????????????????????? |
| 0xa0920000 | ?????????? | ?????????? | AHB DMA block                       |
| 0xa3300000 | 0xa33a0000 | ?????????? | Bluetooth things                    |
| 0xfff00000 | 0xffffffff |   0x100000 | Boot ROM, mirrored each 64K (its real size) |

About the difference of -A and -D
---------------------------------
* The MT2502A offers the full MT2502 feature set supported by built-in 32Mb RAM and external Flash for ROM memory.
* The MT2502D excludes support for GSM/GPRS (doesn’t contain a 2G Modem) supported by built-in 32Mb RAM and 32Mb ROM.
* The MT6260D does not support external serial flash
* The MT6260A does support external serial flash

Various cores/dies that might be in a MTK6260
---------------------------------------------

|Chip 	|Capability| 	Relevance for 6260| 	Notes|
|-------|----------|----------------------|----------|
|MT1308 	|CD/DVD-ROM platform|||
|MT1309 	|CD/DVD-ROM platform|||
|MT1805 	|Internal slimline DVD-RW platform|||
|MT1807 	|External DVD-RW platform|||
|MT1879 	|SATA DVD-RW platform|||
|MT1939 	|Rewritable Blu-ray drive platform|||
|MT2501 	|SoC used for smartwatches, 108Mhz|||
|MT2502 	|ARM7EJ SOC, GSM/GPRS (2G), BT4.0, FM-Radio, Camera, USB1.1, SD 	|this chip is labled MT2502, but it reports itself as being a MT6261, so either they are very similar or identical, core of LinkIt||
|MT2503 	|? , GPS 	|It is using MT6261, but it also has GPS||
|MT2601 	|SoC for wearable, compatible with 6630|||
|MT3318 	|GPS|||
|MT3326 	|GPS|||
|MT3328 	|GPS|||
|MT3329 	|GPS|||
|MT3332 	|GPS+GLONASS+Beidou 	|part of LinkIt||
|MT3333 	|GPS+Beidou|||
|MT3336 	|GPS+QZSS+SBA|||
|MT3337 	|GPS|||
|MT3339 	|GPS, QZSS, SBAS|||
|MT5112 	|Digital terrestrial and cable TV demodulator|||
|MT5135 	|Digital terrestrial and cable TV demodulator for Europe|||
|MT5175 	|Digital terrestrial and cable TV demodulator for China|||
|MT5131 	|OFDM-Demod IC|||
|MT5192 	|MATV|||
|MT5193 	|MATV|||
|MT5301 	|Low cost China ATV|||
|MT5366 	|60Hz cost efficiency TV|||
|MT5389 	|60Hz Basic 3D/connected DTV|||
|MT5395 	|120Hz iPTV & 3D TV|||
|MT5396 	|120Hz Smart & Advanced 3D TV|||
|MT5398 	|Smart 3D TV platform|||
|MT5505 	|Smart 3D TV platform|||
|MT5580 	|Connected 3D TV platform|||
|MT5901 	|WLAN, based on Inprocomm|||
|MT5911 	|WLAN, based on Inprocomm|||
|MT5912 	|WLAN, based on Inprocomm|||
|MT5921 	|WLAN chip 	|unfortunately not part of 6260||
|MT5931 	|802.11n platform (2.4GHz) 	|part of LinkIt||
|MT6100 	|Analog die which is part of MT6260 and MT6250|||
|MT6129 	|RF Transceiver|||
|MT6139 	|RF Transceiver for GSM/DCS/PCS|||
|MT6140 	|RF chip that is used in phones together with the MT6235 	|possibly merged into 6260||
|MT6162 	|RF Transceiver (Othello)|||
|MT6163 	|RF Transceiver (Othello)|||
|MT6169 	|RF Transceiver LWG+LTG|||
|MT6188C 	|FM Radio chip that is used in phones together with MT6235 	|possibly merged into 6260||
|MT6205 	|GSM Baseband Processor|||
|MT6217 	|GSM/GPRS Baseband Processor|||
|MT6218 	|GSM/GPRS Baseband Processor|||
|MT6219 	|GSM/GPRS Baseband Processor 	|seems to be a predecessor of 6260 	|read the datasheet!|
|MT6223 	|GSM/GPRS Baseband Processor 	|seems to be a predecessor of 6260 	|read the datasheet!|
|MT6225 	|GSM/GPRS Baseband Processor|||
|MT6226 	|GSM/GPRS Baseband Processor|||
|MT6227 	|GSM/GPRS Baseband Processor|||
|MT6228 	|GSM/GPRS Baseband Processor 	|seems to be a predecessor of 6260 	|read the datasheet!|
|MT6235 	|GSM/GPRS/EDGE SoC for FeaturePhones, ARM9 Up to 208 MHz|||
|MT6236 	|GSM/GPRS/EDGE platform for FeaturePhones|||
|MT6238 	|GSM/GPRS/EDGE platform for FeaturePhones|||
|MT6239 	|GSM/GPRS/EDGE platform for FeaturePhones|||
|MT6250 	|GSM/GPRS/EDGE-RX for FeaturePhones 	|requires 6139(RF) and 6138(Power), which are possibly included in 6260||
|MT6251 	|SoC with FM-Radio 	|||
|MT6252 	|Quad-band GSM/GPRS/EDGE platform for FeaturePhones|||
|MT6253 	|GSM/GPRS platform|||
|MT6255 	|Quad-band GSM/GPRS/EDGE platform|||
|MT6256 	|SoC for FeaturePhone|||
|MT6260 	|SoC with an ARM core, Bluetooth, LCD, GSM+GPRS, Camera, FM-Radio, ... 	|definitely used||
|MT6261 	|SoC with an ARM core, Bluetooth, LCD, GSM+GPRS, Camera, FM-Radio, ... 	|possible upgrade for fernvale?||
|MT6268 	|GSM/GPRS/EDGE/W-CDMA platform|||
|MT6275 	|ARMv7 SoC, GPS, BT4.0 	|||
|MT6276 	|SoC BT+FM-Radio|||
|MT6276M 	|HSPA modem|||
|MT6280 	|3G/HSPA+ thin modem|||
|MT6290 	|Modem processor LTE R9 (4G), DC-HSPA+, W-CDMA, TD-SCDMA, EDGE and GSM/GPRS|||
|MT6301 	|Touchscreen controller|||
|MT6305B 	|GSM Power Management System|||
|MT6306 	|SIM-Card multiplexer, allows to switch between 4 simcards|||
|MT6318 	|PMIC - Power management IC|||
|MT6320 	|PMIC - Power management IC|||
|MT6322 	|PMIC - Power management IC|||
|MT6323 	|PMIC - Power management for phones 	|possibly merged into 6260, was also reused in MT6572||
|MT6326 	|PMIC|||
|MT6329 	|PMIC - Power management 	|possibly merged into 6260 	|might explain the POWERKEY handling|
|MT6331 	|PMIC - Power management|||
|MT6332 	|PMIC - Power management|||
|MT6333 	|PMIC - Power management|||
|MT6513 	|SoC - Android|||
|MT6515 	|SoC - Android|||
|MT6516 	|SoC - GSM/GPRS/EDGE platform|||
|MT6517 	|SoC - 1GHz, Single core, GPS|||
|MT6571 	|SoC - Entrylevel|||
|MT6572 	|SoC - Dual-core platform with HSPA+|||
|MT6573 	|SoC - used in Alcatel 918D|||
|MT6575 	|SoC for Android, similar to MT6573, compatible to MT6162|||
|MT6577 	|SoC - 1GHz for Android|||
|MT6582 	|SoC - ARM-A7 Quadcore, WLAN, Bluetooth, GPS, HSPA+|||
|MT6588 	|SoC - Quadcore, pin-compatible to 6582+6591+6592|||
|MT6589 	|SoC - ARM-A7 Quadcore, WLAN, Bluetooth 4.0, GPS, UMTS8|||
|MT6591 	|SoC - ARM Hexacore, 1.5 GHz|||
|MT6592 	|SoC - Octacore, HSPA+|||
|MT6595 	|SoC - Octacore, LTE|||
|MT6601 	|Bluetooth, was used together with MT6235 	|possibly merged into 6260||
|MT6605 	|NFC|||
|MT6612 	|Bluetooth 2.1+EDR|||
|MT6620 	|Bluetooth, GPS, 802.11n (2.4/5GHz), GNSS, Bluetooth and FM platform|||
|MT6622 	|Bluetooth 2.1+EDR|||
|MT6626 	|Bluetooth 2.1+EDR with FM|||
|MT6627 	|GPS, compatible with MAX2659|||
|MT6628 	|GPS|||
|MT6628Q 	|802.11n (2.4/5GHz), GNSS, Bluetooth and FM platform|||
|MT6628T 	|802.11n (2.4/5GHz), Bluetooth and FM platform|||
|MT6630 	|GPS 	|2014||
|MT6921 	|Variant of MT6236|||
|MT6922 	|Variant of MT6255|||
|MT6732 	|64-bit quad-core LTE platform|||
|MT6735 	|64-bit quad-core World Mode LTE platform|||
|MT6752 	|64-bit octa-core LTE platform|||
|MT6753 	|64-bit octa-core LTE platform|||
|MT6755 	|64-bit octa-core LTE platform 	|Smartphone Oppo F1 Plus||
|MT6795 	|64bit LTE Octa-core platform|||
|MT6797W 	|64bit LTE Octa-core platform (Helio X10 ?)|||
|MT6856 	|802.11ac/802.11n network processor for access points and routers|||
|MT6921 	|SoC|||
|MT7502 	|ADSL AFE+Modem+Ethernet|||
|MT7505 	|MIPS SoC ADSL AFE+Modem+Ethernet|||
|MT7510 	|MIPS SoC DSL|||
|MT7511 	|MIPS SoC DSL|||
|MT7530 	|Gigabit Ethernet Switch|||
|MT7550 	|xDSL analog front end (AFE)|||
|MT7555 	|Line Driver (LD) for VDSL2/ADSL2+|||
|MT7592 	|Wifi|||
|MT7600 	|Wifi|||
|MT7601 	|Wifi chip, based on Realtek|||
|MT7602 	|Wifi chip|||
|MT7603 	|Wifi|||
|MT7606 	|Wifi|||
|MT7610 	|Wifi chip, based on Realtek|||
|MT7612 	|Wifi chip, based on Realtek|||
|MT7615 	|ARM SoC with Wifi|||
|MT7620 	|MIPS SoC, Wifi bgn, PCIe, SDHC, USB|||
|MT7621 	|MIPS SoC, GbE, RGMII, PCIe, USB3|||
|MT7623 	|ARM Quadcore SoC|||
|MT7628 	|MIPS SoC|||
|MT7630 	|Bluetooth based on RT3290|||
|MT7632 	|Wifi+Bluetooth|||
|MT7636 	|Wifi+Bluetooth|||
|MT7650 	|802.11a/ac 1T1R platform (2.4/5GHz) with Bluetooth 4.0|||
|MT7662 	|Wifi abgn+ac + Bluetooth4|||
|MT7681 	|WiFi b/g/n SoC with GPIO, PWM, UART|||
|MT7688 	|MIPS SoC with WiFi|||
|MT8123 	|Tablet dual-core platform|||
|MT8125 	|Tablet Quad-core platform with HSPA+|||
|MT8127 	|Quad-core platform with HEVC video playback|||
|MT8135 	|Quad-core platform with ARM big.LITTLE architecture|||
|MT8303 	|DVB related chip, comes in TQFP 256|||
|MT8307 	|Cost-effective soundbar platform|||
|MT8317 	|ARM SoC|||
|MT8377 	|Dual-core platform with HSPA|||
|MT8382 	|Quad-core dual-SIM HSPA platform|||
|MT8389 	|Tablet Quad-core platform with HSPA+|||
|MT8392 	|Octa-core HSPA+ tablet platform|||
|MT8502 	|Soundbar platform 	|this could be included in 6260||
|MT8506 	|Premium Connected Audio platform|||
|MT8507 	|Connected audio platform|||
|MT8732 	|64-bit octa-core LTE tablet platform|||
|MT8752 	|64-bit octa-core LTE tablet platform|||
|RT3883 	|802.11n WLAN from Realtek|||
|RT6856 	|802.11ac WLAN from Realtek|||
|RT9362 	|LCM backlight driver, was used in phones together with the MT6235 	|was possibly merged into 6260||
|W25Q32 	|Winbond Flash, 4MB 	|part of MT6260DA||
