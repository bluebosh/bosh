package brats_test

import (
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Scheduled jobs", func() {
	BeforeEach(func() {
		bratsutils.StartInnerBosh("-o", bratsutils.AssetPath("ops-frequent-scheduler-job.yml"))
	})

	It("schedules jobs on intervals", func() {
		session := bratsutils.OuterBosh("-d", bratsutils.InnerBoshDirectorName(), "ssh", "-c", `sudo grep Bosh::Director::Jobs::ScheduledOrphanedVMCleanup.has_work:false /var/vcap/sys/log/director/scheduler.stdout.log`)
		Eventually(session, 10*time.Minute).Should(gexec.Exit(0))
	})
})
