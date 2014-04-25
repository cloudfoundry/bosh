package disk

type MountSearchCallBack func(string, string) (bool, error)

type MountsSearcher interface {
	SearchMounts(mountFieldsFunc MountSearchCallBack) (found bool, err error)
}
