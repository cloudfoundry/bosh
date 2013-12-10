package action

import (
	"errors"
	"github.com/stretchr/testify/assert"
	"testing"
)

type valueType struct {
	Id      int
	Success bool
}

type argsType struct {
	User     string `json:"user"`
	Password string `json:"pwd"`
	Id       int    `json:"id"`
}

type actionWithGoodRunMethod struct {
	Value valueType
	Err   error

	SubAction string
	SomeId    int
	ExtraArgs argsType
	SliceArgs []string
}

func (a *actionWithGoodRunMethod) IsAsynchronous() bool {
	return false
}

func (a *actionWithGoodRunMethod) Run(payloadBytes []byte) (value interface{}, err error) {
	return
}

func (a *actionWithGoodRunMethod) RunWithoutPayload(subAction string, someId int, extraArgs argsType, sliceArgs []string) (value valueType, err error) {
	a.SubAction = subAction
	a.SomeId = someId
	a.ExtraArgs = extraArgs
	a.SliceArgs = sliceArgs

	value = a.Value
	err = a.Err
	return
}

func TestRunnerRunParsesThePayload(t *testing.T) {
	runner := NewRunner()

	expectedValue := valueType{Id: 13, Success: true}
	expectedErr := errors.New("Oops")

	action := &actionWithGoodRunMethod{Value: expectedValue, Err: expectedErr}
	payload := `{
		"arguments":[
			"setup",
			 123,
			 {"user":"rob","pwd":"rob123","id":12},
			 ["a","b","c"],
			 456
		]
	}`

	value, err := runner.Run(action, []byte(payload))
	assert.Error(t, err)
	assert.Equal(t, err.Error(), "Oops")

	assert.Equal(t, value, expectedValue)
	assert.Equal(t, err, expectedErr)

	assert.Equal(t, action.SubAction, "setup")
	assert.Equal(t, action.SomeId, 123)
	assert.Equal(t, action.ExtraArgs, argsType{User: "rob", Password: "rob123", Id: 12})
	assert.Equal(t, action.SliceArgs, []string{"a", "b", "c"})
}

func TestRunnerRunErrsWhenActionsNotEnoughArguments(t *testing.T) {
	runner := NewRunner()

	expectedValue := valueType{Id: 13, Success: true}

	action := &actionWithGoodRunMethod{Value: expectedValue}
	payload := `{"arguments":["setup"]}`

	_, err := runner.Run(action, []byte(payload))
	assert.Error(t, err)
}

func TestRunnerRunErrsWhenActionArgumentsTypesDoNotMatch(t *testing.T) {
	runner := NewRunner()

	expectedValue := valueType{Id: 13, Success: true}

	action := &actionWithGoodRunMethod{Value: expectedValue}
	payload := `{"arguments":[123, "setup", {"user":"rob","pwd":"rob123","id":12}]}`

	_, err := runner.Run(action, []byte(payload))
	assert.Error(t, err)
}

type actionWithoutRunMethod struct {
}

func (a *actionWithoutRunMethod) IsAsynchronous() bool {
	return false
}

func (a *actionWithoutRunMethod) Run(payloadBytes []byte) (value interface{}, err error) {
	return
}

func TestRunnerRunErrsWhenActionDoesNotImplementRun(t *testing.T) {
	runner := NewRunner()
	_, err := runner.Run(&actionWithoutRunMethod{}, []byte(`{"arguments":[]}`))
	assert.Error(t, err)
}

type actionWithOneRunReturnValue struct {
}

func (a *actionWithOneRunReturnValue) IsAsynchronous() bool {
	return false
}

func (a *actionWithOneRunReturnValue) Run(payloadBytes []byte) (value interface{}, err error) {
	return
}

func (a *actionWithOneRunReturnValue) RunWithoutPayload() (err error) {
	return
}

func TestRunnerRunErrsWhenActionsRunDoesNotReturnTwoValues(t *testing.T) {
	runner := NewRunner()
	_, err := runner.Run(&actionWithOneRunReturnValue{}, []byte(`{"arguments":[]}`))
	assert.Error(t, err)
}

type actionWithSecondReturnValueNotError struct {
}

func (a *actionWithSecondReturnValueNotError) IsAsynchronous() bool {
	return false
}

func (a *actionWithSecondReturnValueNotError) Run(payloadBytes []byte) (value interface{}, err error) {
	return
}

func (a *actionWithSecondReturnValueNotError) RunWithoutPayload() (value interface{}, otherValue string) {
	return
}

func TestRunnerRunErrsWhenActionsRunSecondReturnTypeIsNotError(t *testing.T) {
	runner := NewRunner()
	_, err := runner.Run(&actionWithSecondReturnValueNotError{}, []byte(`{"arguments":[]}`))
	assert.Error(t, err)
}
