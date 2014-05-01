package action

import (
	"encoding/json"
	"reflect"

	bosherr "bosh/errors"
)

type Runner interface {
	Run(action Action, payload []byte) (value interface{}, err error)
	Resume(action Action, payload []byte) (value interface{}, err error)
}

func NewRunner() Runner {
	return concreteRunner{}
}

type concreteRunner struct{}

func (r concreteRunner) Run(action Action, payloadBytes []byte) (value interface{}, err error) {
	payloadArgs, err := r.extractJSONArguments(payloadBytes)
	if err != nil {
		err = bosherr.WrapError(err, "Extracting json arguments")
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

	methodArgs, err := r.extractMethodArgs(runMethodType, payloadArgs)
	if err != nil {
		err = bosherr.WrapError(err, "Extracting method arguments from payload")
		return
	}

	values := runMethodValue.Call(methodArgs)
	return r.extractReturns(values)
}

func (r concreteRunner) Resume(action Action, payloadBytes []byte) (value interface{}, err error) {
	return action.Resume()
}

func (r concreteRunner) extractJSONArguments(payloadBytes []byte) (args []interface{}, err error) {
	type payloadType struct {
		Arguments []interface{} `json:"arguments"`
	}
	payload := payloadType{}

	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling payload arguments to interface{} types")
	}
	args = payload.Arguments
	return
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

func (r concreteRunner) extractMethodArgs(runMethodType reflect.Type, args []interface{}) (methodArgs []reflect.Value, err error) {
	numberOfArgs := runMethodType.NumIn()
	numberOfReqArgs := numberOfArgs

	if runMethodType.IsVariadic() {
		numberOfReqArgs--
	}

	if len(args) < numberOfReqArgs {
		err = bosherr.New("Not enough arguments, expected %d, got %d", numberOfReqArgs, len(args))
		return
	}

	for i, argFromPayload := range args {
		var rawArgBytes []byte
		rawArgBytes, err = json.Marshal(argFromPayload)
		if err != nil {
			err = bosherr.WrapError(err, "Marshalling action argument")
			return
		}

		argType, typeFound := r.getMethodArgType(runMethodType, i)
		if !typeFound {
			continue
		}

		argValuePtr := reflect.New(argType)

		err = json.Unmarshal(rawArgBytes, argValuePtr.Interface())
		if err != nil {
			err = bosherr.WrapError(err, "Unmarshalling action argument")
			return
		}

		methodArgs = append(methodArgs, reflect.Indirect(argValuePtr))
	}

	return
}

func (r concreteRunner) getMethodArgType(methodType reflect.Type, index int) (argType reflect.Type, found bool) {
	numberOfArgs := methodType.NumIn()

	switch {
	case !methodType.IsVariadic() && index >= numberOfArgs:
		return nil, false

	case methodType.IsVariadic() && index >= numberOfArgs-1:
		sliceType := methodType.In(numberOfArgs - 1)
		return sliceType.Elem(), true

	default:
		return methodType.In(index), true
	}
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
