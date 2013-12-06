package action

import (
	boshblob "bosh/blobstore"
	bosherr "bosh/errors"
	boshdisk "bosh/platform/disk"
	boshsettings "bosh/settings"
	"encoding/json"
	"errors"
	"path/filepath"
)

type logsAction struct {
	compressor boshdisk.Compressor
	blobstore  boshblob.Blobstore
}

func newLogs(compressor boshdisk.Compressor, blobstore boshblob.Blobstore) (action logsAction) {
	action.compressor = compressor
	action.blobstore = blobstore
	return
}

func (action logsAction) Run(payloadBytes []byte) (value interface{}, err error) {
	filters, err := extractFilters(payloadBytes)
	if err != nil {
		err = bosherr.WrapError(err, "Extracting filters from payload")
		return
	}

	if len(filters) == 0 {
		filters = []string{"**/*"}
	}

	logsDir := filepath.Join(boshsettings.VCAP_BASE_DIR, "bosh", "log")
	tarball, err := action.compressor.CompressFilesInDir(logsDir, filters)
	if err != nil {
		err = bosherr.WrapError(err, "Making logs tarball")
		return
	}

	blobId, err := action.blobstore.Create(tarball)
	if err != nil {
		err = bosherr.WrapError(err, "Create file on blobstore")
		return
	}

	value = map[string]string{"blobstore_id": blobId}
	return
}

func extractFilters(payloadBytes []byte) (filters []string, err error) {
	type payloadType struct {
		Arguments []interface{}
	}
	payload := payloadType{}
	err = json.Unmarshal(payloadBytes, &payload)
	if err != nil {
		err = bosherr.WrapError(err, "Unmarshalling payload")
		return
	}

	if len(payload.Arguments) < 2 {
		err = errors.New("Not enough arguments in payload")
		return
	}

	filterArgs, ok := payload.Arguments[1].([]interface{})
	parseError := errors.New("Error parsing arguments when processing logs")

	if !ok {
		err = parseError
		return
	}

	for _, filterArg := range filterArgs {
		filter, ok := filterArg.(string)
		if !ok {
			err = parseError
			return
		}

		filters = append(filters, filter)
	}

	return
}
