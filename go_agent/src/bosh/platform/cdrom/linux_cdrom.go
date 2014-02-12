package cdrom

import (
	bosherr "bosh/errors"
	"bosh/platform/cdrom/udevdevice"
)

type LinuxCdrom struct {
	udev udevdevice.UdevDevice
}

func NewLinuxCdrom(udev udevdevice.UdevDevice) (cdrom LinuxCdrom) {
	cdrom.udev = udev
	return
}

func (cdrom LinuxCdrom) WaitForMedia() (err error) {
	cdrom.udev.KickDevice("/dev/sr0")
	err = cdrom.udev.Settle()
	if err != nil {
		err = bosherr.WrapError(err, "Waiting for udev to settle")
		return
	}

	err = cdrom.udev.EnsureDeviceReadable("/dev/sr0")
	return
}
