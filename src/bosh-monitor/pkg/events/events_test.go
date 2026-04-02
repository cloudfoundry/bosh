package events_test

import (
	"encoding/json"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/events"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Alert", func() {
	Describe("NewAlert", func() {
		It("creates an alert from attributes", func() {
			attrs := map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test Alert",
				"summary":    "Something went wrong",
				"source":     "test-source",
				"deployment": "test-deployment",
				"created_at": 1234567890,
			}
			alert := events.NewAlert(attrs)
			Expect(alert.ID()).To(Equal("alert-1"))
			Expect(alert.Kind()).To(Equal("alert"))
			Expect(alert.Severity).To(Equal(2))
			Expect(alert.Title).To(Equal("Test Alert"))
			Expect(alert.Summary).To(Equal("Something went wrong"))
			Expect(alert.Source).To(Equal("test-source"))
			Expect(alert.Deployment).To(Equal("test-deployment"))
			Expect(alert.CreatedAt.Unix()).To(Equal(int64(1234567890)))
		})

		It("uses title as summary when summary is missing", func() {
			attrs := map[string]interface{}{
				"id":         "alert-1",
				"severity":   2,
				"title":      "Test Alert",
				"created_at": 1234567890,
			}
			alert := events.NewAlert(attrs)
			Expect(alert.Summary).To(Equal("Test Alert"))
		})
	})

	Describe("Validate", func() {
		It("returns no errors for valid alert", func() {
			alert := events.NewAlert(validAlertAttrs())
			Expect(alert.Validate()).To(BeEmpty())
		})

		It("returns error when id is missing", func() {
			attrs := validAlertAttrs()
			delete(attrs, "id")
			alert := events.NewAlert(attrs)
			Expect(alert.Validate()).To(ContainElement("id is missing"))
		})

		It("returns error when severity is missing", func() {
			attrs := validAlertAttrs()
			delete(attrs, "severity")
			alert := events.NewAlert(attrs)
			Expect(alert.Validate()).To(ContainElement("severity is missing"))
		})

		It("returns error when title is missing", func() {
			attrs := validAlertAttrs()
			delete(attrs, "title")
			alert := events.NewAlert(attrs)
			Expect(alert.Validate()).To(ContainElement("title is missing"))
		})

		It("returns error when created_at is missing", func() {
			attrs := validAlertAttrs()
			delete(attrs, "created_at")
			alert := events.NewAlert(attrs)
			Expect(alert.Validate()).To(ContainElement("timestamp is missing"))
		})
	})

	Describe("SeverityName", func() {
		It("maps severity to name", func() {
			alert := events.NewAlert(map[string]interface{}{
				"id": "1", "severity": 1, "title": "t", "created_at": time.Now().Unix(),
			})
			Expect(alert.SeverityName()).To(Equal("alert"))

			alert2 := events.NewAlert(map[string]interface{}{
				"id": "1", "severity": 2, "title": "t", "created_at": time.Now().Unix(),
			})
			Expect(alert2.SeverityName()).To(Equal("critical"))

			alert3 := events.NewAlert(map[string]interface{}{
				"id": "1", "severity": 3, "title": "t", "created_at": time.Now().Unix(),
			})
			Expect(alert3.SeverityName()).To(Equal("error"))

			alert4 := events.NewAlert(map[string]interface{}{
				"id": "1", "severity": 4, "title": "t", "created_at": time.Now().Unix(),
			})
			Expect(alert4.SeverityName()).To(Equal("warning"))
		})
	})

	Describe("ToHash", func() {
		It("returns hash representation", func() {
			alert := events.NewAlert(validAlertAttrs())
			h := alert.ToHash()
			Expect(h["kind"]).To(Equal("alert"))
			Expect(h["id"]).To(Equal("alert-1"))
			Expect(h["severity"]).To(Equal(2))
			Expect(h["title"]).To(Equal("Test Alert"))
		})
	})

	Describe("ToJSON", func() {
		It("returns valid JSON", func() {
			alert := events.NewAlert(validAlertAttrs())
			j, err := alert.ToJSON()
			Expect(err).NotTo(HaveOccurred())
			var parsed map[string]interface{}
			Expect(json.Unmarshal([]byte(j), &parsed)).To(Succeed())
			Expect(parsed["kind"]).To(Equal("alert"))
		})
	})

	Describe("ToPlainText", func() {
		It("returns readable text", func() {
			alert := events.NewAlert(validAlertAttrs())
			text := alert.ToPlainText()
			Expect(text).To(ContainSubstring("test-source"))
			Expect(text).To(ContainSubstring("Test Alert"))
			Expect(text).To(ContainSubstring("Severity: 2"))
		})
	})

	Describe("ShortDescription", func() {
		It("returns short description", func() {
			alert := events.NewAlert(validAlertAttrs())
			Expect(alert.ShortDescription()).To(Equal("Severity 2: test-source Test Alert"))
		})
	})

	Describe("Metrics", func() {
		It("returns nil for alerts", func() {
			alert := events.NewAlert(validAlertAttrs())
			Expect(alert.Metrics()).To(BeNil())
		})
	})
})

var _ = Describe("Heartbeat", func() {
	Describe("NewHeartbeat", func() {
		It("creates a heartbeat from attributes", func() {
			hb := events.NewHeartbeat(validHeartbeatAttrs())
			Expect(hb.ID()).To(Equal("hb-1"))
			Expect(hb.Kind()).To(Equal("heartbeat"))
			Expect(hb.Deployment).To(Equal("test-deployment"))
			Expect(hb.AgentID).To(Equal("agent-1"))
			Expect(hb.Job).To(Equal("test-job"))
			Expect(hb.Index).To(Equal("0"))
			Expect(hb.InstanceID).To(Equal("instance-1"))
			Expect(hb.JobState).To(Equal("running"))
		})
	})

	Describe("Validate", func() {
		It("returns no errors for valid heartbeat", func() {
			hb := events.NewHeartbeat(validHeartbeatAttrs())
			Expect(hb.Validate()).To(BeEmpty())
		})

		It("returns error when id is missing", func() {
			attrs := validHeartbeatAttrs()
			delete(attrs, "id")
			hb := events.NewHeartbeat(attrs)
			Expect(hb.Validate()).To(ContainElement("id is missing"))
		})

		It("returns error when timestamp is missing", func() {
			attrs := validHeartbeatAttrs()
			delete(attrs, "timestamp")
			hb := events.NewHeartbeat(attrs)
			Expect(hb.Validate()).To(ContainElement("timestamp is missing"))
		})
	})

	Describe("Metrics", func() {
		It("populates metrics from vitals", func() {
			hb := events.NewHeartbeat(validHeartbeatAttrs())
			metrics := hb.Metrics()
			Expect(len(metrics)).To(BeNumerically(">", 0))

			metricNames := make(map[string]bool)
			for _, m := range metrics {
				metricNames[m.Name] = true
			}

			Expect(metricNames).To(HaveKey("system.load.1m"))
			Expect(metricNames).To(HaveKey("system.cpu.user"))
			Expect(metricNames).To(HaveKey("system.cpu.sys"))
			Expect(metricNames).To(HaveKey("system.cpu.wait"))
			Expect(metricNames).To(HaveKey("system.mem.percent"))
			Expect(metricNames).To(HaveKey("system.mem.kb"))
			Expect(metricNames).To(HaveKey("system.swap.percent"))
			Expect(metricNames).To(HaveKey("system.swap.kb"))
			Expect(metricNames).To(HaveKey("system.disk.system.percent"))
			Expect(metricNames).To(HaveKey("system.disk.system.inode_percent"))
			Expect(metricNames).To(HaveKey("system.disk.ephemeral.percent"))
			Expect(metricNames).To(HaveKey("system.disk.ephemeral.inode_percent"))
			Expect(metricNames).To(HaveKey("system.disk.persistent.percent"))
			Expect(metricNames).To(HaveKey("system.disk.persistent.inode_percent"))
			Expect(metricNames).To(HaveKey("system.healthy"))
		})

		It("sets system.healthy to 1 when running", func() {
			hb := events.NewHeartbeat(validHeartbeatAttrs())
			for _, m := range hb.Metrics() {
				if m.Name == "system.healthy" {
					Expect(m.Value).To(Equal("1"))
				}
			}
		})

		It("sets system.healthy to 0 when not running", func() {
			attrs := validHeartbeatAttrs()
			attrs["job_state"] = "failing"
			hb := events.NewHeartbeat(attrs)
			for _, m := range hb.Metrics() {
				if m.Name == "system.healthy" {
					Expect(m.Value).To(Equal("0"))
				}
			}
		})

		It("includes tags with job, index, and id", func() {
			hb := events.NewHeartbeat(validHeartbeatAttrs())
			for _, m := range hb.Metrics() {
				Expect(m.Tags["job"]).To(Equal("test-job"))
				Expect(m.Tags["index"]).To(Equal("0"))
				Expect(m.Tags["id"]).To(Equal("instance-1"))
			}
		})
	})

	Describe("ToHash", func() {
		It("returns hash representation", func() {
			hb := events.NewHeartbeat(validHeartbeatAttrs())
			h := hb.ToHash()
			Expect(h["kind"]).To(Equal("heartbeat"))
			Expect(h["id"]).To(Equal("hb-1"))
			Expect(h["deployment"]).To(Equal("test-deployment"))
			Expect(h["agent_id"]).To(Equal("agent-1"))
		})
	})

	Describe("ToJSON", func() {
		It("returns valid JSON", func() {
			hb := events.NewHeartbeat(validHeartbeatAttrs())
			j, err := hb.ToJSON()
			Expect(err).NotTo(HaveOccurred())
			var parsed map[string]interface{}
			Expect(json.Unmarshal([]byte(j), &parsed)).To(Succeed())
			Expect(parsed["kind"]).To(Equal("heartbeat"))
		})
	})
})

var _ = Describe("Event Factory", func() {
	Describe("Create", func() {
		It("creates alert events", func() {
			event, err := events.Create("alert", validAlertAttrs())
			Expect(err).NotTo(HaveOccurred())
			Expect(event.Kind()).To(Equal("alert"))
		})

		It("creates heartbeat events", func() {
			event, err := events.Create("heartbeat", validHeartbeatAttrs())
			Expect(err).NotTo(HaveOccurred())
			Expect(event.Kind()).To(Equal("heartbeat"))
		})

		It("returns error for unknown event type", func() {
			_, err := events.Create("unknown", map[string]interface{}{})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("cannot find 'unknown' event handler"))
		})
	})

	Describe("CreateAndValidate", func() {
		It("returns error for invalid events", func() {
			_, err := events.CreateAndValidate("alert", map[string]interface{}{})
			Expect(err).To(HaveOccurred())
		})

		It("returns valid events", func() {
			event, err := events.CreateAndValidate("alert", validAlertAttrs())
			Expect(err).NotTo(HaveOccurred())
			Expect(event.Valid()).To(BeTrue())
		})
	})
})

func validAlertAttrs() map[string]interface{} {
	return map[string]interface{}{
		"id":         "alert-1",
		"severity":   2,
		"title":      "Test Alert",
		"summary":    "Something went wrong",
		"source":     "test-source",
		"deployment": "test-deployment",
		"created_at": time.Now().Unix(),
	}
}

func validHeartbeatAttrs() map[string]interface{} {
	return map[string]interface{}{
		"id":          "hb-1",
		"timestamp":   time.Now().Unix(),
		"deployment":  "test-deployment",
		"agent_id":    "agent-1",
		"job":         "test-job",
		"index":       "0",
		"instance_id": "instance-1",
		"job_state":   "running",
		"teams":       []interface{}{"team-1"},
		"vitals": map[string]interface{}{
			"load": []interface{}{0.1, 0.2, 0.3},
			"cpu":  map[string]interface{}{"user": "10", "sys": "5", "wait": "1"},
			"mem":  map[string]interface{}{"percent": "50", "kb": "1024000"},
			"swap": map[string]interface{}{"percent": "10", "kb": "512000"},
			"disk": map[string]interface{}{
				"system":     map[string]interface{}{"percent": "30", "inode_percent": "5"},
				"ephemeral":  map[string]interface{}{"percent": "40", "inode_percent": "6"},
				"persistent": map[string]interface{}{"percent": "50", "inode_percent": "7"},
			},
		},
	}
}
