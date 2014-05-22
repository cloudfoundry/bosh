package devicepathresolver_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"testing"
)

func TestDevicepathresolver(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Devicepathresolver Suite")
}
