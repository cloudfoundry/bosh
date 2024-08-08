package performance_test

import (
	"fmt"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
	"github.com/onsi/gomega/gmeasure"

	"brats/utils"
)

const deploymentName = "cf"

var _ = Describe("Template Rendering", Serial, func() {
	var (
		cfDeploymentPath string
	)

	BeforeEach(func() {
		utils.StartInnerBosh(
			fmt.Sprintf("-o %s", utils.BoshDeploymentAssetPath("uaa.yml")),
			fmt.Sprintf("-o %s", utils.BoshDeploymentAssetPath("credhub.yml")),
		)
		utils.UploadStemcell(utils.AssertEnvExists("CANDIDATE_STEMCELL_TARBALL_PATH"))
		cfDeploymentPath = utils.AssertEnvExists("CF_DEPLOYMENT_RELEASE_PATH")
	})

	It("deploys", func() {
		experiment := gmeasure.NewExperiment("Template Rendering")
		AddReportEntry(experiment.Name, experiment)
		stopwatch := experiment.NewStopwatch()

		manifestPath := filepath.Join(cfDeploymentPath, "cf-deployment.yml")
		compiledReleasesOpsFilePath := filepath.Join(cfDeploymentPath, "operations", "use-compiled-releases.yml")
		templateRenderingOpsFile := utils.AssetPath("template-rendering-ops-file.yml")
		session := utils.Bosh("deploy", "-n", "-d", deploymentName, manifestPath,
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

		session = utils.Bosh("deploy", "-n", "-d", deploymentName, manifestPath,
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
