require 'system/spec_helper'

describe 'initialization', :skip_task_check do
  describe 'environment requirements' do
    it 'should have a readable stemcell' do
      expect(File.exist?(@requirements.stemcell.to_path)).to be(true)
    end

    it 'should have readable releases' do
      expect(File.exist?(@requirements.release.to_path)).to be(true)
    end

    it 'should have a readable deployment' do
      load_deployment_spec
      with_deployment do |deployment|
        expect(File.exists?(deployment.to_path)).to be(true)
      end
    end

    it 'raises an argument error if one of the ENV vars are missing' do
      expect {
        Bat::Env.new({})
      }.to raise_error(ArgumentError)
    end
  end

  describe 'director' do
    it 'should be targetable' do
      expect(@bosh_runner.bosh("target #{@env.director}")).to succeed_with /Target \w*\s*set/
    end

    it 'should not have bat deployments' do
      deployments = @bosh_api.deployments
      expect(deployments).to_not have_key('bat')
      expect(deployments).to_not have_key('bat2')
    end

    it 'should fetch releases' do
      expect(@bosh_api.releases).to_not be_nil
    end

    it 'should fetch stemcells' do
      @bosh_api.stemcells.each { |s| expect(s).to_not be_nil }
    end
  end
end
