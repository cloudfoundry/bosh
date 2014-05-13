package fakes

import (
	"time"
)

type FakeService struct {
	NowTime time.Time
}

func (f *FakeService) Now() time.Time {
	return f.NowTime
}
