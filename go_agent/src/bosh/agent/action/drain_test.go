package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	boshdrain "bosh/agent/drain"
	fakedrain "bosh/agent/drain/fakes"
	fakejobsuper "bosh/jobsupervisor/fakes"
	fakenotif "bosh/notification/fakes"
)

func init() {
	Describe("DrainAction", func() {
		var (
			notifier            *fakenotif.FakeNotifier
			specService         *fakeas.FakeV1Service
			drainScriptProvider *fakedrain.FakeDrainScriptProvider
			jobSupervisor       *fakejobsuper.FakeJobSupervisor
			action              DrainAction
		)

		BeforeEach(func() {
			notifier = fakenotif.NewFakeNotifier()
			specService = fakeas.NewFakeV1Service()
			drainScriptProvider = fakedrain.NewFakeDrainScriptProvider()
			jobSupervisor = fakejobsuper.NewFakeJobSupervisor()
			action = NewDrain(notifier, specService, drainScriptProvider, jobSupervisor)
		})

		BeforeEach(func() {
			drainScriptProvider.NewDrainScriptDrainScript.ExistsBool = true
		})

		It("is asynchronous", func() {
			Expect(action.IsAsynchronous()).To(BeTrue())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		Context("when drain update is requested", func() {
			act := func() (int, error) { return action.Run(DrainTypeUpdate, boshas.V1ApplySpec{}) }

			Context("when current agent has a job spec template", func() {
				var currentSpec boshas.V1ApplySpec

				BeforeEach(func() {
					currentSpec = boshas.V1ApplySpec{}
					currentSpec.JobSpec.Template = "foo"
					specService.Spec = currentSpec
				})

				It("unmonitors services so that drain scripts can kill processes on their own", func() {
					value, err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(1))

					Expect(jobSupervisor.Unmonitored).To(BeTrue())
				})

				Context("when unmonitoring services succeeds", func() {
					It("does not notify of job shutdown", func() {
						value, err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(value).To(Equal(1))

						Expect(notifier.NotifiedShutdown).To(BeFalse())
					})

					Context("when new apply spec is provided", func() {
						newSpec := boshas.V1ApplySpec{
							PackageSpecs: map[string]boshas.PackageSpec{
								"foo": boshas.PackageSpec{
									Name: "foo",
									Sha1: "foo-sha1-new",
								},
							},
						}

						Context("when drain script exists", func() {
							It("runs drain script with job_shutdown param", func() {
								value, err := action.Run(DrainTypeUpdate, newSpec)
								Expect(err).ToNot(HaveOccurred())
								Expect(value).To(Equal(1))

								Expect(drainScriptProvider.NewDrainScriptTemplateName).To(Equal("foo"))
								Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeTrue())

								params := drainScriptProvider.NewDrainScriptDrainScript.RunParams
								Expect(params).To(Equal(boshdrain.NewUpdateDrainParams(currentSpec, newSpec)))
							})

							Context("when drain script runs and errs", func() {
								It("returns error", func() {
									drainScriptProvider.NewDrainScriptDrainScript.RunError = errors.New("fake-drain-run-error")

									value, err := act()
									Expect(err).To(HaveOccurred())
									Expect(err.Error()).To(ContainSubstring("fake-drain-run-error"))
									Expect(value).To(Equal(0))
								})
							})
						})

						Context("when drain script does not exist", func() {
							It("returns 0", func() {
								drainScriptProvider.NewDrainScriptDrainScript.ExistsBool = false

								value, err := act()
								Expect(err).ToNot(HaveOccurred())
								Expect(value).To(Equal(0))

								Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeFalse())
							})
						})
					})

					Context("when apply spec is not provided", func() {
						It("returns error", func() {
							value, err := action.Run(DrainTypeUpdate)
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("Drain update requires new spec"))
							Expect(value).To(Equal(0))
						})
					})
				})

				Context("when unmonitoring services fails", func() {
					It("returns error", func() {
						jobSupervisor.UnmonitorErr = errors.New("fake-unmonitor-error")

						value, err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-unmonitor-error"))
						Expect(value).To(Equal(0))
					})
				})
			})

			Context("when current agent spec does not have a job spec template", func() {
				It("returns 0 and does not run drain script", func() {
					specService.Spec = boshas.V1ApplySpec{}

					value, err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(0))

					Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeFalse())
				})
			})
		})

		Context("when drain shutdown is requested", func() {
			act := func() (int, error) { return action.Run(DrainTypeShutdown) }

			Context("when current agent has a job spec template", func() {
				var currentSpec boshas.V1ApplySpec

				BeforeEach(func() {
					currentSpec = boshas.V1ApplySpec{}
					currentSpec.JobSpec.Template = "foo"
					specService.Spec = currentSpec
				})

				It("unmonitors services so that drain scripts can kill processes on their own", func() {
					value, err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(1))

					Expect(jobSupervisor.Unmonitored).To(BeTrue())
				})

				Context("when unmonitoring services succeeds", func() {
					It("notifies that job is about to shutdown", func() {
						value, err := act()
						Expect(err).ToNot(HaveOccurred())
						Expect(value).To(Equal(1))

						Expect(notifier.NotifiedShutdown).To(BeTrue())
					})

					Context("when job shutdown notification succeeds", func() {
						Context("when drain script exists", func() {
							It("runs drain script with job_shutdown param passing no apply spec", func() {
								value, err := action.Run(DrainTypeShutdown)
								Expect(err).ToNot(HaveOccurred())
								Expect(value).To(Equal(1))

								Expect(drainScriptProvider.NewDrainScriptTemplateName).To(Equal("foo"))
								Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeTrue())

								params := drainScriptProvider.NewDrainScriptDrainScript.RunParams
								Expect(params).To(Equal(boshdrain.NewShutdownDrainParams(currentSpec, nil)))
							})

							It("runs drain script with job_shutdown param passing in first apply spec", func() {
								newSpec := boshas.V1ApplySpec{}
								newSpec.JobSpec.Template = "fake-updated-template"

								value, err := action.Run(DrainTypeShutdown, newSpec)
								Expect(err).ToNot(HaveOccurred())
								Expect(value).To(Equal(1))

								Expect(drainScriptProvider.NewDrainScriptTemplateName).To(Equal("foo"))
								Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeTrue())

								params := drainScriptProvider.NewDrainScriptDrainScript.RunParams
								Expect(params).To(Equal(boshdrain.NewShutdownDrainParams(currentSpec, &newSpec)))
							})

							Context("when drain script runs and errs", func() {
								It("returns error", func() {
									drainScriptProvider.NewDrainScriptDrainScript.RunError = errors.New("fake-drain-run-error")

									value, err := act()
									Expect(err).To(HaveOccurred())
									Expect(err.Error()).To(ContainSubstring("fake-drain-run-error"))
									Expect(value).To(Equal(0))
								})
							})
						})

						Context("when drain script does not exist", func() {
							It("returns 0", func() {
								drainScriptProvider.NewDrainScriptDrainScript.ExistsBool = false

								value, err := act()
								Expect(err).ToNot(HaveOccurred())
								Expect(value).To(Equal(0))

								Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeFalse())
							})
						})
					})

					Context("when job shutdown notification fails", func() {
						It("returns error if job shutdown notifications errs", func() {
							notifier.NotifyShutdownErr = errors.New("fake-shutdown-error")

							value, err := act()
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("fake-shutdown-error"))
							Expect(value).To(Equal(0))
						})
					})
				})

				Context("when unmonitoring services fails", func() {
					It("returns error", func() {
						jobSupervisor.UnmonitorErr = errors.New("fake-unmonitor-error")

						value, err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-unmonitor-error"))
						Expect(value).To(Equal(0))
					})
				})
			})

			Context("when current agent spec does not have a job spec template", func() {
				It("returns 0 and does not run drain script", func() {
					specService.Spec = boshas.V1ApplySpec{}

					value, err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(0))

					Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeFalse())
				})
			})
		})

		Context("when drain status is requested", func() {
			act := func() (int, error) { return action.Run(DrainTypeStatus) }

			Context("when current agent has a job spec template", func() {
				var currentSpec boshas.V1ApplySpec

				BeforeEach(func() {
					currentSpec = boshas.V1ApplySpec{}
					currentSpec.JobSpec.Template = "foo"
					specService.Spec = currentSpec
				})

				It("unmonitors services so that drain scripts can kill processes on their own", func() {
					value, err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(1))

					Expect(jobSupervisor.Unmonitored).To(BeTrue())
				})

				It("does not notify of job shutdown", func() {
					value, err := act()
					Expect(err).ToNot(HaveOccurred())
					Expect(value).To(Equal(1))

					Expect(notifier.NotifiedShutdown).To(BeFalse())
				})

				Context("when unmonitoring services succeeds", func() {
					Context("when drain script exists", func() {
						It("runs drain script with job_check_status param passing no apply spec", func() {
							value, err := action.Run(DrainTypeStatus)
							Expect(err).ToNot(HaveOccurred())
							Expect(value).To(Equal(1))

							Expect(drainScriptProvider.NewDrainScriptTemplateName).To(Equal("foo"))
							Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeTrue())

							params := drainScriptProvider.NewDrainScriptDrainScript.RunParams
							Expect(params).To(Equal(boshdrain.NewStatusDrainParams(currentSpec, nil)))
						})

						It("runs drain script with job_check_status param passing in first apply spec", func() {
							newSpec := boshas.V1ApplySpec{}
							newSpec.JobSpec.Template = "fake-updated-template"

							value, err := action.Run(DrainTypeStatus, newSpec)
							Expect(err).ToNot(HaveOccurred())
							Expect(value).To(Equal(1))

							Expect(drainScriptProvider.NewDrainScriptTemplateName).To(Equal("foo"))
							Expect(drainScriptProvider.NewDrainScriptDrainScript.DidRun).To(BeTrue())

							params := drainScriptProvider.NewDrainScriptDrainScript.RunParams
							Expect(params).To(Equal(boshdrain.NewStatusDrainParams(currentSpec, &newSpec)))
						})

						Context("when drain script runs and errs", func() {
							It("returns error if drain script errs", func() {
								drainScriptProvider.NewDrainScriptDrainScript.RunError = errors.New("fake-drain-run-error")

								value, err := act()
								Expect(err).To(HaveOccurred())
								Expect(err.Error()).To(ContainSubstring("fake-drain-run-error"))
								Expect(value).To(Equal(0))
							})
						})
					})

					Context("when drain script does not exist", func() {
						It("returns error because drain status must be called after starting draining", func() {
							drainScriptProvider.NewDrainScriptDrainScript.ExistsBool = false

							value, err := act()
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("Check Status on Drain action requires a valid drain script"))
							Expect(value).To(Equal(0))
						})
					})
				})

				Context("when unmonitoring services fails", func() {
					It("returns error if unmonitoring services errs", func() {
						jobSupervisor.UnmonitorErr = errors.New("fake-unmonitor-error")

						value, err := act()
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-unmonitor-error"))
						Expect(value).To(Equal(0))
					})
				})
			})

			Context("when current agent spec does not have a job spec template", func() {
				It("returns error because drain status should only be called after starting draining", func() {
					specService.Spec = boshas.V1ApplySpec{}

					value, err := action.Run(DrainTypeStatus)
					Expect(err).To(HaveOccurred())
					Expect(err.Error()).To(ContainSubstring("Check Status on Drain action requires job spec"))
					Expect(value).To(Equal(0))
				})
			})
		})
	})
}
