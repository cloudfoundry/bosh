package settings

import (
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetAgentId(t *testing.T) {
	settings := Settings{AgentId: "some-agent-id"}
	provider := NewProvider(settings)
	assert.Equal(t, provider.GetAgentId(), "some-agent-id")
}

func TestGetMbusUrl(t *testing.T) {
	settings := Settings{Mbus: "nats://user:pwd@some-ip:some-port"}
	provider := NewProvider(settings)
	assert.Equal(t, provider.GetMbusUrl(), "nats://user:pwd@some-ip:some-port")
}
