package action

import (
	"errors"
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
	// (1) Restart agent which will in turn fetch infrastructure settings
	// (2) Re-fetch infrastructure settings yourself, and reinitialize connections
	//
	// Option 1 was picked for simplicity and
	// to avoid having two ways to reload connections.

	// Instead of waiting for some time, ideally this action would receive a signal
	// that asynchronous task response was sent to the API consumer.
	time.Sleep(a.waitToKillAgentInterval)

	os.Exit(0)

	panic("unreachable")
}

func (a ConfigureNetworksAction) Resume() (interface{}, error) {
	return "ok", nil
}

func (a ConfigureNetworksAction) Cancel() error {
	return errors.New("not supported")
}
