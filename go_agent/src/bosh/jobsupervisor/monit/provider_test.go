package monit

import (
	fakeplatform "bosh/platform/fakes"
	"github.com/stretchr/testify/assert"
	"net/http"
	"testing"
)

func TestGet(t *testing.T) {
	platform := fakeplatform.NewFakePlatform()

	platform.GetMonitCredentialsUsername = "fake-user"
	platform.GetMonitCredentialsPassword = "fake-pass"

	client, err := NewProvider(platform).Get()

	assert.NoError(t, err)

	expectedClient := NewHttpClient("127.0.0.1:2822", "fake-user", "fake-pass", http.DefaultClient)
	assert.Equal(t, expectedClient, client)
}
