package infrastructure_test

import (
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	fakeinf "bosh/infrastructure/fakes"
	boshsettings "bosh/settings"
)

var _ = Describe("concreteRegistry", func() {
	var (
		metadataService *fakeinf.FakeMetadataService
		registry        Registry
	)

	BeforeEach(func() {
		metadataService = &fakeinf.FakeMetadataService{}
		registry = NewConcreteRegistry(metadataService, false)
	})

	Describe("GetSettings", func() {
		var (
			ts           *httptest.Server
			settingsJSON string
		)

		BeforeEach(func() {
			boshRegistryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				GinkgoRecover()

				Expect(r.Method).To(Equal("GET"))
				Expect(r.URL.Path).To(Equal("/instances/fake-identifier/settings"))

				w.Write([]byte(settingsJSON))
			})

			ts = httptest.NewServer(boshRegistryHandler)
		})

		AfterEach(func() {
			ts.Close()
		})

		Context("when registry is configured to not use server name as id", func() {
			BeforeEach(func() {
				registry = NewConcreteRegistry(metadataService, false)
				metadataService.InstanceID = "fake-identifier"
				metadataService.RegistryEndpoint = ts.URL
			})

			It("returns settings fetched from http server based on instance id", func() {
				settingsJSON = `{"settings": "{\"agent_id\":\"my-agent-id\"}"}`

				settings, err := registry.GetSettings()
				Expect(err).ToNot(HaveOccurred())
				Expect(settings).To(Equal(boshsettings.Settings{AgentID: "my-agent-id"}))
			})

			It("returns error if registry settings wrapper cannot be parsed", func() {
				settingsJSON = "invalid-json"

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Unmarshalling settings wrapper"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})

			It("returns error if registry settings wrapper contains invalid json", func() {
				settingsJSON = `{"settings": "invalid-json"}`

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Unmarshalling wrapped settings"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})

			It("returns error if metadata service fails to return instance id", func() {
				metadataService.GetInstanceIDErr = errors.New("fake-get-instance-id-err")

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-instance-id-err"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})

			It("returns error if metadata service fails to return registry endpoint", func() {
				metadataService.GetRegistryEndpointErr = errors.New("fake-get-registry-endpoint-err")

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-registry-endpoint-err"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})

			Describe("setting fields", func() {
				It("unmarshalls JSON properly", func() {
					settingsJSON = `{
						"agent_id": "my-agent-id",
						"blobstore": {
							"options": {
								"bucket_name": "george",
								"encryption_key": "optional encryption key",
								"access_key_id": "optional access key id",
								"secret_access_key": "optional secret access key",
								"port": 443
							},
							"provider": "s3"
						},
						"disks": {
							"ephemeral": "/dev/sdb",
							"persistent": {
								"vol-xxxxxx": "/dev/sdf"
							},
							"system": "/dev/sda1"
						},
						"env": {
							"bosh": {
								"password": "some encrypted password"
							}
						},
						"networks": {
							"netA": {
								"default": ["dns", "gateway"],
								"ip": "ww.ww.ww.ww",
								"dns": [
									"xx.xx.xx.xx",
									"yy.yy.yy.yy"
								]
							},
							"netB": {
								"dns": [
									"zz.zz.zz.zz"
								]
							}
						},
						"mbus": "https://vcap:b00tstrap@0.0.0.0:6868",
						"ntp": [
							"0.north-america.pool.ntp.org",
							"1.north-america.pool.ntp.org"
						],
						"vm": {
							"name": "vm-abc-def"
						}
					}`
					settingsJSON = strings.Replace(settingsJSON, `"`, `\"`, -1)
					settingsJSON = strings.Replace(settingsJSON, "\n", "", -1)
					settingsJSON = strings.Replace(settingsJSON, "\t", "", -1)
					settingsJSON = fmt.Sprintf(`{"settings": "%s"}`, settingsJSON)

					expectedSettings := boshsettings.Settings{
						AgentID: "my-agent-id",
						Blobstore: boshsettings.Blobstore{
							Type: "s3",
							Options: map[string]interface{}{
								"bucket_name":       "george",
								"encryption_key":    "optional encryption key",
								"access_key_id":     "optional access key id",
								"secret_access_key": "optional secret access key",
								"port":              443.0,
							},
						},
						Disks: boshsettings.Disks{
							Ephemeral:  "/dev/sdb",
							Persistent: map[string]string{"vol-xxxxxx": "/dev/sdf"},
							System:     "/dev/sda1",
						},
						Env: boshsettings.Env{
							Bosh: boshsettings.BoshEnv{
								Password: "some encrypted password",
							},
						},
						Networks: boshsettings.Networks{
							"netA": boshsettings.Network{
								Default: []string{"dns", "gateway"},
								IP:      "ww.ww.ww.ww",
								DNS:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy"},
							},
							"netB": boshsettings.Network{
								DNS: []string{"zz.zz.zz.zz"},
							},
						},
						Mbus: "https://vcap:b00tstrap@0.0.0.0:6868",
						Ntp: []string{
							"0.north-america.pool.ntp.org",
							"1.north-america.pool.ntp.org",
						},
						VM: boshsettings.VM{
							Name: "vm-abc-def",
						},
					}

					metadataService.InstanceID = "fake-identifier"
					metadataService.RegistryEndpoint = ts.URL

					settings, err := registry.GetSettings()
					Expect(err).ToNot(HaveOccurred())
					Expect(settings).To(Equal(expectedSettings))
				})
			})
		})

		Context("when registry is configured to use server name as id", func() {
			BeforeEach(func() {
				registry = NewConcreteRegistry(metadataService, true)
				metadataService.ServerName = "fake-identifier"
				metadataService.RegistryEndpoint = ts.URL
			})

			It("returns settings fetched from http server based on server name", func() {
				settingsJSON = `{"settings": "{\"agent_id\":\"my-agent-id\"}"}`

				settings, err := registry.GetSettings()
				Expect(err).ToNot(HaveOccurred())
				Expect(settings).To(Equal(boshsettings.Settings{AgentID: "my-agent-id"}))
			})

			It("returns error if registry settings wrapper cannot be parsed", func() {
				settingsJSON = "invalid-json"

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Unmarshalling settings wrapper"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})

			It("returns error if registry settings wrapper contains invalid json", func() {
				settingsJSON = `{"settings": "invalid-json"}`

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("Unmarshalling wrapped settings"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})

			It("returns error if metadata service fails to return server name", func() {
				metadataService.GetServerNameErr = errors.New("fake-get-server-name-err")

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-server-name-err"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})

			It("returns error if metadata service fails to return registry endpoint", func() {
				metadataService.GetRegistryEndpointErr = errors.New("fake-get-registry-endpoint-err")

				settings, err := registry.GetSettings()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-registry-endpoint-err"))

				Expect(settings).To(Equal(boshsettings.Settings{}))
			})
		})
	})
})
