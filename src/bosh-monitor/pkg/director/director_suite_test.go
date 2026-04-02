package director_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestDirector(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Director Suite")
}
