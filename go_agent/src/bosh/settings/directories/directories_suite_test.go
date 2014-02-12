package directories_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestDirectories(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Directories Suite")
}
