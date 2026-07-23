package authprovider_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestAuthProvider(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "AuthProvider Suite")
}
