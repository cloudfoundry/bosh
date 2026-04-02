package userssync_test

import (
	"encoding/json"
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
					data, _ := json.Marshal(cfg)
					os.WriteFile(natsConfigFilePath, data, 0644)
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
				mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
					requestCount++
					if requestCount <= 1 {
						w.WriteHeader(http.StatusServiceUnavailable)
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

			It("eventually succeeds", func() {
				sync = createSync()
				err := sync.Execute()
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("when director connection times out", func() {
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
})
