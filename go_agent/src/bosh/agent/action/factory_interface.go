package action

type Factory interface {
	Create(method string) (action Action)
}
