package devicepathresolver_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"testing"
)

func Test_devicepathresolver(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "ALL devicepathresolver Suite")
}
