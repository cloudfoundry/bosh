package infrastructure_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	fakeinf "bosh/infrastructure/fakes"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
)

func init() {
	var (
		metadataService    MetadataService
		registry           Registry
		platform           *fakeplatform.FakePlatform
		devicePathResolver *fakedpresolv.FakeDevicePathResolver
	)

	BeforeEach(func() {
		metadataService = NewConcreteMetadataService("fake-metadata-host", &fakeinf.FakeDNSResolver{})
		registry = NewConcreteRegistry(metadataService)
		platform = fakeplatform.NewFakePlatform()
		devicePathResolver = fakedpresolv.NewFakeDevicePathResolver()
	})

	Describe("AWS Infrastructure", func() {
		Describe("SetupSsh", func() {
			var (
				ts  *httptest.Server
				aws Infrastructure
			)

			const expectedKey = "some public key"

			BeforeEach(func() {
				handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					Expect(r.Method).To(Equal("GET"))
					Expect(r.URL.Path).To(Equal("/latest/meta-data/public-keys/0/openssh-key"))
					w.Write([]byte(expectedKey))
				})
				ts = httptest.NewServer(handler)
			})

			AfterEach(func() {
				ts.Close()
			})

			It("gets the public key and sets up ssh via the platform", func() {
				metadataService = NewConcreteMetadataService(ts.URL, &fakeinf.FakeDNSResolver{})

				aws = NewAwsInfrastructure(
					metadataService,
					registry,
					platform,
					devicePathResolver,
				)

				err := aws.SetupSsh("vcap")
				Expect(err).NotTo(HaveOccurred())

				Expect(platform.SetupSshPublicKey).To(Equal(expectedKey))
				Expect(platform.SetupSshUsername).To(Equal("vcap"))
			})
		})

		Describe("GetSettings", func() {
			var (
				settingsJSON     string
				expectedSettings boshsettings.Settings
			)

			BeforeEach(func() {
				settingsJSON = `{
					"agent_id": "my-agent-id",
					"blobstore": {
						"options": {
							"bucket_name": "george",
							"encryption_key": "optional encryption key",
							"access_key_id": "optional access key id",
							"secret_access_key": "optional secret access key"
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

				expectedSettings = boshsettings.Settings{
					AgentID: "my-agent-id",
					Blobstore: boshsettings.Blobstore{
						Options: map[string]string{
							"bucket_name":       "george",
							"encryption_key":    "optional encryption key",
							"access_key_id":     "optional access key id",
							"secret_access_key": "optional secret access key",
						},
						Type: "s3",
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
			})

			Context("when a dns is not provided", func() {
				It("aws get settings", func() {
					boshRegistryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))
						Expect(r.URL.Path).To(Equal("/instances/123-456-789/settings"))
						w.Write([]byte(settingsJSON))
					})

					registryTs := httptest.NewServer(boshRegistryHandler)
					defer registryTs.Close()

					expectedUserData := fmt.Sprintf(`{"registry":{"endpoint":"%s"}}`, registryTs.URL)

					instanceID := "123-456-789"

					awsMetaDataHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))

						switch r.URL.Path {
						case "/latest/user-data":
							w.Write([]byte(expectedUserData))
						case "/latest/meta-data/instance-id":
							w.Write([]byte(instanceID))
						}
					})

					metadataTs := httptest.NewServer(awsMetaDataHandler)
					defer metadataTs.Close()

					metadataService = NewConcreteMetadataService(metadataTs.URL, &fakeinf.FakeDNSResolver{})

					registry = NewConcreteRegistry(metadataService)

					platform := fakeplatform.NewFakePlatform()

					aws := NewAwsInfrastructure(metadataService, registry, platform, devicePathResolver)

					settings, err := aws.GetSettings()
					Expect(err).NotTo(HaveOccurred())
					Expect(settings).To(Equal(expectedSettings))
				})
			})

			Context("when dns servers are provided", func() {
				It("aws get settings", func() {
					fakeDNSResolver := &fakeinf.FakeDNSResolver{}

					fakeDNSResolver.RegisterRecord(fakeinf.FakeDNSRecord{
						DNSServers: []string{"8.8.8.8", "9.9.9.9"},
						Host:       "the.registry.name",
						IP:         "127.0.0.1",
					})

					registryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))
						Expect(r.URL.Path).To(Equal("/instances/123-456-789/settings"))
						w.Write([]byte(settingsJSON))
					})

					registryTs := httptest.NewServer(registryHandler)

					registryURL, err := url.Parse(registryTs.URL)
					Expect(err).NotTo(HaveOccurred())
					registryTsPort := strings.Split(registryURL.Host, ":")[1]
					defer registryTs.Close()

					expectedUserData := fmt.Sprintf(`
						{
							"registry":{
								"endpoint":"http://the.registry.name:%s"
							},
							"dns":{
								"nameserver": ["8.8.8.8", "9.9.9.9"]
							}
						}`, registryTsPort)

					instanceID := "123-456-789"

					awsMetaDataHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))

						switch r.URL.Path {
						case "/latest/user-data":
							w.Write([]byte(expectedUserData))
						case "/latest/meta-data/instance-id":
							w.Write([]byte(instanceID))
						}
					})

					metadataTs := httptest.NewServer(awsMetaDataHandler)
					defer metadataTs.Close()

					metadataService = NewConcreteMetadataService(metadataTs.URL, fakeDNSResolver)

					registry = NewConcreteRegistry(metadataService)

					platform := fakeplatform.NewFakePlatform()

					aws := NewAwsInfrastructure(metadataService, registry, platform, devicePathResolver)

					settings, err := aws.GetSettings()
					Expect(err).NotTo(HaveOccurred())
					Expect(settings).To(Equal(expectedSettings))
				})
			})
		})

		Describe("SetupNetworking", func() {
			It("sets up DHCP on the platform", func() {
				platform := fakeplatform.NewFakePlatform()
				aws := NewAwsInfrastructure(metadataService, registry, platform, devicePathResolver)
				networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

				aws.SetupNetworking(networks)

				Expect(platform.SetupDhcpNetworks).To(Equal(networks))
			})
		})

		Describe("GetEphemeralDiskPath", func() {
			It("returns the real disk path given an AWS EBS hint", func() {
				platform := fakeplatform.NewFakePlatform()
				aws := NewAwsInfrastructure(metadataService, registry, platform, devicePathResolver)

				platform.NormalizeDiskPathRealPath = "/dev/xvdb"
				platform.NormalizeDiskPathFound = true

				realPath, found := aws.GetEphemeralDiskPath("/dev/sdb")

				Expect(found).To(Equal(true))
				Expect(realPath).To(Equal("/dev/xvdb"))
				Expect(platform.NormalizeDiskPathPath).To(Equal("/dev/sdb"))
			})
		})
	})
}
