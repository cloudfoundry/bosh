package cmd_test

import (
	. "bosh/davcli/cmd"
	davconf "bosh/davcli/config"
	"github.com/stretchr/testify/assert"
	"reflect"
	"testing"
)

func TestFactoryCreateAPutCommand(t *testing.T) {
	factory := buildFactory()
	cmd, err := factory.Create("put")

	assert.NoError(t, err)
	assert.Equal(t, reflect.TypeOf(cmd), reflect.TypeOf(PutCmd{}))
}

func TestFactoryCreateAGetCommand(t *testing.T) {
	factory := buildFactory()
	cmd, err := factory.Create("get")

	assert.NoError(t, err)
	assert.Equal(t, reflect.TypeOf(cmd), reflect.TypeOf(GetCmd{}))
}

func TestFactoryCreateWhenCmdIsUnknown(t *testing.T) {
	factory := buildFactory()
	_, err := factory.Create("some unknown cmd")

	assert.Error(t, err)
}

func buildFactory() (factory Factory) {
	config := davconf.Config{User: "some user"}

	factory = NewFactory()
	factory.SetConfig(config)
	return
}
