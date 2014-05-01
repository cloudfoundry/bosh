package udevdevice

import (
	"os"
	"time"

	bosherr "bosh/errors"
	boshsys "bosh/system"
)

type ConcreteUdevDevice struct {
	runner boshsys.CmdRunner
}

func NewConcreteUdevDevice(runner boshsys.CmdRunner) ConcreteUdevDevice {
	return ConcreteUdevDevice{runner}
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
		_, _, _, err = udev.runner.RunCommand("udevadm", "settle")
	case udev.runner.CommandExists("udevsettle"):
		_, _, _, err = udev.runner.RunCommand("udevsettle")
	default:
		err = bosherr.New("can not find udevadm or udevsettle commands")
	}
	return
}

func (udev ConcreteUdevDevice) EnsureDeviceReadable(filePath string) error {
	for i := 0; i < 5; i++ {
		readByte(filePath)
		time.Sleep(time.Second / 2)
	}

	err := readByte(filePath)
	if err != nil {
		return bosherr.WrapError(err, "Reading udev device")
	}

	return nil
}

func readByte(filePath string) error {
	device, err := os.Open(filePath)
	if err != nil {
		return err
	}

	bytes := make([]byte, 1, 1)
	read, err := device.Read(bytes)
	if err != nil {
		return err
	}

	if read != 1 {
		return bosherr.New("Device readable but zero length")
	}

	return nil
}
