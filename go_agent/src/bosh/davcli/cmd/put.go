package cmd

import (
	"errors"
	"os"

	davclient "bosh/davcli/client"
)

type PutCmd struct {
	client davclient.Client
}

func newPutCmd(client davclient.Client) (cmd PutCmd) {
	cmd.client = client
	return
}

func (cmd PutCmd) Run(args []string) error {
	if len(args) != 2 {
		return errors.New("Incorrect usage, put needs local file and remote blob destination")
	}

	file, err := os.Open(args[0])
	if err != nil {
		return err
	}

	return cmd.client.Put(args[1], file)
}
