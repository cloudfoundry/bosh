package notification_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestNotification(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Notification Suite")
}
