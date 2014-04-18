package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	boshsys "bosh/system"
	fakesys "bosh/system/fakes"
)

var _ = Describe("RunErrand", func() {
	var (
		specService *fakeas.FakeV1Service
		cmdRunner   *fakesys.FakeCmdRunner
		action      RunErrandAction
	)

	BeforeEach(func() {
		specService = fakeas.NewFakeV1Service()
		cmdRunner = fakesys.NewFakeCmdRunner()
		action = NewRunErrand(specService, "/fake-jobs-dir", cmdRunner)
	})

	It("is asynchronous", func() {
		Expect(action.IsAsynchronous()).To(BeTrue())
	})

	It("is not persistent", func() {
		Expect(action.IsPersistent()).To(BeFalse())
	})

	Describe("Run", func() {
		Context("when apply spec is successfully retrieved", func() {
			Context("when current agent has a job spec template", func() {
				BeforeEach(func() {
					currentSpec := boshas.V1ApplySpec{}
					currentSpec.JobSpec.Template = "fake-job-name"
					specService.Spec = currentSpec
				})

				Context("when errand script exits with non-0 exit code (execution of script is ok)", func() {
					BeforeEach(func() {
						cmdRunner.AddCmdResult(
							"/fake-jobs-dir/fake-job-name/bin/run",
							fakesys.FakeCmdResult{
								Stdout:     "fake-stdout",
								Stderr:     "fake-stderr",
								ExitStatus: 0,
							},
						)
					})

					It("returns errand result without error after running an errand", func() {
						result, err := action.Run()
						Expect(err).ToNot(HaveOccurred())
						Expect(result).To(Equal(
							ErrandResult{
								Stdout:     "fake-stdout",
								Stderr:     "fake-stderr",
								ExitStatus: 0,
							},
						))
					})

					It("runs errand script with properly configured environment", func() {
						_, err := action.Run()
						Expect(err).ToNot(HaveOccurred())
						Expect(cmdRunner.RunComplexCommands).To(Equal([]boshsys.Command{
							boshsys.Command{
								Name: "/fake-jobs-dir/fake-job-name/bin/run",
								Env: map[string]string{
									"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
								},
							},
						}))
					})
				})

				Context("when errand script fails with non-0 exit code (execution of script is ok)", func() {
					BeforeEach(func() {
						cmdRunner.AddCmdResult(
							"/fake-jobs-dir/fake-job-name/bin/run",
							fakesys.FakeCmdResult{
								Stdout:     "fake-stdout",
								Stderr:     "fake-stderr",
								ExitStatus: 123,
								Error:      errors.New("fake-bosh-error"), // not used
							},
						)
					})

					It("returns errand result without an error", func() {
						result, err := action.Run()
						Expect(err).ToNot(HaveOccurred())
						Expect(result).To(Equal(
							ErrandResult{
								Stdout:     "fake-stdout",
								Stderr:     "fake-stderr",
								ExitStatus: 123,
							},
						))
					})
				})

				Context("when errand script fails to execute", func() {
					BeforeEach(func() {
						cmdRunner.AddCmdResult(
							"/fake-jobs-dir/fake-job-name/bin/run",
							fakesys.FakeCmdResult{
								ExitStatus: -1,
								Error:      errors.New("fake-bosh-error"),
							},
						)
					})

					It("returns error because script failed to execute", func() {
						result, err := action.Run()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-bosh-error"))
						Expect(result).To(Equal(ErrandResult{}))
					})
				})
			})

			Context("when current agent spec does not have a job spec template", func() {
				BeforeEach(func() {
					specService.Spec = boshas.V1ApplySpec{}
				})

				It("returns error stating that job template is required", func() {
					_, err := action.Run()
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(Equal("At least one job template is required to run an errand"))
				})

				It("does not run errand script", func() {
					_, err := action.Run()
					Expect(err).To(HaveOccurred())
					Expect(len(cmdRunner.RunComplexCommands)).To(Equal(0))
				})
			})
		})

		Context("when apply spec could not be retrieved", func() {
			BeforeEach(func() {
				specService.GetErr = errors.New("fake-get-error")
			})

			It("returns error stating that job template is required", func() {
				_, err := action.Run()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("fake-get-error"))
			})

			It("does not run errand script", func() {
				_, err := action.Run()
				Expect(err).To(HaveOccurred())
				Expect(len(cmdRunner.RunComplexCommands)).To(Equal(0))
			})
		})
	})
})
