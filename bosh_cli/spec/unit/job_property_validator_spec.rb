# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::JobPropertyValidator do
  before do
    File.stub(:read).with('/jobs/director/templates/director.yml.erb.erb').and_return('---\nname: <%= p("director.name") %>')
    File.stub(:read).with('/jobs/blobstore/templates/blobstore.yml.erb').and_return('---\nprovider: <%= p("blobstore.provider") %>')
    File.stub(:read).with('/jobs/blobstore/templates/test.yml.erb').and_return('---\nhost: <%= spec.networks.send("foo").ip %>')
  end

  let(:director_job) do
    double(Bosh::Cli::JobBuilder,
           name: 'director',
           properties: {'director.name' =>
                            {'description' => 'Name of director'},
                        'director.port' =>
                            {'description' => 'Port that the director nginx listens on', 'default' => 25555}},
           all_templates: %w[/jobs/director/templates/director.yml.erb.erb])
  end

  let(:blobstore_job) do
    double(Bosh::Cli::JobBuilder,
           name: 'blobstore',
           properties: {'blobstore.provider' =>
                            {'description' => 'Type of blobstore'}},
           all_templates: %w[/jobs/blobstore/templates/blobstore.yml.erb /jobs/blobstore/templates/test.yml.erb])
  end

  let(:built_jobs) { [director_job, blobstore_job] }

  let(:deployment_manifest) do
    {
        'properties' => deployment_properties,
        'networks' => [{
          'name' => 'foo',
          'type' => 'manual',
          'subnets' => [{
            'range' => '10.10.0.0/24',
            'reserved' => [
                '10.0.0.2 - 10.0.0.9',
                '10.0.0.255 - 10.0.0.255'
            ],
            'static' => ['10.0.0.10 - 10.0.0.20'],
            'gateway' => '10.0.0.1',
            'dns' => ['10.0.0.2']
          }]
        }],
        'jobs' => [{
          'name' => 'bosh',
          'instances' => 2,
          'template' => job_template_list,
          'networks' => [
            'name' => 'foo',
          ]
        }]
    }
  end

  subject(:validator) { described_class.new(built_jobs, deployment_manifest) }

  context 'missing deployment manifest properties' do
    let(:deployment_properties) { {} }

    context 'colocated jobs' do
      let(:job_template_list) { %w[director blobstore] }

      it 'should have template errors' do
        validator.validate

        expect(validator.template_errors.size).to eq(2)
        expect(validator.template_errors.first.exception.to_s).to eq "Can't find property `[\"director.name\"]'"
        expect(validator.template_errors.last.exception.to_s).to eq "Can't find property `[\"blobstore.provider\"]'"
      end
    end

    context 'non-colocated jobs' do
      let(:job_template_list) { 'director' }

      it 'should have template errors' do
        validator.validate

        expect(validator.template_errors.size).to eq(1)
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

    let(:job_template_list) { %w[director blobstore] }

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

    let(:built_jobs) { [director_job, no_props_job] }

    let(:job_template_list) { %w[director noprops] }

    let(:deployment_properties) { {} }

    it 'should identify legacy jobs with no properties' do
      validator.validate

      expect(validator.jobs_without_properties.size).to eq(1)
      expect(validator.jobs_without_properties.first.name).to eq 'noprops'
    end
  end
end
