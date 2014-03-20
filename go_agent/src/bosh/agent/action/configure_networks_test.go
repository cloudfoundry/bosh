package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
)

func init() {
	Describe("configureNetworks", func() {
		var (
			action ConfigureNetworksAction
		)

		BeforeEach(func() {
			action = NewConfigureNetworks()
		})

		It("is asynchronous", func() {
			Expect(action.IsAsynchronous()).To(BeTrue())
		})

		// Current implementation kills agent
	})
}
