#!/bin/bash
# -*- coding: utf-8 -*-

# assembles the firmware package of the Raspberry Pi kernels
# (firmware.rasp.<version>.tar.xz) from pinned and sha256 verified
# inputs, the result is reproducible for the same tar and xz versions
# usage: [VERSION=20260928] [WORK=dir] [OUT=dir] ./firmware.rasp.20260928.sh

VERSION=${VERSION-20260928}
MTIME=${MTIME-${VERSION:0:4}-${VERSION:4:2}-${VERSION:6:2} 00:00:00Z}
WORK=${WORK-$(pwd)/firmware.rasp.build}
OUT=${OUT-$(pwd)}
FILE=${FILE-firmware.rasp.$VERSION.tar.xz}

# pinned versions of the inputs, these must match the checksums
# of the inputs.sha256 list below (update both at the same time)
BRCM_VERSION=20260519-1~bpo13+1+rpt1
BLUEZ_VERSION=1.2-13+rpt2
REGDB_VERSION=2026.09.03
LFW_VERSION=20260916
LFW_COMMIT=ab23307cfe7f9366c819025ca3e4778299bc2db2
BLUEZ_COMMIT=cdf61dc691a49ff01a124752bd04194907f0f9cd
PATCHES_COMMIT=f16bb3715ed5745b7fc352cf5c58245f5ed141f9

RPI_URL=http://archive.raspberrypi.com/debian/pool/main
REGDB_URL=https://mirrors.edge.kernel.org/pub/software/network/wireless-regdb
LFW_URL=https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/LICENSES
BLUEZ_URL=https://raw.githubusercontent.com/RPi-Distro/bluez-firmware/$BLUEZ_COMMIT
PATCHES_URL=https://github.com/hivesolutions/patches/raw/$PATCHES_COMMIT

SEPARATOR="--------------------------------------------------------------------------"

set -e +h

export LC_ALL=C TZ=UTC
umask 022

# retrieves the given url into the provided file name, in case the
# file already exists (previous run) the download is skipped as the
# checksum verification below guarantees its integrity
get() {
    if [ -e "$2" ]; then return 0; fi
    wget --tries=3 --timeout=20 -O "$2.part" "$1"
    mv "$2.part" "$2"
}

# writes the header of a new section of the manifest with the drivers
# that load its files and the input from which they are taken
section() {
    printf "\n%s\n\nDriver: %s\nSource: %s\n\n" "$SEPARATOR" "$1" "$2" >> $TREE/WHENCE
}

# copies the given files from the (extracted) input directory into
# the firmware tree and lists each one of them in the manifest
files() {
    base=$1 && shift
    for file in "$@"; do
        mkdir -p $TREE/$(dirname $file)
        cp $base/$file $TREE/$file
        echo "File: $file" >> $TREE/WHENCE
    done
}

# creates the given symbolic links (pairs of link and target, with the
# target relative to the link) and lists each one of them in the manifest
links() {
    while [ "$#" -gt "1" ]; do
        ln -s $2 $TREE/$1
        echo "Link: $1 -> $2" >> $TREE/WHENCE
        shift 2
    done
}

# closes the current section of the manifest with the licence files
# (under LICENSES/) that cover all of its files and links
licence() {
    names="LICENSES/$1" && shift
    for name in "$@"; do names="$names and LICENSES/$name"; done
    printf "\nLicence: Redistributable. See %s for details.\n" "$names" >> $TREE/WHENCE
}

rm -rf $WORK/firmware $WORK/brcm $WORK/bluez $WORK/regdb $WORK/old
mkdir -p $WORK/sources $WORK/firmware $WORK/brcm $WORK/bluez $WORK/regdb $WORK/old $OUT
pushd $WORK/sources > /dev/null

get $RPI_URL/f/firmware-nonfree/firmware-brcm80211_${BRCM_VERSION}_all.deb firmware-brcm80211_${BRCM_VERSION}_all.deb
get $RPI_URL/b/bluez-firmware/bluez-firmware_${BLUEZ_VERSION}_all.deb bluez-firmware_${BLUEZ_VERSION}_all.deb
get $REGDB_URL/wireless-regdb-$REGDB_VERSION.tar.xz wireless-regdb-$REGDB_VERSION.tar.xz
get $PATCHES_URL/firmware/firmware.rasp.tar.xz firmware.rasp.2018.tar.xz
get $BLUEZ_URL/debian/firmware/synaptics/LICENSE.synaptics LICENSE.synaptics
for name in LICENCE.cypress LICENCE.broadcom_bcm43xx LICENCE.atheros_firmware LICENSE.QualcommAtheros_ar3k\
    LICENCE.open-ath9k-htc-firmware LICENCE.Abilis LICENCE.xc4000 LICENCE.xc5000 LICENCE.xc5000c LICENSE.dib0700\
    LICENCE.it913x LICENSE.drxk LICENCE.ene_firmware LICENCE.sensoray LICENCE.go7007 LICENCE.kaweth LICENCE.OLPC\
    LICENCE.Marvell LICENCE.moxa LICENCE.ralink_a_mediatek_company_firmware LICENCE.multitech\
    LICENSE.QualcommAtheros_ath10k NOTICE.qca LICENCE.ralink-firmware.txt LICENCE.rtlwifi_firmware.txt\
    LICENSE.r8169 LICENCE.ueagle-atm4-firmware LICENSE.conexant; do
    get "$LFW_URL/$name?id=$LFW_COMMIT" $name
done

# verifies the integrity of every input, the packages match the trixie
# index of the Raspberry Pi archive, the wireless-regdb tarball matches
# the signed sha256sums.asc of kernel.org, firmware.rasp.2018.tar.xz is
# the 2018 package of the patches repository (commit f16bb37) and the
# licence texts are the ones of linux-firmware 20260916
cat > inputs.sha256 << "EOF"
c25e13e84be8dbf58b6b3381b4a10ad7e9dbeae101579376f457e0f17e60d902  firmware-brcm80211_20260519-1~bpo13+1+rpt1_all.deb
bfa0cb7a3806fb30a50b9f5756efee4530075aab192ba245758881efb2f24421  bluez-firmware_1.2-13+rpt2_all.deb
b22e0901227b820cd1c280abe681a15b773a5103a5e10dc442e94ebb34cbf58d  wireless-regdb-2026.09.03.tar.xz
7ad74ec7ae2f9c4951631343c360f1b06e61d7b05c0c52bc829dc425287689be  firmware.rasp.2018.tar.xz
b7b095f324ca8aa8d4edc758165959d8385dddb58aa8a5798d9cf12cc1ef9132  LICENSE.synaptics
ae0db6cc4db33941148df0f67de53e76a77b1b5a46b3165edb7040aa2750015f  LICENCE.cypress
b16056fc91b82a0e3e8de8f86c2dac98201aa9dc3cbd33e8d38f1b087fcec30d  LICENCE.broadcom_bcm43xx
802b7014b26c606cf6248ae8b0ab1ce6d2d1b0db236d38dd269e676cd70710f2  LICENCE.atheros_firmware
a064cbf83e10d72579d236a1e36032681adb8e442943ff75b57020a82992a5ed  LICENSE.QualcommAtheros_ar3k
83870e84c54aa76be973a78387b342c80ef0908b8cb82edde6d54c511b18c16c  LICENCE.open-ath9k-htc-firmware
8116433f4004fc0c24d72b3d9e497808b724aa0e5e1cd63fc1bf66b715b1e2e9  LICENCE.Abilis
8ea9f4aee5f53ad877041ff089e8c95d34d615ce19a3111e5e1ea70d990ed7ff  LICENCE.xc4000
30ec8a66503dc73f83937564ae70ca23aa03259e64727ff4195b5b6f695e782f  LICENCE.xc5000
f8822049f32fef2e90a197bd8cf259f476db75d549456bdca8567616a9c07ace  LICENCE.xc5000c
630fd46c95d3ac6544590c2265ba7348fbc930fb386261a1c04dcd9f403645b8  LICENSE.dib0700
0e0c11073ba3c832097da38e0905da36b8a3526f219407977b13b71c6675be7d  LICENCE.it913x
617bb89b39f6500a30e98b9626adf5fa23570ce0dbd9e4e401e334d3739850cc  LICENSE.drxk
da354fe486079e7f19ebd2424d2cf5309a31425ecfbf4afd6d35eeaf1fe2f0a1  LICENCE.ene_firmware
c30449d04eaafa81f6cfd658e16575191d9cfbdd1d583f3ae27417d757be1527  LICENCE.sensoray
95a6f553b1b3a068cdf45dc0cf7a74be303372c11c4c103f664804f7da516c6b  LICENCE.go7007
548ec9f2a93639d6f7ec40b47b4de7af45cab3237ab2ce06aca49b3e981c2f5a  LICENCE.kaweth
ad25f9a70b86bb066e897bd5a3727223977c036c825415ac3a05cb1fe7454fb7  LICENCE.OLPC
2d6062d63b91eb750bf741498691604f75184b9fee97608ec537cd09bd6a42b4  LICENCE.Marvell
59ae206c89108905ebdc9ad4c9336526bd2c0d50fbf988c21e8c2a82719d42a4  LICENCE.moxa
8568352b57f3574f9d5b2753cdb7c6e5eb2b79e82fbb9c9ba6566947467ef508  LICENCE.ralink_a_mediatek_company_firmware
7e3a87a7a07eb938140f89ad9bd5fc7ee3bffc1909b5d4069840c94852e54d0e  LICENCE.multitech
337a55102138d7baa143ee4a4c6c91693e0113fece35d380b2a12109e8c23b3f  LICENSE.QualcommAtheros_ath10k
600276e0992c8e5a85300d605fb2db6132ffcf2a21ddcfd0e8566a19e0f491c3  NOTICE.qca
d7bec70668ddd4aae8fb4aa32870e54b49fcdb0b9b007aa9f54b53a1ac7461bd  LICENCE.ralink-firmware.txt
a61351665b4f264f6c631364f85b907d8f8f41f8b369533ef4021765f9f3b62e  LICENCE.rtlwifi_firmware.txt
f9689ba2640d61e7b4527ad84cbfa6a9f0ec11484e2c9f6b5500197e22c27ecd  LICENSE.r8169
6ee33b50e65db65aabc453ce3aa82d7ba61c6274c33fd40e6bf8b6128beedd2b  LICENCE.ueagle-atm4-firmware
55b2839fe117f505c592a40f64c8c56e5ea25d4b867a9e5f5108b85231c61656  LICENSE.conexant
EOF
sha256sum -c inputs.sha256

popd > /dev/null

# extracts the (data of the) packages, the wireless-regdb tarball and
# the 2018 package into their own directories for the copy
pushd $WORK/brcm > /dev/null
ar x $WORK/sources/firmware-brcm80211_${BRCM_VERSION}_all.deb
tar -xf data.tar.*
popd > /dev/null
pushd $WORK/bluez > /dev/null
ar x $WORK/sources/bluez-firmware_${BLUEZ_VERSION}_all.deb
tar -xf data.tar.*
popd > /dev/null
tar -Jxf $WORK/sources/wireless-regdb-$REGDB_VERSION.tar.xz -C $WORK/regdb --strip-components=1
tar -Jxf $WORK/sources/firmware.rasp.2018.tar.xz -C $WORK/old

TREE=$WORK/firmware
BRCM=$WORK/brcm/usr/lib/firmware
BLUEZ=$WORK/bluez/usr/lib/firmware
OLD=$WORK/old/firmware
LICENSES=$TREE/LICENSES
mkdir -p $LICENSES

cat > $TREE/WHENCE << EOF
Scudum firmware package for the Raspberry Pi ($FILE)

Assembled by assemble.sh from pinned and sha256 verified inputs:

  firmware-brcm80211 1:$BRCM_VERSION (Raspberry Pi OS trixie)
  bluez-firmware $BLUEZ_VERSION (Raspberry Pi OS trixie)
  wireless-regdb $REGDB_VERSION (kernel.org)
  firmware.rasp.tar.xz of 2018 (hivesolutions/patches ${PATCHES_COMMIT:0:7})
  linux-firmware $LFW_VERSION (licence texts only)

Each section lists the files and links it ships, the input they come
from and the licence (under LICENSES/) that covers them. The onboard
Wi-Fi and Bluetooth files and links are the ones of Raspberry Pi OS,
with cypress/cyfmac43455-sdio.bin pointing to the standard variant.
EOF

# onboard wlan (firmware-brcm80211), the links are the ones of the
# package (without the two ACPI names) and cyfmac43455-sdio.bin is the
# link that update-alternatives creates for the standard variant
section "brcmfmac - onboard Wi-Fi of the Pi 3, 3B+, 4, CM4, 5, 500, CM5, Zero W and CM0" "firmware-brcm80211 1:$BRCM_VERSION"
files $BRCM cypress/cyfmac43430-sdio.bin cypress/cyfmac43430-sdio.clm_blob cypress/cyfmac43439-sdio.bin\
    cypress/cyfmac43439-sdio.clm_blob cypress/cyfmac43439-sdio.txt cypress/cyfmac43455-sdio.clm_blob\
    cypress/cyfmac43455-sdio-minimal.bin cypress/cyfmac43455-sdio-standard.bin brcm/brcmfmac43430-sdio.txt\
    brcm/brcmfmac43455-sdio.txt
links cypress/cyfmac43455-sdio.bin cyfmac43455-sdio-standard.bin\
    brcm/brcmfmac43430-sdio.bin ../cypress/cyfmac43430-sdio.bin\
    brcm/brcmfmac43430-sdio.clm_blob ../cypress/cyfmac43430-sdio.clm_blob\
    brcm/brcmfmac43430-sdio.raspberrypi,3-model-b.bin ../cypress/cyfmac43430-sdio.bin\
    brcm/brcmfmac43430-sdio.raspberrypi,3-model-b.clm_blob ../cypress/cyfmac43430-sdio.clm_blob\
    brcm/brcmfmac43430-sdio.raspberrypi,3-model-b.txt brcmfmac43430-sdio.txt\
    brcm/brcmfmac43430-sdio.raspberrypi,model-zero-w.bin ../cypress/cyfmac43430-sdio.bin\
    brcm/brcmfmac43430-sdio.raspberrypi,model-zero-w.clm_blob ../cypress/cyfmac43430-sdio.clm_blob\
    brcm/brcmfmac43430-sdio.raspberrypi,model-zero-w.txt brcmfmac43430-sdio.txt\
    brcm/brcmfmac43439-sdio.bin ../cypress/cyfmac43439-sdio.bin\
    brcm/brcmfmac43439-sdio.clm_blob ../cypress/cyfmac43439-sdio.clm_blob\
    brcm/brcmfmac43439-sdio.txt ../cypress/cyfmac43439-sdio.txt\
    brcm/brcmfmac43439-sdio.raspberrypi,0-compute-module.bin ../cypress/cyfmac43439-sdio.bin\
    brcm/brcmfmac43439-sdio.raspberrypi,0-compute-module.clm_blob ../cypress/cyfmac43439-sdio.clm_blob\
    brcm/brcmfmac43439-sdio.raspberrypi,0-compute-module.txt ../cypress/cyfmac43439-sdio.txt\
    brcm/brcmfmac43455-sdio.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,3-model-a-plus.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.raspberrypi,3-model-a-plus.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,3-model-a-plus.txt brcmfmac43455-sdio.txt\
    brcm/brcmfmac43455-sdio.raspberrypi,3-model-b-plus.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.raspberrypi,3-model-b-plus.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,3-model-b-plus.txt brcmfmac43455-sdio.txt\
    brcm/brcmfmac43455-sdio.raspberrypi,4-compute-module.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.raspberrypi,4-compute-module.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,4-compute-module.txt brcmfmac43455-sdio.txt\
    brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.txt brcmfmac43455-sdio.txt\
    brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,5-compute-module.txt brcmfmac43455-sdio.txt\
    brcm/brcmfmac43455-sdio.raspberrypi,5-model-b.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.raspberrypi,5-model-b.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,5-model-b.txt brcmfmac43455-sdio.txt\
    brcm/brcmfmac43455-sdio.raspberrypi,500.bin ../cypress/cyfmac43455-sdio.bin\
    brcm/brcmfmac43455-sdio.raspberrypi,500.clm_blob ../cypress/cyfmac43455-sdio.clm_blob\
    brcm/brcmfmac43455-sdio.raspberrypi,500.txt brcmfmac43455-sdio.txt
licence LICENCE.cypress

section "brcmfmac - onboard Wi-Fi of the Pi 400, CM4 (43456), Zero 2 W and CM0 (43436)" "firmware-brcm80211 1:$BRCM_VERSION"
files $BRCM brcm/brcmfmac43436-sdio.bin brcm/brcmfmac43436-sdio.clm_blob brcm/brcmfmac43436-sdio.txt\
    brcm/brcmfmac43436s-sdio.bin brcm/brcmfmac43436s-sdio.nolpo.txt brcm/brcmfmac43436s-sdio.txt\
    brcm/brcmfmac43456-sdio.bin brcm/brcmfmac43456-sdio.clm_blob brcm/brcmfmac43456-sdio.txt
links brcm/brcmfmac43430-sdio.raspberrypi,0-compute-module.bin brcmfmac43436s-sdio.bin\
    brcm/brcmfmac43430-sdio.raspberrypi,0-compute-module.txt brcmfmac43436s-sdio.nolpo.txt\
    brcm/brcmfmac43430-sdio.raspberrypi,model-zero-2-w.bin brcmfmac43436s-sdio.bin\
    brcm/brcmfmac43430-sdio.raspberrypi,model-zero-2-w.txt brcmfmac43436s-sdio.txt\
    brcm/brcmfmac43430b0-sdio.raspberrypi,model-zero-2-w.bin brcmfmac43436-sdio.bin\
    brcm/brcmfmac43430b0-sdio.raspberrypi,model-zero-2-w.clm_blob brcmfmac43436-sdio.clm_blob\
    brcm/brcmfmac43430b0-sdio.raspberrypi,model-zero-2-w.txt brcmfmac43436-sdio.txt\
    brcm/brcmfmac43436-sdio.raspberrypi,model-zero-2-w.bin brcmfmac43436-sdio.bin\
    brcm/brcmfmac43436-sdio.raspberrypi,model-zero-2-w.clm_blob brcmfmac43436-sdio.clm_blob\
    brcm/brcmfmac43436-sdio.raspberrypi,model-zero-2-w.txt brcmfmac43436-sdio.txt\
    brcm/brcmfmac43436s-sdio.raspberrypi,0-compute-module.bin brcmfmac43436s-sdio.bin\
    brcm/brcmfmac43436s-sdio.raspberrypi,0-compute-module.txt brcmfmac43436s-sdio.nolpo.txt\
    brcm/brcmfmac43436s-sdio.raspberrypi,model-zero-2-w.bin brcmfmac43436s-sdio.bin\
    brcm/brcmfmac43436s-sdio.raspberrypi,model-zero-2-w.txt brcmfmac43436s-sdio.txt\
    brcm/brcmfmac43456-sdio.raspberrypi,4-compute-module.bin brcmfmac43456-sdio.bin\
    brcm/brcmfmac43456-sdio.raspberrypi,4-compute-module.clm_blob brcmfmac43456-sdio.clm_blob\
    brcm/brcmfmac43456-sdio.raspberrypi,4-compute-module.txt brcmfmac43456-sdio.txt\
    brcm/brcmfmac43456-sdio.raspberrypi,400.bin brcmfmac43456-sdio.bin\
    brcm/brcmfmac43456-sdio.raspberrypi,400.clm_blob brcmfmac43456-sdio.clm_blob\
    brcm/brcmfmac43456-sdio.raspberrypi,400.txt brcmfmac43456-sdio.txt
licence LICENSE.synaptics-wlan

# onboard bluetooth (bluez-firmware), with the links of the package
section "btbcm - onboard Bluetooth of the Pi 3, 3B+, 4, 400, CM4, 5, 500, CM5, Zero W and CM0" "bluez-firmware $BLUEZ_VERSION"
files $BLUEZ brcm/BCM43430A1.hcd brcm/BCM43430B0.hcd brcm/BCM4343A2.hcd brcm/BCM4345C0.hcd brcm/BCM4345C5.hcd
links brcm/BCM43430A1.raspberrypi,3-model-b.hcd BCM43430A1.hcd\
    brcm/BCM43430A1.raspberrypi,model-zero-w.hcd BCM43430A1.hcd\
    brcm/BCM4343A2.raspberrypi,0-compute-module.hcd BCM4343A2.hcd\
    brcm/BCM4345C0.raspberrypi,3-model-a-plus.hcd BCM4345C0.hcd\
    brcm/BCM4345C0.raspberrypi,3-model-b-plus.hcd BCM4345C0.hcd\
    brcm/BCM4345C0.raspberrypi,4-compute-module.hcd BCM4345C0.hcd\
    brcm/BCM4345C0.raspberrypi,4-model-b.hcd BCM4345C0.hcd\
    brcm/BCM4345C0.raspberrypi,5-compute-module.hcd BCM4345C0.hcd\
    brcm/BCM4345C0.raspberrypi,5-model-b.hcd BCM4345C0.hcd\
    brcm/BCM4345C0.raspberrypi,500.hcd BCM4345C0.hcd\
    brcm/BCM4345C5.raspberrypi,4-compute-module.hcd BCM4345C5.hcd\
    brcm/BCM4345C5.raspberrypi,400.hcd BCM4345C5.hcd
licence LICENCE.cypress

section "btbcm - onboard Bluetooth of the Pi Zero 2 W" "bluez-firmware $BLUEZ_VERSION"
files $BLUEZ synaptics/SYN43430A1.hcd synaptics/SYN43430B0.hcd
links brcm/BCM43430A1.raspberrypi,model-zero-2-w.hcd ../synaptics/SYN43430A1.hcd\
    brcm/BCM43430B0.raspberrypi,model-zero-2-w.hcd ../synaptics/SYN43430B0.hcd
licence LICENSE.synaptics-bluetooth

section "bcm203x - Broadcom BCM2033 USB Bluetooth" "bluez-firmware $BLUEZ_VERSION"
files $BLUEZ BCM2033-FW.bin BCM2033-MD.hex
licence LICENSE.BCM2033

# signed regulatory database, required by the kernels as they are
# built with CFG80211_REQUIRE_SIGNED_REGDB (verified with wens.x509)
section "cfg80211 - wireless regulatory database" "wireless-regdb $REGDB_VERSION"
files $WORK/regdb regulatory.db regulatory.db.p7s
licence LICENSE.wireless-regdb

# carry over of the 2018 files that the modules of the Raspberry Pi
# kernels can still load (USB and SDIO dongles, DVB and serial adapters),
# the licence of each group is the one of the linux-firmware WHENCE of
# that time, with the texts of linux-firmware 20260916
SOURCE="firmware.rasp.tar.xz of 2018"

section "ath3k, ar5523, ath6kl_usb - Atheros USB Bluetooth and wireless" "$SOURCE"
files $OLD ar3k/AthrBT_0x01020001.dfu ar3k/AthrBT_0x01020200.dfu ar3k/AthrBT_0x11020000.dfu ar3k/AthrBT_0x11020100.dfu\
    ar3k/AthrBT_0x31010000.dfu ar3k/AthrBT_0x31010100.dfu ar3k/AthrBT_0x41020000.dfu ar3k/ramps_0x01020001_26.dfu\
    ar3k/ramps_0x01020200_26.dfu ar3k/ramps_0x01020200_40.dfu ar3k/ramps_0x01020201_26.dfu ar3k/ramps_0x01020201_40.dfu\
    ar3k/ramps_0x11020000_40.dfu ar3k/ramps_0x11020100_40.dfu ar3k/ramps_0x31010000_40.dfu ar3k/ramps_0x31010100_40.dfu\
    ar3k/ramps_0x41020000_40.dfu ar5523.bin ath3k-1.fw ath6k/AR6004/hw1.2/bdata.bin ath6k/AR6004/hw1.2/fw-2.bin\
    ath6k/AR6004/hw1.3/bdata.bin ath6k/AR6004/hw1.3/fw-3.bin
licence LICENCE.atheros_firmware

section "ath3k - Atheros AR3012 USB Bluetooth" "$SOURCE"
files $OLD ar3k/AthrBT_0x01020201.dfu
licence LICENSE.QualcommAtheros_ar3k

section "btusb - Qualcomm Atheros USB Bluetooth" "$SOURCE"
files $OLD qca/nvm_usb_00000200.bin qca/nvm_usb_00000201.bin qca/nvm_usb_00000300.bin qca/nvm_usb_00000302.bin\
    qca/rampatch_usb_00000200.bin qca/rampatch_usb_00000201.bin qca/rampatch_usb_00000300.bin qca/rampatch_usb_00000302.bin
licence LICENSE.QualcommAtheros_ath10k NOTICE.qca

section "ath9k_htc - Atheros USB wireless" "$SOURCE"
files $OLD ath9k_htc/htc_7010-1.4.0.fw ath9k_htc/htc_9271-1.4.0.fw
licence LICENCE.open-ath9k-htc-firmware

section "brcmfmac - Broadcom USB and SDIO wireless dongles" "$SOURCE"
files $OLD brcm/brcmfmac43143.bin brcm/brcmfmac43143-sdio.bin brcm/brcmfmac43236b.bin brcm/brcmfmac43241b0-sdio.bin\
    brcm/brcmfmac43241b4-sdio.bin brcm/brcmfmac43241b5-sdio.bin brcm/brcmfmac43242a.bin brcm/brcmfmac4329-sdio.bin\
    brcm/brcmfmac4330-sdio.bin brcm/brcmfmac43340-sdio.bin brcm/brcmfmac4334-sdio.bin brcm/brcmfmac4335-sdio.bin\
    brcm/brcmfmac43362-sdio.bin brcm/brcmfmac4339-sdio.bin brcm/brcmfmac4354-sdio.bin brcm/brcmfmac43569.bin
licence LICENCE.broadcom_bcm43xx

section "libertas, mwifiex, btmrvl - Marvell wireless and Bluetooth" "$SOURCE"
files $OLD libertas/sd8385.bin libertas/sd8385_helper.bin libertas/sd8686_v8.bin libertas/sd8686_v8_helper.bin\
    libertas/sd8686_v9.bin libertas/sd8686_v9_helper.bin libertas/sd8688.bin libertas/sd8688_helper.bin\
    libertas/usb8388_v5.bin libertas/usb8388_v9.bin libertas/usb8682.bin mrvl/sd8688.bin mrvl/sd8688_helper.bin\
    mrvl/sd8787_uapsta.bin mrvl/sd8797_uapsta.bin mrvl/sd8801_uapsta.bin mrvl/sd8887_uapsta.bin mrvl/sd8897_uapsta.bin\
    sd8385.bin sd8385_helper.bin sd8686.bin sd8686_helper.bin sd8688.bin sd8688_helper.bin usb8388.bin
licence LICENCE.Marvell

section "libertas_tf_usb - Marvell USB wireless (OLPC)" "$SOURCE"
files $OLD lbtf_usb.bin
licence LICENCE.OLPC

section "rt2800usb, rt73usb - Ralink USB wireless" "$SOURCE"
files $OLD rt2870.bin rt73.bin
licence LICENCE.ralink-firmware.txt

section "mt7601u - MediaTek MT7601U USB wireless" "$SOURCE"
files $OLD mt7601u.bin
licence LICENCE.ralink_a_mediatek_company_firmware

section "rtl8xxxu, rtl8192cu, btrtl - Realtek USB wireless and Bluetooth" "$SOURCE"
files $OLD rtl_bt/rtl8723a_fw.bin rtl_bt/rtl8723b_fw.bin rtl_bt/rtl8761a_fw.bin rtl_bt/rtl8821a_fw.bin\
    rtl_bt/rtl8822b_config.bin rtl_bt/rtl8822b_fw.bin rtlwifi/rtl8188eufw.bin rtlwifi/rtl8192cufw_A.bin\
    rtlwifi/rtl8192cufw_B.bin rtlwifi/rtl8192cufw.bin rtlwifi/rtl8192cufw_TMSC.bin rtlwifi/rtl8192eu_nic.bin\
    rtlwifi/rtl8723aufw_A.bin rtlwifi/rtl8723aufw_B.bin rtlwifi/rtl8723aufw_B_NoBT.bin rtlwifi/rtl8723bu_nic.bin
licence LICENCE.rtlwifi_firmware.txt

section "r8169 - Realtek ethernet" "$SOURCE"
files $OLD rtl_nic/rtl8105e-1.fw rtl_nic/rtl8106e-1.fw rtl_nic/rtl8106e-2.fw rtl_nic/rtl8107e-2.fw rtl_nic/rtl8168d-1.fw\
    rtl_nic/rtl8168d-2.fw rtl_nic/rtl8168e-1.fw rtl_nic/rtl8168e-2.fw rtl_nic/rtl8168e-3.fw rtl_nic/rtl8168f-1.fw\
    rtl_nic/rtl8168f-2.fw rtl_nic/rtl8168g-2.fw rtl_nic/rtl8168g-3.fw rtl_nic/rtl8168h-2.fw rtl_nic/rtl8402-1.fw\
    rtl_nic/rtl8411-1.fw rtl_nic/rtl8411-2.fw
licence LICENSE.r8169

section "kaweth - KL5KUSB101 USB ethernet" "$SOURCE"
files $OLD kaweth/new_code.bin kaweth/new_code_fix.bin kaweth/trigger_code.bin kaweth/trigger_code_fix.bin
licence LICENCE.kaweth

section "ueagle-atm - Eagle IV USB ADSL modem" "$SOURCE"
files $OLD ueagle-atm/CMV4p.bin.v2 ueagle-atm/DSP4p.bin ueagle-atm/eagleIV.fw
licence LICENCE.ueagle-atm4-firmware

section "dvb-as102 - Abilis AS102 USB DVB-T" "$SOURCE"
files $OLD as102_data1_st.hex as102_data2_st.hex
licence LICENCE.Abilis

section "dvb_usb_dib0700 - DiBcom DiB0700 USB DVB" "$SOURCE"
files $OLD dvb-usb-dib0700-1.20.fw
licence LICENSE.dib0700

section "dvb_usb_af9035 - ITE IT9135 USB DVB-T" "$SOURCE"
files $OLD dvb-usb-it9135-01.fw dvb-usb-it9135-02.fw
licence LICENCE.it913x

section "drxk - DRX-K demodulator (em28xx-dvb, Terratec H5)" "$SOURCE"
files $OLD dvb-usb-terratec-h5-drxk.fw
licence LICENSE.drxk

section "xc4000 - Xceive 4000 tuner" "$SOURCE"
files $OLD dvb-fe-xc4000-1.4.1.fw
licence LICENCE.xc4000

section "xc5000 - Xceive 5000 tuner" "$SOURCE"
files $OLD dvb-fe-xc5000-1.6.114.fw dvb-fe-xc5000c-4.1.30.7.fw
licence LICENCE.xc5000 LICENCE.xc5000c

section "cx231xx, cx23885, cx25840 - Conexant video decoders" "$SOURCE"
files $OLD v4l-cx231xx-avcore-01.fw v4l-cx23885-avcore-01.fw v4l-cx25840.fw
licence LICENSE.conexant

section "go7007 - WIS GO7007 USB video encoder" "$SOURCE"
files $OLD go7007/go7007fw.bin go7007/go7007tv.bin go7007/lr192.fw go7007/px-m402u.fw go7007/px-tv402u.fw\
    go7007/wis-startrek.fw
licence LICENCE.go7007

section "s2255drv, go7007 - Sensoray 2255 and 2250 USB video" "$SOURCE"
files $OLD f2255usb.bin go7007/s2250-1.fw go7007/s2250-2.fw
licence LICENCE.sensoray

section "ums-eneub6250 - ENE UB6250 USB card reader" "$SOURCE"
files $OLD ene-ub6250/ms_init.bin ene-ub6250/msp_rdwr.bin ene-ub6250/ms_rdwr.bin ene-ub6250/sd_init1.bin\
    ene-ub6250/sd_init2.bin ene-ub6250/sd_rdwr.bin
licence LICENCE.ene_firmware

section "mxuport, mxu11x0 - Moxa UPort USB serial" "$SOURCE"
files $OLD moxa/moxa-1110.fw moxa/moxa-1130.fw moxa/moxa-1131.fw moxa/moxa-1150.fw moxa/moxa-1151.fw moxa/moxa-1250.fw\
    moxa/moxa-1251.fw moxa/moxa-1410.fw moxa/moxa-1450.fw moxa/moxa-1451.fw moxa/moxa-1613.fw moxa/moxa-1618.fw\
    moxa/moxa-1653.fw moxa/moxa-1658.fw
licence LICENCE.moxa

section "ti_usb_3410_5052 - Multi-Tech USB modems" "$SOURCE"
files $OLD mts_cdma.fw mts_edge.fw mts_gsm.fw
licence LICENCE.multitech

# copies the licence texts, most of them come from linux-firmware and
# the others from the packages (the synaptics wlan one is the stanza
# of the copyright file of firmware-brcm80211) and wireless-regdb
for name in LICENCE.cypress LICENCE.broadcom_bcm43xx LICENCE.atheros_firmware LICENSE.QualcommAtheros_ar3k\
    LICENCE.open-ath9k-htc-firmware LICENCE.Abilis LICENCE.xc4000 LICENCE.xc5000 LICENCE.xc5000c LICENSE.dib0700\
    LICENCE.it913x LICENSE.drxk LICENCE.ene_firmware LICENCE.sensoray LICENCE.go7007 LICENCE.kaweth LICENCE.OLPC\
    LICENCE.Marvell LICENCE.moxa LICENCE.ralink_a_mediatek_company_firmware LICENCE.multitech\
    LICENSE.QualcommAtheros_ath10k NOTICE.qca LICENCE.ralink-firmware.txt LICENCE.rtlwifi_firmware.txt\
    LICENSE.r8169 LICENCE.ueagle-atm4-firmware LICENSE.conexant; do
    cp $WORK/sources/$name $LICENSES/$name
done
cp $WORK/sources/LICENSE.synaptics $LICENSES/LICENSE.synaptics-bluetooth
sed -n '8393,8505p' $WORK/brcm/usr/share/doc/firmware-brcm80211/copyright | sed 's/^ //; s/^\.$//' > $LICENSES/LICENSE.synaptics-wlan
cp $WORK/bluez/usr/share/doc/bluez-firmware/BCM-LEGAL.txt $LICENSES/LICENSE.BCM2033
cp $WORK/regdb/LICENSE $LICENSES/LICENSE.wireless-regdb

# normalizes the permissions (no world writable entries) and makes sure
# that every link resolves inside the tree and that the licences in the
# manifest and the ones under LICENSES/ are exactly the same set
find $TREE -type f -exec chmod 0644 {} + && find $TREE -type d -exec chmod 0755 {} +
broken=$(find $TREE -xtype l)
if [ "$broken" != "" ]; then echo "assemble.sh: broken links: $broken" && exit 1; fi
grep "^Licence:" $TREE/WHENCE | grep -o "LICENSES/[^ ]*[^ .]" | sort -u > $WORK/licences.whence
(cd $TREE && find LICENSES -type f | sort) > $WORK/licences.tree
diff -u $WORK/licences.whence $WORK/licences.tree

# packs the tree with fixed ownership, order and modification time so that
# the resulting tarball is reproducible, then prints its checksum
tar --format=gnu --sort=name --owner=0 --group=0 --numeric-owner --mtime="$MTIME"\
    -C $WORK -cf - firmware | xz -9e -T1 > $OUT/$FILE
echo "assemble.sh: $(find $TREE -type f | wc -l) files, $(find $TREE -type l | wc -l) links, $(find $TREE -type d | wc -l) directories"
(cd $OUT && sha256sum $FILE && ls -l $FILE)
