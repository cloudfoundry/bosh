package runner_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-nats-sync/pkg/config"
	"bosh-nats-sync/pkg/runner"
)

var _ = Describe("Runner", func() {
	var (
		cfg                *config.Config
		logBuf             *bytes.Buffer
		logger             *slog.Logger
		natsConfigFile     *os.File
		server             *httptest.Server
		commandRunnerCalls []string
		commandRunnerErr   error
	)

	BeforeEach(func() {
		logBuf = &bytes.Buffer{}
		logger = slog.New(slog.NewTextHandler(logBuf, &slog.HandlerOptions{Level: slog.LevelInfo}))

		var err error
		natsConfigFile, err = os.CreateTemp("", "nats_config_*.json")
		Expect(err).NotTo(HaveOccurred())
		os.WriteFile(natsConfigFile.Name(), []byte("{}"), 0644)

		dirSubjectFile, err := os.CreateTemp("", "director-subject-*")
		Expect(err).NotTo(HaveOccurred())
		os.WriteFile(dirSubjectFile.Name(), []byte("C=USA, O=Cloud Foundry, CN=default.director.bosh-internal"), 0644)

		hmSubjectFile, err := os.CreateTemp("", "hm-subject-*")
		Expect(err).NotTo(HaveOccurred())
		os.WriteFile(hmSubjectFile.Name(), []byte("C=USA, O=Cloud Foundry, CN=default.hm.bosh-internal"), 0644)

		commandRunnerCalls = nil
		commandRunnerErr = nil

		mux := http.NewServeMux()
		server = httptest.NewServer(mux)

		infoJSON := fmt.Sprintf(`{
			"name": "bosh-lite",
			"user_authentication": {
				"type": "uaa",
				"options": {"url": "%s"}
			}
		}`, server.URL)

		mux.HandleFunc("/info", func(w http.ResponseWriter, r *http.Request) {
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

		cfg = &config.Config{
			Director: config.DirectorConfig{
				URL:                   server.URL,
				User:                  "admin",
				Password:              "admin",
				ClientID:              "client_id",
				ClientSecret:          "client_secret",
				DirectorSubjectFile:   dirSubjectFile.Name(),
				HMSubjectFile:         hmSubjectFile.Name(),
				ConnectionWaitTimeout: 2,
			},
			Intervals: config.IntervalsConfig{
				PollUserSync: 1,
			},
			NATS: config.NATSConfig{
				ConfigFilePath:       natsConfigFile.Name(),
				NATSServerExecutable: "/var/vcap/packages/nats/bin/nats-server",
				NATSServerPIDFile:    "/var/vcap/sys/run/bpm/nats/nats.pid",
			},
		}
	})

	AfterEach(func() {
		if natsConfigFile != nil {
			os.Remove(natsConfigFile.Name())
		}
		if server != nil {
			server.Close()
		}
	})

	cmdRunner := func(executable string, args ...string) ([]byte, error) {
		commandRunnerCalls = append(commandRunnerCalls, fmt.Sprintf("%s %s", executable, strings.Join(args, " ")))
		return []byte("Success"), commandRunnerErr
	}

	Describe("when the runner is created with the sample config", func() {
		It("starts UsersSync.Execute on the configured interval", func() {
			r := runner.NewWithCommandRunner(cfg, logger, cmdRunner)

			go r.Run()
			time.Sleep(2500 * time.Millisecond)
			r.Stop()

			data, err := os.ReadFile(natsConfigFile.Name())
			Expect(err).NotTo(HaveOccurred())
			var result map[string]interface{}
			Expect(json.Unmarshal(data, &result)).To(Succeed())
			Expect(result).To(HaveKey("authorization"))

			Expect(len(commandRunnerCalls)).To(BeNumerically(">=", 1))
		})

		It("logs when starting", func() {
			r := runner.NewWithCommandRunner(cfg, logger, cmdRunner)

			go r.Run()
			time.Sleep(500 * time.Millisecond)
			r.Stop()

			Expect(logBuf.String()).To(ContainSubstring("Nats Sync starting..."))
		})
	})

	Describe("bootstrap on startup", func() {
		It("writes the initial NATS config from subject files before the first sync tick", func() {
			// Override natsConfigFile with the fooBar placeholder that pre-start creates.
			os.WriteFile(natsConfigFile.Name(), []byte(`{"authorization":{"token":"f0oBar"}}`), 0644)

			r := runner.NewWithCommandRunner(cfg, logger, cmdRunner)

			go r.Run()
			// Sleep well under PollUserSync (1s) — bootstrap must fire synchronously.
			time.Sleep(200 * time.Millisecond)
			r.Stop()

			data, err := os.ReadFile(natsConfigFile.Name())
			Expect(err).NotTo(HaveOccurred())
			var result map[string]interface{}
			Expect(json.Unmarshal(data, &result)).To(Succeed())

			auth := result["authorization"].(map[string]interface{})
			users := auth["users"].([]interface{})
			Expect(len(users)).To(BeNumerically(">=", 2), "expected director and HM users in bootstrap config")

			subjects := make([]string, 0, len(users))
			for _, u := range users {
				subjects = append(subjects, u.(map[string]interface{})["user"].(string))
			}
			Expect(subjects).To(ContainElement(ContainSubstring("director.bosh-internal")))
			Expect(subjects).To(ContainElement(ContainSubstring("hm.bosh-internal")))

			// cmdRunner must have been called at least once for the bootstrap SIGHUP.
			Expect(len(commandRunnerCalls)).To(BeNumerically(">=", 1))
		})

		It("does not contact the director during bootstrap", func() {
			var directorCalled bool
			isolatedMux := http.NewServeMux()
			isolatedMux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
				directorCalled = true
				w.WriteHeader(http.StatusOK)
			})
			isolatedServer := httptest.NewServer(isolatedMux)
			defer isolatedServer.Close()

			isolatedCfg := *cfg
			isolatedCfg.Director.URL = isolatedServer.URL

			r := runner.NewWithCommandRunner(&isolatedCfg, logger, cmdRunner)
			go r.Run()
			time.Sleep(200 * time.Millisecond)
			r.Stop()

			Expect(directorCalled).To(BeFalse(), "bootstrap must not query the director")
		})

		Context("when bootstrap fails (e.g. NATS SIGHUP error)", func() {
			It("logs the error but continues running the sync loop", func() {
				var callCount int32
				nonFatalRunner := func(executable string, args ...string) ([]byte, error) {
					n := atomic.AddInt32(&callCount, 1)
					if n == 1 {
						// bootstrap reload fails
						return nil, fmt.Errorf("cannot execute: bootstrap reload failed")
					}
					return []byte("ok"), nil
				}

				r := runner.NewWithCommandRunner(cfg, logger, nonFatalRunner)

				done := make(chan struct{})
				go func() {
					r.Run()
					close(done)
				}()

				// Run() must NOT exit immediately after a bootstrap failure.
				Consistently(done, 500*time.Millisecond).ShouldNot(BeClosed())
				r.Stop()
				Eventually(done, 2*time.Second).Should(BeClosed())

				Expect(logBuf.String()).To(ContainSubstring("Bootstrap failed"))
				Expect(logBuf.String()).To(ContainSubstring("bootstrap reload failed"))
			})
		})
	})

	Describe("exception handling", func() {
		Context("when an error occurs during periodic sync", func() {
			It("stops the runner and logs the error", func() {
				var syncCount int32

				failServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					count := atomic.AddInt32(&syncCount, 1)
					if r.URL.Path == "/info" && count <= 2 {
						w.WriteHeader(http.StatusOK)
						fmt.Fprint(w, `{"name":"bosh-lite"}`)
						return
					}
					w.WriteHeader(http.StatusInternalServerError)
				}))
				defer failServer.Close()

				failCfg := &config.Config{
					Director: config.DirectorConfig{
						URL:                   failServer.URL,
						User:                  "admin",
						Password:              "admin",
						DirectorSubjectFile:   "/nonexistent",
						HMSubjectFile:         "/nonexistent",
						ConnectionWaitTimeout: 1,
					},
					Intervals: config.IntervalsConfig{PollUserSync: 1},
					NATS: config.NATSConfig{
						ConfigFilePath:       natsConfigFile.Name(),
						NATSServerExecutable: "/var/vcap/packages/nats/bin/nats-server",
						NATSServerPIDFile:    "/var/vcap/sys/run/bpm/nats/nats.pid",
					},
				}

				var reloadCount int32
				failCmdRunner := func(executable string, args ...string) ([]byte, error) {
					atomic.AddInt32(&reloadCount, 1)
					return nil, fmt.Errorf("cannot execute: reload failed")
				}

				r := runner.NewWithCommandRunner(failCfg, logger, failCmdRunner)

				done := make(chan struct{})
				go func() {
					r.Run()
					close(done)
				}()
				Eventually(done, 5*time.Second).Should(BeClosed())

				logOutput := logBuf.String()
				Expect(logOutput).To(ContainSubstring("reload failed"))
			})
		})
	})
})
