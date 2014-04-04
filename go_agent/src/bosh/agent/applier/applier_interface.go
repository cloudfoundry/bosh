package applier

import (
	as "bosh/agent/applier/applyspec"
)

type Applier interface {
	Apply(currentApplySpec, desiredApplySpec as.ApplySpec) error
}
