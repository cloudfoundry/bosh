package alert

import (
	"fmt"
	"sort"
	"strings"
	"time"

	boshlog "bosh/logger"
	boshsettings "bosh/settings"
)

type concreteBuilder struct {
	settingsService boshsettings.Service
	logger          boshlog.Logger
}

func NewBuilder(settingsService boshsettings.Service, logger boshlog.Logger) Builder {
	return concreteBuilder{
		settingsService: settingsService,
		logger:          logger,
	}
}

func (b concreteBuilder) Build(input MonitAlert) (alert Alert, err error) {
	alert.ID = input.ID
	alert.Severity = b.getSeverity(input)
	alert.Title = b.getTitle(input)
	alert.Summary = input.Description
	alert.CreatedAt = b.getCreatedAt(input)
	return
}

func (b concreteBuilder) getSeverity(input MonitAlert) (severity SeverityLevel) {
	severity, severityFound := eventToSeverity[strings.ToLower(input.Event)]
	if !severityFound {
		b.logger.Error("Agent", "Unknown monit event name `%s', using default severity %d", input.Event, SeverityDefault)
		severity = SeverityDefault
	}
	return
}

func (b concreteBuilder) getTitle(input MonitAlert) (title string) {
	service := input.Service
	ips := b.settingsService.GetIPs()
	sort.Strings(ips)

	if len(ips) > 0 {
		service = fmt.Sprintf("%s (%s)", service, strings.Join(ips, ", "))
	}

	title = fmt.Sprintf("%s - %s - %s", service, input.Event, input.Action)
	return
}

func (b concreteBuilder) getCreatedAt(input MonitAlert) (timestamp int64) {
	createdAt, timeParseErr := time.Parse(time.RFC1123Z, input.Date)
	if timeParseErr != nil {
		createdAt = time.Now()
	}

	return createdAt.Unix()
}

type SeverityLevel int

const (
	SeverityAlert    SeverityLevel = 1
	SeverityCritical SeverityLevel = 2
	SeverityError    SeverityLevel = 3
	SeverityWarning  SeverityLevel = 4
	SeverityIgnored  SeverityLevel = -1
	SeverityDefault  SeverityLevel = SeverityCritical
)

var eventToSeverity = map[string]SeverityLevel{
	"action done":                  SeverityIgnored,
	"checksum failed":              SeverityCritical,
	"checksum changed":             SeverityWarning,
	"checksum succeeded":           SeverityIgnored,
	"checksum not changed":         SeverityIgnored,
	"connection failed":            SeverityAlert,
	"connection succeeded":         SeverityIgnored,
	"connection changed":           SeverityError,
	"connection not changed":       SeverityIgnored,
	"content failed":               SeverityError,
	"content succeeded":            SeverityIgnored,
	"content match":                SeverityIgnored,
	"content doesn't match":        SeverityError,
	"data access error":            SeverityError,
	"data access succeeded":        SeverityIgnored,
	"data access changed":          SeverityWarning,
	"data access not changed":      SeverityIgnored,
	"execution failed":             SeverityAlert,
	"execution succeeded":          SeverityIgnored,
	"execution changed":            SeverityWarning,
	"execution not changed":        SeverityIgnored,
	"filesystem flags failed":      SeverityError,
	"filesystem flags succeeded":   SeverityIgnored,
	"filesystem flags changed":     SeverityWarning,
	"filesystem flags not changed": SeverityIgnored,
	"gid failed":                   SeverityError,
	"gid succeeded":                SeverityIgnored,
	"gid changed":                  SeverityWarning,
	"gid not changed":              SeverityIgnored,
	"heartbeat failed":             SeverityError,
	"heartbeat succeeded":          SeverityIgnored,
	"heartbeat changed":            SeverityWarning,
	"heartbeat not changed":        SeverityIgnored,
	"icmp failed":                  SeverityCritical,
	"icmp succeeded":               SeverityIgnored,
	"icmp changed":                 SeverityWarning,
	"icmp not changed":             SeverityIgnored,
	"monit instance failed":        SeverityAlert,
	"monit instance succeeded":     SeverityIgnored,
	"monit instance changed":       SeverityIgnored,
	"monit instance not changed":   SeverityIgnored,
	"invalid type":                 SeverityError,
	"type succeeded":               SeverityIgnored,
	"type changed":                 SeverityWarning,
	"type not changed":             SeverityIgnored,
	"does not exist":               SeverityAlert,
	"exists":                       SeverityIgnored,
	"existence changed":            SeverityWarning,
	"existence not changed":        SeverityIgnored,
	"permission failed":            SeverityError,
	"permission succeeded":         SeverityIgnored,
	"permission changed":           SeverityWarning,
	"permission not changed":       SeverityIgnored,
	"pid failed":                   SeverityCritical,
	"pid succeeded":                SeverityIgnored,
	"pid changed":                  SeverityWarning,
	"pid not changed":              SeverityIgnored,
	"ppid failed":                  SeverityCritical,
	"ppid succeeded":               SeverityIgnored,
	"ppid changed":                 SeverityWarning,
	"ppid not changed":             SeverityIgnored,
	"resource limit matched":       SeverityError,
	"resource limit succeeded":     SeverityIgnored,
	"resource limit changed":       SeverityWarning,
	"resource limit not changed":   SeverityIgnored,
	"size failed":                  SeverityError,
	"size succeeded":               SeverityIgnored,
	"size changed":                 SeverityError,
	"size not changed":             SeverityIgnored,
	"timeout":                      SeverityCritical,
	"timeout recovery":             SeverityIgnored,
	"timeout changed":              SeverityWarning,
	"timeout not changed":          SeverityIgnored,
	"timestamp failed":             SeverityError,
	"timestamp succeeded":          SeverityIgnored,
	"timestamp changed":            SeverityWarning,
	"timestamp not changed":        SeverityIgnored,
	"uid failed":                   SeverityCritical,
	"uid succeeded":                SeverityIgnored,
	"uid changed":                  SeverityWarning,
	"uid not changed":              SeverityIgnored,
}
