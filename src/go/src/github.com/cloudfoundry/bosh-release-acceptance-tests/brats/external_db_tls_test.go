package brats_test

import (
	"os"

	"io/ioutil"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Director external database TLS connections", func() {
	testDBConnectionOverTLS := func(databaseType string, mutualTLSEnabled bool, useIncorrectCA bool) {
		tmpCertDir, err := ioutil.TempDir("", "db_tls")
		Expect(err).ToNot(HaveOccurred())
		dbConfig := bratsutils.LoadExternalDBConfig(databaseType, mutualTLSEnabled, tmpCertDir)
		bratsutils.CreateDB(dbConfig)
		defer os.RemoveAll(tmpCertDir)
		defer bratsutils.DeleteDB(dbConfig)

		realCACertPath := dbConfig.CACertPath
		if useIncorrectCA {
			dbConfig.CACertPath = bratsutils.AssetPath("external_db/invalid_ca_cert.pem")
		}

		startInnerBoshArgs := bratsutils.InnerBoshWithExternalDBOptions(dbConfig)

		if useIncorrectCA {
			bratsutils.StartInnerBoshWithExpectation(true, "Error: 'bosh/[0-9a-f]{8}-[0-9a-f-]{27} \\(0\\)' is not running after update", startInnerBoshArgs...)
			dbConfig.CACertPath = realCACertPath
		} else {
			defer bratsutils.StopInnerBosh()
			bratsutils.StartInnerBosh(startInnerBoshArgs...)
		}
	}

	Context("RDS", func() {
		var mutualTLSEnabled = false
		var useIncorrectCA = false

		DescribeTable("Regular TLS", testDBConnectionOverTLS,
			Entry("allows TLS connections to POSTGRES", "rds_postgres", mutualTLSEnabled, useIncorrectCA),
			Entry("allows TLS connections to MYSQL", "rds_mysql", mutualTLSEnabled, useIncorrectCA),
		)
	})

	Context("GCP", func() {
		Context("Mutual TLS", func() {
			var mutualTLSEnabled = true
			var useIncorrectCA = false

			DescribeTable("DB Connections", testDBConnectionOverTLS,
				Entry("allows TLS connections to MYSQL", "gcp_mysql", mutualTLSEnabled, useIncorrectCA),
				Entry("allows TLS connections to POSTGRES", "gcp_postgres", mutualTLSEnabled, useIncorrectCA),
			)
		})

		Context("With Incorrect CA", func() {
			var mutualTLSEnabled = true
			var useIncorrectCA = true

			DescribeTable("DB Connections", testDBConnectionOverTLS,
				// Pending https://www.pivotaltracker.com/story/show/153421636/comments/185372185
				PEntry("fails to connect to MYSQL refer to https://www.pivotaltracker.com/story/show/153421636/comments/185372185", "gcp_mysql", mutualTLSEnabled, useIncorrectCA),
				Entry("fails to connect to POSTGRES", "gcp_postgres", mutualTLSEnabled, useIncorrectCA),
			)
		})
	})
})
