package settings_test

import (
	. "bosh/settings"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("default network for when networks is empty", func() {

			networks := Networks{}

			_, found := networks.DefaultNetworkFor("dns")
			assert.False(GinkgoT(), found)
		})
		It("default network for with single network", func() {

			networks := Networks{
				"bosh": Network{
					Dns: []string{"xx.xx.xx.xx"},
				},
			}

			settings, found := networks.DefaultNetworkFor("dns")
			assert.True(GinkgoT(), found)
			assert.Equal(GinkgoT(), settings, networks["bosh"])
		})
		It("default network for with multiple networks and default is found for dns", func() {

			networks := Networks{
				"bosh": Network{
					Default: []string{"dns"},
					Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
				},
				"vip": Network{
					Default: []string{},
					Dns:     []string{"aa.aa.aa.aa"},
				},
			}

			settings, found := networks.DefaultNetworkFor("dns")
			assert.True(GinkgoT(), found)
			assert.Equal(GinkgoT(), settings, networks["bosh"])
		})
		It("default network for with multiple networks and default is not found", func() {

			networks := Networks{
				"bosh": Network{
					Default: []string{"foo"},
					Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
				},
				"vip": Network{
					Default: []string{},
					Dns:     []string{"aa.aa.aa.aa"},
				},
			}

			_, found := networks.DefaultNetworkFor("dns")
			assert.False(GinkgoT(), found)
		})
		It("default ip with two networks", func() {

			networks := Networks{
				"bosh": Network{
					Ip: "xx.xx.xx.xx",
				},
				"vip": Network{
					Ip: "aa.aa.aa.aa",
				},
			}

			ip, found := networks.DefaultIp()
			assert.True(GinkgoT(), found)
			assert.Equal(GinkgoT(), "xx.xx.xx.xx", ip)
		})
		It("default ip with two networks only with defaults", func() {

			networks := Networks{
				"bosh": Network{
					Ip: "xx.xx.xx.xx",
				},
				"vip": Network{
					Ip:      "aa.aa.aa.aa",
					Default: []string{"dns"},
				},
			}

			ip, found := networks.DefaultIp()
			assert.True(GinkgoT(), found)
			assert.Equal(GinkgoT(), "aa.aa.aa.aa", ip)
		})
		It("default ip when none specified", func() {

			networks := Networks{
				"bosh": Network{},
				"vip": Network{
					Default: []string{"dns"},
				},
			}

			_, found := networks.DefaultIp()
			assert.False(GinkgoT(), found)
		})
	})
}
