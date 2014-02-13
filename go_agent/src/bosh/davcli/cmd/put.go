package cmd

import (
	davclient "bosh/davcli/client"
	"errors"
	"os"
)

type PutCmd struct {
	client davclient.Client
}

func newPutCmd(client davclient.Client) (cmd PutCmd) {
	cmd.client = client
	return
}

func (cmd PutCmd) Run(args []string) (err error) {
	if len(args) != 2 {
		err = errors.New("Incorrect usage, put needs local file and remote blob destination")
		return
	}

	file, err := os.Open(args[0])
	if err != nil {
		return
	}

	cmd.client.Put(args[1], file)
	return
}
