package mbus_test

import (
	. "bosh/mbus"
	boshvitals "bosh/platform/vitals"
	"encoding/json"
	. "github.com/onsi/ginkgo"
	"github.com/stretchr/testify/assert"
)

func init() {
	Describe("Testing with Ginkgo", func() {
		It("heartbeat json representation", func() {

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
			assert.NoError(GinkgoT(), err)
			assert.Equal(GinkgoT(), string(hbBytes), expectedJson)
		})
	})
}
