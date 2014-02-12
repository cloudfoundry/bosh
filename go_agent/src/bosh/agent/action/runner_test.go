package action_test

import (
	. "bosh/agent/action"
	"errors"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
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

type actionWithoutRunMethod struct {
}

func (a *actionWithoutRunMethod) IsAsynchronous() bool {
	return false
}

type actionWithOneRunReturnValue struct {
}

func (a *actionWithOneRunReturnValue) IsAsynchronous() bool {
	return false
}

func (a *actionWithOneRunReturnValue) Run() (err error) {
	return
}

type actionWithSecondReturnValueNotError struct {
}

func (a *actionWithSecondReturnValueNotError) IsAsynchronous() bool {
	return false
}

func (a *actionWithSecondReturnValueNotError) Run() (value interface{}, otherValue string) {
	return
}
func init() {
	Describe("Testing with Ginkgo", func() {
		It("runner run parses the payload", func() {
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
			assert.Error(GinkgoT(), err)
			assert.Equal(GinkgoT(), err.Error(), "Oops")

			assert.Equal(GinkgoT(), value, expectedValue)
			assert.Equal(GinkgoT(), err, expectedErr)

			assert.Equal(GinkgoT(), action.SubAction, "setup")
			assert.Equal(GinkgoT(), action.SomeId, 123)
			assert.Equal(GinkgoT(), action.ExtraArgs, argsType{User: "rob", Password: "rob123", Id: 12})
			assert.Equal(GinkgoT(), action.SliceArgs, []string{"a", "b", "c"})
		})
		It("runner run errs when actions not enough arguments", func() {

			runner := NewRunner()

			expectedValue := valueType{Id: 13, Success: true}

			action := &actionWithGoodRunMethod{Value: expectedValue}
			payload := `{"arguments":["setup"]}`

			_, err := runner.Run(action, []byte(payload))
			assert.Error(GinkgoT(), err)
		})
		It("runner run errs when action arguments types do not match", func() {

			runner := NewRunner()

			expectedValue := valueType{Id: 13, Success: true}

			action := &actionWithGoodRunMethod{Value: expectedValue}
			payload := `{"arguments":[123, "setup", {"user":"rob","pwd":"rob123","id":12}]}`

			_, err := runner.Run(action, []byte(payload))
			assert.Error(GinkgoT(), err)
		})
		It("runner handles optional arguments being passed in", func() {

			runner := NewRunner()

			expectedValue := valueType{Id: 13, Success: true}
			expectedErr := errors.New("Oops")

			action := &actionWithOptionalRunArgument{Value: expectedValue, Err: expectedErr}
			payload := `{"arguments":["setup", {"user":"rob","pwd":"rob123","id":12}, {"user":"bob","pwd":"bob123","id":13}]}`

			value, err := runner.Run(action, []byte(payload))

			assert.Equal(GinkgoT(), value, expectedValue)
			assert.Equal(GinkgoT(), err, expectedErr)

			assert.Equal(GinkgoT(), action.SubAction, "setup")
			assert.Equal(GinkgoT(), action.OptionalArgs, []argsType{
				{User: "rob", Password: "rob123", Id: 12},
				{User: "bob", Password: "bob123", Id: 13},
			})
		})
		It("runner handles optional arguments when not passed in", func() {

			runner := NewRunner()
			action := &actionWithOptionalRunArgument{}
			payload := `{"arguments":["setup"]}`

			runner.Run(action, []byte(payload))

			assert.Equal(GinkgoT(), action.SubAction, "setup")
			assert.Equal(GinkgoT(), action.OptionalArgs, []argsType{})
		})
		It("runner run errs when action does not implement run", func() {

			runner := NewRunner()
			_, err := runner.Run(&actionWithoutRunMethod{}, []byte(`{"arguments":[]}`))
			assert.Error(GinkgoT(), err)
		})
		It("runner run errs when actions run does not return two values", func() {

			runner := NewRunner()
			_, err := runner.Run(&actionWithOneRunReturnValue{}, []byte(`{"arguments":[]}`))
			assert.Error(GinkgoT(), err)
		})
		It("runner run errs when actions run second return type is not error", func() {

			runner := NewRunner()
			_, err := runner.Run(&actionWithSecondReturnValueNotError{}, []byte(`{"arguments":[]}`))
			assert.Error(GinkgoT(), err)
		})
	})
}
