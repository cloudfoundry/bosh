package events

import (
	"encoding/json"
	"fmt"
	"time"
)

type Heartbeat struct {
	HeartbeatID string
	Timestamp   time.Time
	Deployment  string
	AgentID     string
	Job         string
	Index       string
	InstanceID  string
	JobState    string
	Teams       []string
	Vitals      map[string]interface{}
	HBMetrics   []Metric
	Attrs       map[string]interface{}
}

func NewHeartbeat(attributes map[string]interface{}) *Heartbeat {
	h := &Heartbeat{Attrs: attributes}

	if v, ok := attributes["id"]; ok {
		h.HeartbeatID = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["timestamp"]; ok {
		switch tv := v.(type) {
		case int:
			h.Timestamp = time.Unix(int64(tv), 0)
		case int64:
			h.Timestamp = time.Unix(tv, 0)
		case float64:
			h.Timestamp = time.Unix(int64(tv), 0)
		case time.Time:
			h.Timestamp = tv
		}
	}
	if v, ok := attributes["deployment"]; ok {
		h.Deployment = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["agent_id"]; ok {
		h.AgentID = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["job"]; ok {
		h.Job = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["index"]; ok {
		h.Index = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["instance_id"]; ok {
		h.InstanceID = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["job_state"]; ok {
		h.JobState = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["teams"]; ok {
		if teams, ok := v.([]interface{}); ok {
			for _, t := range teams {
				h.Teams = append(h.Teams, fmt.Sprintf("%v", t))
			}
		} else if teams, ok := v.([]string); ok {
			h.Teams = teams
		}
	}
	if v, ok := attributes["vitals"]; ok {
		if vitals, ok := v.(map[string]interface{}); ok {
			h.Vitals = vitals
		}
	}
	if h.Vitals == nil {
		h.Vitals = map[string]interface{}{}
	}

	h.populateMetrics()
	return h
}

func (h *Heartbeat) ID() string   { return h.HeartbeatID }
func (h *Heartbeat) Kind() string { return "heartbeat" }

func (h *Heartbeat) Validate() []string {
	var errs []string
	if h.HeartbeatID == "" {
		errs = append(errs, "id is missing")
	}
	if h.Timestamp.IsZero() {
		errs = append(errs, "timestamp is missing")
	}
	return errs
}

func (h *Heartbeat) Valid() bool {
	return len(h.Validate()) == 0
}

func (h *Heartbeat) ShortDescription() string {
	desc := fmt.Sprintf("Heartbeat from %s/%s (agent_id=%s", h.Job, h.InstanceID, h.AgentID)
	if h.Index != "" {
		desc += fmt.Sprintf(" index=%s", h.Index)
	}
	desc += fmt.Sprintf(") @ %s", h.Timestamp.UTC().Format(time.RFC1123Z))
	return desc
}

func (h *Heartbeat) ToHash() map[string]interface{} {
	result := map[string]interface{}{
		"kind":        "heartbeat",
		"id":          h.HeartbeatID,
		"timestamp":   h.Timestamp.Unix(),
		"deployment":  h.Deployment,
		"agent_id":    h.AgentID,
		"job":         h.Job,
		"index":       h.Index,
		"instance_id": h.InstanceID,
		"job_state":   h.JobState,
		"vitals":      h.Vitals,
		"teams":       h.Teams,
		"metrics":     h.metricsToHash(),
	}
	if v, ok := h.Attrs["number_of_processes"]; ok {
		result["number_of_processes"] = v
	}
	return result
}

func (h *Heartbeat) metricsToHash() []map[string]interface{} {
	var result []map[string]interface{}
	for _, m := range h.HBMetrics {
		result = append(result, map[string]interface{}{
			"name":      m.Name,
			"value":     m.Value,
			"timestamp": m.Timestamp,
			"tags":      m.Tags,
		})
	}
	return result
}

func (h *Heartbeat) ToJSON() (string, error) {
	data, err := json.Marshal(h.ToHash())
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func (h *Heartbeat) ToPlainText() string {
	return h.ShortDescription()
}

func (h *Heartbeat) Metrics() []Metric {
	return h.HBMetrics
}

func (h *Heartbeat) Attributes() map[string]interface{} {
	return h.Attrs
}

func (h *Heartbeat) String() string {
	return h.ShortDescription()
}

func (h *Heartbeat) addMetric(name string, value interface{}) {
	if value == nil {
		return
	}
	tags := map[string]string{}
	if h.Job != "" {
		tags["job"] = h.Job
	}
	if h.Index != "" {
		tags["index"] = h.Index
	}
	if h.InstanceID != "" {
		tags["id"] = h.InstanceID
	}
	h.HBMetrics = append(h.HBMetrics, Metric{
		Name:      name,
		Value:     fmt.Sprintf("%v", value),
		Timestamp: h.Timestamp.Unix(),
		Tags:      tags,
	})
}

func (h *Heartbeat) populateMetrics() {
	load := getSlice(h.Vitals, "load")
	if len(load) > 0 {
		h.addMetric("system.load.1m", load[0])
	}

	cpu := getMap(h.Vitals, "cpu")
	h.addMetric("system.cpu.user", cpu["user"])
	h.addMetric("system.cpu.sys", cpu["sys"])
	h.addMetric("system.cpu.wait", cpu["wait"])

	mem := getMap(h.Vitals, "mem")
	h.addMetric("system.mem.percent", mem["percent"])
	h.addMetric("system.mem.kb", mem["kb"])

	swap := getMap(h.Vitals, "swap")
	h.addMetric("system.swap.percent", swap["percent"])
	h.addMetric("system.swap.kb", swap["kb"])

	disk := getMap(h.Vitals, "disk")
	systemDisk := getMap(disk, "system")
	h.addMetric("system.disk.system.percent", systemDisk["percent"])
	h.addMetric("system.disk.system.inode_percent", systemDisk["inode_percent"])

	ephemeralDisk := getMap(disk, "ephemeral")
	h.addMetric("system.disk.ephemeral.percent", ephemeralDisk["percent"])
	h.addMetric("system.disk.ephemeral.inode_percent", ephemeralDisk["inode_percent"])

	persistentDisk := getMap(disk, "persistent")
	h.addMetric("system.disk.persistent.percent", persistentDisk["percent"])
	h.addMetric("system.disk.persistent.inode_percent", persistentDisk["inode_percent"])

	healthy := 0
	if h.JobState == "running" {
		healthy = 1
	}
	h.addMetric("system.healthy", healthy)
}

func getMap(m map[string]interface{}, key string) map[string]interface{} {
	if v, ok := m[key]; ok {
		if vm, ok := v.(map[string]interface{}); ok {
			return vm
		}
	}
	return map[string]interface{}{}
}

func getSlice(m map[string]interface{}, key string) []interface{} {
	if v, ok := m[key]; ok {
		if vs, ok := v.([]interface{}); ok {
			return vs
		}
	}
	return nil
}
