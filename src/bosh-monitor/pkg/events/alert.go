package events

import (
	"encoding/json"
	"fmt"
	"time"
)

const (
	CategoryVMHealth         = "vm_health"
	CategoryDeploymentHealth = "deployment_health"
)

var SeverityMap = map[int]string{
	1:  "alert",
	2:  "critical",
	3:  "error",
	4:  "warning",
	-1: "ignored",
}

type Alert struct {
	AlertID    string
	Severity   int
	Category   string
	Title      string
	Summary    string
	Source     string
	Deployment string
	CreatedAt  time.Time
	Attrs      map[string]interface{}
}

func NewAlert(attributes map[string]interface{}) *Alert {
	a := &Alert{Attrs: attributes}

	if v, ok := attributes["id"]; ok {
		a.AlertID = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["severity"]; ok {
		switch sv := v.(type) {
		case int:
			a.Severity = sv
		case float64:
			a.Severity = int(sv)
		}
	}
	if v, ok := attributes["category"]; ok {
		a.Category = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["title"]; ok {
		a.Title = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["summary"]; ok {
		a.Summary = fmt.Sprintf("%v", v)
	} else {
		a.Summary = a.Title
	}
	if v, ok := attributes["source"]; ok {
		a.Source = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["deployment"]; ok {
		a.Deployment = fmt.Sprintf("%v", v)
	}
	if v, ok := attributes["created_at"]; ok {
		switch cv := v.(type) {
		case int:
			a.CreatedAt = time.Unix(int64(cv), 0)
		case int64:
			a.CreatedAt = time.Unix(cv, 0)
		case float64:
			a.CreatedAt = time.Unix(int64(cv), 0)
		case time.Time:
			a.CreatedAt = cv
		}
	}

	return a
}

func (a *Alert) ID() string { return a.AlertID }
func (a *Alert) Kind() string { return "alert" }

func (a *Alert) Validate() []string {
	var errs []string
	if a.AlertID == "" {
		errs = append(errs, "id is missing")
	}
	if _, hasSev := a.Attrs["severity"]; !hasSev {
		errs = append(errs, "severity is missing")
	} else if a.Severity < 0 {
		errs = append(errs, "severity is invalid (non-negative integer expected)")
	}
	if a.Title == "" {
		errs = append(errs, "title is missing")
	}
	if a.CreatedAt.IsZero() {
		errs = append(errs, "timestamp is missing")
	}
	return errs
}

func (a *Alert) Valid() bool {
	return len(a.Validate()) == 0
}

func (a *Alert) SeverityName() string {
	if name, ok := SeverityMap[a.Severity]; ok {
		return name
	}
	return fmt.Sprintf("%d", a.Severity)
}

func (a *Alert) ShortDescription() string {
	return fmt.Sprintf("Severity %d: %s %s", a.Severity, a.Source, a.Title)
}

func (a *Alert) ToHash() map[string]interface{} {
	return map[string]interface{}{
		"kind":       "alert",
		"id":         a.AlertID,
		"severity":   a.Severity,
		"category":   a.Category,
		"title":      a.Title,
		"summary":    a.Summary,
		"source":     a.Source,
		"deployment": a.Deployment,
		"created_at": a.CreatedAt.Unix(),
	}
}

func (a *Alert) ToJSON() (string, error) {
	data, err := json.Marshal(a.ToHash())
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func (a *Alert) ToPlainText() string {
	result := ""
	if a.Source != "" {
		result += a.Source + "\n"
	}
	if a.Title != "" {
		result += a.Title + "\n"
	} else {
		result += "Unknown Alert\n"
	}
	result += fmt.Sprintf("Severity: %d\n", a.Severity)
	if a.Summary != "" {
		result += fmt.Sprintf("Summary: %s\n", a.Summary)
	}
	result += fmt.Sprintf("Time: %s\n", a.CreatedAt.UTC().Format(time.RFC1123Z))
	return result
}

func (a *Alert) Metrics() []Metric {
	return nil
}

func (a *Alert) Attributes() map[string]interface{} {
	return a.Attrs
}

func (a *Alert) String() string {
	return fmt.Sprintf("Alert @ %s, severity %d: %s", a.CreatedAt.UTC().Format(time.RFC1123Z), a.Severity, a.Summary)
}
