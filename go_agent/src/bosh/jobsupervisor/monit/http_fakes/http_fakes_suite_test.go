package http_fakes_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestHttp_fakes(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Http_fakes Suite")
}
