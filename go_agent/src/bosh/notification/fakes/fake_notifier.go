package fakes

type FakeNotifier struct {
	NotifiedShutdown  bool
	NotifyShutdownErr error
}

func NewFakeNotifier() *FakeNotifier {
	return &FakeNotifier{}
}

func (n *FakeNotifier) NotifyShutdown() (err error) {
	n.NotifiedShutdown = true
	err = n.NotifyShutdownErr
	return
}
