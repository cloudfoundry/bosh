package natsauthconfig_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestNatsAuthConfig(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "NatsAuthConfig Suite")
}
