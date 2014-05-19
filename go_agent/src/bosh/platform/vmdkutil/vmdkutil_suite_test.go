package vmdkutil_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestVmdkutil(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Vmdkutil Suite")
}
