package main

import (
	"os"

	boshapp "bosh/app"
	boshlog "bosh/logger"
)

const mainLogTag = "main"

func main() {
	logger := boshlog.NewLogger(boshlog.LevelDebug)
	defer logger.HandlePanic("Main")

	logger.Debug(mainLogTag, "Starting agent")

	app := boshapp.New(logger)

	err := app.Setup(os.Args)
	if err != nil {
		logger.Error(mainLogTag, "App setup %s", err.Error())
		os.Exit(1)
	}

	err = app.Run()
	if err != nil {
		logger.Error(mainLogTag, "App run %s", err.Error())
		os.Exit(1)
	}
}
