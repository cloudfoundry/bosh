package action

import (
	"os"
	"time"
)

type ConfigureNetworksAction struct {
	waitToKillAgentInterval time.Duration
}

func NewConfigureNetworks() (prepareAction ConfigureNetworksAction) {
	prepareAction.waitToKillAgentInterval = 1 * time.Second
	return
}

func (a ConfigureNetworksAction) IsAsynchronous() bool {
	return true
}

func (a ConfigureNetworksAction) IsPersistent() bool {
	return true
}

func (a ConfigureNetworksAction) Run() (interface{}, error) {
	// Two possible ways to implement this action:
	//
	// (1) Restart agent which will in turn fetch infrastructure settings
	// (2) Re-fetch infrastructure settings yourself, and reinitialize connections
	//
	// Number 1 was picked for simplicity and
	// to avoid having two ways to reload connections.
	//
	go a.killAgent()

	return "ok", nil
}

func (a ConfigureNetworksAction) killAgent() {
	// Allow agent to send back immediate response
	time.Sleep(a.waitToKillAgentInterval)

	os.Exit(0)

	return
}
