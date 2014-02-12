package settings_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestSettings(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Settings Suite")
}
