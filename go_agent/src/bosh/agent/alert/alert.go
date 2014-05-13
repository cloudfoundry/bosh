package alert

type SeverityLevel int

const (
	SeverityAlert    SeverityLevel = 1
	SeverityCritical SeverityLevel = 2
	SeverityError    SeverityLevel = 3
	SeverityWarning  SeverityLevel = 4
	SeverityIgnored  SeverityLevel = -1
	SeverityDefault  SeverityLevel = SeverityCritical
)

type Alert struct {
	ID        string        `json:"id"`
	Severity  SeverityLevel `json:"severity"`
	Title     string        `json:"title"`
	Summary   string        `json:"summary"`
	CreatedAt int64         `json:"created_at"`
}

type MonitAlert struct {
	ID          string
	Service     string
	Event       string
	Action      string
	Date        string
	Description string
}
