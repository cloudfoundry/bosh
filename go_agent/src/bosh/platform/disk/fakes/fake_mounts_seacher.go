package fakes

import (
	boshdisk "bosh/platform/disk"
)

type FakeMountsSearcher struct {
	SearchMountsMounts []boshdisk.Mount
	SearchMountsErr    error
}

func (s *FakeMountsSearcher) SearchMounts() ([]boshdisk.Mount, error) {
	return s.SearchMountsMounts, s.SearchMountsErr
}
