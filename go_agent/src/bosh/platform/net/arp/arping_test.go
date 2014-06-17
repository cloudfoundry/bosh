package arp_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "bosh/logger"
	. "bosh/platform/net/arp"
	fakesys "bosh/system/fakes"
)

var _ = Describe("arping", func() {
	const arpingIterations = 6

	var (
		fs        *fakesys.FakeFileSystem
		cmdRunner *fakesys.FakeCmdRunner
		arping    AddressBroadcaster
	)

	BeforeEach(func() {
		fs = fakesys.NewFakeFileSystem()
		cmdRunner = fakesys.NewFakeCmdRunner()
		logger := boshlog.NewLogger(boshlog.LevelNone)
		arping = NewArping(cmdRunner, fs, logger, arpingIterations, 0, 0)
	})

	Describe("BroadcastMACAddresses", func() {
		BeforeEach(func() {
			fs.WriteFile("/sys/class/net/eth0", []byte{})
			fs.WriteFile("/sys/class/net/eth1", []byte{})
		})

		addresses := []InterfaceAddress{
			InterfaceAddress{
				Interface: "eth0",
				IP:        "192.168.195.6",
			},
			InterfaceAddress{
				Interface: "eth1",
				IP:        "127.0.0.1",
			},
		}

		It("runs arping commands for each interface", func() {
			arping.BroadcastMACAddresses(addresses)

			for i := 0; i < arpingIterations; i++ {
				Expect(cmdRunner.RunCommands[i*2]).To(Equal([]string{
					"arping", "-c", "1", "-U", "-I", "eth0", "192.168.195.6",
				}))

				Expect(cmdRunner.RunCommands[i*2+1]).To(Equal([]string{
					"arping", "-c", "1", "-U", "-I", "eth1", "127.0.0.1",
				}))
			}
		})
	})
})
