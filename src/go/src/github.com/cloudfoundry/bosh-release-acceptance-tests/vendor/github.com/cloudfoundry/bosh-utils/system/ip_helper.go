package system

import (
	"errors"
	bosherr "github.com/cloudfoundry/bosh-utils/errors"
	"strconv"
	"strings"
)

func CalculateNetworkAndBroadcast(ipAddress, netmask string) (network, broadcast string, err error) {
	ipComponents := strings.Split(ipAddress, ".")
	maskComponents := strings.Split(netmask, ".")

	if len(ipComponents) != 4 || len(maskComponents) != 4 {
		err = errors.New("Invalid ip or netmask")
		return
	}

	networkComponents := []string{}
	broadcastComponents := []string{}

	for i := 0; i < 4; i++ {
		var ipComponent int
		var maskComponent int

		ipComponent, err = strconv.Atoi(ipComponents[i])
		if err != nil {
			err = bosherr.WrapError(err, "Parsing number from ip address")
			return
		}

		maskComponent, err = strconv.Atoi(maskComponents[i])
		if err != nil {
			err = bosherr.WrapError(err, "Parsing number from netmask")
			return
		}

		networkComponent := strconv.Itoa(ipComponent & maskComponent)
		broadcastComponent := strconv.Itoa((ipComponent | (^maskComponent)) & 255)

		networkComponents = append(networkComponents, networkComponent)
		broadcastComponents = append(broadcastComponents, broadcastComponent)
	}

	network = strings.Join(networkComponents, ".")
	broadcast = strings.Join(broadcastComponents, ".")

	return
}
