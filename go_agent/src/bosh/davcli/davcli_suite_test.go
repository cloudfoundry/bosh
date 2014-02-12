package davcli_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestDavcli(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Davcli Suite")
}
