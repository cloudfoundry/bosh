package net

type Route struct {
	Destination   string
	Gateway       string
	InterfaceName string
}

type RoutesSearcher interface {
	SearchRoutes() ([]Route, error)
}

func (r Route) IsDefault() bool {
	return r.Destination == "0.0.0.0"
}
