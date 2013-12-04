package infrastructure

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	"bytes"
	"errors"
	"fmt"
	"net"
	"os/exec"
	"strings"
)

type digDnsResolver struct {
	logger boshlog.Logger
}

func (res digDnsResolver) LookupHost(dnsServers []string, host string) (ipString string, err error) {
	ip := net.ParseIP(host)
	if ip != nil {
		ipString = host
		return
	}

	for _, dnsServer := range dnsServers {
		ipString, err = res.lookupHostWithDnsServer(dnsServer, host)
		if err == nil {
			return
		}
	}

	return
}

func (res digDnsResolver) lookupHostWithDnsServer(dnsServer string, host string) (ipString string, err error) {
	stdout, _, err := res.runCommand(
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

func (res digDnsResolver) runCommand(cmdName string, args ...string) (stdout, stderr string, err error) {
	res.logger.Debug("Dig Dns Resolver", "Running command: %s %s", cmdName, strings.Join(args, " "))
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
	stdout = string(stdoutWriter.Bytes())
	stderr = string(stderrWriter.Bytes())

	res.logger.Debug("Cmd Runner", "Stdout: %s", stdout)
	res.logger.Debug("Cmd Runner", "Stderr: %s", stderr)
	res.logger.Debug("Cmd Runner", "Successful: %t", err == nil)

	if err != nil {
		err = bosherr.WrapError(err, "Waiting for dig command")
	}
	return
}
