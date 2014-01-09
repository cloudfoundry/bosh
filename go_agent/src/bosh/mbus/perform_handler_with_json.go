package mbus

import (
	bosherr "bosh/errors"
	boshlog "bosh/logger"
	"encoding/json"
)

func performHandlerWithJSON(rawJSON []byte, handler HandlerFunc, logger boshlog.Logger) (moreJSON []byte, request Request, err error) {
	err = json.Unmarshal(rawJSON, &request)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling JSON payload")
		return
	}
	request.payload = rawJSON

	logger.Info("MBus Handler", "Received request with action %s", request.Method)
	logger.DebugWithDetails("MBus Handler", "Payload", request.payload)

	response := handler(request)
	moreJSON, err = json.Marshal(response)
	if err != nil {
		err = bosherr.WrapError(err, "Marshalling JSON response")
		return
	}

	logger.Info("MBus Handler", "Responding")
	logger.DebugWithDetails("MBus Handler", "Payload", moreJSON)

	return
}
