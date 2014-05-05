package infrastructure_test

import (
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/infrastructure"
	fakeinf "bosh/infrastructure/fakes"
)

var _ = Describe("concreteMetadataService", func() {
	var (
		dnsResolver     *fakeinf.FakeDNSResolver
		metadataService MetadataService
	)

	BeforeEach(func() {
		dnsResolver = &fakeinf.FakeDNSResolver{}
		metadataService = NewConcreteMetadataService("fake-metadata-host", dnsResolver)
	})

	Describe("GetPublicKey", func() {
		var (
			ts *httptest.Server
		)

		BeforeEach(func() {
			handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				GinkgoRecover()

				Expect(r.Method).To(Equal("GET"))
				Expect(r.URL.Path).To(Equal("/latest/meta-data/public-keys/0/openssh-key"))

				w.Write([]byte("fake-public-key"))
			})

			ts = httptest.NewServer(handler)

			metadataService = NewConcreteMetadataService(ts.URL, dnsResolver)
		})

		AfterEach(func() {
			ts.Close()
		})

		It("returns fetched public key", func() {
			publicKey, err := metadataService.GetPublicKey()
			Expect(err).NotTo(HaveOccurred())
			Expect(publicKey).To(Equal("fake-public-key"))
		})
	})

	Describe("GetInstanceID", func() {
		var (
			ts *httptest.Server
		)

		BeforeEach(func() {
			handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				GinkgoRecover()

				Expect(r.Method).To(Equal("GET"))
				Expect(r.URL.Path).To(Equal("/latest/meta-data/instance-id"))

				w.Write([]byte("fake-instance-id"))
			})

			ts = httptest.NewServer(handler)

			metadataService = NewConcreteMetadataService(ts.URL, dnsResolver)
		})

		AfterEach(func() {
			ts.Close()
		})

		It("returns fetched instance id", func() {
			publicKey, err := metadataService.GetInstanceID()
			Expect(err).NotTo(HaveOccurred())
			Expect(publicKey).To(Equal("fake-instance-id"))
		})
	})

	Describe("GetServerName", func() {
		var (
			ts         *httptest.Server
			serverName *string
		)

		handlerFunc := func(w http.ResponseWriter, r *http.Request) {
			GinkgoRecover()

			Expect(r.Method).To(Equal("GET"))
			Expect(r.URL.Path).To(Equal("/latest/user-data"))

			var jsonStr string

			if serverName == nil {
				jsonStr = `{}`
			} else {
				jsonStr = fmt.Sprintf(`{"server":{"name":"%s"}}`, *serverName)
			}

			w.Write([]byte(jsonStr))
		}

		BeforeEach(func() {
			serverName = nil

			handler := http.HandlerFunc(handlerFunc)
			ts = httptest.NewServer(handler)
			metadataService = NewConcreteMetadataService(ts.URL, dnsResolver)
		})

		AfterEach(func() {
			ts.Close()
		})

		Context("when the server name is present in the JSON", func() {
			BeforeEach(func() {
				name := "fake-server-name"
				serverName = &name
			})

			It("returns the server name", func() {
				name, err := metadataService.GetServerName()
				Expect(err).ToNot(HaveOccurred())
				Expect(name).To(Equal("fake-server-name"))
			})
		})

		Context("when the server name is not present in the JSON", func() {
			BeforeEach(func() {
				serverName = nil
			})

			It("returns an error", func() {
				name, err := metadataService.GetServerName()
				Expect(err).To(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("GetRegistryEndpoint", func() {
		var (
			ts          *httptest.Server
			registryURL *string
			dnsServer   *string
		)

		handlerFunc := func(w http.ResponseWriter, r *http.Request) {
			GinkgoRecover()

			Expect(r.Method).To(Equal("GET"))
			Expect(r.URL.Path).To(Equal("/latest/user-data"))

			var jsonStr string

			if dnsServer == nil {
				jsonStr = fmt.Sprintf(`{"registry":{"endpoint":"%s"}}`, *registryURL)
			} else {
				jsonStr = fmt.Sprintf(`{
					"registry":{"endpoint":"%s"},
					"dns":{"nameserver":["%s"]}
				}`, *registryURL, *dnsServer)
			}

			w.Write([]byte(jsonStr))
		}

		BeforeEach(func() {
			url := "http://fake-registry.com"
			registryURL = &url
			dnsServer = nil

			handler := http.HandlerFunc(handlerFunc)
			ts = httptest.NewServer(handler)
			metadataService = NewConcreteMetadataService(ts.URL, dnsResolver)
		})

		AfterEach(func() {
			ts.Close()
		})

		Context("when metadata contains a dns server", func() {
			BeforeEach(func() {
				server := "fake-dns-server-ip"
				dnsServer = &server
			})

			Context("when registry endpoint is successfully resolved", func() {
				BeforeEach(func() {
					dnsResolver.RegisterRecord(fakeinf.FakeDNSRecord{
						DNSServers: []string{"fake-dns-server-ip"},
						Host:       "fake-registry.com",
						IP:         "fake-registry-ip",
					})
				})

				Context("when registry endpoint has a port", func() {
					BeforeEach(func() {
						url := "http://fake-registry.com:8877"
						registryURL = &url
					})

					It("returns the successfully resolved registry endpoint with port", func() {
						endpoint, err := metadataService.GetRegistryEndpoint()
						Expect(err).ToNot(HaveOccurred())
						Expect(endpoint).To(Equal("http://fake-registry-ip:8877"))
					})
				})

				Context("when registry endpoint does not have a port", func() {
					BeforeEach(func() {
						url := "http://fake-registry.com"
						registryURL = &url
					})

					It("returns the successfully resolved registry endpoint", func() {
						endpoint, err := metadataService.GetRegistryEndpoint()
						Expect(err).ToNot(HaveOccurred())
						Expect(endpoint).To(Equal("http://fake-registry-ip"))
					})
				})
			})

			Context("when registry endpoint is not successfully resolved", func() {
				BeforeEach(func() {
					dnsResolver.LookupHostErr = errors.New("fake-lookup-host-err")
				})

				It("returns error because it failed to resolve registry endpoint", func() {
					endpoint, err := metadataService.GetRegistryEndpoint()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("fake-lookup-host-err"))
					Expect(endpoint).To(BeEmpty())
				})
			})
		})

		Context("when metadata does not contain dns servers", func() {
			It("returns fetched registry endpoint", func() {
				endpoint, err := metadataService.GetRegistryEndpoint()
				Expect(err).NotTo(HaveOccurred())
				Expect(endpoint).To(Equal("http://fake-registry.com"))
			})
		})
	})
})
