require 'spec_helper'
require 'bosh/dev/gem_component'
require 'timecop'

module Bosh::Dev
  describe GemComponent do
    let(:root) { Dir.mktmpdir }
    let(:component_version_file) { "#{root}/fake-component/lib/fake/component/version.rb" }

    subject(:gem_component) do
      GemComponent.new('fake-component', '1.1234.0')
    end

    before do
      stub_const('Bosh::Dev::GemComponent::ROOT', root)

      Rake::FileUtilsExt.stub(:sh)
    end

    after do
      FileUtils.rm_rf(root)
    end

    its(:dot_gem) { should eq('fake-component-1.1234.0.gem') }

    describe '#build_gem' do
      include FakeFS::SpecHelpers

      before do
        File.stub(read: '1.5.0.pre.3') # old version
        File.stub(:open)
      end

      it 'shells out to build the gem' do
        Rake::FileUtilsExt.should_receive(:sh).with('cd fake-component && ' +
                                                    'gem build fake-component.gemspec && ' +
                                                    'mv fake-component-1.1234.0.gem fake-destination-dir')

        gem_component.build_gem('fake-destination-dir')
      end
    end

    describe '#update_version' do
      before do
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

      it 'set the components version to the given version' do
        expect {
          gem_component.update_version
        }.to change { File.read(component_version_file) }.to <<-RUBY.gsub /^\s+/, ''
              module Fake::Component
                VERSION = '1.1234.0'
              end
        RUBY
      end
    end

    describe '#dependencies' do
      subject(:gem_component) do
        GemComponent.new('bosh-core', '1.0000.0')
      end

      before do
        File.open(File.join(root, 'Gemfile.lock'), 'w+') do |f|
          f.write <<-GEMFILE
PATH
  remote: bosh-core
  specs:
    bosh-core (1.0000.0)
      gibberish
      yajl-ruby

PLATFORMS
  ruby

DEPENDENCIES
  bosh-core!
          GEMFILE
        end
      end

      it 'returns dependencies specified in Gemfile.lock' do
        expect(gem_component.dependencies.map(&:name)).to eq(
          %w(gibberish yajl-ruby bosh-core)
        )
      end
    end
  end
end
