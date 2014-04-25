package disk

type cmdMountsSearcher struct{}

func NewCmdMountsSearcher() cmdMountsSearcher {
	return cmdMountsSearcher{}
}

func (s cmdMountsSearcher) SearchMounts(mountFieldsFunc MountSearchCallBack) (bool, error) {
	return false, nil
}
