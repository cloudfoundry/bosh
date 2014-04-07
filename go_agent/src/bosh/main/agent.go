package main

import (
	boshapp "bosh/app"
	boshlog "bosh/logger"
	"os"
)

func main() {
	logger := boshlog.NewLogger(boshlog.LevelDebug)
	defer logger.HandlePanic("Main")
	logger.Debug("main", "Starting agent")

	app := boshapp.New(logger)
	app.Setup(os.Args)
	err := app.Run()

	if err != nil {
		logger.Error("Main", err.Error())
		os.Exit(1)
	}
}
