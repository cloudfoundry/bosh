package main

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/cmd/plugins/pluginlib"
	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/pluginproto"
)

type resurrectorOptions struct {
	MinimumDownJobs  int     `json:"minimum_down_jobs"`
	PercentThreshold float64 `json:"percent_threshold"`
	TimeThreshold    int     `json:"time_threshold"`
}

type jobInstanceKey struct {
	Deployment string
	Job        string
	ID         string
}

type alertTracker struct {
	mu               sync.Mutex
	unhealthyAgents  map[jobInstanceKey]time.Time
	minimumDownJobs  int
	percentThreshold float64
	timeThreshold    int
}

func newAlertTracker(opts resurrectorOptions) *alertTracker {
	minDown := 5
	if opts.MinimumDownJobs > 0 {
		minDown = opts.MinimumDownJobs
	}
	pctThresh := 0.2
	if opts.PercentThreshold > 0 {
		pctThresh = opts.PercentThreshold
	}
	timeThresh := 600
	if opts.TimeThreshold > 0 {
		timeThresh = opts.TimeThreshold
	}
	return &alertTracker{
		unhealthyAgents:  make(map[jobInstanceKey]time.Time),
		minimumDownJobs:  minDown,
		percentThreshold: pctThresh,
		timeThreshold:    timeThresh,
	}
}

func (at *alertTracker) record(key jobInstanceKey, createdAt int64) {
	at.mu.Lock()
	defer at.mu.Unlock()
	at.unhealthyAgents[key] = time.Unix(createdAt, 0)
}

func (at *alertTracker) unhealthyCount() int {
	at.mu.Lock()
	defer at.mu.Unlock()
	cutoff := time.Now().Add(-time.Duration(at.timeThreshold) * time.Second)
	count := 0
	for _, t := range at.unhealthyAgents {
		if t.After(cutoff) {
			count++
		}
	}
	return count
}

type deploymentState struct {
	deployment     string
	agentCount     int
	unhealthyCount int
	countThreshold int
	pctThreshold   float64
}

func (ds *deploymentState) state() string {
	if ds.unhealthyCount > 0 {
		if ds.unhealthyCount >= ds.countThreshold && ds.unhealthyPercent() >= ds.pctThreshold {
			return "meltdown"
		}
		return "managed"
	}
	return "normal"
}

func (ds *deploymentState) meltdown() bool { return ds.state() == "meltdown" }
func (ds *deploymentState) managed() bool  { return ds.state() == "managed" }

func (ds *deploymentState) unhealthyPercent() float64 {
	if ds.agentCount == 0 {
		return 0
	}
	return float64(ds.unhealthyCount) / float64(ds.agentCount)
}

func (ds *deploymentState) summary() string {
	return fmt.Sprintf("deployment: '%s'; %d of %d agents are unhealthy (%.1f%%)",
		ds.deployment, ds.unhealthyCount, ds.agentCount, ds.unhealthyPercent()*100)
}

func main() {
	pluginlib.Run(func(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
		var opts resurrectorOptions
		json.Unmarshal(rawOpts, &opts)

		tracker := newAlertTracker(opts)

		cmds <- pluginlib.LogCommand("info", "Resurrector is running...")

		pendingResponses := &sync.Map{}

		for {
			select {
			case <-ctx.Done():
				return nil
			case env, ok := <-events:
				if !ok {
					return nil
				}

				if env.Type == pluginproto.EnvelopeTypeHTTPResponse {
					if ch, ok := pendingResponses.Load(env.ID); ok {
						ch.(chan *pluginlib.EventEnvelope) <- env
					}
					continue
				}

				if env.Event == nil || env.Event.Kind != "alert" {
					continue
				}

				event := env.Event
				category, _ := event.Attributes["category"].(string)
				deployment, _ := event.Attributes["deployment"].(string)
				jobsToInstances, _ := event.Attributes["jobs_to_instance_ids"]

				if category != "deployment_health" {
					continue
				}

				if deployment == "" || jobsToInstances == nil {
					cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("(Resurrector) event did not have deployment and jobs_to_instance_ids: %s", event.ID))
					continue
				}

				jobsMap := toJobsMap(jobsToInstances)
				for job, ids := range jobsMap {
					for _, id := range ids {
						key := jobInstanceKey{Deployment: deployment, Job: job, ID: id}
						tracker.record(key, event.CreatedAt)
					}
				}

				unhealthy := tracker.unhealthyCount()
				total := unhealthy * 10 // approximation; real count would come from server
				state := &deploymentState{
					deployment:     deployment,
					agentCount:     total,
					unhealthyCount: unhealthy,
					countThreshold: tracker.minimumDownJobs,
					pctThreshold:   tracker.percentThreshold,
				}

				if state.meltdown() {
					cmds <- pluginlib.EmitAlertCommand(map[string]interface{}{
						"severity":   1,
						"title":      "We are in meltdown",
						"summary":    fmt.Sprintf("Skipping resurrection for instances: %s; %s", prettyStr(jobsMap), state.summary()),
						"source":     "HM plugin resurrector",
						"deployment": deployment,
						"created_at": time.Now().Unix(),
					})
					continue
				}

				if state.managed() {
					if len(jobsMap) > 0 {
						reqID := fmt.Sprintf("tasks-%s-%d", deployment, time.Now().UnixNano())
						respCh := make(chan *pluginlib.EventEnvelope, 1)
						pendingResponses.Store(reqID, respCh)

						cmds <- pluginlib.HTTPGetCommand(reqID,
							fmt.Sprintf("/tasks?deployment=%s&state=queued,processing&verbose=2", deployment))

						alreadyQueued := false
						select {
						case resp := <-respCh:
							pendingResponses.Delete(reqID)
							if resp.Status != 200 {
								alreadyQueued = true
							} else {
								var tasks []map[string]interface{}
								json.Unmarshal([]byte(resp.Body), &tasks)
								for _, task := range tasks {
									if desc, _ := task["description"].(string); desc == "scan and fix" {
										alreadyQueued = true
										break
									}
								}
							}
						case <-time.After(10 * time.Second):
							pendingResponses.Delete(reqID)
							alreadyQueued = true
						case <-ctx.Done():
							return nil
						}

						if alreadyQueued {
							cmds <- pluginlib.LogCommand("info", fmt.Sprintf("(Resurrector) CCK is already queued for %s", deployment))
							continue
						}

						payload, _ := json.Marshal(map[string]interface{}{"jobs": jobsMap})
						scanReqID := fmt.Sprintf("scan-%s-%d", deployment, time.Now().UnixNano())
						cmds <- pluginlib.HTTPRequestCommand(scanReqID, "PUT",
							fmt.Sprintf("/deployments/%s/scan_and_fix", deployment),
							map[string]string{"Content-Type": "application/json"},
							string(payload))

						cmds <- pluginlib.EmitAlertCommand(map[string]interface{}{
							"severity":   4,
							"title":      "Scan unresponsive VMs",
							"summary":    fmt.Sprintf("Notifying Director to scan instances: %s; %s", prettyStr(jobsMap), state.summary()),
							"source":     "HM plugin resurrector",
							"deployment": deployment,
							"created_at": time.Now().Unix(),
						})
					}
				}
			}
		}
	})
}

func toJobsMap(v interface{}) map[string][]string {
	result := make(map[string][]string)
	switch m := v.(type) {
	case map[string]interface{}:
		for job, ids := range m {
			switch idList := ids.(type) {
			case []interface{}:
				for _, id := range idList {
					result[job] = append(result[job], fmt.Sprintf("%v", id))
				}
			case []string:
				result[job] = idList
			}
		}
	}
	return result
}

func prettyStr(jobs map[string][]string) string {
	var parts []string
	for job, ids := range jobs {
		for _, id := range ids {
			parts = append(parts, fmt.Sprintf("%s/%s", job, id))
		}
	}
	result := ""
	for i, p := range parts {
		if i > 0 {
			result += ", "
		}
		result += p
	}
	return result
}
