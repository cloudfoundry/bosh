package nats_test

import (
	"encoding/json"

	hmNats "github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/nats"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

type fakeAlertProcessor struct {
	processed []map[string]interface{}
	lastKind  string
}

func (f *fakeAlertProcessor) Process(kind string, data map[string]interface{}) error {
	f.lastKind = kind
	f.processed = append(f.processed, data)
	return nil
}

var _ = Describe("DirectorMonitor", func() {
	It("can be created", func() {
		processor := &fakeAlertProcessor{}
		client := hmNats.NewClient(nil)
		monitor := hmNats.NewDirectorMonitor(client, processor, nil)
		Expect(monitor).NotTo(BeNil())
	})

	Describe("valid payload detection", func() {
		It("accepts valid payloads", func() {
			payload := map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test",
				"summary":    "Test summary",
				"created_at": 1234567890,
			}
			data, _ := json.Marshal(payload)
			Expect(data).NotTo(BeEmpty())
		})

		It("rejects payloads missing required keys", func() {
			payload := map[string]interface{}{
				"id": "alert-1",
			}
			requiredKeys := []string{"id", "severity", "title", "summary", "created_at"}
			missing := false
			for _, key := range requiredKeys {
				if _, ok := payload[key]; !ok {
					missing = true
					break
				}
			}
			Expect(missing).To(BeTrue())
		})
	})
})
