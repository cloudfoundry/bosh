package instance_test

import (
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/director"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/instance"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// The tests in this file mirror src/bosh-monitor/spec/unit/bosh/monitor/agent_spec.rb.
// Bosh::Monitor.intervals was configured with agent_timeout: 344, rogue_agent_alert: 124.

var _ = Describe("Agent — timeout and rogue thresholds (agent_spec.rb)", func() {

	Describe("TimedOut", func() {
		// Ruby: "knows if it is timed out"
		//   at t=344 s → false  (exactly at threshold, not past it)
		//   at t=345 s → true
		const agentTimeout = 344 * time.Second

		It("is false when UpdatedAt is just inside the timeout boundary", func() {
			// Ruby uses mocked Time; here we stay 500 ms inside the boundary to
			// avoid a spurious failure from test execution time.
			agent := instance.NewAgent("007", instance.WithAgentTimeout(agentTimeout))
			agent.UpdatedAt = time.Now().Add(-agentTimeout + 500*time.Millisecond)
			Expect(agent.TimedOut()).To(BeFalse(), "just inside threshold should not be timed out")
		})

		It("is true one second past the timeout boundary", func() {
			agent := instance.NewAgent("007", instance.WithAgentTimeout(agentTimeout))
			agent.UpdatedAt = time.Now().Add(-agentTimeout - 1*time.Second)
			Expect(agent.TimedOut()).To(BeTrue(), "one second past threshold should time out")
		})

		It("is false for a freshly created agent", func() {
			agent := instance.NewAgent("007", instance.WithAgentTimeout(agentTimeout))
			Expect(agent.TimedOut()).To(BeFalse())
		})
	})

	Describe("Rogue", func() {
		// Ruby: "knows if it is rogue if it isn't associated with deployment for :rogue_agent_alert seconds"
		//   at t=124 s → false  (exactly at threshold)
		//   at t=125 s → true
		//   after setting deployment → false
		const rogueThreshold = 124 * time.Second

		It("is false when DiscoveredAt is just inside the rogue threshold", func() {
			// Stay 500 ms inside the boundary so test execution time doesn't cause
			// a spurious failure (mirrors Ruby's mocked Time.now + 124 boundary).
			agent := instance.NewAgent("007", instance.WithRogueAgentAlert(rogueThreshold))
			agent.DiscoveredAt = time.Now().Add(-rogueThreshold + 500*time.Millisecond)
			Expect(agent.Rogue()).To(BeFalse(), "just inside threshold should not be rogue")
		})

		It("is true one second past the rogue threshold for an undeployed agent", func() {
			agent := instance.NewAgent("007", instance.WithRogueAgentAlert(rogueThreshold))
			agent.DiscoveredAt = time.Now().Add(-rogueThreshold - 1*time.Second)
			Expect(agent.Rogue()).To(BeTrue(), "one second past threshold should be rogue")
		})

		It("is false once the agent is associated with a deployment", func() {
			agent := instance.NewAgent("007", instance.WithRogueAgentAlert(rogueThreshold))
			agent.DiscoveredAt = time.Now().Add(-rogueThreshold - 1*time.Second)
			Expect(agent.Rogue()).To(BeTrue()) // confirm pre-condition
			agent.Deployment = "mycloud"
			Expect(agent.Rogue()).To(BeFalse(), "managed agent should never be rogue")
		})

		It("is false for a freshly created agent", func() {
			agent := instance.NewAgent("007", instance.WithRogueAgentAlert(rogueThreshold))
			Expect(agent.Rogue()).To(BeFalse())
		})
	})

	Describe("Name", func() {
		// Ruby: "has name that depends on the currently known state"
		// Tests every incremental state transition from the Ruby spec.

		It("includes cid when only cid is set", func() {
			agent := instance.NewAgent("zb")
			agent.CID = "deadbeef"
			Expect(agent.Name()).To(Equal("agent zb [cid=deadbeef]"))
		})

		It("includes instance_id and cid when both are set", func() {
			agent := instance.NewAgent("zb")
			agent.CID = "deadbeef"
			agent.InstanceID = "iuuid"
			// Go orders cid before instance_id in the partial-state format
			Expect(agent.Name()).To(Equal("agent zb [cid=deadbeef, instance_id=iuuid]"))
		})

		It("includes deployment prefix when deployment set but job is missing", func() {
			agent := instance.NewAgent("zb")
			agent.CID = "deadbeef"
			agent.InstanceID = "iuuid"
			agent.Deployment = "oleg-cloud"
			// No job → still partial format, deployment appears first
			Expect(agent.Name()).To(Equal("agent zb [deployment=oleg-cloud, cid=deadbeef, instance_id=iuuid]"))
		})

		It("uses deployment:job(instance_id)[id=…,cid=…] format when deployment+job+instanceID all set", func() {
			// Ruby: agent.job = 'mysql_node' → "oleg-cloud: mysql_node(iuuid) [id=zb, cid=deadbeef]"
			agent := instance.NewAgent("zb")
			agent.Deployment = "oleg-cloud"
			agent.Job = "mysql_node"
			agent.InstanceID = "iuuid"
			agent.CID = "deadbeef"
			Expect(agent.Name()).To(Equal("oleg-cloud: mysql_node(iuuid) [id=zb, cid=deadbeef]"))
		})

		It("includes index when deployment+job+instanceID+index all set", func() {
			// Ruby: agent.index = '0' → "oleg-cloud: mysql_node(iuuid) [id=zb, index=0, cid=deadbeef]"
			agent := instance.NewAgent("zb")
			agent.Deployment = "oleg-cloud"
			agent.Job = "mysql_node"
			agent.InstanceID = "iuuid"
			agent.CID = "deadbeef"
			agent.Index = "0"
			Expect(agent.Name()).To(Equal("oleg-cloud: mysql_node(iuuid) [id=zb, index=0, cid=deadbeef]"))
		})
	})

	Describe("UpdateInstance", func() {
		var inst *instance.Instance

		BeforeEach(func() {
			inst = instance.NewInstance(director.Instance{
				ID:      "id",
				AgentID: "agent_with_instance",
				Job:     "job",
				Index:   "1",
				CID:     "cid",
			})
		})

		It("populates job, index, cid, and instance_id from the instance", func() {
			// Ruby: "populates the corresponding attributes"
			agent := instance.NewAgent("agent_with_instance")
			agent.UpdateInstance(inst)
			Expect(agent.Job).To(Equal("job"))
			Expect(agent.Index).To(Equal("1"))
			Expect(agent.CID).To(Equal("cid"))
			Expect(agent.InstanceID).To(Equal("id"))
		})

		It("does not modify JobState or NumberOfProcesses", func() {
			// Ruby: "does not modify job_state or number_of_processes when updating instance"
			agent := instance.NewAgent("agent_with_instance")
			agent.JobState = "running"
			n := 3
			agent.NumberOfProcesses = &n
			agent.UpdateInstance(inst)
			Expect(agent.JobState).To(Equal("running"))
			Expect(agent.NumberOfProcesses).NotTo(BeNil())
			Expect(*agent.NumberOfProcesses).To(Equal(3))
		})
	})
})
