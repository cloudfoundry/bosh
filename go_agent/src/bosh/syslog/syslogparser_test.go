package syslog_test

import (
	"fmt"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/jeromer/syslogparser/rfc3164"
)

var _ = Describe("syslogparser", func() {
	It("parses an example message", func() {
		text := []byte("<34>Oct 11 22:14:15 mach su: 'su root' failed for lonvick on /dev/pts/8")

		parser := rfc3164.NewParser(text)
		err := parser.Parse()
		Expect(err).ToNot(HaveOccurred())

		parts := parser.Dump() // syslogparser.LogParts
		Expect(fmt.Sprintf("%T", parts["timestamp"])).To(Equal("time.Time"))
		Expect(parts["hostname"]).To(Equal("mach"))
		Expect(parts["tag"]).To(Equal("su"))
		Expect(parts["content"]).To(Equal("'su root' failed for lonvick on /dev/pts/8"))
		Expect(parts["priority"]).To(Equal(34))
		Expect(parts["facility"]).To(Equal(4))
		Expect(parts["severity"]).To(Equal(2))
	})
})
