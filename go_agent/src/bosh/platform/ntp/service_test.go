package ntp_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/platform/ntp"
	boshdir "bosh/settings/directories"
	fakefs "bosh/system/fakes"
)

var _ = Describe("concreteService", func() {
	Describe("GetInfo", func() {
		buildService := func(NTPData string) Service {
			fs := fakefs.NewFakeFileSystem()
			dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

			if NTPData != "" {
				err := fs.WriteFileString("/var/vcap/bosh/log/ntpdate.out", NTPData)
				Expect(err).ToNot(HaveOccurred())
			}

			return NewConcreteService(fs, dirProvider)
		}

		It("returns valid offset", func() {
			NTPData := `server 10.16.45.209, stratum 2, offset -0.081236, delay 0.04291
12 Oct 17:37:58 ntpdate[42757]: adjust time server 10.16.45.209 offset -0.081236 sec
`
			service := buildService(NTPData)

			expectedNTPOffset := NTPInfo{
				Timestamp: "12 Oct 17:37:58",
				Offset:    "-0.081236",
			}
			Expect(service.GetInfo()).To(Equal(expectedNTPOffset))
		})

		It("returns bad file message when file is bad", func() {
			NTPData := "sdfhjsdfjghsdf\n" +
				"dsfjhsdfhjsdfhjg\n" +
				"dsjkfsdfkjhsdfhjk\n"
			service := buildService(NTPData)

			expectedNTPOffset := NTPInfo{
				Message: "bad file contents",
			}
			Expect(service.GetInfo()).To(Equal(expectedNTPOffset))
		})

		It("returns bad ntp server message when file has bad server", func() {
			NTPData := "13 Oct 18:00:05 ntpdate[1754]: no server suitable for synchronization found\n"
			service := buildService(NTPData)

			expectedNTPOffset := NTPInfo{
				Message: "bad ntp server",
			}
			Expect(service.GetInfo()).To(Equal(expectedNTPOffset))
		})

		It("returns nil when file does not exist", func() {
			service := buildService("")

			expectedNTPOffset := NTPInfo{
				Message: "file missing",
			}
			Expect(service.GetInfo()).To(Equal(expectedNTPOffset))
		})
	})
})
