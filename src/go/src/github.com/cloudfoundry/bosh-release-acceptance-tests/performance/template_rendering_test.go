package performance_test

import (
	"fmt"
	"github.com/onsi/gomega/gmeasure"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

const deploymentName = "cf"

var _ = Describe("Template Rendering", Serial, func() {
	var (
		cfDeploymentPath string
	)

	BeforeEach(func() {
		bratsutils.StartInnerBosh(
			fmt.Sprintf("-o %s", bratsutils.BoshDeploymentAssetPath("uaa.yml")),
			fmt.Sprintf("-o %s", bratsutils.BoshDeploymentAssetPath("credhub.yml")),
		)
		bratsutils.UploadStemcell(bratsutils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH"))
		cfDeploymentPath = bratsutils.AssertEnvExists("CF_DEPLOYMENT_RELEASE_PATH")
	})

	It("deploys", func() {
		experiment := gmeasure.NewExperiment("Template Rendering")
		AddReportEntry(experiment.Name, experiment)
		stopwatch := experiment.NewStopwatch()

		manifestPath := filepath.Join(cfDeploymentPath, "cf-deployment.yml")
		compiledReleasesOpsFilePath := filepath.Join(cfDeploymentPath, "operations", "use-compiled-releases.yml")
		templateRenderingOpsFile := bratsutils.AssetPath("template-rendering-ops-file.yml")
		session := bratsutils.Bosh("deploy", "-n", "-d", deploymentName, manifestPath,
			"-o", compiledReleasesOpsFilePath,
			"-o", templateRenderingOpsFile,
			"-v", "diego_cell_instances=0",
			"-v", "system_domain=test-domain.local",
			"--dry-run",
		)
		Eventually(session, 2*time.Hour).Should(gexec.Exit(0))
		stopwatch.Record("initial_deploy")
		prepareDuration, renderingDuration := GetPrepareAndRenderingDurations(session.Out.Contents())
		experiment.RecordDuration("initial_deploy_preparing_deployment", prepareDuration)
		experiment.RecordDuration("initial_deploy_rendering_templates", renderingDuration)
		stopwatch.Reset()

		session = bratsutils.Bosh("deploy", "-n", "-d", deploymentName, manifestPath,
			"-o", compiledReleasesOpsFilePath,
			"-o", templateRenderingOpsFile,
			"-v", "diego_cell_instances=800",
			"-v", "system_domain=test-domain.local",
			"--dry-run",
		)
		Eventually(session, 8*time.Hour).Should(gexec.Exit(0))
		stopwatch.Record("large_deploy")
		prepareDuration, renderingDuration = GetPrepareAndRenderingDurations(session.Out.Contents())
		experiment.RecordDuration("large_deploy_preparing_deployment", prepareDuration)
		experiment.RecordDuration("large_deploy_rendering_templates", renderingDuration)
	})
})

func GetPrepareAndRenderingDurations(deployOutput []byte) (time.Duration, time.Duration) {
	prepareDeploymentRegex := regexp.MustCompile(`Preparing deployment \(([\d:]+)`)
	matches := prepareDeploymentRegex.FindStringSubmatch(string(deployOutput))
	prepareDeploymentDuration := ConvertTimeToDuration(matches[1])

	renderingTemplatesRegex := regexp.MustCompile(`Rendering templates \(([\d:]+)`)
	matches = renderingTemplatesRegex.FindStringSubmatch(string(deployOutput))
	renderingTemplatesDuration := ConvertTimeToDuration(matches[1])

	return prepareDeploymentDuration, renderingTemplatesDuration
}

func ConvertTimeToDuration(timeAsString string) time.Duration {
	segments := strings.Split(timeAsString, ":")
	hours, _ := strconv.Atoi(segments[0])
	minutes, _ := strconv.Atoi(segments[1])
	seconds, _ := strconv.Atoi(segments[2])
	return time.Duration(hours)*time.Hour + time.Duration(minutes)*time.Minute + time.Duration(seconds)*time.Second
}
