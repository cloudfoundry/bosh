package net

import (
	gonet "net"

	bosherr "bosh/errors"
	boshsettings "bosh/settings"
)

type InterfaceToAddrsFunc func(interfaceName string) ([]gonet.Addr, error)

func DefaultInterfaceToAddrsFunc(interfaceName string) ([]gonet.Addr, error) {
	iface, err := gonet.InterfaceByName(interfaceName)
	if err != nil {
		return []gonet.Addr{}, bosherr.WrapError(err, "Searching interfaces %s", interfaceName)
	}

	return iface.Addrs()
}

type defaultNetworkResolver struct {
	routesSearcher   RoutesSearcher
	ifaceToAddrsFunc InterfaceToAddrsFunc
}

func NewDefaultNetworkResolver(
	routesSearcher RoutesSearcher,
	ifaceToAddrsFunc InterfaceToAddrsFunc,
) defaultNetworkResolver {
	return defaultNetworkResolver{
		routesSearcher:   routesSearcher,
		ifaceToAddrsFunc: ifaceToAddrsFunc,
	}
}

func (r defaultNetworkResolver) GetDefaultNetwork() (boshsettings.Network, error) {
	network := boshsettings.Network{}

	routes, err := r.routesSearcher.SearchRoutes()
	if err != nil {
		return network, bosherr.WrapError(err, "Searching routes")
	}

	if len(routes) == 0 {
		return network, bosherr.New("No routes")
	}

	for _, route := range routes {
		if !route.IsDefault() {
			continue
		}

		addrs, err := r.ifaceToAddrsFunc(route.InterfaceName)
		if err != nil {
			return network, bosherr.WrapError(err, "Looking addrs for interface %s", route.InterfaceName)
		}

		if len(addrs) == 0 {
			return network, bosherr.New("No addresses")
		}

		for _, addr := range addrs {
			ip, ok := addr.(*gonet.IPNet)
			if !ok {
				continue
			}

			if ip.IP.To4() == nil { // filter out ipv6
				continue
			}

			return boshsettings.Network{
				IP:      ip.IP.String(),
				Netmask: gonet.IP(ip.Mask).String(),
				Gateway: route.Gateway,
			}, nil
		}

		return network, bosherr.New("Failed to find IPv4 address")
	}

	return network, bosherr.New("Failed to find default route")
}
