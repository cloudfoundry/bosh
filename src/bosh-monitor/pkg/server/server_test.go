package server_test

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/server"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type fakeInstanceManager struct {
	syncDone bool
}

func (f *fakeInstanceManager) DirectorInitialDeploymentSyncDone() bool {
	return f.syncDone
}
func (f *fakeInstanceManager) UnresponsiveAgents() map[string]int {
	return map[string]int{"dep-1": 1}
}
func (f *fakeInstanceManager) UnhealthyAgents() map[string]int {
	return map[string]int{"dep-1": 0}
}
func (f *fakeInstanceManager) TotalAvailableAgents() map[string]int {
	return map[string]int{"dep-1": 5}
}
func (f *fakeInstanceManager) FailingInstances() map[string]int {
	return map[string]int{"dep-1": 2}
}
func (f *fakeInstanceManager) StoppedInstances() map[string]int {
	return map[string]int{"dep-1": 0}
}
func (f *fakeInstanceManager) UnknownInstances() map[string]int {
	return map[string]int{"dep-1": 0}
}

var _ = Describe("Server", func() {
	var (
		srv     *server.Server
		im      *fakeInstanceManager
		port    int
		baseURL string
	)

	BeforeEach(func() {
		port = 25930 + GinkgoParallelProcess()
		im = &fakeInstanceManager{syncDone: true}
		logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
		srv = server.New(port, im, logger)
		baseURL = fmt.Sprintf("http://127.0.0.1:%d", port)

		go srv.Start()
		Eventually(func() error {
			_, err := http.Get(baseURL + "/healthz")
			return err
		}, 2*time.Second, 50*time.Millisecond).Should(Succeed())
	})

	AfterEach(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer cancel()
		srv.Stop(ctx)
	})

	Describe("GET /healthz", func() {
		It("returns 200 when healthy", func() {
			resp, err := http.Get(baseURL + "/healthz")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			body, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			Expect(string(body)).To(ContainSubstring("Last pulse was"))
		})
	})

	Describe("GET /unresponsive_agents", func() {
		It("returns JSON when sync is done", func() {
			resp, err := http.Get(baseURL + "/unresponsive_agents")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			var data map[string]int
			json.NewDecoder(resp.Body).Decode(&data)
			resp.Body.Close()
			Expect(data["dep-1"]).To(Equal(1))
		})

		It("returns 503 when sync is not done", func() {
			im.syncDone = false
			resp, err := http.Get(baseURL + "/unresponsive_agents")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(503))
			resp.Body.Close()
		})
	})

	Describe("GET /unhealthy_agents", func() {
		It("returns JSON data", func() {
			resp, err := http.Get(baseURL + "/unhealthy_agents")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			resp.Body.Close()
		})
	})

	Describe("GET /total_available_agents", func() {
		It("returns JSON data", func() {
			resp, err := http.Get(baseURL + "/total_available_agents")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			resp.Body.Close()
		})
	})

	Describe("GET /failing_instances", func() {
		It("returns JSON data", func() {
			resp, err := http.Get(baseURL + "/failing_instances")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			resp.Body.Close()
		})
	})

	Describe("GET /stopped_instances", func() {
		It("returns JSON data", func() {
			resp, err := http.Get(baseURL + "/stopped_instances")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			resp.Body.Close()
		})
	})

	Describe("GET /unknown_instances", func() {
		It("returns JSON data", func() {
			resp, err := http.Get(baseURL + "/unknown_instances")
			Expect(err).NotTo(HaveOccurred())
			Expect(resp.StatusCode).To(Equal(200))
			resp.Body.Close()
		})
	})
})
