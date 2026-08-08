package pluginhost_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestPluginhost(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Pluginhost Suite")
}
