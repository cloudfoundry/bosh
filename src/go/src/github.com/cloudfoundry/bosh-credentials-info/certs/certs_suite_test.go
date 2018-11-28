package certs_test

import (
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestCreds(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Package 'Certs' test Suite")
}
