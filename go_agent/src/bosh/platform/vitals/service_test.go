package vitals_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshassert "bosh/assert"
	boshstats "bosh/platform/stats"
	fakestats "bosh/platform/stats/fakes"
	. "bosh/platform/vitals"
	boshdirs "bosh/settings/directories"
)

func buildVitalsService() (statsCollector *fakestats.FakeStatsCollector, service Service) {
	dirProvider := boshdirs.NewDirectoriesProvider("/fake/base/dir")
	statsCollector = &fakestats.FakeStatsCollector{
		CPULoad: boshstats.CPULoad{
			One:     0.2,
			Five:    4.55,
			Fifteen: 1.123,
		},
		CPUStats: boshstats.CPUStats{
			User:  56,
			Sys:   10,
			Wait:  1,
			Total: 100,
		},
		MemStats: boshstats.Usage{
			Used:  700 * 1024,
			Total: 1000 * 1024,
		},
		SwapStats: boshstats.Usage{
			Used:  600 * 1024,
			Total: 1000 * 1024,
		},
		DiskStats: map[string]boshstats.DiskStats{
			"/": boshstats.DiskStats{
				DiskUsage:  boshstats.Usage{Used: 100, Total: 200},
				InodeUsage: boshstats.Usage{Used: 50, Total: 500},
			},
			dirProvider.DataDir(): boshstats.DiskStats{
				DiskUsage:  boshstats.Usage{Used: 15, Total: 20},
				InodeUsage: boshstats.Usage{Used: 10, Total: 50},
			},
			dirProvider.StoreDir(): boshstats.DiskStats{
				DiskUsage:  boshstats.Usage{Used: 2, Total: 2},
				InodeUsage: boshstats.Usage{Used: 3, Total: 4},
			},
		},
	}

	service = NewService(statsCollector, dirProvider)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("vitals construction", func() {
			_, service := buildVitalsService()
			vitals, err := service.Get()

			expectedVitals := map[string]interface{}{
				"cpu": map[string]string{
					"sys":  "10.0",
					"user": "56.0",
					"wait": "1.0",
				},
				"disk": map[string]interface{}{
					"system": map[string]string{
						"percent":       "50",
						"inode_percent": "10",
					},
					"ephemeral": map[string]string{
						"percent":       "75",
						"inode_percent": "20",
					},
					"persistent": map[string]string{
						"percent":       "100",
						"inode_percent": "75",
					},
				},
				"load": []string{"0.20", "4.55", "1.12"},
				"mem": map[string]string{
					"kb":      "700",
					"percent": "70",
				},
				"swap": map[string]string{
					"kb":      "600",
					"percent": "60",
				},
			}

			Expect(err).ToNot(HaveOccurred())

			boshassert.MatchesJSONMap(GinkgoT(), vitals, expectedVitals)
		})
		It("getting vitals when missing disks", func() {

			statsCollector, service := buildVitalsService()
			statsCollector.DiskStats = map[string]boshstats.DiskStats{
				"/": boshstats.DiskStats{
					DiskUsage:  boshstats.Usage{Used: 100, Total: 200},
					InodeUsage: boshstats.Usage{Used: 50, Total: 500},
				},
			}

			vitals, err := service.Get()
			Expect(err).ToNot(HaveOccurred())

			boshassert.LacksJSONKey(GinkgoT(), vitals.Disk, "ephemeral")
			boshassert.LacksJSONKey(GinkgoT(), vitals.Disk, "persistent")
		})
		It("get getting vitals on system disk error", func() {

			statsCollector, service := buildVitalsService()
			statsCollector.DiskStats = map[string]boshstats.DiskStats{}

			_, err := service.Get()
			Expect(err).To(HaveOccurred())
		})
	})
}
