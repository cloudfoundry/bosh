package certs_test

import (
	"fmt"
	"os"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/bosh-credentials-info/certs"

	fakesys "github.com/cloudfoundry/bosh-utils/system/fakes"
)

var validCert = `-----BEGIN CERTIFICATE-----
MIIEijCCAvKgAwIBAgIRAKlv5BEguA9GrlrfUVeWwAcwDQYJKoZIhvcNAQELBQAw
TjEMMAoGA1UEBhMDVVNBMRYwFAYDVQQKEw1DbG91ZCBGb3VuZHJ5MSYwJAYDVQQD
Ex1kZWZhdWx0Lm5hdHMtY2EuYm9zaC1pbnRlcm5hbDAeFw0xODExMjEyMTQzNTha
Fw0xOTExMjEyMTQzNThaME4xDDAKBgNVBAYTA1VTQTEWMBQGA1UEChMNQ2xvdWQg
Rm91bmRyeTEmMCQGA1UEAxMdZGVmYXVsdC5uYXRzLWNhLmJvc2gtaW50ZXJuYWww
ggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQDTM7eDeiesG1zZKGHWZdSd
ZQMun/LmVwRCVlLFoutJj+78xoujrh0hMzQ1nHXsvI7kEmlvQfo1KmYTmWpiIgG9
pVXHcsZgwDU+9ZCf4zrl0bTVHLLpkUX1c7FW2ptu1CxLdS8tp9Shk1OMqKL1oYcz
63rVww1nso5nHZDt0Ew81fBdWLk34GPST9RlEUXh7r7IetInA9V1p/65hljj1gsG
wIoqOdpdw3xj9BFt3TxUGtYdeC4PfVyxBl2I7w4w9PDTY84LSnGo6HDSBW43iU4k
x1Cu922G265IMf4w2be51ZyoCkZnHOjb+Wo66ePfJ0Qg7bPHhZuNoqY4df6HAGyn
MPQWJPORT3+/Ri6LLOTF1tghLGjBzWNaAkzfmAPHcCWgWc5WHwlTxmBPYtrts1Vg
9ibOAdcaWz7S4n7FVk7Dh8Npi7RF0Ho8o6MDbcSDDowqlLqXYmieqzAjfCPKNtvk
M5cJ4RCAtG5Po15JOE4HshwfE6gbc5yyLi8RcuWXacUCAwEAAaNjMGEwDgYDVR0P
AQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFAgZx38UBXPQmtHU
622eUCkz/97AMB8GA1UdIwQYMBaAFAgZx38UBXPQmtHU622eUCkz/97AMA0GCSqG
SIb3DQEBCwUAA4IBgQDK6RJOG5AyaAi0VfPJiS1wX3J50mk6ui9krPUTrsE1pmSe
jkluGVPtN66RWXggRjIvnV6C8ICKEOpkwvm2AHkWIxwjM9v76cWCoJs9iYX+BVr8
IVOlkG/UY0rh6KIOEvS6dKgZbqSTtd1GB6iwini/BUSyIFQmYaDVrzjO/I6RAEnB
HVWWM+yJ7uekKf55krQ85LuXIJYg/KugGyM3rnmiDu8unemSeUYDllJaPimxAsTO
rZFz7paCLh5SF4ntNBsymO55vL2NTRE/D7PtUd41yQjGUlJmxzvEFdRUPo/1fcS4
VluN6ZrYe5iS39c3o72T+dgLxWBo4XL8Ynfet6CD+BkZKTO8H0v2zKDhnq6tlvMu
QqoEHFQ6x7sEn+SAACpV4Z+MMaWtrnzfG96DyyTtk1M1MLQowTjown4orABSuNn9
5ka/AP3rwlh66oK1ktwmClpnNPkUumj9wPtyPS/AH04IjeIKfqO9JTPKg0VdEfOT
LYlKT1StItAfXfZyfZs=
-----END CERTIFICATE-----
`

var _ = Describe("Decoder", func() {
	var (
		DIRS = []string{
			"blobstore",
			"director",
			"nats",
			"db",
		}
		PROPERTIES = []string{
			"blobstore.tls.cert.ca",
			"director.config_server.ca_cert",
			"director.config_server.uaa.ca_cert",
			"nats.tls.ca",
			"nats.tls.client_ca.certificate",
			"nats.tls.director.certificate",
			"director.db.tls.cert.ca",
			"director.db.tls.cert.certificate",
		}
		fs *fakesys.FakeFileSystem
	)

	BeforeEach(func(){
		fs = fakesys.NewFakeFileSystem()
		for _, dir := range DIRS {
			err := fs.MkdirAll(jobPath(dir), os.ModeDir)
			Expect(err).NotTo(HaveOccurred())
		}
	})

	Context("GetJobCertificates", func() {
		Describe("When file exists", func(){
			Describe("When the file contents invalid yml", func(){
				BeforeEach(func() {
					certsFileContent := "certs.test : |\nTHIS NO WORK"
					err := fs.WriteFileString(certFilePath(DIRS[1]), certsFileContent)
					Expect(err).NotTo(HaveOccurred())
				})

				It("Returns an error", func(){
					path := certFilePath(DIRS[1])
					result, err := certs.GetJobCertificates(path, fs)
					Expect(result).To(BeEmpty())
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring(fmt.Sprintf("Unmarshaling yml for %s file failed", path)))
				})
			})

			Describe("When the file contents are valid yml", func(){
				BeforeEach(func() {
					certsFileContent := ""
					for _, prop := range PROPERTIES {
						certsFileContent = certsFileContent + "\n" + fakeCert(prop, true)
					}

					err := fs.WriteFileString(certFilePath(DIRS[1]), certsFileContent)
					Expect(err).NotTo(HaveOccurred())
				})

				It("Returns all the properties found in the file", func(){
					result, err := certs.GetJobCertificates(certFilePath(DIRS[1]), fs)
					Expect(err).ToNot(HaveOccurred())
					Expect(len(result)).To(Equal(8))

					for k, _ := range result {
						Expect(result).To(HaveKeyWithValue(k, validCert))
					}
				})
			})
		})

		Describe("When file doesn't exist", func(){
			It("Retuns an error", func(){
				filePath := fmt.Sprintf("%s/%s/%s/%s", certs.BASE_JOB_DIR, DIRS[3], certs.CONFIG_DIR, certs.CERTS_FILE_NAME)

				results, err := certs.GetJobCertificates(filePath, fs)

				Expect(results).To(BeEmpty())
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal(fmt.Sprintf("File %s not found", filePath)))
			})
		})
	})

	Context("GetCertExpiryDate", func() {
		Describe("when certificate can't be decoded", func(){
			It("should show an error", func() {
				cert := "anInvalidCert"
				_, err := certs.GetCertExpiryDate(cert)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(Equal("failed to decode certificate"))
			})
		})

		Describe("when certificate is not a valid x509", func() {
			It("should show an error", func() {
				invalidCert:=`-----BEGIN CERTIFICATE-----
DestroyCAvKgAwIBAgIRAKlv5BEguA9GrlrfUVeWwAcwDQYJKoZIhvcNAQELBQAw
TjEMMAoGA1UEBhMDVVNBMRYwFAYDVQQKEw1DbG91ZCBGb3VuZHJ5MSYwJAYDVQQD
Ex1kZWZhdWx0Lm5hdHMtY2EuYm9zaC1pbnRlcm5hbDAeFw0xODExMjEyMTQzNTha
Fw0xOTExMjEyMTQzNThaME4xDDAKBgNVBAYTA1VTQTEWMBQGA1UEChMNQ2xvdWQg
Rm91bmRyeTEmMCQGA1UEAxMdZGVmYXVsdC5uYXRzLWNhLmJvc2gtaW50ZXJuYWww
ggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQDTM7eDeiesG1zZKGHWZdSd
ZQMun/LmVwRCVlLFoutJj+78xoujrh0hMzQ1nHXsvI7kEmlvQfo1KmYTmWpiIgG9
pVXHcsZgwDU+9ZCf4zrl0bTVHLLpkUX1c7FW2ptu1CxLdS8tp9Shk1OMqKL1oYcz
63rVww1nso5nHZDt0Ew81fBdWLk34GPST9RlEUXh7r7IetInA9V1p/65hljj1gsG
wIoqOdpdw3xj9BFt3TxUGtYdeC4PfVyxBl2I7w4w9PDTY84LSnGo6HDSBW43iU4k
x1Cu922G265IMf4w2be51ZyoCkZnHOjb+Wo66ePfJ0Qg7bPHhZuNoqY4df6HAGyn
MPQWJPORT3+/Ri6LLOTF1tghLGjBzWNaAkzfmAPHcCWgWc5WHwlTxmBPYtrts1Vg
9ibOAdcaWz7S4n7FVk7Dh8Npi7RF0Ho8o6MDbcSDDowqlLqXYmieqzAjfCPKNtvk
M5cJ4RCAtG5Po15JOE4HshwfE6gbc5yyLi8RcuWXacUCAwEAAaNjMGEwDgYDVR0P
AQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFAgZx38UBXPQmtHU
622eUCkz/97AMB8GA1UdIwQYMBaAFAgZx38UBXPQmtHU622eUCkz/97AMA0GCSqG
SIb3DQEBCwUAA4IBgQDK6RJOG5AyaAi0VfPJiS1wX3J50mk6ui9krPUTrsE1pmSe
jkluGVPtN66RWXggRjIvnV6C8ICKEOpkwvm2AHkWIxwjM9v76cWCoJs9iYX+BVr8
IVOlkG/UY0rh6KIOEvS6dKgZbqSTtd1GB6iwini/BUSyIFQmYaDVrzjO/I6RAEnB
HVWWM+yJ7uekKf55krQ85LuXIJYg/KugGyM3rnmiDu8unemSeUYDllJaPimxAsTO
rZFz7paCLh5SF4ntNBsymO55vL2NTRE/D7PtUd41yQjGUlJmxzvEFdRUPo/1fcS4
VluN6ZrYe5iS39c3o72T+dgLxWBo4XL8Ynfet6CD+BkZKTO8H0v2zKDhnq6tlvMu
Destroy6x7sEn+SAACpV4Z+MMaWtrnzfG96DyyTtk1M1MLQowTjown4orABSuNn9
Destroyrwlh66oK1ktwmClpnNPkUumj9wPtyPS/AH04IjeIKfqO9JTPKg0VdEfOT
LYlDestroyAfXfZyfZs=
-----END CERTIFICATE-----
`

				_, err := certs.GetCertExpiryDate(invalidCert)
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("failed to parse certificate"))
			})
		})

		Describe("When certificate is valid", func(){
			It("returns the certificate's expiry date in Unix Epoch format", func(){
				result, err := certs.GetCertExpiryDate(validCert)

				Expect(err).ToNot(HaveOccurred())
				Expect(result).To(Equal(time.Date(2019, 11, 21, 21, 43, 58, 0, time.UTC)))

			})
		})
	})
})