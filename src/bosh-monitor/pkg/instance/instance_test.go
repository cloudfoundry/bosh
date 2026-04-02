package instance_test

import (
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/instance"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Agent", func() {
	Describe("Name", func() {
		It("returns a formatted name with deployment info", func() {
			agent := instance.NewAgent("agent-1", instance.WithDeployment("dep-1"))
			agent.Job = "web"
			agent.InstanceID = "inst-1"
			agent.CID = "cid-1"
			name := agent.Name()
			Expect(name).To(ContainSubstring("dep-1"))
			Expect(name).To(ContainSubstring("web"))
			Expect(name).To(ContainSubstring("agent-1"))
		})

		It("returns basic name without deployment", func() {
			agent := instance.NewAgent("agent-1")
			name := agent.Name()
			Expect(name).To(ContainSubstring("agent-1"))
		})
	})

	Describe("TimedOut", func() {
		It("returns false when recently updated", func() {
			agent := instance.NewAgent("agent-1")
			Expect(agent.TimedOut()).To(BeFalse())
		})

		It("returns true when not updated within timeout", func() {
			agent := instance.NewAgent("agent-1", instance.WithAgentTimeout(1*time.Millisecond))
			time.Sleep(5 * time.Millisecond)
			Expect(agent.TimedOut()).To(BeTrue())
		})
	})

	Describe("Rogue", func() {
		It("returns false for managed agents", func() {
			agent := instance.NewAgent("agent-1", instance.WithDeployment("dep-1"))
			Expect(agent.Rogue()).To(BeFalse())
		})

		It("returns true for unmanaged agents past rogue alert threshold", func() {
			agent := instance.NewAgent("agent-1", instance.WithRogueAgentAlert(1*time.Millisecond))
			time.Sleep(5 * time.Millisecond)
			Expect(agent.Rogue()).To(BeTrue())
		})

		It("returns false for unmanaged agents within rogue alert threshold", func() {
			agent := instance.NewAgent("agent-1", instance.WithRogueAgentAlert(10*time.Second))
			Expect(agent.Rogue()).To(BeFalse())
		})
	})
})

var _ = Describe("Instance", func() {
	Describe("NewInstance", func() {
		It("creates instance from data", func() {
			data := director.Instance{
				ID:        "inst-1",
				AgentID:   "agent-1",
				Job:       "web",
				Index:     "0",
				CID:       "cid-1",
				ExpectsVM: true,
			}
			inst := instance.NewInstance(data)
			Expect(inst.InstanceID).To(Equal("inst-1"))
			Expect(inst.AgentID).To(Equal("agent-1"))
			Expect(inst.Job).To(Equal("web"))
			Expect(inst.Index).To(Equal("0"))
			Expect(inst.CID).To(Equal("cid-1"))
			Expect(inst.ExpectsVM).To(BeTrue())
		})
	})

	Describe("HasVM", func() {
		It("returns true when CID is set", func() {
			inst := instance.NewInstance(director.Instance{ID: "1", CID: "cid-1"})
			Expect(inst.HasVM()).To(BeTrue())
		})

		It("returns false when CID is empty", func() {
			inst := instance.NewInstance(director.Instance{ID: "1"})
			Expect(inst.HasVM()).To(BeFalse())
		})
	})

	Describe("Name", func() {
		It("returns formatted name", func() {
			inst := instance.NewInstance(director.Instance{
				ID: "inst-1", AgentID: "agent-1", Job: "web", Index: "0", CID: "cid-1",
			})
			inst.Deployment = "dep-1"
			Expect(inst.Name()).To(ContainSubstring("dep-1"))
			Expect(inst.Name()).To(ContainSubstring("web"))
		})
	})
})

var _ = Describe("Deployment", func() {
	Describe("NewDeployment", func() {
		It("creates deployment from data", func() {
			data := director.Deployment{
				Name:  "dep-1",
				Teams: []string{"team-1", "team-2"},
			}
			dep := instance.NewDeployment(data, 60*time.Second, 120*time.Second)
			Expect(dep.Name()).To(Equal("dep-1"))
			Expect(dep.Teams).To(ConsistOf("team-1", "team-2"))
		})
	})

	Describe("AddInstance", func() {
		It("adds an instance to the deployment", func() {
			dep := instance.NewDeployment(director.Deployment{Name: "dep-1"}, 60*time.Second, 120*time.Second)
			inst := instance.NewInstance(director.Instance{ID: "inst-1", Job: "web"})
			Expect(dep.AddInstance(inst)).To(BeTrue())
			Expect(dep.GetInstance("inst-1")).To(Equal(inst))
			Expect(inst.Deployment).To(Equal("dep-1"))
		})

		It("returns false for nil instance", func() {
			dep := instance.NewDeployment(director.Deployment{Name: "dep-1"}, 60*time.Second, 120*time.Second)
			Expect(dep.AddInstance(nil)).To(BeFalse())
		})
	})

	Describe("UpsertAgent", func() {
		It("creates agent for instance with agent_id", func() {
			dep := instance.NewDeployment(director.Deployment{Name: "dep-1"}, 60*time.Second, 120*time.Second)
			inst := instance.NewInstance(director.Instance{
				ID: "inst-1", AgentID: "agent-1", Job: "web", CID: "cid-1",
			})
			dep.AddInstance(inst)
			Expect(dep.UpsertAgent(inst)).To(BeTrue())
			Expect(dep.GetAgent("agent-1")).NotTo(BeNil())
		})

		It("returns false for instance without agent_id", func() {
			dep := instance.NewDeployment(director.Deployment{Name: "dep-1"}, 60*time.Second, 120*time.Second)
			inst := instance.NewInstance(director.Instance{ID: "inst-1", Job: "web"})
			dep.AddInstance(inst)
			Expect(dep.UpsertAgent(inst)).To(BeFalse())
		})
	})
})

var _ = Describe("Manager", func() {
	var (
		manager   *instance.Manager
		processor *fakeProcessor
		logger    *slog.Logger
	)

	BeforeEach(func() {
		processor = &fakeProcessor{}
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
		manager = instance.NewManager(processor, logger, 60*time.Second, 120*time.Second)
	})

	Describe("SyncDeployments", func() {
		It("adds new deployments", func() {
			manager.SyncDeployments([]director.Deployment{
				{Name: "dep-1"},
				{Name: "dep-2"},
			})
			Expect(manager.DeploymentsCount()).To(Equal(2))
		})

		It("removes stale deployments", func() {
			manager.SyncDeployments([]director.Deployment{
				{Name: "dep-1"},
				{Name: "dep-2"},
			})
			manager.SyncDeployments([]director.Deployment{
				{Name: "dep-1"},
			})
			Expect(manager.DeploymentsCount()).To(Equal(1))
		})
	})

	Describe("ProcessEvent", func() {
		BeforeEach(func() {
			manager.SyncDeployments([]director.Deployment{{Name: "dep-1"}})
			manager.SyncDeploymentState(
				director.Deployment{Name: "dep-1"},
				[]director.Instance{
					{ID: "inst-1", AgentID: "agent-1", Job: "web", CID: "cid-1", ExpectsVM: true},
				},
			)
		})

		It("processes heartbeat events", func() {
			manager.ProcessEvent("heartbeat", "hm.agent.heartbeat.agent-1", []byte(`{
				"job": "web",
				"job_state": "running",
				"vitals": {}
			}`))
			Expect(manager.HeartbeatsReceived()).To(Equal(1))
		})

		It("processes alert events", func() {
			manager.ProcessEvent("alert", "hm.agent.alert.agent-1", []byte(`{
				"id": "alert-1",
				"severity": 2,
				"title": "Test",
				"created_at": 1234567890
			}`))
			Expect(manager.AlertsProcessed()).To(Equal(1))
		})
	})

	Describe("UnresponsiveAgents", func() {
		It("returns counts per deployment", func() {
			manager.SyncDeployments([]director.Deployment{{Name: "dep-1"}})
			result := manager.UnresponsiveAgents()
			Expect(result).To(HaveKey("dep-1"))
		})
	})

	Describe("AnalyzeAgents", func() {
		It("analyzes agents and returns count", func() {
			manager.SyncDeployments([]director.Deployment{{Name: "dep-1"}})
			manager.SyncDeploymentState(
				director.Deployment{Name: "dep-1"},
				[]director.Instance{
					{ID: "inst-1", AgentID: "agent-1", Job: "web", CID: "cid-1", ExpectsVM: true},
				},
			)
			count := manager.AnalyzeAgents()
			Expect(count).To(BeNumerically(">=", 0))
		})

		It("emits resurrection-disabled alert for timed-out agents with resurrection disabled", func() {
			// Use a very short timeout so the agent times out immediately.
			fastManager := instance.NewManager(processor, logger, 1*time.Millisecond, 120*time.Second)
			fastManager.SetResurrectionChecker(&fakeResurrectionChecker{
				enabledJobs: map[string]bool{"web": false},
			})
			fastManager.SyncDeployments([]director.Deployment{{Name: "dep-1"}})
			fastManager.SyncDeploymentState(
				director.Deployment{Name: "dep-1"},
				[]director.Instance{
					{ID: "inst-1", AgentID: "agent-1", Job: "web", CID: "cid-1", ExpectsVM: true},
				},
			)
			time.Sleep(5 * time.Millisecond) // let agent time out

			fastManager.AnalyzeAgents()

			disabled := processor.alertsWithTitle("Resurrection is disabled by resurrection config")
			Expect(disabled).To(HaveLen(1), "expected exactly one resurrection-disabled alert")
			Expect(disabled[0].Deployment).To(Equal("dep-1"))
		})

		It("does not emit resurrection-disabled alert when resurrection is enabled", func() {
			fastManager := instance.NewManager(processor, logger, 1*time.Millisecond, 120*time.Second)
			fastManager.SyncDeployments([]director.Deployment{{Name: "dep-1"}})
			fastManager.SyncDeploymentState(
				director.Deployment{Name: "dep-1"},
				[]director.Instance{
					{ID: "inst-1", AgentID: "agent-1", Job: "web", CID: "cid-1", ExpectsVM: true},
				},
			)
			time.Sleep(5 * time.Millisecond)

			fastManager.AnalyzeAgents()

			disabled := processor.alertsWithTitle("Resurrection is disabled by resurrection config")
			Expect(disabled).To(BeEmpty())
		})
	})

	Describe("AnalyzeInstances", func() {
		It("detects instances without VMs", func() {
			manager.SyncDeployments([]director.Deployment{{Name: "dep-1"}})
			manager.SyncDeploymentState(
				director.Deployment{Name: "dep-1"},
				[]director.Instance{
					{ID: "inst-1", Job: "web", ExpectsVM: true},
				},
			)
			count := manager.AnalyzeInstances()
			Expect(count).To(Equal(1))
			Expect(processor.processedCount).To(BeNumerically(">", 0))
		})

		It("emits resurrection-disabled alert for missing VMs with resurrection disabled", func() {
			rcManager := instance.NewManager(processor, logger, 60*time.Second, 120*time.Second)
			rcManager.SetResurrectionChecker(&fakeResurrectionChecker{
				enabledJobs: map[string]bool{"web": false},
			})
			rcManager.SyncDeployments([]director.Deployment{{Name: "dep-1"}})
			// Instance with no CID = missing VM; no AgentID = goes through UpsertAgent for deleted-VM path.
			rcManager.SyncDeploymentState(
				director.Deployment{Name: "dep-1"},
				[]director.Instance{
					{ID: "inst-1", Job: "web", ExpectsVM: true},
				},
			)

			rcManager.AnalyzeInstances()

			disabled := processor.alertsWithTitle("Resurrection is disabled by resurrection config")
			Expect(disabled).To(HaveLen(1), "expected exactly one resurrection-disabled alert")
			Expect(disabled[0].Deployment).To(Equal("dep-1"))
		})
	})

	Describe("DirectorInitialDeploymentSyncDone", func() {
		It("returns false initially", func() {
			Expect(manager.DirectorInitialDeploymentSyncDone()).To(BeFalse())
		})
	})

	Describe("FetchDeployments", func() {
		It("sets the sync-done flag only after a full successful cycle", func() {
			d := &fakeDirector{
				deployments: []director.Deployment{{Name: "dep-a"}, {Name: "dep-b"}},
				instances:   map[string][]director.Instance{"dep-a": {}, "dep-b": {}},
			}
			Expect(manager.FetchDeployments(d)).To(Succeed())
			Expect(manager.DirectorInitialDeploymentSyncDone()).To(BeTrue())
		})

		It("does not set the sync-done flag when instance fetch fails", func() {
			d := &fakeDirector{
				deployments: []director.Deployment{{Name: "dep-a"}, {Name: "dep-b"}},
				instances:   map[string][]director.Instance{"dep-a": {}},
				// dep-b not in the map → GetDeploymentInstances returns an error
			}
			Expect(manager.FetchDeployments(d)).NotTo(Succeed())
			Expect(manager.DirectorInitialDeploymentSyncDone()).To(BeFalse())
		})

		It("does not set the sync-done flag when listing deployments fails", func() {
			d := &fakeDirector{listErr: fmt.Errorf("director unavailable")}
			Expect(manager.FetchDeployments(d)).NotTo(Succeed())
			Expect(manager.DirectorInitialDeploymentSyncDone()).To(BeFalse())
		})
	})
})

type fakeProcessor struct {
	processedCount int
	events         []events.Event
}

func (fp *fakeProcessor) Process(e events.Event) error {
	fp.processedCount++
	fp.events = append(fp.events, e)
	return nil
}

func (fp *fakeProcessor) alertsWithTitle(title string) []*events.Alert {
	var out []*events.Alert
	for _, e := range fp.events {
		if a, ok := e.(*events.Alert); ok && a.Title == title {
			out = append(out, a)
		}
	}
	return out
}

type fakeResurrectionChecker struct {
	enabledJobs map[string]bool
}

func (f *fakeResurrectionChecker) ResurrectionEnabled(_ string, job string) bool {
	enabled, ok := f.enabledJobs[job]
	if !ok {
		return true
	}
	return enabled
}

// fakeDirector is a test double for the Director interface used by FetchDeployments.
type fakeDirector struct {
	listErr     error
	deployments []director.Deployment
	instances   map[string][]director.Instance
}

func (fd *fakeDirector) Deployments() ([]director.Deployment, error) {
	if fd.listErr != nil {
		return nil, fd.listErr
	}
	return fd.deployments, nil
}

func (fd *fakeDirector) GetDeploymentInstances(name string) ([]director.Instance, error) {
	insts, ok := fd.instances[name]
	if !ok {
		return nil, fmt.Errorf("no instances for deployment %q", name)
	}
	return insts, nil
}
