package brats_test

import (
	"os"

	"io/ioutil"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
)

var _ = Describe("Director external database TLS connections", func() {
	testDBConnectionOverTLS := func(databaseType string, mutualTLSEnabled bool, useIncorrectCA bool) {
		tmpCertDir, err := ioutil.TempDir("", "db_tls")
		Expect(err).ToNot(HaveOccurred())

		defer os.RemoveAll(tmpCertDir)

		dbConfig := loadExternalDBConfig(databaseType, mutualTLSEnabled, tmpCertDir)

		cleanupDB(dbConfig)

		if useIncorrectCA {
			dbConfig.CACertPath = assetPath("external_db/invalid_ca_cert.pem")
		}

		startInnerBoshArgs := innerBoshWithExternalDBOptions(dbConfig)

		if useIncorrectCA {
			startInnerBoshWithExpectation(true, "Error: 'bosh/[0-9a-f]{8}-[0-9a-f-]{27} \\(0\\)' is not running after update", startInnerBoshArgs...)
		} else {
			startInnerBosh(startInnerBoshArgs...)
			uploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
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
		Context("Regular TLS", func() {
			Context("With valid CA", func() {
				var mutualTLSEnabled = false
				var useIncorrectCA = false

				DescribeTable("DB Connections", testDBConnectionOverTLS,
					Entry("allows TLS connections to MYSQL", "gcp_mysql", mutualTLSEnabled, useIncorrectCA),
					Entry("allows TLS connections to POSTGRES", "gcp_postgres", mutualTLSEnabled, useIncorrectCA),
				)
			})
		})

		Context("Mutual TLS", func() {
			var mutualTLSEnabled = true
			var useIncorrectCA = false

			DescribeTable("DB Connections", testDBConnectionOverTLS,
				Entry("allows TLS connections to MYSQL", "gcp_mysql", mutualTLSEnabled, useIncorrectCA),
				Entry("allows TLS connections to POSTGRES", "gcp_postgres", mutualTLSEnabled, useIncorrectCA),
			)
		})
	})
})
