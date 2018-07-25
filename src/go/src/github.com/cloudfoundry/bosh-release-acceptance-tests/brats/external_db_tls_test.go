package brats_test

import (
	"os"

	"io/ioutil"

	bratsutils "github.com/cloudfoundry/bosh-release-acceptance-tests/brats-utils"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
)

var _ = Describe("Director external database TLS connections", func() {
	testDBConnectionOverTLS := func(databaseType string, mutualTLSEnabled bool) {
		tmpCertDir, err := ioutil.TempDir("", "db_tls")
		Expect(err).ToNot(HaveOccurred())
		dbConfig := bratsutils.LoadExternalDBConfig(databaseType, mutualTLSEnabled, tmpCertDir)
		bratsutils.CreateDB(dbConfig)
		defer os.RemoveAll(tmpCertDir)
		defer bratsutils.DeleteDB(dbConfig)

		startInnerBoshArgs := bratsutils.InnerBoshWithExternalDBOptions(dbConfig)

		bratsutils.StartInnerBosh(startInnerBoshArgs...)
		defer bratsutils.StopInnerBosh()
		bratsutils.UploadRelease("https://bosh.io/d/github.com/cloudfoundry/syslog-release?v=11")
	}

	Context("RDS", func() {
		var mutualTLSEnabled = false

		DescribeTable("Regular TLS", testDBConnectionOverTLS,
			Entry("allows TLS connections to POSTGRES", "rds_postgres", mutualTLSEnabled),
			Entry("allows TLS connections to MYSQL", "rds_mysql", mutualTLSEnabled),
		)
	})

	Context("GCP", func() {
		Context("Regular TLS", func() {
			Context("With valid CA", func() {
				var mutualTLSEnabled = false

				DescribeTable("DB Connections", testDBConnectionOverTLS,
					Entry("allows TLS connections to MYSQL", "gcp_mysql", mutualTLSEnabled),
					Entry("allows TLS connections to POSTGRES", "gcp_postgres", mutualTLSEnabled),
				)
			})
		})

		Context("Mutual TLS", func() {
			var mutualTLSEnabled = true

			DescribeTable("DB Connections", testDBConnectionOverTLS,
				Entry("allows TLS connections to MYSQL", "gcp_mysql", mutualTLSEnabled),
				Entry("allows TLS connections to POSTGRES", "gcp_postgres", mutualTLSEnabled),
			)
		})
	})
})
