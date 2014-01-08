package jobsupervisor

import (
	boshalert "bosh/agent/alert"
	"github.com/pivotal/go-smtpd/smtpd"
	"regexp"
	"strings"
)

type alertEnvelope struct {
	*smtpd.BasicEnvelope
	handler JobFailureHandler
	alert   *boshalert.MonitAlert
}

func (e *alertEnvelope) Write(lineBytes []byte) (err error) {
	line := strings.TrimSpace(string(lineBytes))

	idRegexp, err := regexp.Compile("^Message-id: <([^>]+)>$")
	if err != nil {
		return
	}

	idMatches := idRegexp.FindStringSubmatch(line)

	switch {
	case len(idMatches) == 2:
		e.alert.Id = idMatches[1]
	case strings.HasPrefix(line, "Service: "):
		e.alert.Service = strings.Replace(line, "Service: ", "", 1)
	case strings.HasPrefix(line, "Event: "):
		e.alert.Event = strings.Replace(line, "Event: ", "", 1)
	case strings.HasPrefix(line, "Action: "):
		e.alert.Action = strings.Replace(line, "Action: ", "", 1)
	case strings.HasPrefix(line, "Date: "):
		e.alert.Date = strings.Replace(line, "Date: ", "", 1)
	case strings.HasPrefix(line, "Description: "):
		e.alert.Description = strings.Replace(line, "Description: ", "", 1)
	}

	return nil
}

func (e *alertEnvelope) Close() error {
	alertToHandle := *e.alert
	emptyAlert := boshalert.MonitAlert{}

	if alertToHandle != emptyAlert {
		e.handler(*e.alert)
	}

	return nil
}
