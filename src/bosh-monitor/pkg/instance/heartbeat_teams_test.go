package instance_test

import (
	"errors"
	"log/slog"
	"os"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/instance"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// The tests in this file mirror
// src/bosh-monitor/spec/unit/bosh/monitor/instance_manager_spec.rb
// (context 'heartbeats', context 'bad/good alert', context 'shutdown').

// captureProcessor records every call to Process() and can optionally
// return a configured error.
type captureProcessor struct {
	calls     []events.Event
	returnErr error
}

func (cp *captureProcessor) Process(event events.Event) error {
	cp.calls = append(cp.calls, event)
	return cp.returnErr
}

func (cp *captureProcessor) lastHeartbeat() *events.Heartbeat {
	if len(cp.calls) == 0 {
		return nil
	}
	hb, _ := cp.calls[len(cp.calls)-1].(*events.Heartbeat)
	return hb
}

// ---------------------------------------------------------------------------
// Helpers shared by the tests below
// ---------------------------------------------------------------------------

var cloud1 = []director.Instance{
	{ID: "iuuid1", AgentID: "007", Index: "0", Job: "mutator", ExpectsVM: true},
}

func newHeartbeatManager(proc *captureProcessor) *instance.Manager {
	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
	return instance.NewManager(proc, logger, 10*time.Second, 10*time.Second)
}

// ---------------------------------------------------------------------------
// ProcessEvent — heartbeats
// ---------------------------------------------------------------------------

var _ = Describe("Manager.ProcessEvent — heartbeats (instance_manager_spec.rb)", func() {

	var (
		mgr  *instance.Manager
		proc *captureProcessor
	)

	BeforeEach(func() {
		proc = &captureProcessor{}
		mgr = newHeartbeatManager(proc)
	})

	It("creates unmanaged agents for unknown agent IDs", func() {
		// Ruby: "can process" — heartbeats from unknown agents still increment agent count
		Expect(mgr.AgentsCount()).To(Equal(0))
		mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.agent007", nil)
		mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.agent007", nil)
		mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.agent008", nil)
		Expect(mgr.AgentsCount()).To(Equal(2))
	})

	It("does not process heartbeat when instance_id, job, or deployment cannot be resolved", func() {
		// Ruby: "when heartbeat information cannot be completed for instance_id,
		// job, or deployment" → "does not process the heartbeat"
		// Agent with no matching deployment/instance yields empty fields.
		mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.007", nil)
		Expect(proc.calls).To(BeEmpty())
	})

	Context("when the deployment and instances are synced", func() {
		BeforeEach(func() {
			mgr.SyncDeployments([]director.Deployment{{Name: "mycloud", Teams: []string{"ateam"}}})
			mgr.SyncDeploymentState(
				director.Deployment{Name: "mycloud", Teams: []string{"ateam"}},
				cloud1,
			)
		})

		It("passes agent_id, deployment, instance_id, job, and teams to the processor", func() {
			// Ruby: "processes a valid populated heartbeat message"
			mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.007", nil)

			Expect(proc.calls).To(HaveLen(1))
			Expect(proc.calls[0].Kind()).To(Equal("heartbeat"))
			hb, ok := proc.calls[0].(*events.Heartbeat)
			Expect(ok).To(BeTrue())
			Expect(hb.AgentID).To(Equal("007"))
			Expect(hb.Deployment).To(Equal("mycloud"))
			Expect(hb.InstanceID).To(Equal("iuuid1"))
			Expect(hb.Job).To(Equal("mutator"))
			Expect(hb.Teams).To(ConsistOf("ateam"))
			Expect(hb.Timestamp.IsZero()).To(BeFalse())
		})

		It("uses updated teams after SyncDeploymentState is called again with new teams", func() {
			// Ruby: "when teams have changed between heartbeats" →
			// "updates teams in heartbeat event"
			mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.007", nil)
			Expect(proc.lastHeartbeat().Teams).To(ConsistOf("ateam"))

			// Re-sync with two teams
			mgr.SyncDeploymentState(
				director.Deployment{Name: "mycloud", Teams: []string{"ateam", "bteam"}},
				cloud1,
			)
			mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.007", nil)
			Expect(proc.lastHeartbeat().Teams).To(ConsistOf("ateam", "bteam"))
		})
	})
})

// ---------------------------------------------------------------------------
// ProcessEvent — shutdown
// ---------------------------------------------------------------------------

var _ = Describe("Manager.ProcessEvent — shutdown (instance_manager_spec.rb)", func() {

	It("removes the agent from the manager on shutdown", func() {
		// Ruby: "shutdowns agent" — agents_count drops from 3 to 2 after shutdown.008
		proc := &captureProcessor{}
		mgr := newHeartbeatManager(proc)
		mgr.SyncDeployments([]director.Deployment{{Name: "mycloud"}})
		mgr.SyncDeploymentState(
			director.Deployment{Name: "mycloud"},
			[]director.Instance{
				{ID: "iuuid1", AgentID: "007", Index: "0", Job: "mutator", ExpectsVM: true},
				{ID: "iuuid2", AgentID: "008", Index: "0", Job: "nats", ExpectsVM: true},
				{ID: "iuuid3", AgentID: "009", Index: "28", Job: "mysql_node", ExpectsVM: true},
			},
		)
		Expect(mgr.AgentsCount()).To(Equal(3))

		mgr.ProcessEvent("shutdown", "hm.agent.shutdown.008", nil)
		Expect(mgr.AgentsCount()).To(Equal(2))
	})
})

// ---------------------------------------------------------------------------
// ProcessEvent — alerts
// ---------------------------------------------------------------------------

var _ = Describe("Manager.ProcessEvent — alerts (instance_manager_spec.rb)", func() {

	var (
		mgr  *instance.Manager
		proc *captureProcessor
	)

	BeforeEach(func() {
		proc = &captureProcessor{}
		mgr = newHeartbeatManager(proc)
		mgr.SyncDeployments([]director.Deployment{{Name: "mycloud"}})
		mgr.SyncDeploymentState(
			director.Deployment{Name: "mycloud"},
			cloud1,
		)
	})

	It("does not increment alerts_processed when the processor returns an error", func() {
		// Ruby: "bad alert" → "does not increment alerts_processed"
		// Ruby raises Bosh::Monitor::InvalidEvent; Go returns an error.
		proc.returnErr = errors.New("invalid event")
		before := mgr.AlertsProcessed()
		mgr.ProcessEvent("alert", "hm.agent.alert.007", []byte(`{"id":"778","severity":-2,"title":null,"summary":"zbb","created_at":1234567890}`))
		mgr.ProcessEvent("alert", "hm.agent.alert.007", []byte(`{"id":"778","severity":-2,"title":null,"summary":"zbb","created_at":1234567890}`))
		Expect(mgr.AlertsProcessed()).To(Equal(before))
	})

	It("increments alerts_processed by 2 after two successful alerts", func() {
		// Ruby: "good alert" → "increments alerts_processed" by 2
		before := mgr.AlertsProcessed()
		mgr.ProcessEvent("alert", "hm.agent.alert.007", []byte(`{"id":"778","severity":2,"title":"zb","summary":"zbb","created_at":1234567890}`))
		mgr.ProcessEvent("alert", "hm.agent.alert.007", []byte(`{"id":"778","severity":2,"title":"zb","summary":"zbb","created_at":1234567890}`))
		Expect(mgr.AlertsProcessed()).To(Equal(before + 2))
	})

	It("increments heartbeats_received after a valid heartbeat", func() {
		before := mgr.HeartbeatsReceived()
		mgr.ProcessEvent("heartbeat", "hm.agent.heartbeat.007", nil)
		Expect(mgr.HeartbeatsReceived()).To(Equal(before + 1))
	})
})
