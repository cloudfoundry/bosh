package httpsdispatcher_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestHttpsdispatcher(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Httpsdispatcher Suite")
}
