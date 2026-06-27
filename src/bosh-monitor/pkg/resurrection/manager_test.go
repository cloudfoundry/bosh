package resurrection_test

import (
	"log/slog"
	"os"

	"github.com/cloudfoundry/bosh/src/bosh-monitor/pkg/resurrection"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("ResurrectionManager", func() {
	var (
		manager *resurrection.Manager
		logger  *slog.Logger
	)

	BeforeEach(func() {
		logger = slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
		manager = resurrection.NewManager(logger)
	})

	Describe("ResurrectionEnabled", func() {
		It("returns true by default", func() {
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeTrue())
		})

		It("returns false when disabled by rule", func() {
			configs := []map[string]interface{}{
				{
					"content": "rules:\n  - enabled: false\n",
				},
			}
			manager.UpdateRules(configs)
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeFalse())
		})

		It("returns true when enabled by rule", func() {
			configs := []map[string]interface{}{
				{
					"content": "rules:\n  - enabled: true\n",
				},
			}
			manager.UpdateRules(configs)
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeTrue())
		})

		It("filters by deployment name", func() {
			configs := []map[string]interface{}{
				{
					"content": "rules:\n  - enabled: false\n    include:\n      deployments:\n        - dep-1\n",
				},
			}
			manager.UpdateRules(configs)
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeFalse())
			Expect(manager.ResurrectionEnabled("dep-2", "web")).To(BeTrue())
		})

		It("filters by instance group", func() {
			configs := []map[string]interface{}{
				{
					"content": "rules:\n  - enabled: false\n    include:\n      instance_groups:\n        - web\n",
				},
			}
			manager.UpdateRules(configs)
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeFalse())
			Expect(manager.ResurrectionEnabled("dep-1", "worker")).To(BeTrue())
		})

		It("handles exclude filters", func() {
			configs := []map[string]interface{}{
				{
					"content": "rules:\n  - enabled: false\n    exclude:\n      deployments:\n        - dep-2\n",
				},
			}
			manager.UpdateRules(configs)
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeFalse())
			Expect(manager.ResurrectionEnabled("dep-2", "web")).To(BeTrue())
		})
	})

	Describe("UpdateRules", func() {
		It("does nothing with nil configs", func() {
			manager.UpdateRules(nil)
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeTrue())
		})

		It("does not re-parse unchanged configs", func() {
			configs := []map[string]interface{}{
				{"content": "rules:\n  - enabled: false\n"},
			}
			manager.UpdateRules(configs)
			manager.UpdateRules(configs)
			Expect(manager.ResurrectionEnabled("dep-1", "web")).To(BeFalse())
		})
	})

	Describe("ParseRule", func() {
		It("returns error when enabled is missing", func() {
			_, err := resurrection.ParseRule(map[string]interface{}{})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("required property 'enabled'"))
		})

		It("returns error when enabled is not boolean", func() {
			_, err := resurrection.ParseRule(map[string]interface{}{"enabled": "yes"})
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("did not match the required type 'Boolean'"))
		})

		It("parses valid rule", func() {
			rule, err := resurrection.ParseRule(map[string]interface{}{
				"enabled": true,
				"include": map[string]interface{}{
					"deployments": []interface{}{"dep-1"},
				},
			})
			Expect(err).NotTo(HaveOccurred())
			Expect(rule.Enabled).To(BeTrue())
			Expect(rule.Applies("dep-1", "web")).To(BeTrue())
			Expect(rule.Applies("dep-2", "web")).To(BeFalse())
		})
	})
})
