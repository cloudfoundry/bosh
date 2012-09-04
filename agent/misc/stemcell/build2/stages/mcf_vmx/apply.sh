#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

vsphere=$work/vsphere

mkdir -p $vsphere

disk_image_name=root.img
disk_size=$(($(stat --printf="%s" $work/$disk_image_name) / (1024*1024)))

# 512 bytes per sector
disk_sectors=$(($disk_size * 2048))

# 255 * 63 = 16065 sectors per head
disk_cylinders=$(($disk_sectors / 16065))

# Output disk description
cat > $vsphere/root.vmdk <<EOS
version=1
CID=ffffffff
parentCID=ffffffff
createType="vmfs"

# Extent description
RW $disk_sectors FLAT "$work/$disk_image_name" 0
ddb.toolsVersion = "0"
ddb.adapterType = "lsilogic"
ddb.geometry.biosSectors = "63"
ddb.geometry.biosHeads = "255"
ddb.geometry.biosCylinders = "$disk_cylinders"
ddb.geometry.sectors = "63"
ddb.geometry.heads = "255"
ddb.geometry.cylinders = "$disk_cylinders"
ddb.virtualHWVersion = "4"
EOS

vm_mem=2048
vm_cpus=2
vm_hostname=ubuntu
vm_arch=amd64
vm_guestos=ubuntu-64
mcf_version=1.3.0

cat > $vsphere/$vm_hostname.vmx <<EOS
config.version = "8"
virtualHW.version = 7
floppy0.present = "true"
nvram = "nvram"
deploymentPlatform = "windows"
virtualHW.productCompatibility = "hosted"
tools.upgrade.policy = "useGlobal"
powerType.powerOff = "default"
powerType.powerOn = "default"
powerType.suspend = "default"
powerType.reset = "default"

displayName = "Micro Cloud Foundry v${mcf_version}"

numvcpus = "$vm_cpus"
scsi0.present = "true"
scsi0.sharedBus = "none"
scsi0.virtualDev = "lsilogic"
memsize = "$vm_mem"

scsi0:0.present = "true"
scsi0:0.fileName = "root.vmdk"
scsi0:0.deviceType = "scsi-hardDisk"

ide0:0.present = "true"
ide0:0.clientDevice = "TRUE"
ide0:0.deviceType = "cdrom-raw"
ide0:0.startConnected = "FALSE"
floppy0.startConnected = "false"
floppy0.clientDevice = "true"

guestOSAltName = "$vm_guestos ($vm_arch)"
guestOS = "$vm_guestos"

toolScripts.afterPowerOn = "true"
toolScripts.afterResume = "true"
toolScripts.beforeSuspend = "true"
toolScripts.beforePowerOff = "true"

scsi0:0.redo = ""

tools.syncTime = "FALSE"
tools.remindInstall = "TRUE"

evcCompatibilityMode = "FALSE"

ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "e1000"
ethernet0.wakeOnPcktRcv = "FALSE"
ethernet0.addressType = "generated"
ethernet0.generatedAddress = "00:0c:29:31:03:01"
ethernet0.pciSlotNumber = "33"
ethernet0.generatedAddressOffset = "0"
EOS
