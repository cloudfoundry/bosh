package alert_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/stretchr/testify/assert"

	. "bosh/agent/alert"
	boshlog "bosh/logger"
	fakesettings "bosh/settings/fakes"
)

func buildMonitAlert() MonitAlert {
	return MonitAlert{
		Id:          "some random id",
		Service:     "nats",
		Event:       "does not exist",
		Action:      "restart",
		Date:        "Sun, 22 May 2011 20:07:41 +0500",
		Description: "process is not running",
	}
}

func init() {
	Describe("concreteBuilder", func() {
		var (
			settingsService *fakesettings.FakeSettingsService
			builder         Builder
		)

		BeforeEach(func() {
			logger := boshlog.NewLogger(boshlog.LEVEL_NONE)
			settingsService = &fakesettings.FakeSettingsService{}
			builder = NewBuilder(settingsService, logger)
		})

		Describe("Build", func() {
			It("builds alert with id, severity and other monit related info", func() {
				builtAlert, err := builder.Build(buildMonitAlert())
				Expect(err).ToNot(HaveOccurred())

				expectedAlert := Alert{
					Id:        "some random id",
					Severity:  SEVERITY_ALERT,
					Title:     "nats - does not exist - restart",
					Summary:   "process is not running",
					CreatedAt: 1306076861,
				}

				Expect(builtAlert).To(Equal(expectedAlert))
			})

			It("sets the severity", func() {
				inputAlert := buildMonitAlert()
				inputAlert.Event = "action done"

				builtAlert, _ := builder.Build(inputAlert)
				Expect(builtAlert.Severity).To(Equal(SEVERITY_IGNORED))
			})

			It("sets default severity to critical", func() {
				inputAlert := buildMonitAlert()
				inputAlert.Event = "some unknown event"

				builtAlert, _ := builder.Build(inputAlert)
				Expect(builtAlert.Severity).To(Equal(SEVERITY_CRITICAL))
			})

			It("sets created at", func() {
				inputAlert := buildMonitAlert()
				inputAlert.Date = "Thu, 02 May 2013 20:07:41 +0500"

				builtAlert, _ := builder.Build(inputAlert)
				Expect(int(builtAlert.CreatedAt)).To(Equal(int(1367507261)))
			})

			It("defaults created at to now on parse error", func() {
				inputAlert := buildMonitAlert()
				inputAlert.Date = "Thu, 02 May 2013 20:07:0"

				builtAlert, _ := builder.Build(inputAlert)

				createdAt := time.Unix(builtAlert.CreatedAt, 0)
				now := time.Now()

				assert.WithinDuration(GinkgoT(), now, createdAt, 1*time.Second)
			})

			It("sets the title with ips", func() {
				inputAlert := buildMonitAlert()
				settingsService.Ips = []string{"192.168.0.1", "10.0.0.1"}

				builtAlert, _ := builder.Build(inputAlert)

				Expect(builtAlert.Title).To(Equal("nats (10.0.0.1, 192.168.0.1) - does not exist - restart"))
			})
		})
	})
}
