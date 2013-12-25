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

func (a *actionWithGoodRunMethod) Run(subAction string, someId int, extraArgs argsType, sliceArgs []string) (value valueType, err error) {
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

type actionWithOptionalRunArgument struct {
	SubAction    string
	OptionalArgs []argsType

	Value valueType
	Err   error
}

func (a *actionWithOptionalRunArgument) IsAsynchronous() bool {
	return false
}

func (a *actionWithOptionalRunArgument) Run(subAction string, optionalArgs ...argsType) (value valueType, err error) {
	a.SubAction = subAction
	a.OptionalArgs = optionalArgs

	value = a.Value
	err = a.Err
	return
}

func TestRunnerHandlesOptionalArgumentsBeingPassedIn(t *testing.T) {
	runner := NewRunner()

	expectedValue := valueType{Id: 13, Success: true}
	expectedErr := errors.New("Oops")

	action := &actionWithOptionalRunArgument{Value: expectedValue, Err: expectedErr}
	payload := `{"arguments":["setup", {"user":"rob","pwd":"rob123","id":12}, {"user":"bob","pwd":"bob123","id":13}]}`

	value, err := runner.Run(action, []byte(payload))

	assert.Equal(t, value, expectedValue)
	assert.Equal(t, err, expectedErr)

	assert.Equal(t, action.SubAction, "setup")
	assert.Equal(t, action.OptionalArgs, []argsType{
		{User: "rob", Password: "rob123", Id: 12},
		{User: "bob", Password: "bob123", Id: 13},
	})
}

func TestRunnerHandlesOptionalArgumentsWhenNotPassedIn(t *testing.T) {
	runner := NewRunner()
	action := &actionWithOptionalRunArgument{}
	payload := `{"arguments":["setup"]}`

	runner.Run(action, []byte(payload))

	assert.Equal(t, action.SubAction, "setup")
	assert.Equal(t, action.OptionalArgs, []argsType{})
}

type actionWithoutRunMethod struct {
}

func (a *actionWithoutRunMethod) IsAsynchronous() bool {
	return false
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

func (a *actionWithOneRunReturnValue) Run() (err error) {
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

func (a *actionWithSecondReturnValueNotError) Run() (value interface{}, otherValue string) {
	return
}

func TestRunnerRunErrsWhenActionsRunSecondReturnTypeIsNotError(t *testing.T) {
	runner := NewRunner()
	_, err := runner.Run(&actionWithSecondReturnValueNotError{}, []byte(`{"arguments":[]}`))
	assert.Error(t, err)
}
