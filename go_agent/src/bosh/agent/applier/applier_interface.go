package applier

import (
	boshas "bosh/agent/applier/applyspec"
)

type Applier interface {
	Prepare(desiredApplySpec boshas.ApplySpec) error
	Apply(currentApplySpec, desiredApplySpec boshas.ApplySpec) error
}
