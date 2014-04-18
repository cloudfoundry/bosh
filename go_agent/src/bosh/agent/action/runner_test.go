package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/agent/action"
	fakeaction "bosh/agent/action/fakes"
)

type valueType struct {
	ID      int
	Success bool
}

type argsType struct {
	User     string `json:"user"`
	Password string `json:"pwd"`
	ID       int    `json:"id"`
}

type actionWithGoodRunMethod struct {
	Value valueType
	Err   error

	SubAction string
	SomeID    int
	ExtraArgs argsType
	SliceArgs []string
}

func (a *actionWithGoodRunMethod) IsAsynchronous() bool {
	return false
}

func (a *actionWithGoodRunMethod) IsPersistent() bool {
	return false
}

func (a *actionWithGoodRunMethod) Run(subAction string, someID int, extraArgs argsType, sliceArgs []string) (valueType, error) {
	a.SubAction = subAction
	a.SomeID = someID
	a.ExtraArgs = extraArgs
	a.SliceArgs = sliceArgs
	return a.Value, a.Err
}

func (a *actionWithGoodRunMethod) Resume() (interface{}, error) {
	return nil, nil
}

func (a *actionWithGoodRunMethod) Cancel() error {
	return nil
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

func (a *actionWithOptionalRunArgument) IsPersistent() bool {
	return false
}

func (a *actionWithOptionalRunArgument) Run(subAction string, optionalArgs ...argsType) (valueType, error) {
	a.SubAction = subAction
	a.OptionalArgs = optionalArgs
	return a.Value, a.Err
}

func (a *actionWithOptionalRunArgument) Resume() (interface{}, error) {
	return nil, nil
}

func (a *actionWithOptionalRunArgument) Cancel() error {
	return nil
}

type actionWithoutRunMethod struct{}

func (a *actionWithoutRunMethod) IsAsynchronous() bool {
	return false
}

func (a *actionWithoutRunMethod) IsPersistent() bool {
	return false
}

func (a *actionWithoutRunMethod) Resume() (interface{}, error) {
	return nil, nil
}

func (a *actionWithoutRunMethod) Cancel() error {
	return nil
}

type actionWithOneRunReturnValue struct{}

func (a *actionWithOneRunReturnValue) IsAsynchronous() bool {
	return false
}

func (a *actionWithOneRunReturnValue) IsPersistent() bool {
	return false
}

func (a *actionWithOneRunReturnValue) Run() error {
	return nil
}

func (a *actionWithOneRunReturnValue) Resume() (interface{}, error) {
	return nil, nil
}

func (a *actionWithOneRunReturnValue) Cancel() error {
	return nil
}

type actionWithSecondReturnValueNotError struct{}

func (a *actionWithSecondReturnValueNotError) IsAsynchronous() bool {
	return false
}

func (a *actionWithSecondReturnValueNotError) IsPersistent() bool {
	return false
}

func (a *actionWithSecondReturnValueNotError) Run() (interface{}, string) {
	return nil, ""
}

func (a *actionWithSecondReturnValueNotError) Resume() (interface{}, error) {
	return nil, nil
}

func (a *actionWithSecondReturnValueNotError) Cancel() error {
	return nil
}

func init() {
	Describe("concreteRunner", func() {
		It("runner run parses the payload", func() {
			runner := NewRunner()

			expectedValue := valueType{ID: 13, Success: true}
			expectedErr := errors.New("fake-run-error")

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
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(Equal("fake-run-error"))

			Expect(value).To(Equal(expectedValue))
			Expect(err).To(Equal(expectedErr))

			Expect(action.SubAction).To(Equal("setup"))
			Expect(action.SomeID).To(Equal(123))
			Expect(action.ExtraArgs).To(Equal(argsType{User: "rob", Password: "rob123", ID: 12}))
			Expect(action.SliceArgs).To(Equal([]string{"a", "b", "c"}))
		})

		It("runner run errs when actions not enough arguments", func() {
			runner := NewRunner()

			expectedValue := valueType{ID: 13, Success: true}

			action := &actionWithGoodRunMethod{Value: expectedValue}
			payload := `{"arguments":["setup"]}`

			_, err := runner.Run(action, []byte(payload))
			Expect(err).To(HaveOccurred())
		})

		It("runner run errs when action arguments types do not match", func() {
			runner := NewRunner()

			expectedValue := valueType{ID: 13, Success: true}

			action := &actionWithGoodRunMethod{Value: expectedValue}
			payload := `{"arguments":[123, "setup", {"user":"rob","pwd":"rob123","id":12}]}`

			_, err := runner.Run(action, []byte(payload))
			Expect(err).To(HaveOccurred())
		})

		It("runner handles optional arguments being passed in", func() {
			runner := NewRunner()

			expectedValue := valueType{ID: 13, Success: true}
			expectedErr := errors.New("fake-run-error")

			action := &actionWithOptionalRunArgument{Value: expectedValue, Err: expectedErr}
			payload := `{"arguments":["setup", {"user":"rob","pwd":"rob123","id":12}, {"user":"bob","pwd":"bob123","id":13}]}`

			value, err := runner.Run(action, []byte(payload))

			Expect(value).To(Equal(expectedValue))
			Expect(err).To(Equal(expectedErr))

			Expect(action.SubAction).To(Equal("setup"))
			assert.Equal(GinkgoT(), action.OptionalArgs, []argsType{
				{User: "rob", Password: "rob123", ID: 12},
				{User: "bob", Password: "bob123", ID: 13},
			})
		})

		It("runner handles optional arguments when not passed in", func() {
			runner := NewRunner()
			action := &actionWithOptionalRunArgument{}
			payload := `{"arguments":["setup"]}`

			runner.Run(action, []byte(payload))

			Expect(action.SubAction).To(Equal("setup"))
			Expect(action.OptionalArgs).To(Equal([]argsType{}))
		})

		It("runner run errs when action does not implement run", func() {
			runner := NewRunner()
			_, err := runner.Run(&actionWithoutRunMethod{}, []byte(`{"arguments":[]}`))
			Expect(err).To(HaveOccurred())
		})

		It("runner run errs when actions run does not return two values", func() {
			runner := NewRunner()
			_, err := runner.Run(&actionWithOneRunReturnValue{}, []byte(`{"arguments":[]}`))
			Expect(err).To(HaveOccurred())
		})

		It("runner run errs when actions run second return type is not error", func() {
			runner := NewRunner()
			_, err := runner.Run(&actionWithSecondReturnValueNotError{}, []byte(`{"arguments":[]}`))
			Expect(err).To(HaveOccurred())
		})

		Describe("Resume", func() {
			It("calls Resume() on action", func() {
				runner := NewRunner()
				testAction := &fakeaction.TestAction{
					ResumeErr:   errors.New("fake-action-error"),
					ResumeValue: "fake-action-resume-value",
				}

				value, err := runner.Resume(testAction, []byte{})
				Expect(value).To(Equal("fake-action-resume-value"))
				Expect(err.Error()).To(Equal("fake-action-error"))

				Expect(testAction.Resumed).To(BeTrue())
			})
		})
	})
}
