package pluginlib_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestPluginlib(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Pluginlib Suite")
}
