package main

import (
	boshapp "bosh/app"
	boshlog "bosh/logger"
	"os"
)

func main() {
	defer boshlog.HandlePanic("Main")

	app := boshapp.New()
	err := app.Run(os.Args)

	if err != nil {
		boshlog.Error("Main", err.Error())
		os.Exit(1)
	}
}
