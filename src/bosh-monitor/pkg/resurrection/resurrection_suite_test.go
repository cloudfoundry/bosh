package resurrection_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestResurrection(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Resurrection Suite")
}
