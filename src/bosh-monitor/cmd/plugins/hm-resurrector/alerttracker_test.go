package main

import (
	"testing"
	"time"
)

// ---------------------------------------------------------------------------
// deploymentState.state() / summary()
// ---------------------------------------------------------------------------

func TestDeploymentStateNormal(t *testing.T) {
	// Ruby: "when the number of unresponsive agents is 0" → reports as "normal"
	ds := &deploymentState{
		deployment:     "mycloud",
		agentCount:     10,
		unhealthyCount: 0,
		countThreshold: 5,
		pctThreshold:   0.2,
	}
	if ds.state() != "normal" {
		t.Errorf("expected 'normal', got %q", ds.state())
	}
	if ds.meltdown() {
		t.Error("meltdown() should be false for 0 unhealthy")
	}
	if ds.managed() {
		t.Error("managed() should be false for 0 unhealthy")
	}
}

func TestDeploymentStateManagedBelowCountThreshold(t *testing.T) {
	// Ruby: minimum_down_jobs=2, percent_threshold=0.0, alerts=1 → "managed"
	// (unhealthy count 1 < minimum_down_jobs 2)
	ds := &deploymentState{
		deployment:     "deployment",
		agentCount:     10,
		unhealthyCount: 1,
		countThreshold: 2,
		pctThreshold:   0.0,
	}
	if ds.state() != "managed" {
		t.Errorf("expected 'managed', got %q", ds.state())
	}
	if !ds.managed() {
		t.Error("managed() should be true")
	}
}

func TestDeploymentStateManagedAtCountBelowPercent(t *testing.T) {
	// Ruby: minimum_down_jobs=2, percent_threshold=0.21, alerts=2 → "managed"
	// (count threshold met but 20% < 21%)
	ds := &deploymentState{
		deployment:     "deployment",
		agentCount:     10,
		unhealthyCount: 2,
		countThreshold: 2,
		pctThreshold:   0.21,
	}
	if ds.state() != "managed" {
		t.Errorf("expected 'managed', got %q", ds.state())
	}
}

func TestDeploymentStateMeltdown(t *testing.T) {
	// Ruby: minimum_down_jobs=2, percent_threshold=0.20, alerts=2 → "meltdown"
	// (count=2 ≥ 2, 20% ≥ 20%)
	ds := &deploymentState{
		deployment:     "deployment",
		agentCount:     10,
		unhealthyCount: 2,
		countThreshold: 2,
		pctThreshold:   0.20,
	}
	if ds.state() != "meltdown" {
		t.Errorf("expected 'meltdown', got %q", ds.state())
	}
	if !ds.meltdown() {
		t.Error("meltdown() should be true")
	}
}

func TestDeploymentStateSummary(t *testing.T) {
	ds := &deploymentState{
		deployment:     "deployment",
		agentCount:     10,
		unhealthyCount: 2,
		countThreshold: 2,
		pctThreshold:   0.20,
	}
	want := "deployment: 'deployment'; 2 of 10 agents are unhealthy (20.0%)"
	if got := ds.summary(); got != want {
		t.Errorf("summary mismatch\n  got:  %q\n  want: %q", got, want)
	}
}

func TestDeploymentStateSummaryZero(t *testing.T) {
	ds := &deploymentState{
		deployment:     "deployment",
		agentCount:     10,
		unhealthyCount: 0,
		countThreshold: 5,
		pctThreshold:   0.2,
	}
	want := "deployment: 'deployment'; 0 of 10 agents are unhealthy (0.0%)"
	if got := ds.summary(); got != want {
		t.Errorf("summary mismatch\n  got:  %q\n  want: %q", got, want)
	}
}

func TestDeploymentStateUnhealthyPercentZeroAgents(t *testing.T) {
	ds := &deploymentState{agentCount: 0, unhealthyCount: 0}
	if p := ds.unhealthyPercent(); p != 0.0 {
		t.Errorf("unhealthyPercent with 0 agents should be 0.0, got %v", p)
	}
}

// ---------------------------------------------------------------------------
// newAlertTracker defaults and custom config
// ---------------------------------------------------------------------------

func TestNewAlertTrackerDefaults(t *testing.T) {
	// Ruby: empty config {} → defaults applied
	at := newAlertTracker(resurrectorOptions{})
	if at.minimumDownJobs != 5 {
		t.Errorf("expected default minimumDownJobs=5, got %d", at.minimumDownJobs)
	}
	if at.percentThreshold != 0.2 {
		t.Errorf("expected default percentThreshold=0.2, got %v", at.percentThreshold)
	}
	if at.timeThreshold != 600 {
		t.Errorf("expected default timeThreshold=600, got %d", at.timeThreshold)
	}
}

func TestNewAlertTrackerCustomConfig(t *testing.T) {
	at := newAlertTracker(resurrectorOptions{
		MinimumDownJobs:  3,
		PercentThreshold: 0.5,
		TimeThreshold:    300,
	})
	if at.minimumDownJobs != 3 {
		t.Errorf("expected minimumDownJobs=3, got %d", at.minimumDownJobs)
	}
	if at.percentThreshold != 0.5 {
		t.Errorf("expected percentThreshold=0.5, got %v", at.percentThreshold)
	}
	if at.timeThreshold != 300 {
		t.Errorf("expected timeThreshold=300, got %d", at.timeThreshold)
	}
}

// ---------------------------------------------------------------------------
// alertTracker.unhealthyCount() — time-window filtering
// ---------------------------------------------------------------------------

func TestAlertTrackerUnhealthyCountRecent(t *testing.T) {
	at := newAlertTracker(resurrectorOptions{TimeThreshold: 600})
	now := time.Now()
	at.record(jobInstanceKey{Deployment: "dep", Job: "job", ID: "id-0"}, now.Unix())
	at.record(jobInstanceKey{Deployment: "dep", Job: "job", ID: "id-1"}, now.Unix())

	if c := at.unhealthyCount(); c != 2 {
		t.Errorf("expected 2 recent unhealthy agents, got %d", c)
	}
}

func TestAlertTrackerUnhealthyCountExcludesStale(t *testing.T) {
	// Ruby: time_threshold=600, records at -610s, -600s, -60s → only 2 are fresh
	// Ruby spec records -610 (excluded), -600 (excluded), -60 (included).
	// The Go implementation uses After(cutoff) where cutoff = now - threshold.
	// At t=-600, time.Unix(t) is NOT After(cutoff=now-600), so it is excluded.
	at := newAlertTracker(resurrectorOptions{TimeThreshold: 600})
	now := time.Now()
	at.record(jobInstanceKey{Deployment: "dep", Job: "job", ID: "id-0"}, now.Add(-610*time.Second).Unix())
	at.record(jobInstanceKey{Deployment: "dep", Job: "job", ID: "id-1"}, now.Add(-600*time.Second).Unix())
	at.record(jobInstanceKey{Deployment: "dep", Job: "job", ID: "id-2"}, now.Add(-60*time.Second).Unix())

	if c := at.unhealthyCount(); c != 1 {
		t.Errorf("expected 1 non-stale agent (only -60s entry), got %d", c)
	}
}

func TestAlertTrackerUnhealthyCountEmpty(t *testing.T) {
	at := newAlertTracker(resurrectorOptions{})
	if c := at.unhealthyCount(); c != 0 {
		t.Errorf("expected 0 for empty tracker, got %d", c)
	}
}

// ---------------------------------------------------------------------------
// jobInstanceKey — map equality (Ruby: "hashes properly")
// ---------------------------------------------------------------------------

func TestJobInstanceKeyMapEquality(t *testing.T) {
	// Ruby: two keys constructed with same arguments should resolve to the same map entry
	key1 := jobInstanceKey{Deployment: "deployment", Job: "job", ID: "uuid0"}
	key2 := jobInstanceKey{Deployment: "deployment", Job: "job", ID: "uuid0"}
	m := map[jobInstanceKey]string{key1: "foo"}
	if m[key2] != "foo" {
		t.Errorf("expected map lookup with equal key to return 'foo', got %q", m[key2])
	}
}

func TestJobInstanceKeyMapInequality(t *testing.T) {
	key1 := jobInstanceKey{Deployment: "dep", Job: "job", ID: "uuid0"}
	key2 := jobInstanceKey{Deployment: "dep", Job: "job", ID: "uuid1"}
	m := map[jobInstanceKey]string{key1: "foo"}
	if _, ok := m[key2]; ok {
		t.Error("keys with different IDs should not match")
	}
}
