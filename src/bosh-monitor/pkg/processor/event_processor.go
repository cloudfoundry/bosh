package processor

import (
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
)

// PluginDispatcher dispatches events to external plugin processes.
type PluginDispatcher interface {
	Dispatch(kind string, event events.Event)
}

type EventProcessor struct {
	mu        sync.Mutex
	events    map[string]map[string]eventEntry
	plugins   PluginDispatcher
	logger    *slog.Logger
	pruneStop chan struct{}
}

type eventEntry struct {
	receivedAt int64
}

func NewEventProcessor(dispatcher PluginDispatcher, logger *slog.Logger) *EventProcessor {
	return &EventProcessor{
		events:  make(map[string]map[string]eventEntry),
		plugins: dispatcher,
		logger:  logger,
	}
}

// Process validates, de-duplicates and dispatches an already-constructed event.
// Callers build a typed events.Event (from an agent/director JSON payload, a
// plugin emit_alert, or the monitor's own analysis) and hand it here.
func (ep *EventProcessor) Process(event events.Event) error {
	events.EnsureID(event)
	if errs := event.Validate(); len(errs) > 0 {
		return fmt.Errorf("invalid event: %s", strings.Join(errs, ", "))
	}

	kind := event.Kind()

	ep.mu.Lock()
	if ep.events[kind] == nil {
		ep.events[kind] = make(map[string]eventEntry)
	}
	if _, exists := ep.events[kind][event.ID()]; exists {
		ep.mu.Unlock()
		ep.logger.Debug("Ignoring duplicate event", "kind", kind, "id", event.ID())
		return nil
	}
	ep.events[kind][event.ID()] = eventEntry{receivedAt: time.Now().Unix()}
	ep.mu.Unlock()

	if ep.plugins != nil {
		ep.plugins.Dispatch(kind, event)
	}

	return nil
}

func (ep *EventProcessor) EventsCount() int {
	ep.mu.Lock()
	defer ep.mu.Unlock()
	count := 0
	for _, evts := range ep.events {
		count += len(evts)
	}
	return count
}

func (ep *EventProcessor) EnablePruning(intervalSeconds int) {
	ep.mu.Lock()
	if ep.pruneStop != nil {
		ep.mu.Unlock()
		return
	}
	stop := make(chan struct{})
	ep.pruneStop = stop
	ep.mu.Unlock()

	go func() {
		ticker := time.NewTicker(time.Duration(intervalSeconds) * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				ep.PruneEvents(intervalSeconds)
			case <-stop:
				return
			}
		}
	}()
}

func (ep *EventProcessor) StopPruning() {
	ep.mu.Lock()
	defer ep.mu.Unlock()
	if ep.pruneStop != nil {
		close(ep.pruneStop)
		ep.pruneStop = nil
	}
}

func (ep *EventProcessor) PruneEvents(lifetime int) {
	ep.mu.Lock()
	defer ep.mu.Unlock()

	prunedCount := 0
	totalCount := 0
	cutoff := time.Now().Unix() - int64(lifetime)

	for _, list := range ep.events {
		for id, entry := range list {
			totalCount++
			if entry.receivedAt <= cutoff {
				delete(list, id)
				prunedCount++
			}
		}
	}

	ep.logger.Debug("Pruned events", "pruned", prunedCount, "total", totalCount)
}
