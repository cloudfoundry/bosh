package alert

import (
	boshlog "bosh/logger"
	boshsettings "bosh/settings"
	"fmt"
	"sort"
	"strings"
	"time"
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
	alert.Id = input.Id
	alert.Severity = b.getSeverity(input)
	alert.Title = b.getTitle(input)
	alert.Summary = input.Description
	alert.CreatedAt = b.getCreatedAt(input)
	return
}

func (b concreteBuilder) getSeverity(input MonitAlert) (severity SeverityLevel) {
	severity, severityFound := eventToSeverity[input.Event]
	if !severityFound {
		b.logger.Error("Agent", "Unknown monit event name `%s', using default severity %d", input.Event, SEVERITY_DEFAULT)
		severity = SEVERITY_DEFAULT
	}
	return
}

func (b concreteBuilder) getTitle(input MonitAlert) (title string) {
	service := input.Service
	ips := b.settingsService.GetIps()
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
	SEVERITY_ALERT    SeverityLevel = 1
	SEVERITY_CRITICAL               = 2
	SEVERITY_ERROR                  = 3
	SEVERITY_WARNING                = 4
	SEVERITY_IGNORED                = -1
	SEVERITY_DEFAULT                = SEVERITY_CRITICAL
)

var eventToSeverity = map[string]SeverityLevel{
	"action done":                  SEVERITY_IGNORED,
	"checksum failed":              SEVERITY_CRITICAL,
	"checksum changed":             SEVERITY_WARNING,
	"checksum succeeded":           SEVERITY_IGNORED,
	"checksum not changed":         SEVERITY_IGNORED,
	"connection failed":            SEVERITY_ALERT,
	"connection succeeded":         SEVERITY_IGNORED,
	"connection changed":           SEVERITY_ERROR,
	"connection not changed":       SEVERITY_IGNORED,
	"content failed":               SEVERITY_ERROR,
	"content succeeded":            SEVERITY_IGNORED,
	"content match":                SEVERITY_IGNORED,
	"content doesn't match":        SEVERITY_ERROR,
	"data access error":            SEVERITY_ERROR,
	"data access succeeded":        SEVERITY_IGNORED,
	"data access changed":          SEVERITY_WARNING,
	"data access not changed":      SEVERITY_IGNORED,
	"execution failed":             SEVERITY_ALERT,
	"execution succeeded":          SEVERITY_IGNORED,
	"execution changed":            SEVERITY_WARNING,
	"execution not changed":        SEVERITY_IGNORED,
	"filesystem flags failed":      SEVERITY_ERROR,
	"filesystem flags succeeded":   SEVERITY_IGNORED,
	"filesystem flags changed":     SEVERITY_WARNING,
	"filesystem flags not changed": SEVERITY_IGNORED,
	"gid failed":                   SEVERITY_ERROR,
	"gid succeeded":                SEVERITY_IGNORED,
	"gid changed":                  SEVERITY_WARNING,
	"gid not changed":              SEVERITY_IGNORED,
	"heartbeat failed":             SEVERITY_ERROR,
	"heartbeat succeeded":          SEVERITY_IGNORED,
	"heartbeat changed":            SEVERITY_WARNING,
	"heartbeat not changed":        SEVERITY_IGNORED,
	"icmp failed":                  SEVERITY_CRITICAL,
	"icmp succeeded":               SEVERITY_IGNORED,
	"icmp changed":                 SEVERITY_WARNING,
	"icmp not changed":             SEVERITY_IGNORED,
	"monit instance failed":        SEVERITY_ALERT,
	"monit instance succeeded":     SEVERITY_IGNORED,
	"monit instance changed":       SEVERITY_IGNORED,
	"monit instance not changed":   SEVERITY_IGNORED,
	"invalid type":                 SEVERITY_ERROR,
	"type succeeded":               SEVERITY_IGNORED,
	"type changed":                 SEVERITY_WARNING,
	"type not changed":             SEVERITY_IGNORED,
	"does not exist":               SEVERITY_ALERT,
	"exists":                       SEVERITY_IGNORED,
	"existence changed":            SEVERITY_WARNING,
	"existence not changed":        SEVERITY_IGNORED,
	"permission failed":            SEVERITY_ERROR,
	"permission succeeded":         SEVERITY_IGNORED,
	"permission changed":           SEVERITY_WARNING,
	"permission not changed":       SEVERITY_IGNORED,
	"pid failed":                   SEVERITY_CRITICAL,
	"pid succeeded":                SEVERITY_IGNORED,
	"pid changed":                  SEVERITY_WARNING,
	"pid not changed":              SEVERITY_IGNORED,
	"ppid failed":                  SEVERITY_CRITICAL,
	"ppid succeeded":               SEVERITY_IGNORED,
	"ppid changed":                 SEVERITY_WARNING,
	"ppid not changed":             SEVERITY_IGNORED,
	"resource limit matched":       SEVERITY_ERROR,
	"resource limit succeeded":     SEVERITY_IGNORED,
	"resource limit changed":       SEVERITY_WARNING,
	"resource limit not changed":   SEVERITY_IGNORED,
	"size failed":                  SEVERITY_ERROR,
	"size succeeded":               SEVERITY_IGNORED,
	"size changed":                 SEVERITY_ERROR,
	"size not changed":             SEVERITY_IGNORED,
	"timeout":                      SEVERITY_CRITICAL,
	"timeout recovery":             SEVERITY_IGNORED,
	"timeout changed":              SEVERITY_WARNING,
	"timeout not changed":          SEVERITY_IGNORED,
	"timestamp failed":             SEVERITY_ERROR,
	"timestamp succeeded":          SEVERITY_IGNORED,
	"timestamp changed":            SEVERITY_WARNING,
	"timestamp not changed":        SEVERITY_IGNORED,
	"uid failed":                   SEVERITY_CRITICAL,
	"uid succeeded":                SEVERITY_IGNORED,
	"uid changed":                  SEVERITY_WARNING,
	"uid not changed":              SEVERITY_IGNORED,
}
