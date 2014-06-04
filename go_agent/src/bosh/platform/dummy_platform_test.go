package platform_test

import (
	"encoding/json"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "bosh/logger"
	. "bosh/platform"
	fakestats "bosh/platform/stats/fakes"
	boshsettings "bosh/settings"
	boshdirs "bosh/settings/directories"
	fakesys "bosh/system/fakes"
)

var _ = Describe("dummyPlatform", func() {
	var (
		collector   *fakestats.FakeStatsCollector
		fs          *fakesys.FakeFileSystem
		cmdRunner   *fakesys.FakeCmdRunner
		dirProvider boshdirs.DirectoriesProvider
		platform    Platform
	)

	BeforeEach(func() {
		collector = &fakestats.FakeStatsCollector{}
		fs = fakesys.NewFakeFileSystem()
		cmdRunner = fakesys.NewFakeCmdRunner()
		dirProvider = boshdirs.NewDirectoriesProvider("/fake-dir")
		logger := boshlog.NewLogger(boshlog.LevelNone)
		platform = NewDummyPlatform(collector, fs, cmdRunner, dirProvider, logger)
	})

	Describe("GetDefaultNetwork", func() {
		Context("when default networks settings file is found", func() {
			expectedNetwork := boshsettings.Network{
				Default: []string{"fake-default"},
				DNS:     []string{"fake-dns-name"},
				IP:      "fake-ip-address",
				Netmask: "fake-netmask",
				Gateway: "fake-gateway",
				Mac:     "fake-mac-address",
			}

			BeforeEach(func() {
				settingsPath := filepath.Join(dirProvider.BoshDir(), "dummy-default-network-settings.json")

				expectedNetworkBytes, err := json.Marshal(expectedNetwork)
				Expect(err).ToNot(HaveOccurred())

				fs.WriteFile(settingsPath, expectedNetworkBytes)
			})

			It("returns network", func() {
				network, err := platform.GetDefaultNetwork()
				Expect(err).ToNot(HaveOccurred())
				Expect(network).To(Equal(expectedNetwork))
			})
		})

		Context("when default networks settings file is not found", func() {
			It("does not return error because dummy configuration allows no dynamic IP", func() {
				_, err := platform.GetDefaultNetwork()
				Expect(err).ToNot(HaveOccurred())
			})
		})
	})
})
