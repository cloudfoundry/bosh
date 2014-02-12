package ntp_test

import (
	. "bosh/platform/ntp"
	boshdir "bosh/settings/directories"
	fakefs "bosh/system/fakes"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func buildService(NTPData string) (service Service) {
	fs := fakefs.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

	if NTPData != "" {
		fs.WriteToFile("/var/vcap/bosh/log/ntpdate.out", NTPData)
	}

	service = NewConcreteService(fs, dirProvider)
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("get offset returns valid offset", func() {
			NTPData := `server 10.16.45.209, stratum 2, offset -0.081236, delay 0.04291
12 Oct 17:37:58 ntpdate[42757]: adjust time server 10.16.45.209 offset -0.081236 sec
`
			service := buildService(NTPData)

			expectedNTPOffset := NTPInfo{
				Timestamp: "12 Oct 17:37:58",
				Offset:    "-0.081236",
			}
			assert.Equal(GinkgoT(), service.GetInfo(), expectedNTPOffset)
		})
		It("get offset returns bad file message when file is bad", func() {

			NTPData := "sdfhjsdfjghsdf\n" +
				"dsfjhsdfhjsdfhjg\n" +
				"dsjkfsdfkjhsdfhjk\n"
			service := buildService(NTPData)

			expectedNTPOffset := NTPInfo{
				Message: "bad file contents",
			}
			assert.Equal(GinkgoT(), service.GetInfo(), expectedNTPOffset)
		})
		It("get offset returns bad n t p server message when file has bad server", func() {

			NTPData := "13 Oct 18:00:05 ntpdate[1754]: no server suitable for synchronization found\n"
			service := buildService(NTPData)

			expectedNTPOffset := NTPInfo{
				Message: "bad ntp server",
			}
			assert.Equal(GinkgoT(), service.GetInfo(), expectedNTPOffset)
		})
		It("get offset returns nil when file does not exist", func() {

			service := buildService("")

			expectedNTPOffset := NTPInfo{
				Message: "file missing",
			}
			assert.Equal(GinkgoT(), service.GetInfo(), expectedNTPOffset)
		})
	})
}
