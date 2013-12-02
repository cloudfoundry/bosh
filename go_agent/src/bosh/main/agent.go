package main

import (
	boshapp "bosh/app"
	"fmt"
	"os"
)

func main() {
	app := boshapp.New()
	err := app.Run(os.Args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %s\n", err.Error())
		os.Exit(1)
	}
}
