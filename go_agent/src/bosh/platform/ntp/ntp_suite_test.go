package ntp_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestNtp(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Ntp Suite")
}
