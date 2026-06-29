package director_test

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Director Client", func() {
	var (
		server *httptest.Server
		client *director.Client
		logger *slog.Logger
	)

	BeforeEach(func() {
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
	})

	AfterEach(func() {
		if server != nil {
			server.Close()
		}
	})

	Describe("Deployments", func() {
		It("fetches deployments from director", func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				switch r.URL.Path {
				case "/info":
					json.NewEncoder(w).Encode(map[string]interface{}{
						"user_authentication": map[string]interface{}{
							"type": "basic",
						},
					})
				case "/deployments":
					json.NewEncoder(w).Encode([]map[string]interface{}{
						{"name": "dep-1"},
						{"name": "dep-2"},
					})
				}
			}))

			client = director.NewClient(director.Config{
				Endpoint: server.URL,
				User:     "admin",
				Password: "admin",
			}, logger)

			deployments, err := client.Deployments()
			Expect(err).NotTo(HaveOccurred())
			Expect(deployments).To(HaveLen(2))
			Expect(deployments[0].Name).To(Equal("dep-1"))
		})

		It("returns error on non-200 response", func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				switch r.URL.Path {
				case "/info":
					json.NewEncoder(w).Encode(map[string]interface{}{
						"user_authentication": map[string]interface{}{"type": "basic"},
					})
				default:
					w.WriteHeader(500)
					w.Write([]byte("error"))
				}
			}))

			client = director.NewClient(director.Config{
				Endpoint: server.URL,
				User:     "admin",
				Password: "admin",
			}, logger)

			_, err := client.Deployments()
			Expect(err).To(HaveOccurred())
		})
	})

	Describe("GetDeploymentInstances", func() {
		It("fetches instances for a deployment", func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				switch r.URL.Path {
				case "/info":
					json.NewEncoder(w).Encode(map[string]interface{}{
						"user_authentication": map[string]interface{}{"type": "basic"},
					})
				case "/deployments/dep-1/instances":
					json.NewEncoder(w).Encode([]map[string]interface{}{
						{"id": "inst-1", "agent_id": "agent-1", "job": "web"},
					})
				}
			}))

			client = director.NewClient(director.Config{
				Endpoint: server.URL,
				User:     "admin",
				Password: "admin",
			}, logger)

			instances, err := client.GetDeploymentInstances("dep-1")
			Expect(err).NotTo(HaveOccurred())
			Expect(instances).To(HaveLen(1))
			Expect(instances[0].ID).To(Equal("inst-1"))
		})
	})

	Describe("ResurrectionConfig", func() {
		It("fetches resurrection config", func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				switch r.URL.Path {
				case "/info":
					json.NewEncoder(w).Encode(map[string]interface{}{
						"user_authentication": map[string]interface{}{"type": "basic"},
					})
				case "/configs":
					json.NewEncoder(w).Encode([]map[string]interface{}{
						{"content": "rules:\n  - enabled: true\n"},
					})
				}
			}))

			client = director.NewClient(director.Config{
				Endpoint: server.URL,
				User:     "admin",
				Password: "admin",
			}, logger)

			configs, err := client.ResurrectionConfig()
			Expect(err).NotTo(HaveOccurred())
			Expect(configs).To(HaveLen(1))
		})
	})

	Describe("Info", func() {
		It("fetches director info without auth", func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				Expect(r.Header.Get("Authorization")).To(BeEmpty())
				json.NewEncoder(w).Encode(map[string]interface{}{
					"name": "test-director",
					"user_authentication": map[string]interface{}{
						"type": "basic",
					},
				})
			}))

			client = director.NewClient(director.Config{
				Endpoint: server.URL,
			}, logger)

			info, err := client.Info()
			Expect(err).NotTo(HaveOccurred())
			Expect(info["name"]).To(Equal("test-director"))
		})
	})

	Describe("PerformRequestForPlugin", func() {
		It("executes requests on behalf of plugins", func() {
			server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				switch r.URL.Path {
				case "/info":
					json.NewEncoder(w).Encode(map[string]interface{}{
						"user_authentication": map[string]interface{}{"type": "basic"},
					})
				case "/deployments/dep-1/scan_and_fix":
					Expect(r.Method).To(Equal("PUT"))
					Expect(r.Header.Get("Content-Type")).To(Equal("application/json"))
					w.WriteHeader(302)
					w.Write([]byte(`{"id": 1}`))
				}
			}))

			client = director.NewClient(director.Config{
				Endpoint: server.URL,
				User:     "admin",
				Password: "admin",
			}, logger)

			body, status, err := client.PerformRequestForPlugin("PUT", "/deployments/dep-1/scan_and_fix",
				map[string]string{"Content-Type": "application/json"}, `{"jobs":{"web":["inst-1"]}}`, true)
			Expect(err).NotTo(HaveOccurred())
			Expect(status).To(Equal(302))
			Expect(body).To(ContainSubstring("id"))
		})
	})
})

var _ = Describe("AuthProvider", func() {
	Describe("Basic Auth", func() {
		It("returns basic auth header", func() {
			logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
			authInfo := map[string]interface{}{
				"user_authentication": map[string]interface{}{
					"type": "basic",
				},
			}
			config := director.Config{
				User:     "admin",
				Password: "secret",
			}
			provider := director.NewAuthProvider(authInfo, config, logger)
			header := provider.AuthHeader()
			Expect(header).To(HavePrefix("Basic "))
		})
	})
})

var _ = Describe("TLS verification when talking to the director", func() {
	var (
		server *httptest.Server
		logger *slog.Logger
		tmpDir string
	)

	BeforeEach(func() {
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))

		var err error
		tmpDir, err = os.MkdirTemp("", "hm-director-ca-test")
		Expect(err).NotTo(HaveOccurred())

		server = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			switch r.URL.Path {
			case "/info":
				json.NewEncoder(w).Encode(map[string]interface{}{
					"user_authentication": map[string]interface{}{"type": "basic"},
				})
			case "/deployments":
				json.NewEncoder(w).Encode([]map[string]interface{}{{"name": "dep-1"}})
			default:
				w.WriteHeader(404)
			}
		}))
	})

	AfterEach(func() {
		server.Close()
		Expect(os.RemoveAll(tmpDir)).To(Succeed())
	})

	writeServerCAToFile := func(filename string) string {
		path := filepath.Join(tmpDir, filename)
		certPEM := pem.EncodeToMemory(&pem.Block{
			Type:  "CERTIFICATE",
			Bytes: server.Certificate().Raw,
		})
		Expect(os.WriteFile(path, certPEM, 0600)).To(Succeed())
		return path
	}

	Context("when director_ca_cert points to the trusted CA file", func() {
		It("verifies the peer using the configured CA file", func() {
			caFile := writeServerCAToFile("director-ca.pem")

			client := director.NewClient(director.Config{
				Endpoint:       server.URL,
				User:           "admin",
				Password:       "admin",
				DirectorCACert: caFile,
			}, logger)

			deployments, err := client.Deployments()
			Expect(err).NotTo(HaveOccurred())
			Expect(deployments).To(HaveLen(1))
		})
	})

	Context("when director_ca_cert is not configured", func() {
		It("verifies the peer (rejects unknown self-signed certs)", func() {
			client := director.NewClient(director.Config{
				Endpoint:       server.URL,
				User:           "admin",
				Password:       "admin",
				DirectorCACert: "",
			}, logger)

			_, err := client.Deployments()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(MatchRegexp("certificate|x509|tls"))
		})
	})

	Context("when director_ca_cert points to a non-existent file", func() {
		It("verifies the peer (rejects unknown self-signed certs)", func() {
			client := director.NewClient(director.Config{
				Endpoint:       server.URL,
				User:           "admin",
				Password:       "admin",
				DirectorCACert: filepath.Join(tmpDir, "no-such-file.pem"),
			}, logger)

			_, err := client.Deployments()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(MatchRegexp("certificate|x509|tls"))
		})
	})

	Context("when director_ca_cert points to an empty file", func() {
		It("verifies the peer (rejects unknown self-signed certs)", func() {
			path := filepath.Join(tmpDir, "empty.pem")
			Expect(os.WriteFile(path, []byte("   \n"), 0600)).To(Succeed())

			client := director.NewClient(director.Config{
				Endpoint:       server.URL,
				User:           "admin",
				Password:       "admin",
				DirectorCACert: path,
			}, logger)

			_, err := client.Deployments()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(MatchRegexp("certificate|x509|tls"))
		})
	})

	Context("when director_ca_cert points to a file with no usable PEM blocks", func() {
		It("verifies the peer using system default CAs (and rejects untrusted cert)", func() {
			path := filepath.Join(tmpDir, "garbage.pem")
			Expect(os.WriteFile(path, []byte("not-a-pem-block\n"), 0600)).To(Succeed())

			client := director.NewClient(director.Config{
				Endpoint:       server.URL,
				User:           "admin",
				Password:       "admin",
				DirectorCACert: path,
			}, logger)

			_, err := client.Deployments()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(MatchRegexp("certificate|x509|tls"))
		})
	})

	Context("sanity check: server CA pool actually trusts the test server", func() {
		It("confirms the test fixture roots establish trust", func() {
			caFile := writeServerCAToFile("server-ca.pem")
			pemBytes, err := os.ReadFile(caFile)
			Expect(err).NotTo(HaveOccurred())

			pool := x509.NewCertPool()
			Expect(pool.AppendCertsFromPEM(pemBytes)).To(BeTrue())

			c := &http.Client{
				Transport: &http.Transport{
					TLSClientConfig: &tls.Config{RootCAs: pool},
				},
			}
			resp, err := c.Get(server.URL + "/info")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			resp.Body.Close()
		})
	})
})
