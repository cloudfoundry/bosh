package bundlecollection_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestBundlecollection(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Bundlecollection Suite")
}
