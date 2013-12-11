package action

type Action interface {
	IsAsynchronous() bool

	// See Runner for run method signature details
	// Run(...) (value interface{}, err error)
}
