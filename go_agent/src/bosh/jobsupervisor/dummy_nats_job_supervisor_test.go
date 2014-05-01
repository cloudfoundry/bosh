package jobsupervisor_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	boshalert "bosh/agent/alert"
	boshhandler "bosh/handler"
	. "bosh/jobsupervisor"
	fakembus "bosh/mbus/fakes"
)

var _ = Describe("dummyNatsJobSupervisor", func() {
	var (
		dummyNats JobSupervisor
		handler   *fakembus.FakeHandler
	)

	BeforeEach(func() {
		handler = &fakembus.FakeHandler{}
		dummyNats = NewDummyNatsJobSupervisor(handler)
	})

	Describe("MonitorJobFailures", func() {
		It("monitors job status", func() {
			dummyNats.MonitorJobFailures(func(boshalert.MonitAlert) error { return nil })
			Expect(handler.RegisteredAdditionalHandlerFunc).ToNot(BeNil())
		})
	})

	Describe("Status", func() {
		BeforeEach(func() {
			dummyNats.MonitorJobFailures(func(boshalert.MonitAlert) error { return nil })
		})

		It("returns the received status", func() {
			statusMessage := boshhandler.NewRequest("", "set_dummy_status", []byte(`{"status":"failing"}`))
			handler.RegisteredAdditionalHandlerFunc(statusMessage)
			Expect(dummyNats.Status()).To(Equal("failing"))
		})

		It("returns running as a default value", func() {
			Expect(dummyNats.Status()).To(Equal("running"))
		})

		It("does not change the status given other messages", func() {
			statusMessage := boshhandler.NewRequest("", "some_other_message", []byte(`{"status":"failing"}`))
			handler.RegisteredAdditionalHandlerFunc(statusMessage)
			Expect(dummyNats.Status()).To(Equal("running"))
		})
	})
})
