package fakes

import boshntp "bosh/platform/ntp"

type FakeService struct {
	GetOffsetNTPOffset boshntp.NTPInfo
}

func (oc *FakeService) GetInfo() (ntpInfo boshntp.NTPInfo) {
	ntpInfo = oc.GetOffsetNTPOffset
	return
}
