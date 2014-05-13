package time

import (
	"time"
)

type concreteService struct{}

func NewConcreteService() concreteService {
	return concreteService{}
}

func (s concreteService) Now() time.Time {
	return time.Now()
}
