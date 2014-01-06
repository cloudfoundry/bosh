package ntp

import (
	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
	"path/filepath"
	"regexp"
	"strings"
)

type NTPInfo struct {
	Offset    string `json:"offset,omitempty"`
	Timestamp string `json:"timestamp,omitempty"`
	Message   string `json:"message,omitempty"`
}

type Service interface {
	GetInfo() (ntpInfo NTPInfo)
}

type concreteService struct {
	fs          boshsys.FileSystem
	dirProvider boshdir.DirectoriesProvider
}

func NewConcreteService(fs boshsys.FileSystem, dirProvider boshdir.DirectoriesProvider) concreteService {
	return concreteService{
		fs:          fs,
		dirProvider: dirProvider,
	}
}

func (oc concreteService) GetInfo() (ntpInfo NTPInfo) {
	ntpPath := filepath.Join(oc.dirProvider.BaseDir(), "/bosh/log/ntpdate.out")
	content, err := oc.fs.ReadFile(ntpPath)
	if err != nil {
		ntpInfo = NTPInfo{Message: "file missing"}
		return
	}

	lines := strings.Split(content, "\n")
	lastLine := lines[len(lines)-1]

	regex, _ := regexp.Compile(`^(.+)\s+ntpdate.+offset\s+(-*\d+\.\d+)`)
	badServerRegex, _ := regexp.Compile(`no server suitable for synchronization found`)
	matches := regex.FindAllStringSubmatch(lastLine, -1)

	if len(matches) > 0 && len(matches[0]) == 3 {
		ntpInfo = NTPInfo{
			Timestamp: matches[0][1],
			Offset:    matches[0][2],
		}
	} else if badServerRegex.MatchString(lastLine) {
		ntpInfo = NTPInfo{Message: "bad ntp server"}
	} else {
		ntpInfo = NTPInfo{Message: "bad file contents"}
	}

	return
}
