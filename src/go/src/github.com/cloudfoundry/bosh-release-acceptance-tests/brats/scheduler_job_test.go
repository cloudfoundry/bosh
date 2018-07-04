package brats_test

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Scheduled jobs", func() {
	BeforeEach(func() {
		startInnerBosh("-o", assetPath("ops-frequent-scheduler-job.yml"))
	})

	It("schedules jobs on intervals", func() {
		session := outerBosh("-d", "bosh", "ssh", "-c", `sudo grep Bosh::Director::Jobs::ScheduledOrphanedVMCleanup.has_work:false /var/vcap/sys/log/director/scheduler.stdout.log`)
		Eventually(session, 3*time.Minute).Should(gexec.Exit(0))
	})
})
