package applyspec_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/applier/applyspec"
	boshassert "bosh/assert"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("concreteV1Service", func() {
		var (
			fs       *fakesys.FakeFileSystem
			platform *fakeplatform.FakePlatform
			specPath = "/spec.json"
			service  V1Service
		)

		BeforeEach(func() {
			fs = fakesys.NewFakeFileSystem()
			platform = fakeplatform.NewFakePlatform()
			service = NewConcreteV1Service(fs, platform, specPath)
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

		Describe("ResolveDynamicNetworks", func() {
			Context("when there is are no dynamic networks", func() {
				unresolvedSpec := V1ApplySpec{
					Deployment: "fake-deployment",
					NetworkSpecs: map[string]NetworkSpec{
						"fake-net": NetworkSpec{
							Fields: map[string]interface{}{"ip": "fake-net-ip"},
						},
					},
				}

				It("returns spec without modifying any networks", func() {
					spec, err := service.ResolveDynamicNetworks(unresolvedSpec)
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

			Context("when there is one dynamic network", func() {
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
					},
				}

				Context("when default network can be retrieved", func() {
					BeforeEach(func() {
						platform.GetDefaultNetworkNetwork = boshsettings.Network{
							IP:      "fake-resolved-ip",
							Netmask: "fake-resolved-netmask",
							Gateway: "fake-resolved-gateway",
						}
					})

					It("returns spec with modified dynamic network and keeping everything else the same", func() {
						spec, err := service.ResolveDynamicNetworks(unresolvedSpec)
						Expect(err).ToNot(HaveOccurred())
						Expect(spec).To(Equal(V1ApplySpec{
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
										"ip":      "fake-resolved-ip",
										"netmask": "fake-resolved-netmask",
										"gateway": "fake-resolved-gateway",
									},
								},
							},
						}))
					})
				})

				Context("when default network fails to be retrieved", func() {
					BeforeEach(func() {
						platform.GetDefaultNetworkErr = errors.New("fake-get-default-network-err")
					})

					It("returns error", func() {
						spec, err := service.ResolveDynamicNetworks(unresolvedSpec)
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-get-default-network-err"))
						Expect(spec).To(Equal(V1ApplySpec{}))
					})
				})
			})

			Context("when there is are multiple dynamic networks", func() {
				unresolvedSpec := V1ApplySpec{
					NetworkSpecs: map[string]NetworkSpec{
						"fake-net1": NetworkSpec{
							Fields: map[string]interface{}{"type": NetworkSpecTypeDynamic},
						},
						"fake-net2": NetworkSpec{
							Fields: map[string]interface{}{"type": NetworkSpecTypeDynamic},
						},
					},
				}

				It("returns error because multiple dynamic networks are not supported", func() {
					spec, err := service.ResolveDynamicNetworks(unresolvedSpec)
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("Multiple dynamic networks are not supported"))
					Expect(spec).To(Equal(V1ApplySpec{}))
				})
			})
		})
	})
}
