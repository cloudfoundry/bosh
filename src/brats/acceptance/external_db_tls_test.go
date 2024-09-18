package acceptance_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"brats/utils"
)

var _ = Describe("Director external database TLS connections", func() {
	testDBConnectionOverTLS := func(databaseType string, mutualTLSEnabled bool, useIncorrectCA bool) {
		tmpCertDir, err := os.MkdirTemp("", "db_tls")
		Expect(err).ToNot(HaveOccurred())
		dbConfig := utils.LoadExternalDBConfig(databaseType, mutualTLSEnabled, tmpCertDir)
		utils.CreateDB(dbConfig)
		defer os.RemoveAll(tmpCertDir)
		defer utils.DeleteDB(dbConfig)

		realCACertPath := dbConfig.CACertPath
		if useIncorrectCA {
			dbConfig.CACertPath = utils.AssetPath("external_db/invalid_ca_cert.pem")
		}

		startInnerBoshArgs := utils.InnerBoshWithExternalDBOptions(dbConfig)

		if useIncorrectCA {
			utils.StartInnerBoshWithExpectation(true, "Error: 'bosh/[0-9a-f]{8}-[0-9a-f-]{27} \\(0\\)' is not running after update", startInnerBoshArgs...)
			dbConfig.CACertPath = realCACertPath
		} else {
			defer utils.StopInnerBosh()
			utils.StartInnerBosh(startInnerBoshArgs...)
		}
	}
	var mutualTLSEnabled bool
	var useIncorrectCA bool

	Context("RDS", func() {
		mutualTLSEnabled = false
		useIncorrectCA = false

		DescribeTable("Regular TLS", testDBConnectionOverTLS,
			Entry("allows TLS connections to MYSQL", "rds_mysql", mutualTLSEnabled, useIncorrectCA),
			Entry("allows TLS connections to POSTGRES", "rds_postgres", mutualTLSEnabled, useIncorrectCA),
		)
	})

	Context("GCP", func() {
		Context("Mutual TLS", func() {
			mutualTLSEnabled = true
			useIncorrectCA = false

			DescribeTable("DB Connections", testDBConnectionOverTLS,
				Entry("allows TLS connections to MYSQL", "gcp_mysql", mutualTLSEnabled, useIncorrectCA),
				Entry("allows TLS connections to POSTGRES", "gcp_postgres", mutualTLSEnabled, useIncorrectCA),
			)
		})

		Context("With Incorrect CA", func() {
			mutualTLSEnabled = true
			useIncorrectCA = true

			DescribeTable("DB Connections", testDBConnectionOverTLS,
				// Pending https://www.pivotaltracker.com/story/show/153421636/comments/185372185
				PEntry("fails to connect to MYSQL refer to https://www.pivotaltracker.com/story/show/153421636/comments/185372185", "gcp_mysql", mutualTLSEnabled, useIncorrectCA),
				Entry("fails to connect to POSTGRES", "gcp_postgres", mutualTLSEnabled, useIncorrectCA),
			)
		})
	})
})
