package processor_test

import (
	"log/slog"
	"os"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/processor"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type fakeDispatcher struct {
	dispatched []events.Event
}

func (fd *fakeDispatcher) Dispatch(_ string, event events.Event) {
	fd.dispatched = append(fd.dispatched, event)
}

func validAlert() events.Event {
	return events.NewAlert(map[string]interface{}{
		"id":         "alert-1",
		"severity":   2,
		"title":      "Test Alert",
		"created_at": time.Now().Unix(),
	})
}

var _ = Describe("EventProcessor", func() {
	var (
		ep         *processor.EventProcessor
		dispatcher *fakeDispatcher
		logger     *slog.Logger
	)

	BeforeEach(func() {
		dispatcher = &fakeDispatcher{}
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
		ep = processor.NewEventProcessor(dispatcher, logger)
	})

	Describe("Process", func() {
		It("processes valid alert events", func() {
			Expect(ep.Process(validAlert())).To(Succeed())
			Expect(dispatcher.dispatched).To(HaveLen(1))
		})

		It("processes valid heartbeat events", func() {
			hb := events.NewHeartbeat(map[string]interface{}{
				"id":        "hb-1",
				"timestamp": time.Now().Unix(),
			})
			Expect(ep.Process(hb)).To(Succeed())
			Expect(dispatcher.dispatched).To(HaveLen(1))
		})

		It("returns error for invalid events", func() {
			Expect(ep.Process(events.NewAlert(map[string]interface{}{}))).To(HaveOccurred())
		})

		It("deduplicates events with same ID", func() {
			Expect(ep.Process(validAlert())).To(Succeed())
			Expect(ep.Process(validAlert())).To(Succeed())
			Expect(dispatcher.dispatched).To(HaveLen(1))
		})

		It("accepts a monitor-generated alert built from typed fields", func() {
			// Regression: alerts built via NewAlertFromData carry no attributes
			// map, so validation must not depend on one. An ID is auto-assigned.
			alert := events.NewAlertFromData(events.AlertData{
				Severity:   2,
				Category:   "deployment_health",
				Source:     "dep-1",
				Title:      "dep-1 has instances with timed out agents",
				CreatedAt:  time.Now(),
				Deployment: "dep-1",
			})
			Expect(ep.Process(alert)).To(Succeed())
			Expect(dispatcher.dispatched).To(HaveLen(1))
			Expect(dispatcher.dispatched[0].ID()).NotTo(BeEmpty())
		})
	})

	Describe("EventsCount", func() {
		It("tracks event count", func() {
			Expect(ep.EventsCount()).To(Equal(0))
			Expect(ep.Process(validAlert())).To(Succeed())
			Expect(ep.EventsCount()).To(Equal(1))
		})
	})

	Describe("PruneEvents", func() {
		It("removes old events", func() {
			Expect(ep.Process(validAlert())).To(Succeed())
			Expect(ep.EventsCount()).To(Equal(1))

			ep.PruneEvents(0)
			Expect(ep.EventsCount()).To(Equal(0))
		})

		It("keeps recent events", func() {
			Expect(ep.Process(validAlert())).To(Succeed())
			ep.PruneEvents(3600)
			Expect(ep.EventsCount()).To(Equal(1))
		})
	})
})
