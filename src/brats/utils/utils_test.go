package utils_test

import (
	"fmt"
	"path/filepath"
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"brats/utils"
)

var _ = Describe("Utils", func() {
	var dbHost string
	var dbUser string
	var dbPass string
	var dbName string

	var iaasAndDbName string
	var connectionVarsFile string
	var connectionOptionsFile string

	var certTmpDir string

	BeforeEach(func() {
		dbHost = "fake-db.example.com"
		dbUser = "fake-db-user"
		dbPass = "fake-db-pass"

		certTmpDir = GinkgoT().TempDir()
	})

	Context("LoadExternalDBConfig", func() {
		var mTlsEnabled bool

		Context("when IaaS and DB is 'gcp_mysql'", func() {
			BeforeEach(func() {
				iaasAndDbName = "gcp_mysql"
				dbName = fmt.Sprintf("db_mysql_%d", GinkgoParallelProcess())

				connectionVarsFile = fmt.Sprintf("external_db/%s.yml", iaasAndDbName)
				connectionOptionsFile = fmt.Sprintf("external_db/%s_connection_options.yml", iaasAndDbName)

				GinkgoT().Setenv(
					fmt.Sprintf("%s_EXTERNAL_DB_HOST", strings.ToUpper(iaasAndDbName)),
					dbHost,
				)

				GinkgoT().Setenv(
					fmt.Sprintf("%s_EXTERNAL_DB_USER", strings.ToUpper(iaasAndDbName)),
					dbUser,
				)

				GinkgoT().Setenv(
					fmt.Sprintf("%s_EXTERNAL_DB_PASSWORD", strings.ToUpper(iaasAndDbName)),
					dbPass,
				)
			})

			Context("when an ENV var for the External DB's CA present", func() {
				BeforeEach(func() {
					GinkgoT().Setenv(
						fmt.Sprintf("%s_EXTERNAL_DB_CA", strings.ToUpper(iaasAndDbName)),
						"-----FAKE DB_CA-----",
					)
				})

				Context("when mTLS is NOT enabled", func() {
					BeforeEach(func() {
						mTlsEnabled = false
					})

					It("creates the expected ExternalDBConfig", func() {
						externalDBConfig := utils.LoadExternalDBConfig(iaasAndDbName, mTlsEnabled, certTmpDir)

						expectedExternalDBConfig := &utils.ExternalDBConfig{
							Type:                  "mysql",
							Host:                  dbHost,
							User:                  dbUser,
							Password:              dbPass,
							DBName:                dbName,
							ConnectionVarFile:     connectionVarsFile,
							ConnectionOptionsFile: connectionOptionsFile,
							CACertPath:            filepath.Join(certTmpDir, "db_ca"),
						}

						Expect(externalDBConfig).To(Equal(expectedExternalDBConfig))
					})
				})

				Context("when mTLS is enabled", func() {
					BeforeEach(func() {
						mTlsEnabled = true

						GinkgoT().Setenv(
							fmt.Sprintf("%s_EXTERNAL_DB_CLIENT_CERTIFICATE", strings.ToUpper(iaasAndDbName)),
							"-----FAKE DB_CLIENT_CERTIFICATE-----",
						)

						GinkgoT().Setenv(
							fmt.Sprintf("%s_EXTERNAL_DB_CLIENT_PRIVATE_KEY", strings.ToUpper(iaasAndDbName)),
							"-----FAKE EXTERNAL_DB_CLIENT_PRIVATE_KEY-----",
						)
					})

					It("creates the expected ExternalDBConfig", func() {
						externalDBConfig := utils.LoadExternalDBConfig(iaasAndDbName, mTlsEnabled, certTmpDir)

						expectedExternalDBConfig := &utils.ExternalDBConfig{
							Type:                  "mysql",
							Host:                  dbHost,
							User:                  dbUser,
							Password:              dbPass,
							DBName:                dbName,
							ConnectionVarFile:     connectionVarsFile,
							ConnectionOptionsFile: connectionOptionsFile,
							CACertPath:            filepath.Join(certTmpDir, "db_ca"),
							ClientCertPath:        filepath.Join(certTmpDir, "client_cert"),
							ClientKeyPath:         filepath.Join(certTmpDir, "client_key"),
						}

						Expect(externalDBConfig).To(Equal(expectedExternalDBConfig))
					})
				})
			})
		})
	})

	Context("GenerateMySQLCommand", func() {
		var externalDBConfig *utils.ExternalDBConfig
		var dbType = "mysql"
		var sqlToExecute string

		BeforeEach(func() {
			sqlToExecute = "FAKE SQL TO EXECUTE;"
		})

		Context("ClientCertPath and ClientKeyPath are empty", func() {
			BeforeEach(func() {
				externalDBConfig = &utils.ExternalDBConfig{
					Type:       dbType,
					Host:       dbHost,
					User:       dbUser,
					Password:   dbPass,
					DBName:     dbName,
					CACertPath: "fake/ca_cert/path",
				}
			})

			It("generates the expected args", func() {
				expectedAgs := []string{
					"-h",
					dbHost,
					fmt.Sprintf("--user=%s", dbUser),
					fmt.Sprintf("--password=%s", dbPass),
					"-e",
					sqlToExecute,
					"--ssl-ca=fake/ca_cert/path",
					"--ssl-mode=VERIFY_IDENTITY",
				}

				Expect(utils.GenerateMySQLCommand(sqlToExecute, externalDBConfig)).To(Equal(expectedAgs))
			})
		})

		Context("ClientCertPath is empty", func() {
			BeforeEach(func() {
				externalDBConfig = &utils.ExternalDBConfig{
					Type:          dbType,
					Host:          dbHost,
					User:          dbUser,
					Password:      dbPass,
					DBName:        dbName,
					CACertPath:    "fake/ca_cert/path",
					ClientKeyPath: "fake/client_key/path",
				}
			})

			It("generates the expected args", func() {
				expectedAgs := []string{
					"-h",
					dbHost,
					fmt.Sprintf("--user=%s", dbUser),
					fmt.Sprintf("--password=%s", dbPass),
					"-e",
					sqlToExecute,
					"--ssl-ca=fake/ca_cert/path",
					"--ssl-cert=",
					"--ssl-key=fake/client_key/path",
					"--ssl-mode=VERIFY_CA",
				}

				Expect(utils.GenerateMySQLCommand(sqlToExecute, externalDBConfig)).To(Equal(expectedAgs))
			})
		})

		Context("ClientKeyPath is empty", func() {
			BeforeEach(func() {
				externalDBConfig = &utils.ExternalDBConfig{
					Type:           dbType,
					Host:           dbHost,
					User:           dbUser,
					Password:       dbPass,
					DBName:         dbName,
					CACertPath:     "fake/ca_cert/path",
					ClientCertPath: "fake/client_cert/path",
				}
			})

			It("generates the expected args", func() {
				expectedAgs := []string{
					"-h",
					dbHost,
					fmt.Sprintf("--user=%s", dbUser),
					fmt.Sprintf("--password=%s", dbPass),
					"-e",
					sqlToExecute,
					"--ssl-ca=fake/ca_cert/path",
					"--ssl-cert=fake/client_cert/path",
					"--ssl-key=",
					"--ssl-mode=VERIFY_CA",
				}

				Expect(utils.GenerateMySQLCommand(sqlToExecute, externalDBConfig)).To(Equal(expectedAgs))
			})
		})
	})

	Context("GeneratePSQLCommand", func() {
		var externalDBConfig *utils.ExternalDBConfig
		var dbType = "postgres"

		var sqlToExecute string

		BeforeEach(func() {
			dbName = "fake-db-name"
			sqlToExecute = "FAKE SQL TO EXECUTE;"
		})

		Context("ClientCertPath and ClientKeyPath are empty", func() {
			BeforeEach(func() {
				externalDBConfig = &utils.ExternalDBConfig{
					Type:       dbType,
					Host:       dbHost,
					User:       dbUser,
					Password:   dbPass,
					DBName:     dbName,
					CACertPath: "fake/ca_cert/path",
				}
			})

			It("generates the expected args", func() {
				expectedAgs := []string{
					fmt.Sprintf(
						"dbname=%s host=%s user=%s password=%s sslrootcert=%s sslmode=verify-full ",
						dbType, dbHost, dbUser, dbPass, "fake/ca_cert/path",
					),
					"-c",
					sqlToExecute,
				}

				Expect(utils.GeneratePSQLCommand(sqlToExecute, externalDBConfig)).To(Equal(expectedAgs))
			})
		})

		Context("ClientCertPath is empty", func() {
			BeforeEach(func() {
				externalDBConfig = &utils.ExternalDBConfig{
					Type:          dbType,
					Host:          dbHost,
					User:          dbUser,
					Password:      dbPass,
					DBName:        dbName,
					CACertPath:    "fake/ca_cert/path",
					ClientKeyPath: "fake/client_key/path",
				}
			})

			It("generates the expected args", func() {
				expectedAgs := []string{
					fmt.Sprintf(
						"dbname=%s host=%s user=%s password=%s sslrootcert=%s sslcert= sslkey=%s sslmode=verify-ca ",
						dbType, dbHost, dbUser, dbPass, "fake/ca_cert/path", "fake/client_key/path",
					),
					"-c",
					sqlToExecute,
				}

				Expect(utils.GeneratePSQLCommand(sqlToExecute, externalDBConfig)).To(Equal(expectedAgs))
			})
		})

		Context("ClientKeyPath is empty", func() {
			BeforeEach(func() {
				externalDBConfig = &utils.ExternalDBConfig{
					Type:           dbType,
					Host:           dbHost,
					User:           dbUser,
					Password:       dbPass,
					DBName:         dbName,
					CACertPath:     "fake/ca_cert/path",
					ClientCertPath: "fake/client_cert/path",
				}
			})

			It("generates the expected args", func() {
				expectedAgs := []string{
					fmt.Sprintf(
						"dbname=%s host=%s user=%s password=%s sslrootcert=%s sslcert=%s sslkey= sslmode=verify-ca ",
						dbType, dbHost, dbUser, dbPass, "fake/ca_cert/path", "fake/client_cert/path",
					),
					"-c",
					sqlToExecute,
				}

				Expect(utils.GeneratePSQLCommand(sqlToExecute, externalDBConfig)).To(Equal(expectedAgs))
			})
		})
	})

	Context("InnerBoshWithExternalDBOptions", func() {
		var externalDBConfig *utils.ExternalDBConfig

		BeforeEach(func() {
			connectionVarsFile = "external_db/fake.yml"
			connectionOptionsFile = "external_db/fake_connection_options.yml"

			externalDBConfig = &utils.ExternalDBConfig{
				Type:                  "mysql",
				Host:                  dbHost,
				User:                  dbUser,
				Password:              dbPass,
				DBName:                dbName,
				ConnectionVarFile:     connectionVarsFile,
				ConnectionOptionsFile: connectionOptionsFile,
				CACertPath:            filepath.Join(certTmpDir, "db_ca"),
				ClientCertPath:        filepath.Join(certTmpDir, "client_cert"),
				ClientKeyPath:         filepath.Join(certTmpDir, "client_key"),
			}
		})

		It("generates the expected args", func() {
			expectedAgs := []string{
				"-o", utils.BoshDeploymentAssetPath("misc/external-db.yml"),
				"-o", utils.BoshDeploymentAssetPath("experimental/db-enable-tls.yml"),
				"-o", utils.AssetPath(connectionOptionsFile),
				"--vars-file", utils.AssetPath(connectionVarsFile),
				fmt.Sprintf("--var=db_ca=%s", filepath.Join(certTmpDir, "db_ca")),
				"-v", fmt.Sprintf("external_db_host=%s", dbHost),
				"-v", fmt.Sprintf("external_db_user=%s", dbUser),
				"-v", fmt.Sprintf("external_db_password=%s", dbPass),
				"-v", fmt.Sprintf("external_db_name=%s", dbName),
				fmt.Sprintf("-o %s", utils.BoshDeploymentAssetPath("experimental/db-enable-mutual-tls.yml")),
				fmt.Sprintf("-o %s", utils.AssetPath("tls-skip-host-verify.yml")),
				fmt.Sprintf("--var=db_client_certificate=%s", filepath.Join(certTmpDir, "client_cert")),
				fmt.Sprintf("--var=db_client_private_key=%s", filepath.Join(certTmpDir, "client_key")),
			}

			Expect(utils.InnerBoshWithExternalDBOptions(externalDBConfig)).To(Equal(expectedAgs))
		})
	})
})
