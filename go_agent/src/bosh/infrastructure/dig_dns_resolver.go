package infrastructure

import (
	"bytes"
	"errors"
	"fmt"
	"net"
	"os/exec"
	"strings"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

const digDNSResolverLogTag = "Dig DNS Resolver"

type DigDNSResolver struct {
	logger boshlog.Logger
}

func NewDigDNSResolver(logger boshlog.Logger) DigDNSResolver {
	return DigDNSResolver{logger: logger}
}

func (res DigDNSResolver) LookupHost(dnsServers []string, host string) (string, error) {
	ip := net.ParseIP(host)
	if ip != nil {
		return host, nil
	}

	var err error
	var ipString string

	if len(dnsServers) == 0 {
		err = errors.New("No DNS servers provided")
	}

	for _, dnsServer := range dnsServers {
		ipString, err = res.lookupHostWithDNSServer(dnsServer, host)
		if err == nil {
			return ipString, nil
		}
	}

	return "", err
}

func (res DigDNSResolver) lookupHostWithDNSServer(dnsServer string, host string) (ipString string, err error) {
	stdout, _, err := res.runCommand(
		"dig",
		fmt.Sprintf("@%s", dnsServer),
		host,
		"+short",
		"+time=1",
	)
	if err != nil {
		return "", bosherr.WrapError(err, "Shelling out to dig")
	}

	ipString = strings.Split(stdout, "\n")[0]
	ip := net.ParseIP(ipString)
	if ip == nil {
		return "", errors.New("Resolving host")
	}

	return ipString, nil
}

func (res DigDNSResolver) runCommand(cmdName string, args ...string) (string, string, error) {
	res.logger.Debug(digDNSResolverLogTag, "Running command: %s %s", cmdName, strings.Join(args, " "))
	cmd := exec.Command(cmdName, args...)

	stdoutWriter := bytes.NewBufferString("")
	stderrWriter := bytes.NewBufferString("")
	cmd.Stdout = stdoutWriter
	cmd.Stderr = stderrWriter

	err := cmd.Start()
	if err != nil {
		return "", "", bosherr.WrapError(err, "Starting dig command")
	}

	err = cmd.Wait()

	stdout := string(stdoutWriter.Bytes())
	res.logger.Debug(digDNSResolverLogTag, "Stdout: %s", stdout)

	stderr := string(stderrWriter.Bytes())
	res.logger.Debug(digDNSResolverLogTag, "Stderr: %s", stderr)

	res.logger.Debug(digDNSResolverLogTag, "Successful: %t", err == nil)

	if err != nil {
		return "", "", bosherr.WrapError(err, "Waiting for dig command")
	}

	return stdout, stderr, nil
}
