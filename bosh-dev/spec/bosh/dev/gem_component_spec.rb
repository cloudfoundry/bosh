require 'spec_helper'
require 'bosh/dev/gem_component'

module Bosh::Dev
  describe GemComponent do
    let(:root) { Dir.mktmpdir }
    let(:global_bosh_version_file) { "#{root}/BOSH_VERSION" }
    let(:component_version_file) { "#{root}/fake-component/lib/fake/component/version.rb" }

    subject(:gem_component) do
      GemComponent.new('fake-component')
    end

    describe '#update_version' do
      before do
        gem_component.stub(root: root)

        File.open(global_bosh_version_file, 'w') do |file|
          file.write('fake-bosh-version')
        end

        FileUtils.mkdir_p(File.dirname(component_version_file))
        File.open(component_version_file, 'w') do |file|
          file.write <<-RUBY.gsub /^\s+/, ''
            module Fake::Component
              VERSION = '1.5.0.pre.3'
            end
          RUBY
        end
      end

      after do
        FileUtils.rm_r(root)
      end

      it "set the component's version to the global BOSH_VERSION" do
        expect {
          gem_component.update_version
        }.to change { File.read(component_version_file) }.to <<-RUBY.gsub /^\s+/, ''
              module Fake::Component
                VERSION = 'fake-bosh-version'
              end
        RUBY
      end
    end
  end
end
