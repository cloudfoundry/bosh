package vmdk_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestVmdk(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Vmdk Suite")
}
