package aws_device_path_resolver_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestAws_device_path_resolver(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Aws_device_path_resolver Suite")
}
