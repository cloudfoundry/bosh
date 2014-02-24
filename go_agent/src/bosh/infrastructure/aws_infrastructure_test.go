package infrastructure_test

import (
	. "bosh/infrastructure"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	"fmt"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
)

type FakeDnsResolver struct {
	LookupHostIp         string
	LookupHostDnsServers []string
	LookupHostHost       string
}

func (res *FakeDnsResolver) LookupHost(dnsServers []string, host string) (ip string, err error) {
	res.LookupHostDnsServers = dnsServers
	res.LookupHostHost = host
	ip = res.LookupHostIp
	return
}

func init() {
	Describe("AWS Infrastructure", func() {
		Describe("SetupSsh", func() {
			var (
				ts       *httptest.Server
				aws      Infrastructure
				platform *fakeplatform.FakePlatform
			)
			const expectedKey = "some public key"

			BeforeEach(func() {
				handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					Expect(r.Method).To(Equal("GET"))
					Expect(r.URL.Path).To(Equal("/latest/meta-data/public-keys/0/openssh-key"))
					w.Write([]byte(expectedKey))
				})
				ts = httptest.NewServer(handler)
				platform = fakeplatform.NewFakePlatform()
			})

			AfterEach(func() {
				ts.Close()
			})

			It("gets the public key and sets up ssh via the platform", func() {
				aws = NewAwsInfrastructure(ts.URL, &FakeDnsResolver{}, platform)
				err := aws.SetupSsh("vcap")
				Expect(err).NotTo(HaveOccurred())

				Expect(platform.SetupSshPublicKey).To(Equal(expectedKey))
				Expect(platform.SetupSshUsername).To(Equal("vcap"))
			})
		})

		Describe("GetSettings", func() {
			var (
				settingsJson     string
				expectedSettings boshsettings.Settings
			)

			BeforeEach(func() {
				settingsJson = `{
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
				settingsJson = strings.Replace(settingsJson, `"`, `\"`, -1)
				settingsJson = strings.Replace(settingsJson, "\n", "", -1)
				settingsJson = strings.Replace(settingsJson, "\t", "", -1)

				settingsJson = fmt.Sprintf(`{"settings": "%s"}`, settingsJson)

				expectedSettings = boshsettings.Settings{
					AgentId: "my-agent-id",
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
							Ip:      "ww.ww.ww.ww",
							Dns:     []string{"xx.xx.xx.xx", "yy.yy.yy.yy"},
						},
						"netB": boshsettings.Network{
							Dns: []string{"zz.zz.zz.zz"},
						},
					},
					Mbus: "https://vcap:b00tstrap@0.0.0.0:6868",
					Ntp: []string{
						"0.north-america.pool.ntp.org",
						"1.north-america.pool.ntp.org",
					},
					Vm: boshsettings.Vm{
						Name: "vm-abc-def",
					},
				}
			})

			Context("when a dns is not provided", func() {
				It("aws get settings", func() {
					boshRegistryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))
						Expect(r.URL.Path).To(Equal("/instances/123-456-789/settings"))
						w.Write([]byte(settingsJson))
					})

					registryTs := httptest.NewServer(boshRegistryHandler)
					defer registryTs.Close()

					expectedUserData := fmt.Sprintf(`{"registry":{"endpoint":"%s"}}`, registryTs.URL)

					instanceId := "123-456-789"

					awsMetaDataHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))

						switch r.URL.Path {
						case "/latest/user-data":
							w.Write([]byte(expectedUserData))
						case "/latest/meta-data/instance-id":
							w.Write([]byte(instanceId))
						}
					})

					metadataTs := httptest.NewServer(awsMetaDataHandler)
					defer metadataTs.Close()

					platform := fakeplatform.NewFakePlatform()

					aws := NewAwsInfrastructure(metadataTs.URL, &FakeDnsResolver{}, platform)

					settings, err := aws.GetSettings()
					Expect(err).NotTo(HaveOccurred())
					Expect(settings).To(Equal(expectedSettings))
				})

			})

			Context("when dns servers are provided", func() {
				It("aws get settings", func() {

					fakeDnsResolver := &FakeDnsResolver{
						LookupHostIp: "127.0.0.1",
					}

					registryHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))
						Expect(r.URL.Path).To(Equal("/instances/123-456-789/settings"))
						w.Write([]byte(settingsJson))
					})

					registryTs := httptest.NewServer(registryHandler)

					registryUrl, err := url.Parse(registryTs.URL)
					Expect(err).NotTo(HaveOccurred())
					registryTsPort := strings.Split(registryUrl.Host, ":")[1]
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

					instanceId := "123-456-789"

					awsMetaDataHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
						Expect(r.Method).To(Equal("GET"))

						switch r.URL.Path {
						case "/latest/user-data":
							w.Write([]byte(expectedUserData))
						case "/latest/meta-data/instance-id":
							w.Write([]byte(instanceId))
						}
					})

					metadataTs := httptest.NewServer(awsMetaDataHandler)
					defer metadataTs.Close()

					platform := fakeplatform.NewFakePlatform()

					aws := NewAwsInfrastructure(metadataTs.URL, fakeDnsResolver, platform)

					settings, err := aws.GetSettings()
					Expect(err).NotTo(HaveOccurred())
					Expect(settings).To(Equal(expectedSettings))
					Expect(fakeDnsResolver.LookupHostHost).To(Equal("the.registry.name"))
					Expect(fakeDnsResolver.LookupHostDnsServers).To(Equal([]string{"8.8.8.8", "9.9.9.9"}))
				})
			})
		})

		It("aws setup networking", func() {

			fakeDnsResolver := &FakeDnsResolver{}
			platform := fakeplatform.NewFakePlatform()
			aws := NewAwsInfrastructure("", fakeDnsResolver, platform)
			networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

			aws.SetupNetworking(networks)

			Expect(platform.SetupDhcpNetworks).To(Equal(networks))
		})
		It("aws get ephemeral disk path", func() {

			fakeDnsResolver := &FakeDnsResolver{}
			platform := fakeplatform.NewFakePlatform()
			aws := NewAwsInfrastructure("", fakeDnsResolver, platform)

			platform.NormalizeDiskPathRealPath = "/dev/xvdb"
			platform.NormalizeDiskPathFound = true

			realPath, found := aws.GetEphemeralDiskPath("/dev/sdb")

			Expect(found).To(Equal(true))
			Expect(realPath).To(Equal("/dev/xvdb"))
			Expect(platform.NormalizeDiskPathPath).To(Equal("/dev/sdb"))
		})
	})
}
