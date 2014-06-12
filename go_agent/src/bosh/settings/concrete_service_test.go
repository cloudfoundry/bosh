package settings_test

import (
	"encoding/json"
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshlog "bosh/logger"
	fakeplatform "bosh/platform/fakes"
	. "bosh/settings"
	fakesys "bosh/system/fakes"
)

func init() {
	Describe("concreteServiceProvider", func() {
		var (
			platform *fakeplatform.FakePlatform
		)

		Describe("NewService", func() {
			It("returns service with settings.json as its settings path", func() {
				// Cannot compare fetcher functions since function comparison is problematic
				fs := fakesys.NewFakeFileSystem()
				logger := boshlog.NewLogger(boshlog.LevelNone)
				service := NewServiceProvider().NewService(fs, "/setting/path", nil, platform, logger)
				Expect(service).To(Equal(NewService(fs, "/setting/path/settings.json", nil, platform, logger)))
			})
		})
	})

	Describe("concreteService", func() {
		var (
			fs       *fakesys.FakeFileSystem
			platform *fakeplatform.FakePlatform
		)

		BeforeEach(func() {
			fs = fakesys.NewFakeFileSystem()
			platform = fakeplatform.NewFakePlatform()
		})

		buildService := func(fetcher SettingsFetcher) (Service, *fakesys.FakeFileSystem) {
			logger := boshlog.NewLogger(boshlog.LevelNone)
			service := NewService(fs, "/setting/path", fetcher, platform, logger)
			return service, fs
		}

		Describe("LoadSettings", func() {
			var (
				fetchedSettings Settings
				fetcherFuncErr  error
				service         Service
			)

			BeforeEach(func() {
				fetchedSettings = Settings{}
				fetcherFuncErr = nil
			})

			JustBeforeEach(func() {
				fetcherFunc := func() (Settings, error) { return fetchedSettings, fetcherFuncErr }
				service, fs = buildService(fetcherFunc)
			})

			Context("when settings fetcher succeeds fetching settings", func() {
				BeforeEach(func() {
					fetchedSettings = Settings{AgentID: "some-new-agent-id"}
				})

				Context("when settings contain at most one dynamic network", func() {
					BeforeEach(func() {
						fetchedSettings.Networks = Networks{
							"fake-net-1": Network{Type: NetworkTypeDynamic},
						}
					})

					It("updates the service with settings from the fetcher", func() {
						err := service.LoadSettings()
						Expect(err).NotTo(HaveOccurred())
						Expect(service.GetSettings().AgentID).To(Equal("some-new-agent-id"))
					})

					It("persists settings to the settings file", func() {
						err := service.LoadSettings()
						Expect(err).NotTo(HaveOccurred())

						json, err := json.Marshal(fetchedSettings)
						Expect(err).NotTo(HaveOccurred())

						fileContent, err := fs.ReadFile("/setting/path")
						Expect(err).NotTo(HaveOccurred())
						Expect(fileContent).To(Equal(json))
					})

					It("returns any error from writing to the setting file", func() {
						fs.WriteToFileError = errors.New("fs-write-file-error")

						err := service.LoadSettings()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fs-write-file-error"))
					})
				})

				Context("when settings contain multiple dynamic networks", func() {
					BeforeEach(func() {
						fetchedSettings.Networks = Networks{
							"fake-net-1": Network{Type: NetworkTypeDynamic},
							"fake-net-2": Network{Type: NetworkTypeDynamic},
						}
					})

					It("returns error because multiple dynamic networks are not supported", func() {
						err := service.LoadSettings()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("Multiple dynamic networks are not supported"))
					})
				})
			})

			Context("when settings fetcher fails fetching settings", func() {
				BeforeEach(func() {
					fetcherFuncErr = errors.New("fake-fetch-error")
				})

				Context("when a settings file exists", func() {
					Context("when settings contain at most one dynamic network", func() {
						BeforeEach(func() {
							fs.WriteFile("/setting/path", []byte(`{
								"agent_id":"some-agent-id",
								"networks": {"fake-net-1": {"type": "dynamic"}}
							}`))
						})

						It("returns settings from the settings file", func() {
							err := service.LoadSettings()
							Expect(err).ToNot(HaveOccurred())
							Expect(service.GetSettings()).To(Equal(Settings{
								AgentID: "some-agent-id",
								Networks: Networks{
									"fake-net-1": Network{Type: NetworkTypeDynamic},
								},
							}))
						})
					})

					Context("when settings contain multiple dynamic networks", func() {
						BeforeEach(func() {
							fs.WriteFile("/setting/path", []byte(`{
								"agent_id":"some-agent-id",
								"networks": {
									"fake-net-1": {"type": "dynamic"},
									"fake-net-2": {"type": "dynamic"}
								}
							}`))
						})

						It("returns error because multiple dynamic networks are not supported", func() {
							err := service.LoadSettings()
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("Multiple dynamic networks are not supported"))
						})
					})
				})

				Context("when non-unmarshallable settings file exists", func() {
					It("returns any error from the fetcher", func() {
						fs.WriteFile("/setting/path", []byte(`$%^&*(`))

						err := service.LoadSettings()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-fetch-error"))

						Expect(service.GetSettings()).To(Equal(Settings{}))
					})
				})

				Context("when no settings file exists", func() {
					It("returns any error from the fetcher", func() {
						err := service.LoadSettings()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-fetch-error"))

						Expect(service.GetSettings()).To(Equal(Settings{}))
					})
				})
			})
		})

		Describe("InvalidateSettings", func() {
			It("removes the settings file", func() {
				service, fs := buildService(nil)

				fs.WriteFile("/setting/path", []byte(`{}`))

				err := service.InvalidateSettings()
				Expect(err).ToNot(HaveOccurred())

				Expect(fs.FileExists("/setting/path")).To(BeFalse())
			})

			It("returns err if removing settings file errored", func() {
				service, fs := buildService(nil)

				fs.RemoveAllError = errors.New("fs-remove-all-error")

				err := service.InvalidateSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fs-remove-all-error"))
			})
		})

		Describe("GetSettings", func() {
			var (
				loadedSettings Settings
				service        Service
			)

			BeforeEach(func() {
				loadedSettings = Settings{AgentID: "some-agent-id"}
			})

			JustBeforeEach(func() {
				service, _ = buildService(func() (Settings, error) { return loadedSettings, nil })
				err := service.LoadSettings()
				Expect(err).NotTo(HaveOccurred())
			})

			Context("when there is are no dynamic networks", func() {
				It("returns settings without modifying any networks", func() {
					Expect(service.GetSettings()).To(Equal(loadedSettings))
				})

				It("does not try to determine default network", func() {
					_ = service.GetSettings()
					Expect(platform.GetDefaultNetworkCalled).To(BeFalse())
				})
			})

			Context("when there is one dynamic network", func() {
				BeforeEach(func() {
					loadedSettings = Settings{
						Networks: map[string]Network{
							"fake-net1": Network{
								IP:      "fake-net1-ip",
								Netmask: "fake-net1-netmask",
								Gateway: "fake-net1-gateway",
							},
							"fake-net2": Network{
								Type:    "dynamic",
								IP:      "fake-net2-ip",
								Netmask: "fake-net2-netmask",
								Gateway: "fake-net2-gateway",
								DNS:     []string{"fake-net2-dns"},
							},
						},
					}
				})

				Context("when default network can be retrieved", func() {
					BeforeEach(func() {
						platform.GetDefaultNetworkNetwork = Network{
							IP:      "fake-resolved-ip",
							Netmask: "fake-resolved-netmask",
							Gateway: "fake-resolved-gateway",
						}
					})

					It("returns settings with resolved dynamic network ip, netmask, gateway and keeping everything else the same", func() {
						settings := service.GetSettings()
						Expect(settings).To(Equal(Settings{
							Networks: map[string]Network{
								"fake-net1": Network{
									IP:      "fake-net1-ip",
									Netmask: "fake-net1-netmask",
									Gateway: "fake-net1-gateway",
								},
								"fake-net2": Network{
									Type:    "dynamic",
									IP:      "fake-resolved-ip",
									Netmask: "fake-resolved-netmask",
									Gateway: "fake-resolved-gateway",
									DNS:     []string{"fake-net2-dns"},
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
						settings := service.GetSettings()
						Expect(settings).To(Equal(loadedSettings))
					})
				})
			})
		})
	})
}
