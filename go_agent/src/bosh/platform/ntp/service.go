package ntp

import (
	"path/filepath"
	"regexp"
	"strings"

	boshdir "bosh/settings/directories"
	boshsys "bosh/system"
)

var (
	offsetRegex    = regexp.MustCompile(`^(.+)\s+ntpdate.+offset\s+(-*\d+\.\d+)`)
	badServerRegex = regexp.MustCompile(`no server suitable for synchronization found`)
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

func (oc concreteService) GetInfo() NTPInfo {
	ntpPath := filepath.Join(oc.dirProvider.BaseDir(), "/bosh/log/ntpdate.out")
	content, err := oc.fs.ReadFileString(ntpPath)
	if err != nil {
		return NTPInfo{Message: "file missing"}
	}

	lines := strings.Split(strings.Trim(content, "\n"), "\n")
	lastLine := lines[len(lines)-1]

	matches := offsetRegex.FindAllStringSubmatch(lastLine, -1)

	if len(matches) > 0 && len(matches[0]) == 3 {
		return NTPInfo{
			Timestamp: matches[0][1],
			Offset:    matches[0][2],
		}
	} else if badServerRegex.MatchString(lastLine) {
		return NTPInfo{Message: "bad ntp server"}
	} else {
		return NTPInfo{Message: "bad file contents"}
	}
}
