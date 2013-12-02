package apply_spec

import (
	bosherr "bosh/errors"
	"encoding/json"
)

type ApplySpec struct {
	properties `json:"properties"`
}

type properties struct {
	logging `json:"logging"`
}

type logging struct {
	MaxLogFileSize string `json:"max_log_file_size"`
}

// Currently uses json.Unmarshal to interpret data into structs.
// Will be replaced with generic unmarshaler that operates on maps.
func NewApplySpecFromData(data interface{}) (as *ApplySpec, err error) {
	marshaledData, err := json.Marshal(data)
	if err != nil {
		err = bosherr.WrapError(err, "Failed to interpret apply spec")
		return
	}

	err = json.Unmarshal(marshaledData, &as)
	if err != nil {
		err = bosherr.WrapError(err, "Failed to interpret apply spec")
		return
	}

	return
}

func (as *ApplySpec) MaxLogFileSize() string {
	fileSize := as.properties.logging.MaxLogFileSize
	if len(fileSize) > 0 {
		return fileSize
	}
	return "50M"
}
