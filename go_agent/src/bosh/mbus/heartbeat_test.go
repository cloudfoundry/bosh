package mbus

import (
	boshvitals "bosh/platform/vitals"
	"encoding/json"
	"github.com/stretchr/testify/assert"
	"testing"
)

func TestHeartbeatJsonRepresentation(t *testing.T) {
	hb := Heartbeat{
		Job:      "foo",
		Index:    0,
		JobState: "running",
		Vitals: boshvitals.Vitals{
			Disk: boshvitals.DiskVitals{
				"system":     boshvitals.SpecificDiskVitals{},
				"ephemeral":  boshvitals.SpecificDiskVitals{},
				"persistent": boshvitals.SpecificDiskVitals{},
			},
		},
	}

	expectedJson := `{"job":"foo","index":0,"job_state":"running","vitals":{"cpu":{},"disk":{"ephemeral":{},"persistent":{},"system":{}},"mem":{},"swap":{}}}`

	hbBytes, err := json.Marshal(hb)
	assert.NoError(t, err)
	assert.Equal(t, string(hbBytes), expectedJson)
}
