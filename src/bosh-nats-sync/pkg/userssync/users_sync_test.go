package userssync_test

import (
	"bytes"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-nats-sync/pkg/config"
	"bosh-nats-sync/pkg/natsauthconfig"
	"bosh-nats-sync/pkg/userssync"
)

var _ = Describe("UsersSync", func() {
	var (
		logger              *slog.Logger
		natsConfigFile      *os.File
		natsConfigFilePath  string
		natsExecutable      string
		natsServerPIDFile   string
		directorSubjectFile string
		hmSubjectFile       string
		directorSubject     string
		hmSubject           string
		boshConfig          config.DirectorConfig
		server              *httptest.Server
		commandRunnerCalls  []string
		commandRunnerErr    error
		sync                *userssync.UsersSync

		deploymentsJSON string
		vmsJSON         string
		infoJSON        string
	)

	BeforeEach(func() {
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))

		var err error
		natsConfigFile, err = os.CreateTemp("", "nats_config_*.json")
		Expect(err).NotTo(HaveOccurred())
		natsConfigFilePath = natsConfigFile.Name()
		natsConfigFile.Close()

		natsExecutable = "/var/vcap/packages/nats/bin/nats-server"
		natsServerPIDFile = "/var/vcap/sys/run/bpm/nats/nats.pid"

		tmpDir, err := os.MkdirTemp("", "nats_sync_test_*")
		Expect(err).NotTo(HaveOccurred())

		directorSubjectFile = filepath.Join(tmpDir, "director-subject")
		hmSubjectFile = filepath.Join(tmpDir, "hm-subject")

		directorSubject = "C=USA, O=Cloud Foundry, CN=default.director.bosh-internal"
		hmSubject = "C=USA, O=Cloud Foundry, CN=default.hm.bosh-internal"

		os.WriteFile(directorSubjectFile, []byte(directorSubject), 0644)
		os.WriteFile(hmSubjectFile, []byte(hmSubject), 0644)

		commandRunnerCalls = nil
		commandRunnerErr = nil

		deploymentsJSON = `[{"name": "deployment-1"}]`
		vmsJSON = `[
			{"agent_id":"fef068d8-bbdd-46ff-b4a5-bf0838f918d9","permanent_nats_credentials":true},
			{"agent_id":"c5e7c705-459e-41c0-b640-db32d8dc6e71","permanent_nats_credentials":true}
		]`
		infoJSON = `{
			"name": "bosh-lite",
			"user_authentication": {
				"type": "uaa",
				"options": {"url": "https://192.168.56.6:8443"}
			}
		}`
	})

	AfterEach(func() {
		os.Remove(natsConfigFilePath)
		os.Remove(directorSubjectFile)
		os.Remove(hmSubjectFile)
		if server != nil {
			server.Close()
		}
	})

	setupServer := func() {
		server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			switch {
			case r.URL.Path == "/info":
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, infoJSON)
			case r.URL.Path == "/deployments" && !strings.Contains(r.URL.Path, "/vms"):
				if r.Header.Get("Authorization") != "Bearer xyz" {
					w.WriteHeader(http.StatusUnauthorized)
					fmt.Fprint(w, "Unauthorized")
					return
				}
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, deploymentsJSON)
			case strings.HasSuffix(r.URL.Path, "/vms"):
				if r.Header.Get("Authorization") != "Bearer xyz" {
					w.WriteHeader(http.StatusUnauthorized)
					fmt.Fprint(w, "Unauthorized")
					return
				}
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, vmsJSON)
			default:
				w.WriteHeader(http.StatusNotFound)
			}
		}))
	}

	setupServerWithUAAToken := func() {
		mux := http.NewServeMux()
		mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, infoJSON)
		})
		mux.HandleFunc("/oauth/token", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			fmt.Fprint(w, `{"access_token":"xyz","token_type":"bearer","expires_in":3600}`)
		})
		mux.HandleFunc("/deployments", func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("Authorization") != "Bearer xyz" {
				w.WriteHeader(http.StatusUnauthorized)
				fmt.Fprint(w, "Unauthorized")
				return
			}
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, deploymentsJSON)
		})
		mux.HandleFunc("/deployments/deployment-1/vms", func(w http.ResponseWriter, r *http.Request) {
			if r.Header.Get("Authorization") != "Bearer xyz" {
				w.WriteHeader(http.StatusUnauthorized)
				fmt.Fprint(w, "Unauthorized")
				return
			}
			w.WriteHeader(http.StatusOK)
			fmt.Fprint(w, vmsJSON)
		})

		server = httptest.NewServer(mux)
		infoJSON = fmt.Sprintf(`{
			"name": "bosh-lite",
			"user_authentication": {
				"type": "uaa",
				"options": {"url": "%s"}
			}
		}`, server.URL)
	}

	createSync := func() *userssync.UsersSync {
		return &userssync.UsersSync{
			NATSConfigFilePath:   natsConfigFilePath,
			BoshConfig:           boshConfig,
			NATSServerExecutable: natsExecutable,
			NATSServerPIDFile:    natsServerPIDFile,
			Logger:               logger,
			CommandRunner: func(executable string, args ...string) ([]byte, error) {
				commandRunnerCalls = append(commandRunnerCalls, fmt.Sprintf("%s %s", executable, strings.Join(args, " ")))
				return []byte("Success"), commandRunnerErr
			},
		}
	}

	Describe("Execute", func() {
		BeforeEach(func() {
			os.WriteFile(natsConfigFilePath, []byte("{}"), 0644)
		})

		Context("when UAA is not deployed and the BOSH API is not available", func() {
			BeforeEach(func() {
				setupServer()
				infoJSON = `{"name": "bosh-lite"}`

				boshConfig = config.DirectorConfig{
					URL:                   server.URL,
					User:                  "admin",
					Password:              "admin",
					ClientID:              "client_id",
					ClientSecret:          "client_secret",
					DirectorSubjectFile:   directorSubjectFile,
					HMSubjectFile:         hmSubjectFile,
					ConnectionWaitTimeout: 1,
				}
			})

			Context("and the authentication file is empty", func() {
				It("writes the basic bosh configuration", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).NotTo(HaveOccurred())

					data, err := os.ReadFile(natsConfigFilePath)
					Expect(err).NotTo(HaveOccurred())
					var result natsauthconfig.AuthorizationConfig
					Expect(json.Unmarshal(data, &result)).To(Succeed())

					users := result.Authorization.Users
					Expect(users).To(HaveLen(2))
					userNames := []string{users[0].User, users[1].User}
					Expect(userNames).To(ContainElement(directorSubject))
					Expect(userNames).To(ContainElement(hmSubject))
				})
			})

			Context("and the authentication file is corrupted", func() {
				BeforeEach(func() {
					os.WriteFile(natsConfigFilePath, []byte("{invalidchar"), 0644)
				})

				It("writes the basic bosh configuration", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).NotTo(HaveOccurred())

					data, err := os.ReadFile(natsConfigFilePath)
					Expect(err).NotTo(HaveOccurred())
					var result natsauthconfig.AuthorizationConfig
					Expect(json.Unmarshal(data, &result)).To(Succeed())

					users := result.Authorization.Users
					Expect(users).To(HaveLen(2))
					userNames := []string{users[0].User, users[1].User}
					Expect(userNames).To(ContainElement(directorSubject))
					Expect(userNames).To(ContainElement(hmSubject))
				})
			})

			Context("and the authentication file is not empty", func() {
				BeforeEach(func() {
					os.WriteFile(natsConfigFilePath, []byte(`{"authorization": {"users": [{"user": "foo"}]}}`), 0644)
				})

				It("does not overwrite the authentication file", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).NotTo(HaveOccurred())

					data, err := os.ReadFile(natsConfigFilePath)
					Expect(err).NotTo(HaveOccurred())
					var result map[string]interface{}
					Expect(json.Unmarshal(data, &result)).To(Succeed())
					auth := result["authorization"].(map[string]interface{})
					users := auth["users"].([]interface{})
					Expect(users).To(HaveLen(1))
					Expect(users[0].(map[string]interface{})["user"]).To(Equal("foo"))
				})
			})
		})

		Context("when there are no deployments with running vms in Bosh", func() {
			BeforeEach(func() {
				deploymentsJSON = "[]"
				setupServerWithUAAToken()
				boshConfig = config.DirectorConfig{
					URL:                   server.URL,
					User:                  "admin",
					Password:              "admin",
					ClientID:              "client_id",
					ClientSecret:          "client_secret",
					DirectorSubjectFile:   directorSubjectFile,
					HMSubjectFile:         hmSubjectFile,
					ConnectionWaitTimeout: 2,
				}
			})

			It("writes the basic bosh configuration", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(natsConfigFilePath)
				Expect(err).NotTo(HaveOccurred())
				var result natsauthconfig.AuthorizationConfig
				Expect(json.Unmarshal(data, &result)).To(Succeed())

				users := result.Authorization.Users
				Expect(users).To(HaveLen(2))
				userNames := []string{users[0].User, users[1].User}
				Expect(userNames).To(ContainElement(directorSubject))
				Expect(userNames).To(ContainElement(hmSubject))
			})
		})

		Context("when there are deployments with running vms in Bosh", func() {
			BeforeEach(func() {
				setupServerWithUAAToken()
				boshConfig = config.DirectorConfig{
					URL:                   server.URL,
					User:                  "admin",
					Password:              "admin",
					ClientID:              "client_id",
					ClientSecret:          "client_secret",
					DirectorSubjectFile:   directorSubjectFile,
					HMSubjectFile:         hmSubjectFile,
					ConnectionWaitTimeout: 2,
				}
			})

			It("logs when it is starting and finishing", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())
			})

			It("writes the right number of users to the NATS configuration file", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(natsConfigFilePath)
				Expect(err).NotTo(HaveOccurred())
				var result natsauthconfig.AuthorizationConfig
				Expect(json.Unmarshal(data, &result)).To(Succeed())
				Expect(result.Authorization.Users).To(HaveLen(4))
			})

			It("writes the right agent_ids to the NATS configuration file", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(natsConfigFilePath)
				Expect(err).NotTo(HaveOccurred())
				var result natsauthconfig.AuthorizationConfig
				Expect(json.Unmarshal(data, &result)).To(Succeed())

				userNames := make([]string, len(result.Authorization.Users))
				for i, u := range result.Authorization.Users {
					userNames[i] = u.User
				}
				Expect(userNames).To(ContainElement(directorSubject))
				Expect(userNames).To(ContainElement(hmSubject))
				Expect(userNames).To(ContainElement("C=USA, O=Cloud Foundry, CN=fef068d8-bbdd-46ff-b4a5-bf0838f918d9.agent.bosh-internal"))
				Expect(userNames).To(ContainElement("C=USA, O=Cloud Foundry, CN=c5e7c705-459e-41c0-b640-db32d8dc6e71.agent.bosh-internal"))
			})

			It("does not write wrong ids to the NATS configuration file", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(natsConfigFilePath)
				Expect(err).NotTo(HaveOccurred())
				var result natsauthconfig.AuthorizationConfig
				Expect(json.Unmarshal(data, &result)).To(Succeed())

				userNames := make([]string, len(result.Authorization.Users))
				for i, u := range result.Authorization.Users {
					userNames[i] = u.User
				}
				Expect(userNames).NotTo(ContainElement(ContainSubstring("9cb7120d-d817-40f5-9410-d2b6f01ba746")))
				Expect(userNames).NotTo(ContainElement(ContainSubstring("209b96c8-e482-43c7-9f3e-04de9f93c535")))
			})

			It("reloads the nats process", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())

				Expect(commandRunnerCalls).To(HaveLen(1))
				Expect(commandRunnerCalls[0]).To(Equal(
					fmt.Sprintf("%s --signal reload=%s", natsExecutable, natsServerPIDFile)))
			})

			Context("when there is a previous configuration file with the same users", func() {
				BeforeEach(func() {
					vms := []natsauthconfig.VM{
						{PermanentNATSCredentials: true, AgentID: "fef068d8-bbdd-46ff-b4a5-bf0838f918d9"},
						{PermanentNATSCredentials: true, AgentID: "c5e7c705-459e-41c0-b640-db32d8dc6e71"},
					}
					ds := directorSubject
					hs := hmSubject
					cfg := natsauthconfig.CreateConfig(vms, &ds, &hs)
					// Use the same HTML-escape-free encoding that writeNATSConfigFile uses,
					// so the hash matches and Execute() correctly skips the reload.
					var buf bytes.Buffer
					enc := json.NewEncoder(&buf)
					enc.SetEscapeHTML(false)
					_ = enc.Encode(cfg)
					os.WriteFile(natsConfigFilePath, bytes.TrimRight(buf.Bytes(), "\n"), 0644)
				})

				It("does not reload the NATS process", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).NotTo(HaveOccurred())
					Expect(commandRunnerCalls).To(BeEmpty())
				})
			})

			Context("when there is a previous configuration file with different users", func() {
				BeforeEach(func() {
					vms := []natsauthconfig.VM{
						{PermanentNATSCredentials: true, AgentID: "fef068d8-bbdd-46ff-b4a5-bf0838f918d9"},
						{PermanentNATSCredentials: true, AgentID: "209b96c8-e482-43c7-8f3e-04de9f93c535"},
					}
					ds := directorSubject
					hs := hmSubject
					cfg := natsauthconfig.CreateConfig(vms, &ds, &hs)
					data, _ := json.Marshal(cfg)
					os.WriteFile(natsConfigFilePath, data, 0644)
				})

				It("reloads the NATS process", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).NotTo(HaveOccurred())
					Expect(commandRunnerCalls).To(HaveLen(1))
					Expect(commandRunnerCalls[0]).To(Equal(
						fmt.Sprintf("%s --signal reload=%s", natsExecutable, natsServerPIDFile)))
				})
			})

			Context("when there are running vms but no subject information for hm or the director", func() {
				BeforeEach(func() {
					boshConfig.DirectorSubjectFile = "/file/nonexistent1"
					boshConfig.HMSubjectFile = "/file/nonexistent2"
				})

				It("writes the right number of users to the NATS configuration file", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).NotTo(HaveOccurred())

					data, err := os.ReadFile(natsConfigFilePath)
					Expect(err).NotTo(HaveOccurred())
					var result natsauthconfig.AuthorizationConfig
					Expect(json.Unmarshal(data, &result)).To(Succeed())
					Expect(result.Authorization.Users).To(HaveLen(2))
				})

				It("does not write the configuration for the bosh director or the bosh monitor", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).NotTo(HaveOccurred())

					data, err := os.ReadFile(natsConfigFilePath)
					Expect(err).NotTo(HaveOccurred())
					var result natsauthconfig.AuthorizationConfig
					Expect(json.Unmarshal(data, &result)).To(Succeed())

					userNames := make([]string, len(result.Authorization.Users))
					for i, u := range result.Authorization.Users {
						userNames[i] = u.User
					}
					Expect(userNames).NotTo(ContainElement(hmSubject))
					Expect(userNames).NotTo(ContainElement(directorSubject))
				})
			})

			Context("when reloading the NATS server fails", func() {
				BeforeEach(func() {
					commandRunnerErr = fmt.Errorf("cannot execute: nats-server --signal reload, Status Code: 1\nError: Failed to reload NATs server")
				})

				It("returns an error", func() {
					sync = createSync()
					err := sync.Execute()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("Failed to reload NATs server"))
				})
			})
		})
	})

	Describe("waitForDirectorConnection", func() {
		BeforeEach(func() {
			os.WriteFile(natsConfigFilePath, []byte("{}"), 0644)
		})

		Context("when director is immediately available", func() {
			BeforeEach(func() {
				deploymentsJSON = "[]"
				setupServerWithUAAToken()
				boshConfig = config.DirectorConfig{
					URL:                   server.URL,
					User:                  "admin",
					Password:              "admin",
					ClientID:              "client_id",
					ClientSecret:          "client_secret",
					DirectorSubjectFile:   directorSubjectFile,
					HMSubjectFile:         hmSubjectFile,
					ConnectionWaitTimeout: 5,
				}
			})

			It("connects without retrying", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("when director becomes available after retries", func() {
			var requestCount int

			BeforeEach(func() {
				requestCount = 0
				mux := http.NewServeMux()
				// On the first /info request, abort the connection (simulates a transient
				// network error that isConnectionError() will detect and retry). Subsequent
				// requests succeed so withDirectorConnection() eventually proceeds.
				mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
					requestCount++
					if requestCount <= 1 {
						hj, ok := w.(http.Hijacker)
						if ok {
							conn, _, _ := hj.Hijack()
							conn.Close()
						}
						return
					}
					w.WriteHeader(http.StatusOK)
					fmt.Fprint(w, infoJSON)
				})
				mux.HandleFunc("/oauth/token", func(w http.ResponseWriter, r *http.Request) {
					w.Header().Set("Content-Type", "application/json")
					fmt.Fprint(w, `{"access_token":"xyz","token_type":"bearer","expires_in":3600}`)
				})
				mux.HandleFunc("/deployments", func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusOK)
					fmt.Fprint(w, "[]")
				})
				server = httptest.NewServer(mux)

				infoJSON = fmt.Sprintf(`{
					"name": "bosh-lite",
					"user_authentication": {
						"type": "uaa",
						"options": {"url": "%s"}
					}
				}`, server.URL)

				boshConfig = config.DirectorConfig{
					URL:                   server.URL,
					User:                  "admin",
					Password:              "admin",
					ClientID:              "client_id",
					ClientSecret:          "client_secret",
					DirectorSubjectFile:   directorSubjectFile,
					HMSubjectFile:         hmSubjectFile,
					ConnectionWaitTimeout: 5,
				}
			})

			It("eventually succeeds after retrying", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())
				Expect(requestCount).To(BeNumerically(">=", 2))
			})
		})

		Context("when director connection times out (connection refused)", func() {
			BeforeEach(func() {
				boshConfig = config.DirectorConfig{
					URL:                   "http://127.0.0.1:1",
					User:                  "admin",
					Password:              "admin",
					DirectorSubjectFile:   directorSubjectFile,
					HMSubjectFile:         hmSubjectFile,
					ConnectionWaitTimeout: 2,
				}
			})

			It("writes basic config when file is empty", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())

				data, err := os.ReadFile(natsConfigFilePath)
				Expect(err).NotTo(HaveOccurred())
				var result natsauthconfig.AuthorizationConfig
				Expect(json.Unmarshal(data, &result)).To(Succeed())
				Expect(result.Authorization.Users).To(HaveLen(2))
			})
		})

		Context("when director connection probe returns an EOF error (server closes connection)", func() {
			// Mirrors Ruby Errno::ECONNRESET / Net::ReadTimeout handling via Bosh::Common.retryable
			var (
				requestCount int
				flakyServer  *httptest.Server
			)

			BeforeEach(func() {
				requestCount = 0
				mux := http.NewServeMux()
				mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
					requestCount++
					if requestCount == 1 {
						// Simulate transient connection failure on first attempt
						hj, ok := w.(http.Hijacker)
						if ok {
							conn, _, _ := hj.Hijack()
							conn.Close()
							return
						}
					}
					w.WriteHeader(http.StatusOK)
					fmt.Fprint(w, `{"name":"bosh-lite"}`)
				})
				mux.HandleFunc("/deployments", func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusOK)
					fmt.Fprint(w, "[]")
				})
				flakyServer = httptest.NewServer(mux)

				boshConfig = config.DirectorConfig{
					URL:                   flakyServer.URL,
					DirectorSubjectFile:   directorSubjectFile,
					HMSubjectFile:         hmSubjectFile,
					ConnectionWaitTimeout: 5,
				}
			})

			AfterEach(func() {
				if flakyServer != nil {
					flakyServer.Close()
				}
			})

			It("retries and eventually succeeds", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())
				Expect(requestCount).To(BeNumerically(">=", 2))
			})
		})

		Context("when connection_wait_timeout is not configured", func() {
			BeforeEach(func() {
				deploymentsJSON = "[]"
				setupServerWithUAAToken()
				boshConfig = config.DirectorConfig{
					URL:                 server.URL,
					User:                "admin",
					Password:            "admin",
					ClientID:            "client_id",
					ClientSecret:        "client_secret",
					DirectorSubjectFile: directorSubjectFile,
					HMSubjectFile:       hmSubjectFile,
				}
			})

			It("uses the default timeout and runs without error", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())
			})
		})
	})

	Describe("TLS verification of director HTTPS requests", func() {
		var (
			tlsServer  *httptest.Server
			caCertPath string
			tmpDir     string
		)

		writeServerCert := func(srv *httptest.Server, dir string) string {
			ServerCert := srv.Certificate()
			Expect(ServerCert).NotTo(BeNil())
			pemBlock := &pem.Block{Type: "CERTIFICATE", Bytes: ServerCert.Raw}
			path := filepath.Join(dir, "director_ca.pem")
			Expect(os.WriteFile(path, pem.EncodeToMemory(pemBlock), 0o600)).To(Succeed())
			return path
		}

		BeforeEach(func() {
			os.WriteFile(natsConfigFilePath, []byte("{}"), 0o644)

			var err error
			tmpDir, err = os.MkdirTemp("", "nats_sync_tls_*")
			Expect(err).NotTo(HaveOccurred())

			mux := http.NewServeMux()
			mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, `{"name": "bosh-lite"}`)
			})
			mux.HandleFunc("/deployments", func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
				fmt.Fprint(w, "[]")
			})
			tlsServer = httptest.NewTLSServer(mux)
			caCertPath = writeServerCert(tlsServer, tmpDir)
		})

		AfterEach(func() {
			if tlsServer != nil {
				tlsServer.Close()
			}
			os.RemoveAll(tmpDir)
		})

		It("succeeds when director_ca_cert points to a file containing the server's CA", func() {
			boshConfig = config.DirectorConfig{
				URL:                   tlsServer.URL,
				DirectorCACert:        caCertPath,
				DirectorSubjectFile:   directorSubjectFile,
				HMSubjectFile:         hmSubjectFile,
				ConnectionWaitTimeout: 1,
			}
			sync = createSync()
			Expect(sync.Execute()).To(Succeed())
		})

		It("fails verification (does not silently accept self-signed certs) when director_ca_cert is missing", func() {
			boshConfig = config.DirectorConfig{
				URL:                   tlsServer.URL,
				DirectorSubjectFile:   directorSubjectFile,
				HMSubjectFile:         hmSubjectFile,
				ConnectionWaitTimeout: 1,
			}
			sync = createSync()
			Expect(sync.Execute()).To(Succeed())

			// the bosh API is unreachable due to TLS verification, so the
			// users-sync process falls back to writing the basic config file.
			data, err := os.ReadFile(natsConfigFilePath)
			Expect(err).NotTo(HaveOccurred())
			var result natsauthconfig.AuthorizationConfig
			Expect(json.Unmarshal(data, &result)).To(Succeed())
			Expect(result.Authorization.Users).To(HaveLen(2))
		})

		It("falls back to the system trust store when director_ca_cert file is empty", func() {
			emptyPath := filepath.Join(tmpDir, "empty.pem")
			Expect(os.WriteFile(emptyPath, []byte("  \n"), 0o600)).To(Succeed())

			boshConfig = config.DirectorConfig{
				URL:                   tlsServer.URL,
				DirectorCACert:        emptyPath,
				DirectorSubjectFile:   directorSubjectFile,
				HMSubjectFile:         hmSubjectFile,
				ConnectionWaitTimeout: 1,
			}
			sync = createSync()
			Expect(sync.Execute()).To(Succeed())

			data, err := os.ReadFile(natsConfigFilePath)
			Expect(err).NotTo(HaveOccurred())
			var result natsauthconfig.AuthorizationConfig
			Expect(json.Unmarshal(data, &result)).To(Succeed())
			Expect(result.Authorization.Users).To(HaveLen(2))
		})
	})

	Describe("ReloadNATSServerConfig", func() {
		It("calls the nats-server executable with the correct arguments", func() {
			var calledWith string
			runner := func(executable string, args ...string) ([]byte, error) {
				calledWith = fmt.Sprintf("%s %s", executable, strings.Join(args, " "))
				return []byte("OK"), nil
			}
			err := userssync.ReloadNATSServerConfig(natsExecutable, natsServerPIDFile, runner)
			Expect(err).NotTo(HaveOccurred())
			Expect(calledWith).To(Equal(
				fmt.Sprintf("%s --signal reload=%s", natsExecutable, natsServerPIDFile)))
		})

		It("returns an error when the command fails", func() {
			runner := func(executable string, args ...string) ([]byte, error) {
				return nil, fmt.Errorf("command failed")
			}
			err := userssync.ReloadNATSServerConfig(natsExecutable, natsServerPIDFile, runner)
			Expect(err).To(HaveOccurred())
		})
	})

	// Mirrors the BOSH startup race: pre-start writes a fooBar token placeholder
	// to auth.json and the hm-subject / director-subject files, then bosh-nats-sync
	// starts. Bootstrap() must overwrite the placeholder with real user credentials
	// immediately, without querying the director, so that health_monitor can
	// authenticate against NATS before the director finishes starting up.
	Describe("Bootstrap", func() {
		var (
			bootstrapSync     *userssync.UsersSync
			bootstrapCmdCalls []string
			bootstrapCmdErr   error
		)

		BeforeEach(func() {
			bootstrapCmdCalls = nil
			bootstrapCmdErr = nil

			// Simulate the fooBar token placeholder written by pre-start.
			os.WriteFile(natsConfigFilePath, []byte(`{"authorization":{"token":"f0oBar"}}`), 0644)

			// boshConfig is only populated in inner BeforeEach blocks elsewhere,
			// so we build it explicitly here with the subject files from the
			// outer BeforeEach.
			bootstrapSync = &userssync.UsersSync{
				NATSConfigFilePath: natsConfigFilePath,
				BoshConfig: config.DirectorConfig{
					URL:                 "http://127.0.0.1:1", // unreachable; Bootstrap must not contact it
					DirectorSubjectFile: directorSubjectFile,
					HMSubjectFile:       hmSubjectFile,
				},
				NATSServerExecutable: natsExecutable,
				NATSServerPIDFile:    natsServerPIDFile,
				Logger:               logger,
				CommandRunner: func(executable string, args ...string) ([]byte, error) {
					bootstrapCmdCalls = append(bootstrapCmdCalls, fmt.Sprintf("%s %s", executable, strings.Join(args, " ")))
					return []byte("ok"), bootstrapCmdErr
				},
			}
		})

		It("writes the director and HM users to the NATS config without querying the director", func() {
			err := bootstrapSync.Bootstrap()
			Expect(err).NotTo(HaveOccurred())

			data, readErr := os.ReadFile(natsConfigFilePath)
			Expect(readErr).NotTo(HaveOccurred())

			var cfg natsauthconfig.AuthorizationConfig
			Expect(json.Unmarshal(data, &cfg)).To(Succeed())

			subjects := make([]string, 0, len(cfg.Authorization.Users))
			for _, u := range cfg.Authorization.Users {
				subjects = append(subjects, u.User)
			}
			Expect(subjects).To(ContainElement(ContainSubstring("director.bosh-internal")))
			Expect(subjects).To(ContainElement(ContainSubstring("hm.bosh-internal")))
		})

		It("overwrites the fooBar token placeholder left by pre-start", func() {
			Expect(bootstrapSync.Bootstrap()).To(Succeed())

			data, _ := os.ReadFile(natsConfigFilePath)
			Expect(string(data)).NotTo(ContainSubstring("f0oBar"))
			Expect(string(data)).To(ContainSubstring("users"))
		})

		// Regression test: json.Marshal HTML-escapes '>' as '\u003e', which the
		// NATS config parser rejects with "Invalid escape character 'u'".
		// The fix uses json.NewEncoder with SetEscapeHTML(false).
		It("writes '>' literally (not as \\u003e) so NATS can parse the config", func() {
			Expect(bootstrapSync.Bootstrap()).To(Succeed())

			data, _ := os.ReadFile(natsConfigFilePath)
			Expect(string(data)).To(ContainSubstring("director.>"),
				"expected literal '>' but got HTML-escaped '\\u003e'")
			Expect(string(data)).NotTo(ContainSubstring(`\u003e`))
		})

		It("sends a SIGHUP to reload the NATS server after writing the config", func() {
			Expect(bootstrapSync.Bootstrap()).To(Succeed())

			Expect(bootstrapCmdCalls).To(HaveLen(1))
			Expect(bootstrapCmdCalls[0]).To(ContainSubstring("--signal"))
			Expect(bootstrapCmdCalls[0]).To(ContainSubstring("reload="))
		})

		It("skips the write when neither subject file exists", func() {
			bootstrapSync.BoshConfig.DirectorSubjectFile = "/nonexistent"
			bootstrapSync.BoshConfig.HMSubjectFile = "/nonexistent"

			err := bootstrapSync.Bootstrap()
			Expect(err).NotTo(HaveOccurred())

			// Config must remain unchanged (no SIGHUP either).
			data, _ := os.ReadFile(natsConfigFilePath)
			Expect(string(data)).To(ContainSubstring("f0oBar"))
			Expect(bootstrapCmdCalls).To(BeEmpty())
		})

		It("returns an error when the NATS reload fails", func() {
			bootstrapCmdErr = fmt.Errorf("reload failed")

			err := bootstrapSync.Bootstrap()
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("reload failed"))
		})

		It("includes only the HM user when the director subject file is missing", func() {
			bootstrapSync.BoshConfig.DirectorSubjectFile = "/nonexistent"

			Expect(bootstrapSync.Bootstrap()).To(Succeed())

			data, _ := os.ReadFile(natsConfigFilePath)
			var cfg natsauthconfig.AuthorizationConfig
			Expect(json.Unmarshal(data, &cfg)).To(Succeed())
			Expect(cfg.Authorization.Users).To(HaveLen(1))
			Expect(cfg.Authorization.Users[0].User).To(ContainSubstring("hm.bosh-internal"))
		})

		// Regression test: if bosh-nats-sync restarts mid-flight (e.g. after a
		// sync error), auth.json may already contain agent credentials written by a
		// previous Execute() call.  Bootstrap must NOT overwrite those credentials
		// with a director/HM-only config – that would remove agent entries and
		// prevent rebooting VMs from reconnecting to NATS.
		Context("when auth.json already contains real user entries", func() {
			BeforeEach(func() {
				// Pre-populate auth.json with a director user + one agent user to
				// simulate the state after a successful Execute() call.
				existingCfg := natsauthconfig.AuthorizationConfig{
					Authorization: natsauthconfig.Authorization{
						Users: []natsauthconfig.User{
							{
								User:        directorSubject,
								Permissions: natsauthconfig.Permissions{Publish: []string{"agent.*"}, Subscribe: []string{"director.>"}},
							},
							{
								User:        "C=USA, O=Cloud Foundry, CN=8ecbb6f1-d091-4b2d-bc44-b299a4da71dc.agent.bosh-internal",
								Permissions: natsauthconfig.Permissions{Publish: []string{"hm.agent.heartbeat.8ecbb6f1"}, Subscribe: []string{"agent.8ecbb6f1"}},
							},
						},
					},
				}
				var buf bytes.Buffer
				enc := json.NewEncoder(&buf)
				enc.SetEscapeHTML(false)
				Expect(enc.Encode(existingCfg)).To(Succeed())
				Expect(os.WriteFile(natsConfigFilePath, bytes.TrimRight(buf.Bytes(), "\n"), 0644)).To(Succeed())
			})

			It("does not overwrite auth.json and does not send SIGHUP", func() {
				originalData, _ := os.ReadFile(natsConfigFilePath)

				Expect(bootstrapSync.Bootstrap()).To(Succeed())

				currentData, _ := os.ReadFile(natsConfigFilePath)
				Expect(currentData).To(Equal(originalData), "Bootstrap should not modify auth.json when real users already exist")
				Expect(bootstrapCmdCalls).To(BeEmpty(), "Bootstrap should not send SIGHUP when real users already exist")
			})

			It("preserves the agent credential that was already in auth.json", func() {
				Expect(bootstrapSync.Bootstrap()).To(Succeed())

				data, _ := os.ReadFile(natsConfigFilePath)
				Expect(string(data)).To(ContainSubstring("8ecbb6f1-d091-4b2d-bc44-b299a4da71dc.agent.bosh-internal"))
			})
		})
	})
})

// Mirrors Ruby spec: spec/nats_sync/users_sync_spec.rb
//
//	context 'with various network errors' do
//	  [ Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT,
//	    Net::OpenTimeout, SocketError ].each do |error_class|
//	    it "retries on #{error_class}"
//	  end
//	end
//
// In Go the retry gate is isConnectionError, which matches connection-class
// errors by substring.  The table below verifies every string pattern in the
// function, annotated with the Ruby error class it corresponds to.
var _ = DescribeTable("isConnectionError",
	func(err error, shouldRetry bool) {
		Expect(userssync.IsConnectionError(err)).To(Equal(shouldRetry))
	},

	// ── errors that must trigger a retry ──────────────────────────────────

	// Ruby: Errno::ECONNREFUSED
	Entry("connection refused",
		errors.New("dial tcp 127.0.0.1:25555: connect: connection refused"), true),

	// Ruby: Errno::ECONNRESET
	Entry("connection reset by peer",
		errors.New("read tcp 127.0.0.1:12345->127.0.0.1:25555: read: connection reset by peer"), true),

	// Ruby: Errno::ETIMEDOUT
	Entry("connection timed out",
		errors.New("dial tcp 127.0.0.1:25555: connect: connection timed out"), true),

	// Ruby: Net::OpenTimeout — Go surfaces this as an i/o timeout
	Entry("i/o timeout (Net::OpenTimeout read-side)",
		errors.New("read tcp 127.0.0.1:25555: i/o timeout"), true),

	// Ruby: Net::OpenTimeout — Go surfaces this via context deadline
	Entry("context deadline exceeded (Net::OpenTimeout connect-side)",
		errors.New(`get "http://127.0.0.1:25555/info": context deadline exceeded (Client.Timeout exceeded while awaiting headers)`), true),

	// Ruby: SocketError — DNS resolution failure
	Entry("no such host (SocketError)",
		errors.New("dial tcp: lookup director.example.com on 8.8.8.8:53: no such host"), true),

	// Ruby: Errno::EHOSTUNREACH (also in DIRECTOR_CONNECTION_ERRORS)
	Entry("host is unreachable (Errno::EHOSTUNREACH)",
		errors.New("dial tcp: connect: host is unreachable"), true),

	// Ruby: Errno::ENETUNREACH (also in DIRECTOR_CONNECTION_ERRORS)
	Entry("network is unreachable (Errno::ENETUNREACH)",
		errors.New("dial tcp: connect: network is unreachable"), true),

	// Go-specific: bare EOF when the server closes the connection mid-response
	// (surfaces as Errno::ECONNRESET on the Ruby side)
	Entry("EOF",
		errors.New("EOF"), true),

	// Go-specific: partial response body truncated
	Entry("unexpected EOF",
		errors.New("unexpected EOF"), true),

	// ── errors that must NOT trigger a retry ──────────────────────────────

	// HTTP-level application errors are not connection errors
	Entry("HTTP 401 unauthorized",
		errors.New("cannot access: /info, Status Code: 401, Unauthorized"), false),

	Entry("HTTP 500 internal server error",
		errors.New("cannot access: /info, Status Code: 500, Internal Server Error"), false),

	Entry("generic application error",
		errors.New("failed to parse response body"), false),

	// nil means no error occurred — must not be treated as retryable
	Entry("nil error", nil, false),
)
