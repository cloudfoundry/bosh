package natsauthconfig_test

import (
	"fmt"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"bosh-nats-sync/pkg/natsauthconfig"
)

func strPtr(s string) *string { return &s }

var _ = Describe("NatsAuthConfig", func() {
	var (
		vms              []natsauthconfig.VM
		directorSubject  *string
		hmSubject        *string
	)

	BeforeEach(func() {
		vms = []natsauthconfig.VM{
			{PermanentNATSCredentials: false, AgentID: "fef068d8-bbdd-46ff-b4a5-bf0838f918d9"},
			{PermanentNATSCredentials: false, AgentID: "c5e7c705-459e-41c0-b640-db32d8dc6e71"},
		}
		directorSubject = strPtr("subject=C=USA, O=Cloud Foundry, CN=default.hm.bosh-internal")
		hmSubject = strPtr("C=USA, O=Cloud Foundry, CN=default.hm.bosh-internal")
	})

	Describe("CreateConfig", func() {
		It("returns the authentication configs belonging to the deployments", func() {
			cfg := natsauthconfig.CreateConfig(vms, directorSubject, hmSubject)
			users := cfg.Authorization.Users

			Expect(users).To(HaveLen(6))
			Expect(users[0].User).To(Equal(*directorSubject))
			Expect(users[1].User).To(Equal(*hmSubject))
			Expect(users[2].User).To(Equal(
				fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.bootstrap.agent.bosh-internal", vms[0].AgentID)))
			Expect(users[3].User).To(Equal(
				fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.agent.bosh-internal", vms[0].AgentID)))
			Expect(users[4].User).To(Equal(
				fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.bootstrap.agent.bosh-internal", vms[1].AgentID)))
			Expect(users[5].User).To(Equal(
				fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.agent.bosh-internal", vms[1].AgentID)))
		})

		Context("with no director or hm subjects", func() {
			BeforeEach(func() {
				directorSubject = nil
				hmSubject = nil
			})

			It("returns the authentication configs excluding the hm and director configs", func() {
				cfg := natsauthconfig.CreateConfig(vms, directorSubject, hmSubject)
				users := cfg.Authorization.Users

				Expect(users).To(HaveLen(4))
				Expect(users[0].User).To(Equal(
					fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.bootstrap.agent.bosh-internal", vms[0].AgentID)))
				Expect(users[1].User).To(Equal(
					fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.agent.bosh-internal", vms[0].AgentID)))
				Expect(users[2].User).To(Equal(
					fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.bootstrap.agent.bosh-internal", vms[1].AgentID)))
				Expect(users[3].User).To(Equal(
					fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.agent.bosh-internal", vms[1].AgentID)))
			})
		})

		Context("when the vm has permanent_nats_credentials set to false", func() {
			BeforeEach(func() {
				vms = []natsauthconfig.VM{
					{PermanentNATSCredentials: false, AgentID: "fef068d8-bbdd-46ff-b4a5-bf0838f918d9"},
				}
			})

			It("returns the authentication configs for the short and long lived creds", func() {
				cfg := natsauthconfig.CreateConfig(vms, directorSubject, hmSubject)
				users := cfg.Authorization.Users

				Expect(users).To(HaveLen(4))
				Expect(users[2].User).To(Equal(
					fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.bootstrap.agent.bosh-internal", vms[0].AgentID)))
				Expect(users[3].User).To(Equal(
					fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.agent.bosh-internal", vms[0].AgentID)))
			})
		})

		Context("when the vm has permanent_nats_credentials set to true", func() {
			BeforeEach(func() {
				vms = []natsauthconfig.VM{
					{PermanentNATSCredentials: true, AgentID: "fef068d8-bbdd-46ff-b4a5-bf0838f918d9"},
				}
			})

			It("returns the authentication config for the long lived creds only", func() {
				cfg := natsauthconfig.CreateConfig(vms, directorSubject, hmSubject)
				users := cfg.Authorization.Users

				Expect(users).To(HaveLen(3))
				Expect(users[2].User).To(Equal(
					fmt.Sprintf("C=USA, O=Cloud Foundry, CN=%s.agent.bosh-internal", vms[0].AgentID)))
			})
		})

		It("sets correct director permissions", func() {
			cfg := natsauthconfig.CreateConfig(nil, directorSubject, hmSubject)
			dirUser := cfg.Authorization.Users[0]

			Expect(dirUser.Permissions.Publish).To(ConsistOf("agent.*", "hm.director.alert"))
			Expect(dirUser.Permissions.Subscribe).To(ConsistOf("director.>"))
		})

		It("sets correct hm permissions", func() {
			cfg := natsauthconfig.CreateConfig(nil, directorSubject, hmSubject)
			hm := cfg.Authorization.Users[1]

			Expect(hm.Permissions.Publish).To(BeEmpty())
			Expect(hm.Permissions.Subscribe).To(ConsistOf(
				"hm.agent.heartbeat.*", "hm.agent.alert.*", "hm.agent.shutdown.*", "hm.director.alert"))
		})

		It("sets correct agent permissions", func() {
			agentID := "fef068d8-bbdd-46ff-b4a5-bf0838f918d9"
			vms = []natsauthconfig.VM{{PermanentNATSCredentials: true, AgentID: agentID}}
			cfg := natsauthconfig.CreateConfig(vms, directorSubject, hmSubject)
			agent := cfg.Authorization.Users[2]

			Expect(agent.Permissions.Publish).To(ConsistOf(
				fmt.Sprintf("hm.agent.heartbeat.%s", agentID),
				fmt.Sprintf("hm.agent.alert.%s", agentID),
				fmt.Sprintf("hm.agent.shutdown.%s", agentID),
				fmt.Sprintf("director.*.%s.*", agentID),
			))
			Expect(agent.Permissions.Subscribe).To(ConsistOf(
				fmt.Sprintf("agent.%s", agentID),
			))
		})
	})
})
