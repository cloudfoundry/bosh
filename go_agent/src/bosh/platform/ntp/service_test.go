package ntp

import (
	boshdir "bosh/settings/directories"
	fakefs "bosh/system/fakes"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestGetOffsetReturnsValidOffset(t *testing.T) {
	NTPData := "server 10.16.45.209, stratum 2, offset -0.081236, delay 0.04291\n" +
		"12 Oct 17:37:58 ntpdate[42757]: adjust time server 10.16.45.209 offset -0.081236 sec"
	service := buildService(NTPData)

	expectedNTPOffset := NTPInfo{
		Timestamp: "12 Oct 17:37:58",
		Offset:    "-0.081236",
	}
	assert.Equal(t, service.GetInfo(), expectedNTPOffset)
}

func TestGetOffsetReturnsBadFileMessageWhenFileIsBad(t *testing.T) {
	NTPData := "sdfhjsdfjghsdf\n" +
		"dsfjhsdfhjsdfhjg\n" +
		"dsjkfsdfkjhsdfhjk"
	service := buildService(NTPData)

	expectedNTPOffset := NTPInfo{
		Message: "bad file contents",
	}
	assert.Equal(t, service.GetInfo(), expectedNTPOffset)
}

func TestGetOffsetReturnsBadNTPServerMessageWhenFileHasBadServer(t *testing.T) {
	NTPData := "13 Oct 18:00:05 ntpdate[1754]: no server suitable for synchronization found"
	service := buildService(NTPData)

	expectedNTPOffset := NTPInfo{
		Message: "bad ntp server",
	}
	assert.Equal(t, service.GetInfo(), expectedNTPOffset)
}

func TestGetOffsetReturnsNilWhenFileDoesNotExist(t *testing.T) {
	service := buildService("")

	expectedNTPOffset := NTPInfo{
		Message: "file missing",
	}
	assert.Equal(t, service.GetInfo(), expectedNTPOffset)
}

func buildService(NTPData string) (service Service) {
	fs := fakefs.NewFakeFileSystem()
	dirProvider := boshdir.NewDirectoriesProvider("/var/vcap")

	if NTPData != "" {
		fs.WriteToFile("/var/vcap/bosh/log/ntpdate.out", NTPData)
	}

	service = NewConcreteService(fs, dirProvider)
	return
}
