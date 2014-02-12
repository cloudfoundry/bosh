package action_test

import (
	. "bosh/agent/action"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("ping should be synchronous", func() {

			action := NewPing()
			assert.False(GinkgoT(), action.IsAsynchronous())
		})
		It("ping run returns pong", func() {

			action := NewPing()
			pong, err := action.Run()
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), "pong", pong)
		})
	})
}
