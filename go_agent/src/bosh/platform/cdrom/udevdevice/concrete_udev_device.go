package udevdevice

import (
	bosherr "bosh/errors"
	boshsys "bosh/system"
	"os"
	"time"
)

type ConcreteUdevDevice struct {
	runner boshsys.CmdRunner
}

func NewConcreteUdevDevice(runner boshsys.CmdRunner) (udev ConcreteUdevDevice) {
	udev.runner = runner
	return
}

func (udev ConcreteUdevDevice) KickDevice(filePath string) {
	for i := 0; i < 5; i++ {
		err := readByte(filePath)
		if err == nil {
			break
		}
		time.Sleep(time.Second / 2)
	}
	readByte(filePath)
	return
}

func (udev ConcreteUdevDevice) Settle() (err error) {
	switch {
	case udev.runner.CommandExists("udevadm"):
		_, _, err = udev.runner.RunCommand("udevadm", "settle")
	case udev.runner.CommandExists("udevsettle"):
		_, _, err = udev.runner.RunCommand("udevsettle")
	default:
		err = bosherr.New("can not find udevadm or udevsettle commands")
	}
	return
}

func (udev ConcreteUdevDevice) EnsureDeviceReadable(filePath string) (err error) {
	for i := 0; i < 5; i++ {
		readByte(filePath)
		time.Sleep(time.Second / 2)
	}
	readByte(filePath)

	if err != nil {
		err = bosherr.WrapError(err, "Reading udev device")
		return
	}
	return
}

func readByte(filePath string) (err error) {
	device, err := os.Open(filePath)
	if err != nil {
		return
	}

	bytes := make([]byte, 1, 1)
	read, err := device.Read(bytes)
	if err != nil {
		return
	}

	if read != 1 {
		err = bosherr.New("Device readable but zero length")
		return
	}
	return
}
