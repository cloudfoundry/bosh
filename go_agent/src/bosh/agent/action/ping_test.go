package action_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
)

func init() {
	Describe("Ping", func() {
		It("is synchronous", func() {
			action := NewPing()
			Expect(action.IsAsynchronous()).To(BeFalse())
		})

		It("is not persistent", func() {
			action := NewPing()
			Expect(action.IsPersistent()).To(BeFalse())
		})

		It("ping run returns pong", func() {
			action := NewPing()
			pong, err := action.Run()
			Expect(err).ToNot(HaveOccurred())
			Expect(pong).To(Equal("pong"))
		})
	})
}
