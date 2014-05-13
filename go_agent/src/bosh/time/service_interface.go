package time

import (
	"time"
)

type Service interface {
	Now() time.Time
}
