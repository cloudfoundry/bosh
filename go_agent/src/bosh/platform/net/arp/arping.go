package arp

import (
	"path/filepath"
	"time"

	boshlog "bosh/logger"
	boshsys "bosh/system"
)

const arpingLogTag = "arping"

type arping struct {
	cmdRunner boshsys.CmdRunner
	fs        boshsys.FileSystem
	logger    boshlog.Logger

	iterations          int
	iterationDelay      time.Duration
	interfaceCheckDelay time.Duration
}

func NewArping(
	cmdRunner boshsys.CmdRunner,
	fs boshsys.FileSystem,
	logger boshlog.Logger,
	iterations int,
	iterationDelay time.Duration,
	interfaceCheckDelay time.Duration,
) arping {
	return arping{
		cmdRunner:           cmdRunner,
		fs:                  fs,
		logger:              logger,
		iterations:          iterations,
		iterationDelay:      iterationDelay,
		interfaceCheckDelay: interfaceCheckDelay,
	}
}

// BroadcastMACAddresses broadcasts multiple IP/MAC pairs, multiple times
func (a arping) BroadcastMACAddresses(addresses []InterfaceAddress) {
	for i := 0; i < a.iterations; i++ {
		a.broadcastMACAddressesOnce(addresses)
		if i < a.iterations-1 {
			time.Sleep(a.iterationDelay)
		}
	}
}

// broadcastMACAddressesOnce broadcasts multiple IP/MAC pairs to the specified networks
// and logs any failures
func (a arping) broadcastMACAddressesOnce(addresses []InterfaceAddress) {
	for _, address := range addresses {
		a.blockUntilInterfaceExists(address.Interface)
		a.broadcastMACAddress(address)
	}
}

// blockUntilInterfaceExists block until the specified network interface exists
// at /sys/class/net/<interfaceName>
func (a arping) blockUntilInterfaceExists(interfaceName string) {
	//TODO: Timeout waiting for net interface to exist?
	for !a.fs.FileExists(filepath.Join("/sys/class/net", interfaceName)) {
		time.Sleep(a.interfaceCheckDelay)
	}
}

// broadcastMACAddress broadcasts an IP/MAC pair to the specified network and logs any failure
func (a arping) broadcastMACAddress(address InterfaceAddress) {
	_, _, _, err := a.cmdRunner.RunCommand("arping", "-c", "1", "-U", "-I", address.Interface, address.IP)
	if err != nil {
		a.logger.Info(arpingLogTag, "Ignoring arping failure: %s", err.Error())
	}
}
