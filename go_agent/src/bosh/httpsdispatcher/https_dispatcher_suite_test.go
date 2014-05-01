package httpsdispatcher_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestHTTPS_dispatcher(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "HTTPS_dispatcher Suite")
}
