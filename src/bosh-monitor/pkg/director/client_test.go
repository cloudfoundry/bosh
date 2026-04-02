package director_test

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"

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

			client = director.NewClient(map[string]interface{}{
				"endpoint": server.URL,
				"user":     "admin",
				"password": "admin",
			}, logger)

			deployments, err := client.Deployments()
			Expect(err).NotTo(HaveOccurred())
			Expect(deployments).To(HaveLen(2))
			Expect(deployments[0]["name"]).To(Equal("dep-1"))
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

			client = director.NewClient(map[string]interface{}{
				"endpoint": server.URL,
				"user":     "admin",
				"password": "admin",
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

			client = director.NewClient(map[string]interface{}{
				"endpoint": server.URL,
				"user":     "admin",
				"password": "admin",
			}, logger)

			instances, err := client.GetDeploymentInstances("dep-1")
			Expect(err).NotTo(HaveOccurred())
			Expect(instances).To(HaveLen(1))
			Expect(instances[0]["id"]).To(Equal("inst-1"))
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

			client = director.NewClient(map[string]interface{}{
				"endpoint": server.URL,
				"user":     "admin",
				"password": "admin",
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

			client = director.NewClient(map[string]interface{}{
				"endpoint": server.URL,
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

			client = director.NewClient(map[string]interface{}{
				"endpoint": server.URL,
				"user":     "admin",
				"password": "admin",
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
			config := map[string]interface{}{
				"user":     "admin",
				"password": "secret",
			}
			provider := director.NewAuthProvider(authInfo, config, logger)
			header := provider.AuthHeader()
			Expect(header).To(HavePrefix("Basic "))
		})
	})
})
