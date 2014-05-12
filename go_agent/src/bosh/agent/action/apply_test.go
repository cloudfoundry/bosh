package action_test

import (
	"errors"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "bosh/agent/action"
	boshas "bosh/agent/applier/applyspec"
	fakeas "bosh/agent/applier/applyspec/fakes"
	fakeappl "bosh/agent/applier/fakes"
)

func init() {
	Describe("ApplyAction", func() {
		var (
			applier     *fakeappl.FakeApplier
			specService *fakeas.FakeV1Service
			action      ApplyAction
		)

		BeforeEach(func() {
			applier = fakeappl.NewFakeApplier()
			specService = fakeas.NewFakeV1Service()
			action = NewApply(applier, specService)
		})

		It("apply should be asynchronous", func() {
			Expect(action.IsAsynchronous()).To(BeTrue())
		})

		It("is not persistent", func() {
			Expect(action.IsPersistent()).To(BeFalse())
		})

		Describe("Run", func() {
			Context("when desired spec has configuration hash", func() {
				currentApplySpec := boshas.V1ApplySpec{ConfigurationHash: "fake-current-config-hash"}
				desiredApplySpec := boshas.V1ApplySpec{ConfigurationHash: "fake-desired-config-hash"}
				resolvedDesiredApplySpec := boshas.V1ApplySpec{
					ConfigurationHash: "fake-resolved-desired-config-hash",
				}

				Context("when current spec can be retrieved", func() {
					BeforeEach(func() {
						specService.Spec = currentApplySpec
					})

					It("resolves dynamic networks in desired spec", func() {
						_, err := action.Run(desiredApplySpec)
						Expect(err).ToNot(HaveOccurred())
						Expect(specService.ResolveDynamicNetworksSpec).To(Equal(desiredApplySpec))
					})

					Context("when resolving dynamic networks succeeds", func() {
						BeforeEach(func() {
							specService.ResolveDynamicNetworksResultSpec = resolvedDesiredApplySpec
						})

						It("runs applier with resolved desired spec", func() {
							_, err := action.Run(desiredApplySpec)
							Expect(err).ToNot(HaveOccurred())
							Expect(applier.Applied).To(BeTrue())
							Expect(applier.ApplyCurrentApplySpec).To(Equal(currentApplySpec))
							Expect(applier.ApplyDesiredApplySpec).To(Equal(resolvedDesiredApplySpec))
						})

						Context("when applier succeeds applying desired spec", func() {
							Context("when saving desires spec as current spec succeeds", func() {
								It("returns 'applied' after setting resolved desired spec as current spec", func() {
									value, err := action.Run(desiredApplySpec)
									Expect(err).ToNot(HaveOccurred())
									Expect(value).To(Equal("applied"))

									Expect(specService.Spec).To(Equal(resolvedDesiredApplySpec))
								})
							})

							Context("when saving resolved desires spec as current spec fails", func() {
								It("returns error because agent was not able to remember that is converged to desired spec", func() {
									specService.SetErr = errors.New("fake-set-error")

									_, err := action.Run(desiredApplySpec)
									Expect(err).To(HaveOccurred())
									Expect(err.Error()).To(ContainSubstring("fake-set-error"))
								})
							})
						})

						Context("when applier fails applying desired spec", func() {
							BeforeEach(func() {
								applier.ApplyError = errors.New("fake-apply-error")
							})

							It("returns error", func() {
								_, err := action.Run(desiredApplySpec)
								Expect(err).To(HaveOccurred())
								Expect(err.Error()).To(ContainSubstring("fake-apply-error"))
							})

							It("does not save desired spec as current spec", func() {
								_, err := action.Run(desiredApplySpec)
								Expect(err).To(HaveOccurred())
								Expect(specService.Spec).To(Equal(currentApplySpec))
							})
						})
					})

					Context("when resolving dynamic networks fails", func() {
						BeforeEach(func() {
							specService.ResolveDynamicNetworksErr = errors.New("fake-resolve-dynamic-networks-err")
						})

						It("returns error", func() {
							_, err := action.Run(desiredApplySpec)
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("fake-resolve-dynamic-networks-err"))
						})

						It("does not apply desired spec as current spec", func() {
							_, err := action.Run(desiredApplySpec)
							Expect(err).To(HaveOccurred())
							Expect(applier.Applied).To(BeFalse())
						})

						It("does not save desired spec as current spec", func() {
							_, err := action.Run(desiredApplySpec)
							Expect(err).To(HaveOccurred())
							Expect(specService.Spec).To(Equal(currentApplySpec))
						})
					})
				})

				Context("when current spec cannot be retrieved", func() {
					BeforeEach(func() {
						specService.Spec = currentApplySpec
						specService.GetErr = errors.New("fake-get-error")
					})

					It("returns error and does not apply desired spec", func() {
						_, err := action.Run(desiredApplySpec)
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-get-error"))
					})

					It("does not run applier with desired spec", func() {
						_, err := action.Run(desiredApplySpec)
						Expect(err).To(HaveOccurred())
						Expect(applier.Applied).To(BeFalse())
					})

					It("does not save desired spec as current spec", func() {
						_, err := action.Run(desiredApplySpec)
						Expect(err).To(HaveOccurred())
						Expect(specService.Spec).To(Equal(currentApplySpec))
					})
				})
			})

			Context("when desired spec does not have a configuration hash", func() {
				desiredApplySpec := boshas.V1ApplySpec{
					JobSpec: boshas.JobSpec{
						Template: "fake-job-template",
					},
				}

				resolvedDesiredApplySpec := boshas.V1ApplySpec{
					JobSpec: boshas.JobSpec{
						Template: "fake-resolved-job-template",
					},
				}

				It("resolves dynamic networks in desired spec", func() {
					_, err := action.Run(desiredApplySpec)
					Expect(err).ToNot(HaveOccurred())
					Expect(specService.ResolveDynamicNetworksSpec).To(Equal(desiredApplySpec))
				})

				Context("when resolving dynamic networks succeeds", func() {
					BeforeEach(func() {
						specService.ResolveDynamicNetworksResultSpec = resolvedDesiredApplySpec
					})

					Context("when saving desires spec as current spec succeeds", func() {
						It("returns 'applied' after setting desired spec as current spec", func() {
							value, err := action.Run(desiredApplySpec)
							Expect(err).ToNot(HaveOccurred())
							Expect(value).To(Equal("applied"))

							Expect(specService.Spec).To(Equal(resolvedDesiredApplySpec))
						})

						It("does not try to apply desired spec since it does not have jobs and packages", func() {
							_, err := action.Run(desiredApplySpec)
							Expect(err).ToNot(HaveOccurred())
							Expect(applier.Applied).To(BeFalse())
						})
					})

					Context("when saving desires spec as current spec fails", func() {
						BeforeEach(func() {
							specService.SetErr = errors.New("fake-set-error")
						})

						It("returns error because agent was not able to remember that is converged to desired spec", func() {
							_, err := action.Run(desiredApplySpec)
							Expect(err).To(HaveOccurred())
							Expect(err.Error()).To(ContainSubstring("fake-set-error"))
						})

						It("does not try to apply desired spec since it does not have jobs and packages", func() {
							_, err := action.Run(desiredApplySpec)
							Expect(err).To(HaveOccurred())
							Expect(applier.Applied).To(BeFalse())
						})
					})
				})

				Context("when resolving dynamic networks fails", func() {
					BeforeEach(func() {
						specService.ResolveDynamicNetworksErr = errors.New("fake-resolve-dynamic-networks-err")
					})

					It("returns error", func() {
						_, err := action.Run(desiredApplySpec)
						Expect(err).To(HaveOccurred())
						Expect(err.Error()).To(ContainSubstring("fake-resolve-dynamic-networks-err"))
					})

					It("does not apply desired spec as current spec", func() {
						_, err := action.Run(desiredApplySpec)
						Expect(err).To(HaveOccurred())
						Expect(applier.Applied).To(BeFalse())
					})

					It("does not save desired spec as current spec", func() {
						_, err := action.Run(desiredApplySpec)
						Expect(err).To(HaveOccurred())
						Expect(specService.Spec).ToNot(Equal(desiredApplySpec))
					})
				})
			})
		})
	})
}
