package net

import (
	"strings"

	bosherr "bosh/errors"
	boshsys "bosh/system"
)

// cmdRoutesSearcher uses `route -n` command to list routes
// which routes in a same format on Ubuntu and CentOS
type cmdRoutesSearcher struct {
	runner boshsys.CmdRunner
}

func NewCmdRoutesSearcher(runner boshsys.CmdRunner) cmdRoutesSearcher {
	return cmdRoutesSearcher{runner}
}

func (s cmdRoutesSearcher) SearchRoutes() ([]Route, error) {
	var routes []Route

	stdout, _, _, err := s.runner.RunCommand("route", "-n")
	if err != nil {
		return routes, bosherr.WrapError(err, "Running route")
	}

	for i, routeEntry := range strings.Split(stdout, "\n") {
		if i < 2 { // first two lines are informational
			continue
		}

		if routeEntry == "" {
			continue
		}

		routeFields := strings.Fields(routeEntry)

		routes = append(routes, Route{
			Destination:   routeFields[0],
			Gateway:       routeFields[1],
			InterfaceName: routeFields[7],
		})
	}

	return routes, nil
}
