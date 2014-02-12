package stats_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestStats(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Stats Suite")
}
