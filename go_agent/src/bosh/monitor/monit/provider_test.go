package monit

import (
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGet(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()

	platform.GetMonitCredentialsUsername = "fake-user"
	platform.GetMonitCredentialsPassword = "fake-pass"

	client, err := NewProvider(platform).Get()

	assert.NoError(t, err)

	expectedClient := NewHttpMonitClient("127.0.0.1:2822", "fake-user", "fake-pass")
	assert.Equal(t, expectedClient, client)
}
