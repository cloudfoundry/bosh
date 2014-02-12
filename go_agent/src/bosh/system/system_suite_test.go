package system_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestSystem(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "System Suite")
}
