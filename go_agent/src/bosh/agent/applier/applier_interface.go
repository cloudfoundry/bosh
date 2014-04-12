package applier

import (
	as "bosh/agent/applier/applyspec"
)

type Applier interface {
	Prepare(desiredApplySpec as.ApplySpec) error
	Apply(currentApplySpec, desiredApplySpec as.ApplySpec) error
}
