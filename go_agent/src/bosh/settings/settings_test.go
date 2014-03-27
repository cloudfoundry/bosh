package settings_test

import (
	"encoding/json"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/settings"
)

func init() {
	Describe("Networks", func() {
		Describe("DefaultNetworkFor", func() {
			It("when networks is empty", func() {
				networks := Networks{}
				_, found := networks.DefaultNetworkFor("dns")
				Expect(found).To(BeFalse())
			})

			It("with single network", func() {
				networks := Networks{
					"bosh": Network{
						Dns: []string{"xx.xx.xx.xx"},
					},
				}

				settings, found := networks.DefaultNetworkFor("dns")
				Expect(found).To(BeTrue())
				Expect(settings).To(Equal(networks["bosh"]))
			})

			It("with multiple networks and default is found for dns", func() {
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
				Expect(found).To(BeTrue())
				Expect(settings).To(Equal(networks["bosh"]))
			})

			It("with multiple networks and default is not found", func() {
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
				Expect(found).To(BeFalse())
			})
		})

		Describe("DefaultIp", func() {
			It("with two networks", func() {
				networks := Networks{
					"bosh": Network{
						Ip: "xx.xx.xx.xx",
					},
					"vip": Network{
						Ip: "aa.aa.aa.aa",
					},
				}

				ip, found := networks.DefaultIp()
				Expect(found).To(BeTrue())
				Expect(ip).To(Equal("xx.xx.xx.xx"))
			})

			It("with two networks only with defaults", func() {
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
				Expect(found).To(BeTrue())
				Expect(ip).To(Equal("aa.aa.aa.aa"))
			})

			It("when none specified", func() {
				networks := Networks{
					"bosh": Network{},
					"vip": Network{
						Default: []string{"dns"},
					},
				}

				_, found := networks.DefaultIp()
				Expect(found).To(BeFalse())
			})
		})
	})

	Describe("Settings", func() {
		var expectSnakeCaseKeys func(map[string]interface{})

		expectSnakeCaseKeys = func(value map[string]interface{}) {
			for k, v := range value {
				Expect(k).To(MatchRegexp("\\A[a-z0-9_]+\\z"))

				tv, isMap := v.(map[string]interface{})
				if isMap {
					expectSnakeCaseKeys(tv)
				}
			}
		}

		It("marshals into JSON in snake case to stay consistent with CPI agent env formatting", func() {
			settings := Settings{}
			settingsJson, err := json.Marshal(settings)
			Expect(err).NotTo(HaveOccurred())

			var settingsMap map[string]interface{}
			err = json.Unmarshal(settingsJson, &settingsMap)
			Expect(err).NotTo(HaveOccurred())
			expectSnakeCaseKeys(settingsMap)
		})
	})
}
