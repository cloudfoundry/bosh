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

		It("is persistent because director expects configure_networks task to become done after agent is restarted", func() {
			Expect(action.IsPersistent()).To(BeTrue())
		})

		// Current implementation restarts agent process
	})
}
