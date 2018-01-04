package brats_test

import (
	"fmt"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
)

var _ = Describe("Director external database TLS connections", func() {
	AfterEach(func() {
		stopInnerBosh()
	})

	testDBConnectionOverTLS := func(databaseType string) {
		external_db_host := assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_HOST", strings.ToUpper(databaseType)))
		external_db_user := assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_USER", strings.ToUpper(databaseType)))
		external_db_password := assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_PASSWORD", strings.ToUpper(databaseType)))
		external_db_name := assertEnvExists(fmt.Sprintf("%s_EXTERNAL_DB_NAME", strings.ToUpper(databaseType)))

		connectionOptions := fmt.Sprintf("external_db/%s_connection_options.yml", databaseType)
		connectionVarFile := fmt.Sprintf("external_db/%s.yml", databaseType)

		startInnerBosh(
			fmt.Sprintf("-o %s", boshDeploymentAssetPath("misc/external-db.yml")),
			fmt.Sprintf("-o %s", boshDeploymentAssetPath("experimental/db-enable-tls.yml")),
			fmt.Sprintf("-o %s", assetPath(connectionOptions)),
			fmt.Sprintf("--vars-file %s", assetPath(connectionVarFile)),
			fmt.Sprintf("-v external_db_host=%s", external_db_host),
			fmt.Sprintf("-v external_db_user=%s", external_db_user),
			fmt.Sprintf("-v external_db_password=%s", external_db_password),
			fmt.Sprintf("-v external_db_name=%s", external_db_name),
		)

		uploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
	}

	DescribeTable("RDS", testDBConnectionOverTLS,
		Entry("allows TLS connections to POSTGRES", "rds_mysql"),
		Entry("allows TLS connections to MYSQL", "rds_postgres"),
	)

	DescribeTable("GCP", testDBConnectionOverTLS,
		Entry("allows TLS connections to POSTGRES", "gcp_mysql"),
		Entry("allows TLS connections to MYSQL", "gcp_postgres"),
	)
})
