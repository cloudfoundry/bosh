package handler

import (
	"encoding/json"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

func PerformHandlerWithJSON(rawJSON []byte, handler HandlerFunc, logger boshlog.Logger) ([]byte, Request, error) {
	var request Request

	err := json.Unmarshal(rawJSON, &request)
	if err != nil {
		return []byte{}, request, bosherr.WrapError(err, "Unmarshalling JSON payload")
	}

	request.Payload = rawJSON

	logger.Info("MBus Handler", "Received request with action %s", request.Method)
	logger.DebugWithDetails("MBus Handler", "Payload", request.Payload)

	response := handler(request)
	if response == nil {
		return []byte{}, request, nil
	}

	respJSON, err := json.Marshal(response)
	if err != nil {
		return respJSON, request, bosherr.WrapError(err, "Marshalling JSON response")
	}

	logger.Info("MBus Handler", "Responding")
	logger.DebugWithDetails("MBus Handler", "Payload", respJSON)

	return respJSON, request, nil
}
