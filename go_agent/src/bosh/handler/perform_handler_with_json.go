package handler

import (
	"encoding/json"

	bosherr "bosh/errors"
	boshlog "bosh/logger"
)

const (
	mbusHandlerLogTag       = "MBus Handler"
	responseMaxLengthErrMsg = "Response exceeded maximum allowed length"
	UnlimitedResponseLength = -1
)

func PerformHandlerWithJSON(rawJSON []byte, handler HandlerFunc, maxResponseLength int, logger boshlog.Logger) ([]byte, Request, error) {
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

	respJSON, err := marshalResponse(response, maxResponseLength, logger)
	if err != nil {
		return respJSON, request, err
	}

	logger.Info(mbusHandlerLogTag, "Responding")
	logger.DebugWithDetails(mbusHandlerLogTag, "Payload", respJSON)

	return respJSON, request, nil
}

func BuildErrorWithJSON(msg string, logger boshlog.Logger) ([]byte, error) {
	response := NewExceptionResponse(bosherr.New(msg))

	respJSON, err := json.Marshal(response)
	if err != nil {
		return respJSON, bosherr.WrapError(err, "Marshalling JSON")
	}

	logger.Info(mbusHandlerLogTag, "Building error", msg)

	return respJSON, nil
}

func marshalResponse(response Response, maxResponseLength int, logger boshlog.Logger) ([]byte, error) {
	respJSON, err := json.Marshal(response)
	if err != nil {
		logger.Error(mbusHandlerLogTag, "Failed to marshal response: %s", err.Error())
		return respJSON, bosherr.WrapError(err, "Marshalling JSON response")
	}

	if maxResponseLength == UnlimitedResponseLength {
		return respJSON, nil
	}

	if len(respJSON) > maxResponseLength {
		respJSON, err = json.Marshal(response.Shorten())
		if err != nil {
			logger.Error(mbusHandlerLogTag, "Failed to marshal response: %s", err.Error())
			return respJSON, bosherr.WrapError(err, "Marshalling JSON response")
		}
	}

	if len(respJSON) > maxResponseLength {
		respJSON, err = BuildErrorWithJSON(responseMaxLengthErrMsg, logger)
		if err != nil {
			logger.Error(mbusHandlerLogTag, "Failed to build 'max length exceeded' response: %s", err.Error())
			return respJSON, bosherr.WrapError(err, "Building error")
		}
	}

	return respJSON, nil
}
