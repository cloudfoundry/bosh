package nats_test

import (
	"bytes"
	"encoding/json"
	"errors"
	"log/slog"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	hmNats "github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/nats"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

// fakeAlertProcessor records every Process call.
type fakeAlertProcessor struct {
	processed []events.Event
	returnErr error
}

func (f *fakeAlertProcessor) Process(event events.Event) error {
	f.processed = append(f.processed, event)
	return f.returnErr
}

// fakeSubscriber is a test double for DirectorAlertSubscriber.
// It captures the handler passed to SubscribeDirectorAlerts so tests can
// fire synthetic messages by calling fakeSubscriber.fireAlert.
type fakeSubscriber struct {
	subscribed bool
	handler    func(payload string)
	returnErr  error
}

func (f *fakeSubscriber) SubscribeDirectorAlerts(handler func(payload string)) error {
	f.subscribed = true
	f.handler = handler
	return f.returnErr
}

func (f *fakeSubscriber) fireAlert(payload string) {
	if f.handler != nil {
		f.handler(payload)
	}
}

// validAlertPayload returns a map with all required fields present.
func validAlertPayload() map[string]interface{} {
	return map[string]interface{}{
		"id":         "payload-id",
		"severity":   3,
		"title":      "payload-title",
		"summary":    "payload-summary",
		"created_at": time.Now().Unix(),
	}
}

var _ = Describe("DirectorMonitor", func() {
	var (
		monitor   *hmNats.DirectorMonitor
		processor *fakeAlertProcessor
		logBuf    bytes.Buffer
		logger    *slog.Logger
	)

	BeforeEach(func() {
		processor = &fakeAlertProcessor{}
		logBuf.Reset()
		logger = slog.New(slog.NewTextHandler(&logBuf, &slog.HandlerOptions{Level: slog.LevelDebug}))
	})

	// ── Subscribe wiring ──────────────────────────────────────────────────────

	// Ruby: "subscribes to hm.director.alert over NATS"
	Describe("Subscribe", func() {
		It("registers a handler with the NATS client for director alerts", func() {
			subscriber := &fakeSubscriber{}
			monitor = hmNats.NewDirectorMonitor(subscriber, processor, logger)

			Expect(monitor.Subscribe()).To(Succeed())
			Expect(subscriber.subscribed).To(BeTrue())
		})

		It("returns an error when the subscriber fails", func() {
			subscriber := &fakeSubscriber{returnErr: errors.New("subscribe failed")}
			monitor = hmNats.NewDirectorMonitor(subscriber, processor, logger)

			Expect(monitor.Subscribe()).To(MatchError("subscribe failed"))
		})

		// Ruby: "tells the event processor to process the alert" — end-to-end
		// through the real NATS subscription path via fakeSubscriber.
		It("processes a valid alert received over the subscription", func() {
			subscriber := &fakeSubscriber{}
			monitor = hmNats.NewDirectorMonitor(subscriber, processor, logger)
			Expect(monitor.Subscribe()).To(Succeed())

			data, err := json.Marshal(validAlertPayload())
			Expect(err).NotTo(HaveOccurred())
			subscriber.fireAlert(string(data))

			Expect(processor.processed).To(HaveLen(1))
			Expect(processor.processed[0].Kind()).To(Equal("alert"))
			Expect(processor.processed[0].ID()).To(Equal("payload-id"))
		})
	})

	// ── Alert handler behaviour ───────────────────────────────────────────────
	// Tests below drive handleAlert directly via hmNats.HandleAlert so they
	// do not require a live NATS connection.

	Describe("alert handler", func() {
		BeforeEach(func() {
			monitor = hmNats.NewDirectorMonitor(nil, processor, logger)
		})

		Context("when the payload is valid", func() {
			// Ruby: "does not log an error"
			It("does not log an error", func() {
				data, _ := json.Marshal(validAlertPayload())
				hmNats.HandleAlert(monitor, string(data))

				Expect(logBuf.String()).NotTo(ContainSubstring("ERROR"))
			})

			// Ruby: "tells the event processor to process the alert"
			It("passes the alert to the event processor with kind 'alert'", func() {
				data, _ := json.Marshal(validAlertPayload())
				hmNats.HandleAlert(monitor, string(data))

				Expect(processor.processed).To(HaveLen(1))
				Expect(processor.processed[0].Kind()).To(Equal("alert"))
			})

			It("passes all alert fields to the event processor", func() {
				payload := validAlertPayload()
				data, _ := json.Marshal(payload)
				hmNats.HandleAlert(monitor, string(data))

				got, ok := processor.processed[0].(*events.Alert)
				Expect(ok).To(BeTrue())
				Expect(got.ID()).To(Equal("payload-id"))
				Expect(got.Title).To(Equal("payload-title"))
				Expect(got.Summary).To(Equal("payload-summary"))
			})
		})

		Context("when the payload is malformed JSON", func() {
			It("logs an error and does not call the event processor", func() {
				hmNats.HandleAlert(monitor, "not-valid-json{")

				Expect(processor.processed).To(BeEmpty())
				Expect(logBuf.String()).To(ContainSubstring("Failed to parse director alert"))
			})
		})

		// Ruby: for each of %w[id severity title created_at]:
		//   "logs an error if the <key> field is missing"
		//   "does not create a new director alert"
		// Note: "summary" is intentionally excluded — Alert.Validate() treats it
		// as optional and falls back to Title when absent, matching actual usage.
		// Note: "created_at" maps to the validation message "timestamp is missing".
		DescribeTable("when a required field is missing",
			func(missingKey, expectedLogFragment string) {
				payload := validAlertPayload()
				delete(payload, missingKey)
				data, _ := json.Marshal(payload)
				hmNats.HandleAlert(monitor, string(data))

				// Ruby: "does not create a new director alert"
				Expect(processor.processed).To(BeEmpty(),
					"processor should not be called when %q is absent", missingKey)

				// Ruby: "logs an error if the <key> field is missing"
				Expect(logBuf.String()).To(ContainSubstring("Invalid director alert"),
					"error log should mention invalid alert when %q is absent", missingKey)
				Expect(logBuf.String()).To(ContainSubstring(expectedLogFragment),
					"error log should mention %q when %q is absent", expectedLogFragment, missingKey)
			},
			Entry("id is missing", "id", "id is missing"),
			Entry("severity is missing", "severity", "severity is missing"),
			Entry("title is missing", "title", "title is missing"),
			Entry("created_at is missing", "created_at", "timestamp is missing"),
		)

		Context("when the event processor returns an error", func() {
			It("logs the processor error", func() {
				processor.returnErr = errors.New("processor failure")
				data, _ := json.Marshal(validAlertPayload())
				hmNats.HandleAlert(monitor, string(data))

				Expect(logBuf.String()).To(ContainSubstring("Failed to process director alert"))
			})
		})
	})
})
