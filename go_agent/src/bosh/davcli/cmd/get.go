package cmd

import (
	davclient "bosh/davcli/client"
	"errors"
	"io"
	"os"
)

type GetCmd struct {
	client davclient.Client
}

func newGetCmd(client davclient.Client) (cmd GetCmd) {
	cmd.client = client
	return
}

func (cmd GetCmd) Run(args []string) (err error) {
	if len(args) != 2 {
		err = errors.New("Incorrect usage, get needs remote blob path and local file destination")
		return
	}

	readCloser, err := cmd.client.Get(args[0])
	if err != nil {
		return
	}
	defer readCloser.Close()

	targetFile, err := os.Create(args[1])
	if err != nil {
		return
	}

	_, err = io.Copy(targetFile, readCloser)
	return
}
