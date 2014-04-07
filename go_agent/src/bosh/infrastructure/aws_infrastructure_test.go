package infrastructure_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	fakedpresolv "bosh/infrastructure/devicepathresolver/fakes"
	boshdisk "bosh/platform/disk"
	fakeplatform "bosh/platform/fakes"
	boshsettings "bosh/settings"
	fakesys "bosh/system/fakes"
)

type FakeDNSResolver struct {
	LookupHostIP         string
	LookupHostDNSServers []string
	LookupHostHost       string
}

func (res *FakeDNSResolver) LookupHost(dnsServers []string, host string) (ip string, err error) {
	res.LookupHostDNSServers = dnsServers
	res.LookupHostHost = host
	ip = res.LookupHostIP
	return
}

func init() {
	var (
		platform               *fakeplatform.FakePlatform
		fakeDevicePathResolver *fakedpresolv.FakeDevicePathResolver
	)

	BeforeEach(func() {
		platform = fakeplatform.NewFakePlatform()
		fakeDevicePathResolver = fakedpresolv.NewFakeDevicePathResolver(
			1*time.Millisecond,
			platform.GetFs(),
		)
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
				aws = NewAwsInfrastructure(ts.URL, &FakeDNSResolver{}, platform, fakeDevicePathResolver)
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

					platform := fakeplatform.NewFakePlatform()

					aws := NewAwsInfrastructure(metadataTs.URL, &FakeDNSResolver{}, platform, fakeDevicePathResolver)

					settings, err := aws.GetSettings()
					Expect(err).NotTo(HaveOccurred())
					Expect(settings).To(Equal(expectedSettings))
				})
			})

			Context("when dns servers are provided", func() {
				It("aws get settings", func() {
					fakeDNSResolver := &FakeDNSResolver{
						LookupHostIP: "127.0.0.1",
					}

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

					platform := fakeplatform.NewFakePlatform()

					aws := NewAwsInfrastructure(metadataTs.URL, fakeDNSResolver, platform, fakeDevicePathResolver)

					settings, err := aws.GetSettings()
					Expect(err).NotTo(HaveOccurred())
					Expect(settings).To(Equal(expectedSettings))
					Expect(fakeDNSResolver.LookupHostHost).To(Equal("the.registry.name"))
					Expect(fakeDNSResolver.LookupHostDNSServers).To(Equal([]string{"8.8.8.8", "9.9.9.9"}))
				})
			})
		})

		Describe("SetupNetworking", func() {
			It("sets up DHCP on the platform", func() {
				fakeDNSResolver := &FakeDNSResolver{}
				platform := fakeplatform.NewFakePlatform()
				aws := NewAwsInfrastructure("", fakeDNSResolver, platform, fakeDevicePathResolver)
				networks := boshsettings.Networks{"bosh": boshsettings.Network{}}

				aws.SetupNetworking(networks)

				Expect(platform.SetupDhcpNetworks).To(Equal(networks))
			})
		})

		Describe("GetEphemeralDiskPath", func() {
			It("returns the real disk path given an AWS EBS hint", func() {
				fakeDNSResolver := &FakeDNSResolver{}
				platform := fakeplatform.NewFakePlatform()
				aws := NewAwsInfrastructure("", fakeDNSResolver, platform, fakeDevicePathResolver)

				platform.NormalizeDiskPathRealPath = "/dev/xvdb"
				platform.NormalizeDiskPathFound = true

				realPath, found := aws.GetEphemeralDiskPath("/dev/sdb")

				Expect(found).To(Equal(true))
				Expect(realPath).To(Equal("/dev/xvdb"))
				Expect(platform.NormalizeDiskPathPath).To(Equal("/dev/sdb"))
			})
		})

		Describe("MountPersistentDisk", func() {
			It("mounts the persistent disk", func() {
				fakePlatform := fakeplatform.NewFakePlatform()

				fakeFormatter := fakePlatform.FakeDiskManager.FakeFormatter
				fakePartitioner := fakePlatform.FakeDiskManager.FakePartitioner
				fakeMounter := fakePlatform.FakeDiskManager.FakeMounter

				fakePlatform.GetFs().WriteFile("/dev/vdf", []byte{})

				fakeDNSResolver := &FakeDNSResolver{}
				aws := NewAwsInfrastructure("", fakeDNSResolver, fakePlatform, fakeDevicePathResolver)

				fakeDevicePathResolver.RealDevicePath = "/dev/vdf"
				err := aws.MountPersistentDisk("/dev/sdf", "/mnt/point")
				Expect(err).NotTo(HaveOccurred())

				mountPoint := fakePlatform.Fs.GetFileTestStat("/mnt/point")
				Expect(mountPoint.FileType).To(Equal(fakesys.FakeFileTypeDir))
				Expect(mountPoint.FileMode).To(Equal(os.FileMode(0700)))

				partition := fakePartitioner.PartitionPartitions[0]
				Expect(fakePartitioner.PartitionDevicePath).To(Equal("/dev/vdf"))
				Expect(len(fakePartitioner.PartitionPartitions)).To(Equal(1))
				Expect(partition.Type).To(Equal(boshdisk.PartitionTypeLinux))

				Expect(len(fakeFormatter.FormatPartitionPaths)).To(Equal(1))
				Expect(fakeFormatter.FormatPartitionPaths[0]).To(Equal("/dev/vdf1"))

				Expect(len(fakeFormatter.FormatFsTypes)).To(Equal(1))
				Expect(fakeFormatter.FormatFsTypes[0]).To(Equal(boshdisk.FileSystemExt4))

				Expect(len(fakeMounter.MountMountPoints)).To(Equal(1))
				Expect(fakeMounter.MountMountPoints[0]).To(Equal("/mnt/point"))
				Expect(len(fakeMounter.MountPartitionPaths)).To(Equal(1))
				Expect(fakeMounter.MountPartitionPaths[0]).To(Equal("/dev/vdf1"))
			})
		})
	})
}
