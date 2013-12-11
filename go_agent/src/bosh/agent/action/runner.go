package action

import (
	bosherr "bosh/errors"
	"encoding/json"
	"reflect"
)

type Runner interface {
	Run(action Action, payload []byte) (value interface{}, err error)
}

func NewRunner() Runner {
	return concreteRunner{}
}

type concreteRunner struct {
}

func (r concreteRunner) Run(action Action, payloadBytes []byte) (value interface{}, err error) {
	type payloadType struct {
		Arguments []interface{} `json:"arguments"`
	}
	payload := payloadType{}

	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling payload arguments to interface{} types")
		return
	}

	actionValue := reflect.ValueOf(action)
	runMethodValue := actionValue.MethodByName("Run")

	if runMethodValue.Kind() != reflect.Func {
		err = bosherr.New("Run method not found")
		return
	}

	runMethodType := runMethodValue.Type()
	if r.invalidReturnTypes(runMethodType) {
		err = bosherr.New("Run method should return a value and an error")
		return
	}

	methodArgs, err := r.extractMethodArgs(runMethodType, payload.Arguments)
	if err != nil {
		err = bosherr.WrapError(err, "Extracting method arguments from payload")
		return
	}

	values := runMethodValue.Call(methodArgs)
	return r.extractReturns(values)
}

func (r concreteRunner) invalidReturnTypes(methodType reflect.Type) (valid bool) {
	if methodType.NumOut() != 2 {
		return true
	}

	secondReturnType := methodType.Out(1)
	if secondReturnType.Kind() != reflect.Interface {
		return true
	}

	errorType := reflect.TypeOf(bosherr.New(""))
	secondReturnIsError := errorType.Implements(secondReturnType)
	if !secondReturnIsError {
		return true
	}

	return
}

func (r concreteRunner) extractMethodArgs(runMethodType reflect.Type, arguments []interface{}) (methodArgs []reflect.Value, err error) {
	numberOfArgs := runMethodType.NumIn()

	if len(arguments) < numberOfArgs {
		err = bosherr.New("Not enough arguments, expected %d, got %d", numberOfArgs, len(arguments))
		return
	}

	methodArgs = make([]reflect.Value, numberOfArgs)

	for i, argFromPayload := range arguments[:numberOfArgs] {
		var rawArgBytes []byte
		rawArgBytes, err = json.Marshal(argFromPayload)
		if err != nil {
			err = bosherr.WrapError(err, "Marshalling action argument")
			return
		}

		argValuePtr := reflect.New(runMethodType.In(i))
		err = json.Unmarshal(rawArgBytes, argValuePtr.Interface())
		if err != nil {
			err = bosherr.WrapError(err, "Unmarshalling action argument")
			return
		}

		methodArgs[i] = reflect.Indirect(argValuePtr)
	}

	return
}

func (r concreteRunner) extractReturns(values []reflect.Value) (value interface{}, err error) {
	errValue := values[1]
	if !errValue.IsNil() {
		errorValues := errValue.MethodByName("Error").Call([]reflect.Value{})
		err = bosherr.New(errorValues[0].String())
	}

	value = values[0].Interface()
	return
}
