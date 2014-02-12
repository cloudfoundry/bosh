package testing_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestTesting(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Testing Suite")
}
