package instance_test

import (
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
			manager.ProcessEvent("heartbeat", "hm.agent.heartbeat.agent-1", `{
				"job": "web",
				"job_state": "running",
				"vitals": {}
			}`)
			Expect(manager.HeartbeatsReceived()).To(Equal(1))
		})

		It("processes alert events", func() {
			manager.ProcessEvent("alert", "hm.agent.alert.agent-1", `{
				"id": "alert-1",
				"severity": 2,
				"title": "Test",
				"created_at": 1234567890
			}`)
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
	})

	Describe("DirectorInitialDeploymentSyncDone", func() {
		It("returns false initially", func() {
			Expect(manager.DirectorInitialDeploymentSyncDone()).To(BeFalse())
		})
	})
})

type fakeProcessor struct {
	processedCount int
}

func (fp *fakeProcessor) Process(_ events.Event) error {
	fp.processedCount++
	return nil
}
