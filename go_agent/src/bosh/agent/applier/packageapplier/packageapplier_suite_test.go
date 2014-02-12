package packageapplier_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestPackageapplier(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Packageapplier Suite")
}
