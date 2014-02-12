package task_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestTask(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Task Suite")
}
