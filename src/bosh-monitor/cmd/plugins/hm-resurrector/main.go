package main

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
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

// alertTracker tracks which agent instances have been unhealthy and when.
// It is accessed exclusively from the outer event-loop goroutine in
// runResurrector; no inner goroutines touch it, so no mutex is needed.
type alertTracker struct {
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
	at.unhealthyAgents[key] = time.Unix(createdAt, 0)
}

// unhealthyCountForDeployment returns the number of agents in the given
// deployment whose alert timestamp falls within the time threshold. It
// intentionally scopes to one deployment so that unhealthy agents in an
// unrelated deployment cannot inflate another deployment's meltdown percentage.
func (at *alertTracker) unhealthyCountForDeployment(deployment string) int {
	cutoff := time.Now().Add(-time.Duration(at.timeThreshold) * time.Second)
	count := 0
	for key, t := range at.unhealthyAgents {
		if key.Deployment == deployment && t.After(cutoff) {
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
	pluginlib.Run(runResurrector)
}

// runResurrector is the plugin entry point. It is exported as a named function
// so that unit tests can drive it directly via pluginlib.RunWithIO.
func runResurrector(ctx context.Context, rawOpts json.RawMessage, events <-chan *pluginlib.EventEnvelope, cmds chan<- *pluginlib.Command) error {
	var opts resurrectorOptions
	if err := json.Unmarshal(rawOpts, &opts); err != nil {
		return fmt.Errorf("failed to parse options: %w", err)
	}

	tracker := newAlertTracker(opts)

	cmds <- pluginlib.LogCommand("info", "Resurrector is running...")

	// pendingChans correlates outgoing HTTP request IDs with the channel that
	// the inner goroutine is waiting on. sync.Map was avoided in favour of a
	// plain map + mutex: sync.Map is optimised for stable-key, many-concurrent-
	// reader workloads; here we have low contention and benefit from the type
	// safety of a concrete map type.
	var pendingMu sync.Mutex
	pendingChans := make(map[string]chan *pluginlib.EventEnvelope)

	for {
		select {
		case <-ctx.Done():
			return nil
		case env, ok := <-events:
			if !ok {
				return nil
			}

			// Route HTTP responses to waiting goroutines without blocking.
			if env.Type == pluginproto.EnvelopeTypeHTTPResponse {
				pendingMu.Lock()
				ch, ok := pendingChans[env.ID]
				pendingMu.Unlock()
				if ok {
					ch <- env
				}
				continue
			}

			if env.Event == nil || env.Event.Kind != "alert" {
				continue
			}

			event := env.Event
			if event.Category != "deployment_health" {
				continue
			}

			if event.Deployment == "" || len(event.JobsToInstanceIDs) == 0 {
				cmds <- pluginlib.LogCommand("warn", fmt.Sprintf("(Resurrector) event did not have deployment and jobs_to_instance_ids: %s", event.ID))
				continue
			}

			deployment := event.Deployment
			jobsMap := event.JobsToInstanceIDs
			for job, ids := range jobsMap {
				for _, id := range ids {
					key := jobInstanceKey{Deployment: deployment, Job: job, ID: id}
					tracker.record(key, event.CreatedAt)
				}
			}

			unhealthy := tracker.unhealthyCountForDeployment(deployment)
			// Use total_agent_count from the alert when available (set by
			// manager.go to mirror Ruby's AlertTracker#state_for which sums
			// get_agents_for_deployment + get_deleted_agents_for_deployment).
			// Fall back to unhealthy*10 for alerts that don't carry it.
			total := unhealthy * 10
			if event.TotalAgentCount > 0 {
				total = event.TotalAgentCount
			}
			state := &deploymentState{
				deployment:     deployment,
				agentCount:     total,
				unhealthyCount: unhealthy,
				countThreshold: tracker.minimumDownJobs,
				pctThreshold:   tracker.percentThreshold,
			}

			if state.meltdown() {
				cmds <- pluginlib.EmitAlertCommand(&pluginlib.AlertPayload{
					Severity:   1,
					Title:      "We are in meltdown",
					Summary:    fmt.Sprintf("Skipping resurrection for instances: %s; %s", prettyStr(jobsMap), state.summary()),
					Source:     "HM plugin resurrector",
					Deployment: deployment,
					CreatedAt:  time.Now().Unix(),
				})
				continue
			}

			if state.managed() && len(jobsMap) > 0 {
				// Spawn a goroutine so the main event loop stays free to route
				// HTTP responses (EnvelopeTypeHTTPResponse) back to respCh via
				// pendingResponses. Blocking the outer loop here would cause the
				// inner select to never receive the response and always time out.
				go func(dep string, jobs map[string][]string, st *deploymentState) {
					reqID := fmt.Sprintf("tasks-%s-%d", dep, time.Now().UnixNano())
					respCh := make(chan *pluginlib.EventEnvelope, 1)
					pendingMu.Lock()
					pendingChans[reqID] = respCh
					pendingMu.Unlock()

					pluginlib.SendCommand(ctx, cmds, pluginlib.HTTPGetCommand(reqID,
						fmt.Sprintf("/tasks?deployment=%s&state=queued,processing&verbose=2", dep)))

					alreadyQueued := false
					select {
					case resp := <-respCh:
						pendingMu.Lock()
						delete(pendingChans, reqID)
						pendingMu.Unlock()
						if resp.Status != 200 {
							// Director returned an error; be conservative and skip
							// this cycle (same behaviour as the Ruby plugin).
							alreadyQueued = true
						} else {
							var tasks []map[string]interface{}
							_ = json.Unmarshal([]byte(resp.Body), &tasks)
							for _, task := range tasks {
								desc, _ := task["description"].(string)
								if desc == "scan and fix" ||
									desc == "delete deployment" ||
									desc == "create deployment" {
									alreadyQueued = true
									break
								}
							}
						}
					case <-time.After(10 * time.Second):
						pendingMu.Lock()
						delete(pendingChans, reqID)
						pendingMu.Unlock()
						// Timed out waiting for task-check response. Be conservative
						// and skip this cycle so we don't pile up duplicate tasks.
						pluginlib.SendCommand(ctx, cmds, pluginlib.LogCommand("warn", fmt.Sprintf("(Resurrector) timed out waiting for task check for %s; skipping this cycle", dep)))
						alreadyQueued = true
					case <-ctx.Done():
						return
					}

					if alreadyQueued {
						pluginlib.SendCommand(ctx, cmds, pluginlib.LogCommand("info", fmt.Sprintf("(Resurrector) CCK is already queued for %s", dep)))
						return
					}

					payload, _ := json.Marshal(map[string]interface{}{"jobs": jobs})
					scanReqID := fmt.Sprintf("scan-%s-%d", dep, time.Now().UnixNano())
					pluginlib.SendCommand(ctx, cmds, pluginlib.HTTPRequestCommand(scanReqID, "PUT",
						fmt.Sprintf("/deployments/%s/scan_and_fix", dep),
						map[string]string{"Content-Type": "application/json"},
						string(payload)))

					pluginlib.SendCommand(ctx, cmds, pluginlib.EmitAlertCommand(&pluginlib.AlertPayload{
						Severity:   4,
						Title:      "Scan unresponsive VMs",
						Summary:    fmt.Sprintf("Notifying Director to scan instances: %s; %s", prettyStr(jobs), st.summary()),
						Source:     "HM plugin resurrector",
						Deployment: dep,
						CreatedAt:  time.Now().Unix(),
					}))
				}(deployment, jobsMap, state)
			}
		}
	}
}

func prettyStr(jobs map[string][]string) string {
	var parts []string
	for job, ids := range jobs {
		for _, id := range ids {
			parts = append(parts, fmt.Sprintf("%s/%s", job, id))
		}
	}
	return strings.Join(parts, ", ")
}
