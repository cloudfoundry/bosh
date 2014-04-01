package fakes

type FakeNotifier struct {
	NotifiedShutdown  bool
	NotifyShutdownErr error
}

func NewFakeNotifier() *FakeNotifier {
	return &FakeNotifier{}
}

func (n *FakeNotifier) NotifyShutdown() error {
	n.NotifiedShutdown = true
	return n.NotifyShutdownErr
}
