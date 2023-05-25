package brats_test

import (
	"fmt"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	"github.com/cloudfoundry/bosh-utils/uuid"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("postgres", func() {
	Context("postgres-10", func() {
		var (
			postgres94Manifest     string
			postgres10Manifest     string
			postgresDeploymentName string
		)

		BeforeEach(func() {
			var err error

			postgresDeploymentName, err = uuid.NewGenerator().Generate()
			Expect(err).NotTo(HaveOccurred())

			postgres94Manifest = bratsutils.AssetPath("postgres-94-manifest.yml")
			postgres10Manifest = bratsutils.AssetPath("postgres-10-manifest.yml")

			session := bratsutils.OuterBosh("deploy", "-n", postgres94Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})

		It("Upgrades from 9.4", func() {
			session := bratsutils.OuterBosh("deploy", "-n", postgres10Manifest,
				"-d", postgresDeploymentName,
				"-v", fmt.Sprintf("stemcell-os=%s", bratsutils.StemcellOS()),
				"-v", fmt.Sprintf("deployment-name=%s", postgresDeploymentName),
			)
			Eventually(session, 15*time.Minute).Should(gexec.Exit(0))
		})
	})
})
