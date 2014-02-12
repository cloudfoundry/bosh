package applyspec_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestApplyspec(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Applyspec Suite")
}
