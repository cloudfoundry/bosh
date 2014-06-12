package applyspec_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/applyspec"
	boshassert "bosh/assert"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("concreteV1Service", func() {
		var (
			fs       *fakesys.FakeFileSystem
			specPath = "/spec.json"
			service  V1Service
		)

		BeforeEach(func() {
			fs = fakesys.NewFakeFileSystem()
			service = NewConcreteV1Service(fs, specPath)
		})

		Describe("Get", func() {
			Context("when filesystem has a spec file", func() {
				BeforeEach(func() {
					fs.WriteFileString(specPath, `{"deployment":"fake-deployment-name"}`)
				})

				It("reads spec from filesystem", func() {
					spec, err := service.Get()
					Expect(err).ToNot(HaveOccurred())
					Expect(spec).To(Equal(V1ApplySpec{Deployment: "fake-deployment-name"}))
				})

				It("returns error if reading spec from filesystem errs", func() {
					fs.ReadFileError = errors.New("fake-read-error")

					spec, err := service.Get()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-read-error"))
					Expect(spec).To(Equal(V1ApplySpec{}))
				})
			})

			Context("when filesystem does not have a spec file", func() {
				It("reads spec from filesystem", func() {
					spec, err := service.Get()
					Expect(err).ToNot(HaveOccurred())
					Expect(spec).To(Equal(V1ApplySpec{}))
				})
			})
		})

		Describe("Set", func() {
			newSpec := V1ApplySpec{Deployment: "fake-deployment-name"}

			It("writes spec to filesystem", func() {
				err := service.Set(newSpec)
				Expect(err).ToNot(HaveOccurred())

				specPathStats := fs.GetFileTestStat(specPath)
				Expect(specPathStats).ToNot(BeNil())
				boshassert.MatchesJSONBytes(GinkgoT(), newSpec, specPathStats.Content)
			})

			It("returns error if writing spec to filesystem errs", func() {
				fs.WriteToFileError = errors.New("fake-write-error")

				err := service.Set(newSpec)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-write-error"))
			})
		})

		Describe("PopulateDynamicNetworks", func() {
			Context("when there are no dynamic networks", func() {
				unresolvedSpec := V1ApplySpec{
					Deployment: "fake-deployment",
					NetworkSpecs: map[string]NetworkSpec{
						"fake-net": NetworkSpec{
							Fields: map[string]interface{}{"ip": "fake-net-ip"},
						},
					},
				}

				It("returns spec without modifying any networks", func() {
					spec, err := service.PopulateDynamicNetworks(unresolvedSpec, boshsettings.Settings{})
					Expect(err).ToNot(HaveOccurred())
					Expect(spec).To(Equal(V1ApplySpec{
						Deployment: "fake-deployment",
						NetworkSpecs: map[string]NetworkSpec{
							"fake-net": NetworkSpec{
								Fields: map[string]interface{}{"ip": "fake-net-ip"},
							},
						},
					}))
				})
			})

			Context("when there are dynamic networks", func() {
				unresolvedSpec := V1ApplySpec{
					Deployment: "fake-deployment",
					NetworkSpecs: map[string]NetworkSpec{
						"fake-net1": NetworkSpec{
							Fields: map[string]interface{}{
								"ip":      "fake-net1-ip",
								"netmask": "fake-net1-netmask",
								"gateway": "fake-net1-gateway",
							},
						},
						"fake-net2": NetworkSpec{
							Fields: map[string]interface{}{
								"type":    NetworkSpecTypeDynamic,
								"ip":      "fake-net2-ip",
								"netmask": "fake-net2-netmask",
								"gateway": "fake-net2-gateway",
							},
						},
						"fake-net3": NetworkSpec{
							Fields: map[string]interface{}{
								"type":    NetworkSpecTypeDynamic,
								"ip":      "fake-net3-ip",
								"netmask": "fake-net3-netmask",
								"gateway": "fake-net3-gateway",
							},
						},
					},
				}

				Context("when associated network is in settings", func() {
					settings := boshsettings.Settings{
						Networks: boshsettings.Networks{
							"fake-net1": boshsettings.Network{
								IP:      "fake-resolved1-ip",
								Netmask: "fake-resolved1-netmask",
								Gateway: "fake-resolved1-gateway",
							},
							"fake-net2": boshsettings.Network{
								IP:      "fake-resolved2-ip",
								Netmask: "fake-resolved2-netmask",
								Gateway: "fake-resolved2-gateway",
							},
							"fake-net3": boshsettings.Network{
								IP:      "fake-resolved3-ip",
								Netmask: "fake-resolved3-netmask",
								Gateway: "fake-resolved3-gateway",
							},
						},
					}

					It("returns spec with modified dynamic networks and keeping everything else the same", func() {
						spec, err := service.PopulateDynamicNetworks(unresolvedSpec, settings)
						Expect(err).ToNot(HaveOccurred())
						Expect(spec).To(Equal(V1ApplySpec{
							Deployment: "fake-deployment",
							NetworkSpecs: map[string]NetworkSpec{
								"fake-net1": NetworkSpec{
									Fields: map[string]interface{}{ // ip info not replaced
										"ip":      "fake-net1-ip",
										"netmask": "fake-net1-netmask",
										"gateway": "fake-net1-gateway",
									},
								},
								"fake-net2": NetworkSpec{
									Fields: map[string]interface{}{
										"type":    NetworkSpecTypeDynamic,
										"ip":      "fake-resolved2-ip",
										"netmask": "fake-resolved2-netmask",
										"gateway": "fake-resolved2-gateway",
									},
								},
								"fake-net3": NetworkSpec{
									Fields: map[string]interface{}{
										"type":    NetworkSpecTypeDynamic,
										"ip":      "fake-resolved3-ip",
										"netmask": "fake-resolved3-netmask",
										"gateway": "fake-resolved3-gateway",
									},
								},
							},
						}))
					})
				})

				Context("when associated network cannot be found in settings", func() {
					It("returns error", func() {
						spec, err := service.PopulateDynamicNetworks(unresolvedSpec, boshsettings.Settings{})
						Expect(err).To(Equal(errors.New("Network fake-net2 is not found in settings")))
						Expect(spec).To(Equal(V1ApplySpec{}))
					})
				})
			})
		})
	})
}
