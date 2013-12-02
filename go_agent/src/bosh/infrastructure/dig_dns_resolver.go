package infrastructure

import (
	bosherr "bosh/errors"
	"bytes"
	"errors"
	"fmt"
	"net"
	"os/exec"
	"strings"
)

type digDnsResolver struct {
}

func (res digDnsResolver) LookupHost(dnsServers []string, host string) (ipString string, err error) {
	ip := net.ParseIP(host)
	if ip != nil {
		ipString = host
		return
	}

	for _, dnsServer := range dnsServers {
		ipString, err = lookupHostWithDnsServer(dnsServer, host)
		if err == nil {
			return
		}
	}

	return
}

func lookupHostWithDnsServer(dnsServer string, host string) (ipString string, err error) {
	stdout, _, err := runCommand(
		"dig",
		fmt.Sprintf("@%s", dnsServer),
		host,
		"+short",
		"+time=1",
	)

	if err != nil {
		err = bosherr.WrapError(err, "Shelling out to dig")
		return
	}

	ipString = strings.Split(stdout, "\n")[0]
	ip := net.ParseIP(ipString)
	if ip == nil {
		err = errors.New("Resolving host")
	}
	return
}

func runCommand(cmdName string, args ...string) (stdout, stderr string, err error) {
	cmd := exec.Command(cmdName, args...)

	stdoutWriter := bytes.NewBufferString("")
	stderrWriter := bytes.NewBufferString("")
	cmd.Stdout = stdoutWriter
	cmd.Stderr = stderrWriter

	err = cmd.Start()
	if err != nil {
		err = bosherr.WrapError(err, "Starting dig command")
		return
	}

	err = cmd.Wait()
	if err != nil {
		err = bosherr.WrapError(err, "Waiting for dig command")
		return
	}
	stdout = string(stdoutWriter.Bytes())
	stderr = string(stderrWriter.Bytes())
	return
}
