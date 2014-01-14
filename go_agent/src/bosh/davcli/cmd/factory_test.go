package cmd

import (
	davclient "bosh/davcli/client"
	davconf "bosh/davcli/config"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestFactoryCreateAPutCommand(t *testing.T) {
	client, factory := buildFactory()
	cmd, err := factory.Create("put")

	assert.NoError(t, err)
	assert.Equal(t, cmd, newPutCmd(client))
}

func TestFactoryCreateAGetCommand(t *testing.T) {
	client, factory := buildFactory()
	cmd, err := factory.Create("get")

	assert.NoError(t, err)
	assert.Equal(t, cmd, newGetCmd(client))
}

func TestFactoryCreateWhenCmdIsUnknown(t *testing.T) {
	_, factory := buildFactory()
	_, err := factory.Create("some unknown cmd")

	assert.Error(t, err)
}

func buildFactory() (client davclient.Client, factory Factory) {
	config := davconf.Config{User: "some user"}
	client = davclient.NewClient(config)

	factory = NewFactory()
	factory.SetConfig(config)
	return
}
