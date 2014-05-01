package alert

type Builder interface {
	Build(input MonitAlert) (alert Alert, err error)
}

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
