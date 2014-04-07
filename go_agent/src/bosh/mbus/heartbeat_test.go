package mbus_test

import (
	"encoding/json"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/mbus"
	boshvitals "bosh/platform/vitals"
)

func init() {
	Describe("Heartbeat", func() {
		Context("when all information is available to the heartbeat", func() {
			It("serializes heartbeat with all fields", func() {
				name := "foo"
				index := 0

				hb := Heartbeat{
					Job:      &name,
					Index:    &index,
					JobState: "running",
					Vitals: boshvitals.Vitals{
						Disk: boshvitals.DiskVitals{
							"system":     boshvitals.SpecificDiskVitals{},
							"ephemeral":  boshvitals.SpecificDiskVitals{},
							"persistent": boshvitals.SpecificDiskVitals{},
						},
					},
				}

				expectedJSON := `{"job":"foo","index":0,"job_state":"running","vitals":{"cpu":{},"disk":{"ephemeral":{},"persistent":{},"system":{}},"mem":{},"swap":{}}}`

				hbBytes, err := json.Marshal(hb)
				Expect(err).ToNot(HaveOccurred())
				Expect(string(hbBytes)).To(Equal(expectedJSON))
			})
		})

		Context("when job name, index are not available", func() {
			It("serializes job name and index as nulls to indicate that there is no job assigned to this agent", func() {
				hb := Heartbeat{
					JobState: "running",
					Vitals: boshvitals.Vitals{
						Disk: boshvitals.DiskVitals{
							"system":     boshvitals.SpecificDiskVitals{},
							"ephemeral":  boshvitals.SpecificDiskVitals{},
							"persistent": boshvitals.SpecificDiskVitals{},
						},
					},
				}

				expectedJSON := `{"job":null,"index":null,"job_state":"running","vitals":{"cpu":{},"disk":{"ephemeral":{},"persistent":{},"system":{}},"mem":{},"swap":{}}}`

				hbBytes, err := json.Marshal(hb)
				Expect(err).ToNot(HaveOccurred())
				Expect(string(hbBytes)).To(Equal(expectedJSON))
			})
		})
	})
}
