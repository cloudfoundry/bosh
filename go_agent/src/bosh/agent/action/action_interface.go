package action

type Action interface {
	IsAsynchronous() bool
	IsPersistent() bool

	// Action should implement Run
	// Arguments should be the list of arguments the payload will include
	// and necessary for running the action
	//
	// It should return:
	//	* a value, used as the response value. It will be converted to JSON
	//	* an error, used to return an error response instead
	//
	// Run(...) (interface{}, error)
	//
	// See Runner for more details

	Resume() (interface{}, error)
	Cancel() error
}
