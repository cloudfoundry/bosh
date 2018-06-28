package brats_test

import (
	"fmt"
	"os"

	"io/ioutil"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
)

var _ = Describe("Director external database TLS connections", func() {
	AfterEach(func() {
		stopInnerBosh()
	})

	testDBConnectionOverTLS := func(databaseType string, mutualTLSEnabled bool, useIncorrectCA bool) {
		tmpCertDir, err := ioutil.TempDir("", "db_tls")
		Expect(err).ToNot(HaveOccurred())

		defer os.RemoveAll(tmpCertDir)

		config := loadExternalDBConfig(databaseType, mutualTLSEnabled, tmpCertDir)

		if useIncorrectCA {
			config.ConnectionVarFile = fmt.Sprintf("external_db/%s_invalid_ca.yml", databaseType)
		}

		startInnerBoshArgs := innerBoshWithExternalDBOptions(config)

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

			// Pending. Check https://www.pivotaltracker.com/story/show/154143917 and https://www.pivotaltracker.com/story/show/153785594/comments/184377346
			PEntry("allows TLS connections to MYSQL, refer to https://www.pivotaltracker.com/story/show/154143917", "rds_mysql", false),
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

			Context("With Incorrect CA", func() {
				var mutualTLSEnabled = false
				var useIncorrectCA = true

				DescribeTable("DB Connections", testDBConnectionOverTLS,
					// Pending https://www.pivotaltracker.com/story/show/153421636/comments/185372185
					PEntry("fails to connect to MYSQL refer to https://www.pivotaltracker.com/story/show/153421636/comments/185372185", "gcp_mysql", mutualTLSEnabled, useIncorrectCA),
					Entry("fails to connect to POSTGRES", "gcp_postgres", mutualTLSEnabled, useIncorrectCA),
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
