package cmd_test

import (
	. "bosh/davcli/cmd"
	davconf "bosh/davcli/config"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
	"reflect"
)

func buildFactory() (factory Factory) {
	config := davconf.Config{User: "some user"}

	factory = NewFactory()
	factory.SetConfig(config)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("factory create a put command", func() {
			factory := buildFactory()
			cmd, err := factory.Create("put")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), reflect.TypeOf(cmd), reflect.TypeOf(PutCmd{}))
		})
		It("factory create a get command", func() {

			factory := buildFactory()
			cmd, err := factory.Create("get")

			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), reflect.TypeOf(cmd), reflect.TypeOf(GetCmd{}))
		})
		It("factory create when cmd is unknown", func() {

			factory := buildFactory()
			_, err := factory.Create("some unknown cmd")

			assert.Error(GinkgoT(), err)
		})
	})
}
