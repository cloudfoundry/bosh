package cdrom_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestCdrom(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Cdrom Suite")
}
