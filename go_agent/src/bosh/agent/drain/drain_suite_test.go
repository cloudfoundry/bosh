package drain_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestDrain(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Drain Suite")
}
