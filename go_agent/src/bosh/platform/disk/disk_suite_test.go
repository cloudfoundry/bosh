package disk_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestDisk(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Disk Suite")
}
