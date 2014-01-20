package https_dispatcher_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestHttps_dispatcher(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Https_dispatcher Suite")
}
