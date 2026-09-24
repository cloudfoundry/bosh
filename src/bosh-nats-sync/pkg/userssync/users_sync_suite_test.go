package userssync_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestUsersSync(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "UsersSync Suite")
}
