package blobstore_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestBlobstore(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Blobstore Suite")
}
