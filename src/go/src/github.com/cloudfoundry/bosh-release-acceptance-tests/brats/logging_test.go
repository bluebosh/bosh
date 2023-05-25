package brats_test

import (
	"fmt"
	"io/ioutil"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo"
	"github.com/onsi/ginkgo/config"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("logging", func() {
	var cpiConfigName string

	BeforeEach(func() {
		cpiConfigName = fmt.Sprintf("%s-logging-test-fake-cpi-config-%d", time.Now().Format("2006-01-02"), config.GinkgoConfig.ParallelNode)
		bratsutils.StartInnerBosh()
	})

	AfterEach(func() {
		session := bratsutils.Bosh("-n", "delete-config", "--type", "cpi", "--name", cpiConfigName)
		Eventually(session, 15*time.Second).Should(gexec.Exit(0))
	})

	It("does not log credentials to the debug logs of director and workers", func() {
		configPath := bratsutils.AssetPath("cpi-config.yml")
		redactable := "password: c1oudc0w"

		content, err := ioutil.ReadFile(configPath)
		Expect(err).NotTo(HaveOccurred())
		Expect(string(content)).To(ContainSubstring(redactable))

		session := bratsutils.Bosh("-n", "update-config", "--type", "cpi", "--name", cpiConfigName, configPath)
		Eventually(session, 1*time.Minute).Should(gexec.Exit(0))

		session = bratsutils.OuterBoshQuiet("-d", bratsutils.InnerBoshDirectorName(), "ssh", "bosh", "-c", "sudo cat /var/vcap/sys/log/director/*")
		Eventually(session, 2*time.Minute).Should(gexec.Exit(0))
		Expect(string(session.Out.Contents())).To(ContainSubstring("INSERT INTO \"configs\" <redacted>"))
		Expect(string(session.Out.Contents())).NotTo(ContainSubstring(redactable))
	})
})
