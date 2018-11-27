package system

import (
	"fmt"
	"net"
	"strconv"
	"strings"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

func CalculateNetworkAndBroadcast(ipAddress, netmask string) (network, broadcast string, err error) {
	ip := net.ParseIP(ipAddress)
	if ip == nil {
		return "", "", fmt.Errorf("Invalid IP '%s'", ipAddress)
	}

	if ip.To4() != nil {
		return calculateV4NetworkAndBroadcast(ipAddress, netmask)
	}

	return "", "", nil
}

func calculateV4NetworkAndBroadcast(ipAddress, netmask string) (network, broadcast string, err error) {
	ipComponents := strings.Split(ipAddress, ".")
	maskComponents := strings.Split(netmask, ".")

	if len(ipComponents) != 4 || len(maskComponents) != 4 {
		return "", "", fmt.Errorf("Invalid netmask '%s'", netmask)
	}

	networkComponents := []string{}
	broadcastComponents := []string{}

	for i := 0; i < 4; i++ {
		var ipComponent int
		var maskComponent int

		ipComponent, err = strconv.Atoi(ipComponents[i])
		if err != nil {
			return "", "", bosherr.WrapError(err, "Parsing number from ip address")
		}

		maskComponent, err = strconv.Atoi(maskComponents[i])
		if err != nil {
			return "", "", bosherr.WrapError(err, "Parsing number from netmask")
		}

		networkComponent := strconv.Itoa(ipComponent & maskComponent)
		broadcastComponent := strconv.Itoa((ipComponent | (^maskComponent)) & 255)

		networkComponents = append(networkComponents, networkComponent)
		broadcastComponents = append(broadcastComponents, broadcastComponent)
	}

	network = strings.Join(networkComponents, ".")
	broadcast = strings.Join(broadcastComponents, ".")

	return network, broadcast, nil
}
