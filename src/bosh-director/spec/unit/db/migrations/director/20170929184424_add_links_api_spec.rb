require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe 'During migrations' do
    let(:db) {DBSpecHelper.db}
    let(:migration_file) {'20170929184424_add_links_api.rb'}

    before do
      DBSpecHelper.migrate_all_before(migration_file)
    end

    it 'creates the appropriate tables' do
      DBSpecHelper.migrate(migration_file)
      expect(db.table_exists? :link_providers).to be_truthy
    end

    context 'when link_spec_json is populated in the deployments table' do
      let(:link_spec_json) do
        {
          'provider_instance_group_1': {
            'provider_job_1': {
              'link_name_1': {
                'link_type_1': {'my_val': 'hello'}
              },
              'link_name_2': {
                'link_type_2': {'foo': 'bar'}
              }
            }
          },
            'provider_instance_group_2': {
              'provider_job_1': {
                'link_name_3': {
                  'link_type_1': {'bar': 'baz'}
                },
              },
              'provider_job_2': {
                'link_name_4': {
                  'link_type_2': {'foobar': 'bazbaz'}
                }
              }
          }
        }
      end

      before do
        db[:deployments] << {name: 'fake-deployment', id: 42, link_spec_json: link_spec_json.to_json}
        DBSpecHelper.migrate(migration_file)
      end

      it 'will create a provider for every link' do
        expect(db[:link_providers].count).to eq(4)

        expected_outputs = [
          {link_name: 'link_name_1', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_1', link_def_type: 'link_type_1', content: '{"my_val":"hello"}'},
          {link_name: 'link_name_2', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_1', link_def_type: 'link_type_2', content: '{"foo":"bar"}'},
          {link_name: 'link_name_3', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_1', link_def_type: 'link_type_1', content: '{"bar":"baz"}'},
          {link_name: 'link_name_4', deployment_id: 42, owner_type: 'job', owner_name: 'provider_job_2', link_def_type: 'link_type_2', content: '{"foobar":"bazbaz"}'},
        ]

        idx = 0
        db[:link_providers].order(:id).each do |provider|
          output = expected_outputs[idx]
          expect(provider[:name]).to eq(output[:link_name])
          expect(provider[:deployment_id]).to eq(output[:deployment_id])
          expect(provider[:owner_object_type]).to eq(output[:owner_type])
          expect(provider[:owner_object_name]).to eq(output[:owner_name])
          expect(provider[:link_provider_definition_type]).to eq(output[:link_def_type])
          expect(provider[:content]).to eq(output[:content])
          idx += 1
        end
      end
    end
  end
end
