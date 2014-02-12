package micro_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestMicro(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Micro Suite")
}
