package mbus_test

import (
	"encoding/json"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/yagnats"
	"github.com/cloudfoundry/yagnats/fakeyagnats"

	boshhandler "bosh/handler"
	boshlog "bosh/logger"
	. "bosh/mbus"
	boshsettings "bosh/settings"
	fakesettings "bosh/settings/fakes"
)

func buildNatsClientAndHandler(settings boshsettings.Service) (client *fakeyagnats.FakeYagnats, handler boshhandler.Handler) {
	logger := boshlog.NewLogger(boshlog.LevelNone)
	client = fakeyagnats.New()
	handler = NewNatsHandler(settings, logger, client)
	return
}
func init() {
	Describe("natsHandler", func() {
		Describe("Start", func() {
			It("starts", func() {
				settings := &fakesettings.FakeSettingsService{
					AgentID: "my-agent-id",
					MbusURL: "nats://foo:bar@127.0.0.1:1234",
				}
				client, handler := buildNatsClientAndHandler(settings)

				var receivedRequest boshhandler.Request

				handler.Start(func(req boshhandler.Request) (resp boshhandler.Response) {
					receivedRequest = req
					return boshhandler.NewValueResponse("expected value")
				})
				defer handler.Stop()

				Expect(client.ConnectedConnectionProvider).ToNot(BeNil())

				Expect(len(client.Subscriptions)).To(Equal(1))
				subscriptions := client.Subscriptions["agent.my-agent-id"]
				Expect(len(subscriptions)).To(Equal(1))

				expectedPayload := []byte(`{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`)
				subscription := client.Subscriptions["agent.my-agent-id"][0]
				subscription.Callback(&yagnats.Message{
					Subject: "agent.my-agent-id",
					Payload: expectedPayload,
				})

				Expect(receivedRequest).To(Equal(boshhandler.Request{
					ReplyTo: "reply to me!",
					Method:  "ping",
					Payload: expectedPayload,
				}))

				Expect(len(client.PublishedMessages)).To(Equal(1))
				messages := client.PublishedMessages["reply to me!"]

				Expect(len(messages)).To(Equal(1))
				message := messages[0]

				Expect([]byte(`{"value":"expected value"}`)).To(Equal(message.Payload))
			})

			It("does not respond if the response is nil", func() {
				settings := &fakesettings.FakeSettingsService{
					AgentID: "my-agent-id",
					MbusURL: "nats://foo:bar@127.0.0.1:1234",
				}
				client, handler := buildNatsClientAndHandler(settings)

				err := handler.Start(func(req boshhandler.Request) (resp boshhandler.Response) {
					return nil
				})
				Expect(err).ToNot(HaveOccurred())
				defer handler.Stop()

				expectedPayload := []byte(`{"method":"ping","arguments":["foo","bar"], "reply_to": "reply to me!"}`)
				subscription := client.Subscriptions["agent.my-agent-id"][0]
				subscription.Callback(&yagnats.Message{
					Subject: "agent.my-agent-id",
					Payload: expectedPayload,
				})

				Expect(len(client.PublishedMessages)).To(Equal(0))
			})

			It("has the correct connection info", func() {
				settings := &fakesettings.FakeSettingsService{MbusURL: "nats://foo:bar@127.0.0.1:1234"}
				client, handler := buildNatsClientAndHandler(settings)

				err := handler.Start(func(req boshhandler.Request) (res boshhandler.Response) { return })
				Expect(err).ToNot(HaveOccurred())
				defer handler.Stop()

				Expect(client.ConnectedConnectionProvider).ToNot(BeNil())

				connInfo := client.ConnectedConnectionProvider

				expectedConnInfo := &yagnats.ConnectionInfo{
					Addr:     "127.0.0.1:1234",
					Username: "foo",
					Password: "bar",
				}

				Expect(connInfo).To(Equal(expectedConnInfo))
			})

			It("does not err when no username and password", func() {
				settings := &fakesettings.FakeSettingsService{MbusURL: "nats://127.0.0.1:1234"}
				_, handler := buildNatsClientAndHandler(settings)

				err := handler.Start(func(req boshhandler.Request) (res boshhandler.Response) { return })
				Expect(err).ToNot(HaveOccurred())
				defer handler.Stop()
			})

			It("errs when has username without password", func() {
				settings := &fakesettings.FakeSettingsService{MbusURL: "nats://foo@127.0.0.1:1234"}
				_, handler := buildNatsClientAndHandler(settings)

				err := handler.Start(func(req boshhandler.Request) (res boshhandler.Response) { return })
				Expect(err).To(HaveOccurred())
				defer handler.Stop()
			})
		})

		Describe("SendToHealthManager", func() {
			It("sends periodic heartbeats", func() {
				settings := &fakesettings.FakeSettingsService{
					AgentID: "my-agent-id",
					MbusURL: "nats://foo:bar@127.0.0.1:1234",
				}
				client, handler := buildNatsClientAndHandler(settings)

				errChan := make(chan error, 1)

				jobName := "foo"
				jobIndex := 0
				expectedHeartbeat := Heartbeat{Job: &jobName, Index: &jobIndex}

				go func() {
					errChan <- handler.SendToHealthManager("heartbeat", expectedHeartbeat)
				}()

				var err error
				select {
				case err = <-errChan:
				}
				Expect(err).ToNot(HaveOccurred())

				Expect(len(client.PublishedMessages)).To(Equal(1))
				messages := client.PublishedMessages["hm.agent.heartbeat.my-agent-id"]

				Expect(len(messages)).To(Equal(1))
				message := messages[0]

				expectedJSON, _ := json.Marshal(expectedHeartbeat)
				Expect(string(expectedJSON)).To(Equal(string(message.Payload)))
			})
		})
	})
}
