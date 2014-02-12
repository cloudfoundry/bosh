package monit_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestMonit(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Monit Suite")
}
