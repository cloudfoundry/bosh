package nginx_load_tests

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/onsi/gomega/gexec"
	"github.com/rcrowley/go-metrics"
)

var _ = Describe("Nginx load tests", func() {
	Context("blobstore nginx", func() {
		Context("a sample of 1000 dns records in the blobstore", func() {
			var davcliConfigPath string
			var recordsFilePath, recordsFileMD5 string
			var blobstorePath = "randomPath"

			BeforeEach(func() {
				var err error

				davcliConfigPath = writeTempFile(
					[]byte(fmt.Sprintf(`{"user":"%s","password":"%s","endpoint":"%s"}`, "agent", agentPassword, fmt.Sprintf("http://%s:25250", directorIp))),
					"davcli-config",
				)

				recordsFilePath, recordsFileMD5 = generateAndWriteRecords()

				session, err := gexec.Start(exec.Command(davcliPath, "-c", davcliConfigPath, "put", recordsFilePath, blobstorePath), GinkgoWriter, GinkgoWriter)
				Expect(err).ToNot(HaveOccurred())
				Eventually(session).Should(gexec.Exit(0))
			})

			AfterEach(func(){
				os.Remove(recordsFilePath)
				os.Remove(davcliConfigPath)
			})

			Context("when 1000 clients download the file in parallel", func() {
				act := func() time.Duration {
					defer func() {
						session, err := gexec.Start(exec.Command("/bin/bash", "-c", "find /tmp -name xargs-* -delete"), GinkgoWriter, GinkgoWriter)
						Expect(err).ToNot(HaveOccurred())
						Eventually(session, 10*time.Second).Should(gexec.Exit(0))
					}()

					timeStart := time.Now()

					session, err := gexec.Start(exec.Command(
						"/bin/bash", "-c",
						fmt.Sprintf("seq 1 1000 | xargs -n1 -P1000 -I{} -- %s -c %s get %s /tmp/xargs-{}", davcliPath, davcliConfigPath, blobstorePath),
					), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 20*time.Second).Should(gexec.Exit(0))

					timeStop := time.Now()

					duration := timeStop.Sub(timeStart)

					// checksum all the download and make sure it is what we expect
					session, err = gexec.Start(exec.Command("/bin/bash", "-c", "find /tmp -name xargs-* | xargs -n1 md5sum | awk '{ print $1 }' | sort | uniq -c"), GinkgoWriter, GinkgoWriter)
					Expect(err).ToNot(HaveOccurred())
					Eventually(session, 10*time.Second).Should(gexec.Exit(0))

					Expect(session.Out.Contents()).To(Equal([]byte(fmt.Sprintf("   %d %s\n", 1000, recordsFileMD5))))

					return duration
				}

				It("consistently downloads quickly", func() {
					timeHistogram := metrics.NewHistogram(metrics.NewUniformSample(10))

					for i := 1; i <= 10; i++ {
						duration := act()

						timeHistogram.Update(duration.Nanoseconds())
					}

					printStatsForHistogram(timeHistogram, "1000 Concurrent Downloads", "ms", 1000*1000)

					pct95Time := timeHistogram.Percentile(0.95) / (1000 * 1000)
					maxTime := timeHistogram.Max()

					Expect(pct95Time).To(BeNumerically("<", 8*time.Second.Nanoseconds()))
					Expect(maxTime).To(BeNumerically("<", 12*time.Second.Nanoseconds()))
				})
			})
		})
	})
})

func generateAndWriteRecords() (string, string) {
	recordsCollection := [][]string{}

	records := struct {
		RecordKeys  []string   `json:"record_keys"`
		RecordInfos [][]string `json:"record_infos"`
	}{
		RecordKeys:  []string{"id", "instance_group", "az", "network", "deployment", "ip", "domain"},
		RecordInfos: recordsCollection,
	}

	for i := 1; i <= 1000; i++ {
		records.RecordInfos = append(
			records.RecordInfos,
			[]string{
				fmt.Sprintf("id-%d", i),
				fmt.Sprintf("my-group-%d", i%6),
				"az1",
				"another-network",
				"my-deployment",
				fmt.Sprintf("123.123.123.%d", i%255),
				"my-bosh",
			},
		)
	}

	recordsJSON, err := json.Marshal(records)
	Expect(err).ToNot(HaveOccurred())

	recordsFilePath := writeTempFile(recordsJSON, "records")

	md5hasher := md5.New()
	md5hasher.Write(recordsJSON)

	return recordsFilePath, hex.EncodeToString(md5hasher.Sum([]byte{}))
}

// https://github.com/cloudfoundry/dns-release/blob/072ee11d3bd2cacf2e790176109253adc716640c/src/performance_tests/performance_test.go#L183
func printStatsForHistogram(hist metrics.Histogram, label string, unit string, scalingDivisor float64) {
	fmt.Printf("\n~~~~~~~~~~~~~~~%s~~~~~~~~~~~~~~~\n", label)
	printStatNamed("Median", hist.Percentile(0.5)/scalingDivisor, unit)
	printStatNamed("Mean", hist.Mean()/scalingDivisor, unit)
	printStatNamed("Max", float64(hist.Max())/scalingDivisor, unit)
	printStatNamed("Min", float64(hist.Min())/scalingDivisor, unit)
	printStatNamed("Std Deviation", hist.StdDev()/scalingDivisor, unit)
	printStatNamed("90th Percentile", hist.Percentile(0.9)/scalingDivisor, unit)
	printStatNamed("95th Percentile", hist.Percentile(0.95)/scalingDivisor, unit)
	printStatNamed("99th Percentile", hist.Percentile(0.99)/scalingDivisor, unit)
	fmt.Printf("Samples: %d\n", hist.Count())
	fmt.Println("")
}

func printStatNamed(label string, value float64, unit string) {
	fmt.Printf("%s: %3.3f%s\n", label, value, unit)
}
