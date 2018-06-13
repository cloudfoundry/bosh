require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'migrate_spec_json_links' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20170616185237_migrate_spec_json_links.rb' }
    let(:created_at_time) { Time.now.utc }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:deployments] << {id: 1, name: 'fake-deployment-name', manifest: '{}'}
      db[:variable_sets] << {id: 100, deployment_id: 1, created_at: Time.now}
      db[:instances] << {
          id: 1,
          job: 'fake-job',
          index: 1,
          deployment_id: 1,
          variable_set_id: 100,
          state: 'started',
          spec_json: pre_migrated_spec_json
      }

      DBSpecHelper.migrate(migration_file)

    end

    context 'when links exist for an instance' do
      let(:pre_migrated_spec_json) do
        {
          'deployment': 'simple-deployment',
          'job': {
            'name': 'provider_instance_group',
            'templates': [
              { 'name': 'simple_job_1' },
              { 'name': 'simple_job_2' },
            ],
          },
          'links': {
            'simple_link_name_1': {
              'name': 'simple_1',
            },
            'simple_link_name_2': {
              'name': 'simple_2',
            },
          },
        }.to_json
      end
      let(:post_migrated_spec_json) do
        {
          'deployment': 'simple-deployment',
          'job': {
            'name': 'provider_instance_group',
            'templates': [
              { 'name': 'simple_job_1' },
              { 'name': 'simple_job_2' },
            ],
          },
          'links': {
            'simple_job_1': {
              'simple_link_name_1': {
                'name': 'simple_1',
              },
              'simple_link_name_2': {
                'name': 'simple_2',
              },
            },
            'simple_job_2': {
              'simple_link_name_1': {
                'name': 'simple_1',
              },
              'simple_link_name_2': {
                'name': 'simple_2',
              },
            },
          },
        }.to_json
      end

      it 'should move links under each own job section' do
        expect(db[:instances].count).to eq(1)
        expect(db[:instances].all[0][:spec_json]).to eq(post_migrated_spec_json)
      end
    end

    context 'when links are empty for an instance' do
      let(:pre_migrated_spec_json) do
        {
          'deployment': 'simple-deployment',
          'job': {
            'name': 'provider_instance_group',
            'templates': [
              { 'name': 'simple_job_1' },
              { 'name': 'simple_job_2' },
            ],
          },
          'links': {},
        }.to_json
      end
      let(:post_migrated_spec_json) do
        {
          'deployment': 'simple-deployment',
          'job': {
            'name': 'provider_instance_group',
            'templates': [
              { 'name': 'simple_job_1' },
              { 'name': 'simple_job_2' },
            ],
          },
          'links': {
            'simple_job_1': {},
            'simple_job_2': {},
          },
        }.to_json
      end
      it 'should move links under each own job section' do
        expect(db[:instances].count).to eq(1)
        expect(db[:instances].all[0][:spec_json]).to eq(post_migrated_spec_json)
      end
    end

    context 'when links key is NOT defined in spec_json' do
      let(:pre_migrated_spec_json) do
        {
          'deployment': 'simple-deployment',
          'job': {
            'name': 'provider_instance_group',
            'templates': [
              { 'name': 'simple_job_1' },
              { 'name': 'simple_job_2' },
            ],
          },
        }.to_json
      end
      it 'should NOT modify spec_json' do
        expect(db[:instances].count).to eq(1)
        expect(db[:instances].all[0][:spec_json]).to eq(pre_migrated_spec_json)
      end
    end

    context 'when spec_json is empty it should NOT raise an error' do
      let(:pre_migrated_spec_json) { nil }

      it 'should NOT modify spec_json' do
        expect(db[:instances].count).to eq(1)
        expect(db[:instances].all[0][:spec_json]).to eq(nil)
      end
    end

    context 'when jobs/templates are empty for an instance' do
      let(:pre_migrated_spec_json) do
        {
          'deployment': 'simple-deployment',
          'job': {
            'name': 'provider_instance_group',
            'templates': [],
          },
          'links': {
            'simple_link_name_1': {
              'name': 'simple_1',
            },
            'simple_link_name_2': {
              'name': 'simple_2',
            },
          },
        }.to_json
      end

      it 'should NOT modify spec_json' do
        expect(db[:instances].count).to eq(1)
        expect(db[:instances].all[0][:spec_json]).to eq(pre_migrated_spec_json)
      end
    end

    context 'when jobs/templates key is NOT defined for an instance' do
      let(:pre_migrated_spec_json) do
        {
          'deployment': 'simple-deployment',
          'job': {
            'name': 'provider_instance_group',
          },
          'links': {
            'simple_link_name_1': {
              'name': 'simple_1',
            },
            'simple_link_name_2': {
              'name': 'simple_2',
            },
          },
        }.to_json
      end

      it 'should NOT modify spec_json' do
        expect(db[:instances].count).to eq(1)
        expect(db[:instances].all[0][:spec_json]).to eq(pre_migrated_spec_json)
      end
    end
  end
end
