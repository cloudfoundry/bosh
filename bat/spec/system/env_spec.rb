# Copyright (c) 2012 VMware, Inc.

require 'system/spec_helper'

describe 'initialization', :skip_task_check do
  describe 'environment' do
    %w[
      BAT_DIRECTOR
      BAT_STEMCELL
      BAT_DEPLOYMENT_SPEC
      BAT_VCAP_PASSWORD
      BAT_DNS_HOST
    ].each do |var|
      it "should have #{var} set" do
        ENV[var].should_not be_nil
      end
    end

    describe 'requirements' do
      it 'should have bosh cli installed' do
        %x{#{bosh_bin} --version}.should match /BOSH \d+\.\d+/
      end

      it 'should have a readable stemcell' do
        File.exist?(stemcell.to_path).should be(true)
      end

      it 'should have readable releases' do
        File.exist?(release.to_path).should be(true)
      end

      it 'should have a readable deployment' do
        load_deployment_spec
        with_deployment do |deployment|
          File.exists?(deployment.to_path).should be(true)
        end
      end
    end
  end

  describe 'director' do
    it 'should be targetable' do
      bosh("target #{bosh_director}").should succeed_with /Target \w*\s*set/
    end

    xit 'should not have bat deployments' do
      deployments.should_not have_key('bat')
      deployments.should_not have_key('bat2')
    end

    it 'should fetch releases' do
      releases.should_not be_nil
    end

    it 'should fetch stemcells' do
      stemcells.each { |s| s.should_not be_nil }
    end
  end
end
