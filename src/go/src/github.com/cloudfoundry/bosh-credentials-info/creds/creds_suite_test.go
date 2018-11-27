package creds_test

import (
	"testing"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestCreds(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Creds Suite")
}
