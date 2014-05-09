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
						DNS: []string{"xx.xx.xx.xx"},
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
						DNS:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
					},
					"vip": Network{
						Default: []string{},
						DNS:     []string{"aa.aa.aa.aa"},
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
						DNS:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy", "zz.zz.zz.zz"},
					},
					"vip": Network{
						Default: []string{},
						DNS:     []string{"aa.aa.aa.aa"},
					},
				}

				_, found := networks.DefaultNetworkFor("dns")
				Expect(found).To(BeFalse())
			})
		})

		Describe("DefaultIP", func() {
			It("with two networks", func() {
				networks := Networks{
					"bosh": Network{
						IP: "xx.xx.xx.xx",
					},
					"vip": Network{
						IP: "aa.aa.aa.aa",
					},
				}

				ip, found := networks.DefaultIP()
				Expect(found).To(BeTrue())
				Expect(ip).To(Equal("xx.xx.xx.xx"))
			})

			It("with two networks only with defaults", func() {
				networks := Networks{
					"bosh": Network{
						IP: "xx.xx.xx.xx",
					},
					"vip": Network{
						IP:      "aa.aa.aa.aa",
						Default: []string{"dns"},
					},
				}

				ip, found := networks.DefaultIP()
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

				_, found := networks.DefaultIP()
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
			settingsJSON, err := json.Marshal(settings)
			Expect(err).NotTo(HaveOccurred())

			var settingsMap map[string]interface{}
			err = json.Unmarshal(settingsJSON, &settingsMap)
			Expect(err).NotTo(HaveOccurred())
			expectSnakeCaseKeys(settingsMap)
		})

		It("allows different types for blobstore option values", func() {
			var settings Settings
			settingsJSON := `{"blobstore":{"options":{"string":"value", "int":443, "bool":true, "map":{}}}}`

			err := json.Unmarshal([]byte(settingsJSON), &settings)
			Expect(err).NotTo(HaveOccurred())
			Expect(settings.Blobstore.Options).To(Equal(map[string]interface{}{
				"string": "value",
				"int":    443.0,
				"bool":   true,
				"map":    map[string]interface{}{},
			}))
		})
	})
}
