package arp

import (
	"path/filepath"
	"sync"
	"time"

	boshlog "bosh/logger"
	boship "bosh/platform/net/ip"
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
func (a arping) BroadcastMACAddresses(addresses []boship.InterfaceAddress) {
	var wg sync.WaitGroup

	for _, addr := range addresses {
		wg.Add(1) // Outside of goroutine

		go func(address boship.InterfaceAddress) {
			a.blockUntilInterfaceExists(address.GetInterfaceName())

			for i := 0; i < a.iterations; i++ {
				a.broadcastMACAddress(address)
				if i < a.iterations-1 {
					// Sleep between iterations
					time.Sleep(a.iterationDelay)
				}
			}

			wg.Done()
		}(addr)
	}

	wg.Wait()
}

// blockUntilInterfaceExists block until the specified network interface exists
// at /sys/class/net/<interfaceName>
func (a arping) blockUntilInterfaceExists(interfaceName string) {
	// TODO: Timeout waiting for net interface to exist?
	for !a.fs.FileExists(filepath.Join("/sys/class/net", interfaceName)) {
		time.Sleep(a.interfaceCheckDelay)
	}
}

// broadcastMACAddress broadcasts an IP/MAC pair to the specified network and logs any failure
func (a arping) broadcastMACAddress(address boship.InterfaceAddress) {
	ip, err := address.GetIP()
	if err != nil {
		a.logger.Info(arpingLogTag, "Ignoring GetIP failure: %s", err.Error())
		return
	}

	ifaceName := address.GetInterfaceName()

	_, _, _, err = a.cmdRunner.RunCommand("arping", "-c", "1", "-U", "-I", ifaceName, ip)
	if err != nil {
		a.logger.Info(arpingLogTag, "Ignoring arping failure: %s", err.Error())
	}
}
