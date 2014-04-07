package http_fakes_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestHTTP_fakes(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "HTTP_fakes Suite")
}
