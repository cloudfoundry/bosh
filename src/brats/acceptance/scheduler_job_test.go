package acceptance_test

import (
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"

	"brats/utils"
)

var _ = Describe("Scheduled jobs", func() {
	BeforeEach(func() {
		utils.StartInnerBosh("-o", utils.AssetPath("ops-frequent-scheduler-job.yml"))
	})

	It("schedules jobs on intervals", func() {
		session := utils.OuterBosh("-d", utils.InnerBoshDirectorName(), "ssh", "-c", `sudo grep Bosh::Director::Jobs::ScheduledOrphanedVMCleanup.has_work:false /var/vcap/sys/log/director/scheduler.stdout.log`)
		Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
	})
})
