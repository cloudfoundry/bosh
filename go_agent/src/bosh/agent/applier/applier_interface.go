package applier

import as "bosh/agent/applier/applyspec"

type Applier interface {
	Apply(applySpec as.ApplySpec) error
}
