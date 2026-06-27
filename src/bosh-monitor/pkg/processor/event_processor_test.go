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

func (fd *fakeDispatcher) Dispatch(kind string, event events.Event) {
	fd.dispatched = append(fd.dispatched, event)
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
			err := ep.Process("alert", map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test Alert",
				"created_at": time.Now().Unix(),
			})
			Expect(err).NotTo(HaveOccurred())
			Expect(dispatcher.dispatched).To(HaveLen(1))
		})

		It("processes valid heartbeat events", func() {
			err := ep.Process("heartbeat", map[string]interface{}{
				"id":        "hb-1",
				"timestamp": time.Now().Unix(),
			})
			Expect(err).NotTo(HaveOccurred())
			Expect(dispatcher.dispatched).To(HaveLen(1))
		})

		It("returns error for invalid events", func() {
			err := ep.Process("alert", map[string]interface{}{})
			Expect(err).To(HaveOccurred())
		})

		It("deduplicates events with same ID", func() {
			attrs := map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test Alert",
				"created_at": time.Now().Unix(),
			}
			err := ep.Process("alert", attrs)
			Expect(err).NotTo(HaveOccurred())

			err = ep.Process("alert", attrs)
			Expect(err).NotTo(HaveOccurred())

			Expect(dispatcher.dispatched).To(HaveLen(1))
		})

		It("returns error for unknown event type", func() {
			err := ep.Process("unknown", map[string]interface{}{})
			Expect(err).To(HaveOccurred())
		})
	})

	Describe("EventsCount", func() {
		It("tracks event count", func() {
			Expect(ep.EventsCount()).To(Equal(0))

			ep.Process("alert", map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test Alert",
				"created_at": time.Now().Unix(),
			})
			Expect(ep.EventsCount()).To(Equal(1))
		})
	})

	Describe("PruneEvents", func() {
		It("removes old events", func() {
			ep.Process("alert", map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test Alert",
				"created_at": time.Now().Unix(),
			})
			Expect(ep.EventsCount()).To(Equal(1))

			ep.PruneEvents(0)
			Expect(ep.EventsCount()).To(Equal(0))
		})

		It("keeps recent events", func() {
			ep.Process("alert", map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test Alert",
				"created_at": time.Now().Unix(),
			})
			ep.PruneEvents(3600)
			Expect(ep.EventsCount()).To(Equal(1))
		})
	})
})
