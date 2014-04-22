package handler

import (
	"encoding/json"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

const mbusHandlerLogTag = "MBus Handler"

func PerformHandlerWithJSON(rawJSON []byte, handler HandlerFunc, logger boshlog.Logger) ([]byte, Request, error) {
	var request Request

	err := json.Unmarshal(rawJSON, &request)
	if err != nil {
		return []byte{}, request, bosherr.WrapError(err, "Unmarshalling JSON payload")
	}

	request.Payload = rawJSON

	logger.Info(mbusHandlerLogTag, "Received request with action %s", request.Method)
	logger.DebugWithDetails(mbusHandlerLogTag, "Payload", request.Payload)

	response := handler(request)
	if response == nil {
		logger.Info(mbusHandlerLogTag, "Nil response returned from handler")
		return []byte{}, request, nil
	}

	respJSON, err := json.Marshal(response)
	if err != nil {
		logger.Info(mbusHandlerLogTag, "Marshal response error")
		return respJSON, request, bosherr.WrapError(err, "Marshalling JSON response")
	}

	logger.Info(mbusHandlerLogTag, "Responding")
	logger.DebugWithDetails(mbusHandlerLogTag, "Payload", respJSON)

	return respJSON, request, nil
}

func BuildErrorWithJSON(msg string, logger boshlog.Logger) ([]byte, error) {
	response := NewExceptionResponse(msg)

	respJSON, err := json.Marshal(response)
	if err != nil {
		return respJSON, bosherr.WrapError(err, "Marshalling JSON")
	}

	logger.Info(mbusHandlerLogTag, "Building error", msg)

	return respJSON, nil
}
