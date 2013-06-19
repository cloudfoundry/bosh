# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::JobPropertyValidator do
  before do
    File.stub(:read).with('/jobs/director/templates/director.yml.erb').and_return("---\nname: <%= p('director.name') %>")
    File.stub(:read).with('/jobs/blobstore/templates/blobstore.yml.erb').and_return("---\nprovider: <%= p('blobstore.provider') %>")
  end

  let(:director_job) do
    double(Bosh::Cli::JobBuilder,
           name: 'director',
           properties: {'director.name' =>
                            {'description' => 'Name of director'},
                        'director.port' =>
                            {'description' => 'Port that the director nginx listens on', 'default' => 25555}},
           all_templates: %w[/jobs/director/templates/director.yml.erb])
  end

  let(:blobstore_job) do
    double(Bosh::Cli::JobBuilder,
           name: 'blobstore',
           properties: {'blobstore.provider' =>
                            {'description' => 'Type of blobstore'}},
           all_templates: %w[/jobs/blobstore/templates/blobstore.yml.erb])
  end

  let(:built_jobs) do
    [director_job, blobstore_job]
  end

  let(:deployment_manifest) do
    {
        'properties' => deployment_properties,
        'jobs' => [{'name' => 'bosh',
                    'template' => job_template_list}]
    }
  end

  subject(:validator) { described_class.new(built_jobs, deployment_manifest) }

  context 'missing deployment manifest properties' do
    let(:deployment_properties) do
      {}
    end

    context 'colocated jobs' do
      let(:job_template_list) do
        %w[director blobstore]
      end

      it 'should have template errors' do
        validator.validate

        expect(validator.template_errors).to have(2).items
        expect(validator.template_errors.first.exception.to_s).to eq "Can't find property `[\"director.name\"]'"
        expect(validator.template_errors.last.exception.to_s).to eq "Can't find property `[\"blobstore.provider\"]'"
      end
    end

    context 'non-colocated jobs' do
      let(:job_template_list) { 'director' }

      it 'should have template errors' do
        validator.validate

        expect(validator.template_errors).to have(1).items
        expect(validator.template_errors.first.exception.to_s).to eq "Can't find property `[\"director.name\"]'"
      end
    end
  end

  context 'all deployment manifest properties defined' do
    let(:deployment_properties) do
      {
          'director'  => {'name' => 'foo'},
          'blobstore' => {'provider' => 's3'}
      }
    end

    let(:job_template_list) do
      %w[director blobstore]
    end

    it 'should not have template errors' do
      validator.validate

      expect(validator.template_errors).to be_empty
    end

    context 'with index' do
      before do
        File.stub(:read).with('/jobs/blobstore/templates/blobstore.yml.erb').and_return("---\nprovider: <%= index %>")
      end

      it 'should not have template errors' do
        validator.validate

        expect(validator.template_errors).to be_empty
      end
    end
  end

  context 'legacy job template with no properties' do
    let(:no_props_job) do
      double(Bosh::Cli::JobBuilder,
             name: 'noprops',
             properties: {},
             all_templates: [])
    end

    let(:built_jobs) do
      [director_job, no_props_job]
    end

    let(:job_template_list) do
      %w[director noprops]
    end

    let(:deployment_properties)do
      {}
    end

    it 'should identify legacy jobs with no properties' do
      validator.validate

      expect(validator.jobs_without_properties).to have(1).items
      expect(validator.jobs_without_properties.first.name).to eq 'noprops'
    end
  end
end
