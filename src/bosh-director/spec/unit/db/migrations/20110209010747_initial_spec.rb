require 'json'
require 'db_spec_helper'

module Bosh::Director
  describe '20110209010747_initial.rb' do
    let(:db) { DBSpecHelper.db }
    subject(:migration_file) { '20110209010747_initial.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)
      DBSpecHelper.migrate(migration_file)
    end

    describe '20160427164345_add_teams' do
      let(:deployment_team_data) do
        { deployment_id: db[:deployments].first[:id], team_id: db[:teams].first[:id] }
      end

      before do
        db[:deployments] << { name: 'FAKE_DEPLOYMENT_NAME' }
        db[:teams] << { name: 'FAKE_TEAM' }
      end

      it 'should check that deployments_teams has unique deployment_id and team_id pairs' do
        db[:deployments_teams] << deployment_team_data

        expect {
          db[:deployments_teams] << deployment_team_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end

    describe '20160818112257_change_stemcell_unique_key' do
      let(:stemcell_data) { { name: 'FAKE_STEMCELL_NAME', version: 'FAKE_VERSION', cid: 'FAKE_CID', cpi: 'FAKE_CPI' } }

      before do
        db[:stemcells] << stemcell_data
      end

      it 'stemcell records with same name, version, and cpi can not be created' do
        expect {
          db[:stemcells] << stemcell_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'stemcell records with same name, version and different cpi can be created' do
        stemcell_data[:cpi] = 'DIFFERENT_FAKE_CPI'

        expect {
          db[:stemcells] << stemcell_data
        }.not_to raise_error
      end
    end

    describe '20161209104649_add_context_id_to_tasks' do
      let(:context_id) { 'x' * 64 }
      let(:task_data) do
        {
          state: 'FAKE_STATE',
          timestamp: Time.now,
          description: 'FAKE_DESCRIPTION',
          type: 'FAKE_TYPE',
          context_id: context_id,
        }
      end

      it 'context_id can be 64 chars in length' do
        db[:tasks] << task_data

        expect(db[:tasks].first[:context_id]).to eq(context_id)
      end
    end

    describe '20161221151107_allow_null_instance_id_local_dns' do
      it 'does NOT have a null constraint on local_dns_records.instance_id' do
        expect {
          db[:local_dns_records] << { ip: 'FAKE_IP', instance_id: nil }
        }.not_to raise_error
      end
    end

    describe '20170116235940_add_errand_runs' do
      let(:deployment_data) do
        {
          name: 'FAKE_DEPLOYMENT_NAME',
        }
      end
      let(:variable_set_data) do
        {
          deployment_id: db[:deployments].first[:id],
          created_at: Time.now,
        }
      end
      let(:errand_run_data) do
        {
          deployment_id: db[:deployments].first[:id],
        }
      end

      before do
        db[:deployments] << deployment_data
        db[:variable_sets] << variable_set_data
      end

      it 'creates the table with default value for ran_successfully' do
        db[:errand_runs] << errand_run_data

        expect(db[:errand_runs].first[:deployment_id]).to eq(db[:deployments].first[:id])
        expect(db[:errand_runs].first[:successful]).to be_falsey
      end

      it 'does not allow null values for deployment_id' do
        errand_run_data[:deployment_id] = nil

        expect {
          db[:errand_runs] << errand_run_data
        }.to raise_error(Sequel::DatabaseError)
      end
    end

    describe '20170119202003_update_sha1_column_sizes' do
      let(:string_with_length_512) { 'b' * 512 }
      let(:string_with_length_255) { 'a' * 255 }

      before do
        db[:releases] << { name: 'FAKE_RELEASE_NAME' }

        release_id = db[:releases].first[:id]

        db[:packages] << {
          release_id: release_id,
          name: 'FAKE_PACKAGE_NAME',
          version: 'FAKE_VERSION',
          dependency_set_json: '{"fake_dependency_set": "json"}',
          sha1: string_with_length_512,
        }

        db[:templates] << {
          name: 'FAKE_TEMPLATE_NAME',
          release_id: release_id,
          version: 'FAKE_VERSION',
          blobstore_id: 'FAKE_BLOBSTORE_ID',
          package_names_json: '{"fake_package_names": "json"}',
          sha1: string_with_length_512
        }

        db[:compiled_packages] << {
          build: 1,
          package_id: db[:packages].first[:id],
          blobstore_id: 'FAKE_BLOBSTORE_ID',
          dependency_key: 'FAKE_DEPENDENCY_KEY',
          dependency_key_sha1: 'FAKE_DEPENDENCY_KEY_SHA1',
          sha1: string_with_length_512
        }

        db[:stemcells] << {
          name: 'FAKE_STEMCELL_NAME',
          sha1: string_with_length_512,
          version: 'FAKE_VERSION',
          cid: 'FAKE_CID'
        }
      end

      it 'columns can handle expected text sizes' do
        expect(db[:packages].where(sha1: string_with_length_512).count).to eq(1)
        expect(db[:templates].where(sha1: string_with_length_512).count).to eq(1)
        expect(db[:compiled_packages].where(sha1: string_with_length_512).count).to eq(1)
        expect(db[:stemcells].where(sha1: string_with_length_512).count).to eq(1)
      end

      describe 'indexes on local_dns_blobs table' do
        let(:local_dns_blobs_indexes) do
          db.indexes(db.tables.select { |t| t == :local_dns_blobs }[0])
        end
        let(:expected_indexes) do
          case db.adapter_scheme
          when :mysql2
            [:columns => [:blob_id], :unique => false]
          else
            []
          end
        end

        it 'has expected indexes on local_dns_blobs.blob_id' do
          expect(local_dns_blobs_indexes.values).to eq(expected_indexes)
        end
      end
    end

    describe '20170203212124_add_variables' do
      let(:deployment_data_0) do
        { id: 1, name: 'FAKE_DEPLOYMENT_NAME_0' }
      end
      let(:deployment_data_1) do
        { id: 2, name: 'FAKE_DEPLOYMENT_NAME_1' }
      end

      before do
        db[:deployments] << deployment_data_0
        db[:deployments] << deployment_data_1
      end

      describe 'variable_sets table' do
        it 'has a non null constraint for deployment_id' do
          expect {
            db[:variable_sets] << { id: 100, deployment_id: nil, created_at: Time.now }
          }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        it 'has a non null constraint for created_at' do
          expect {
            db[:variable_sets] << { id: 100, deployment_id: deployment_data_0[:id], created_at: nil }
          }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        it 'defaults deploy_success to false' do
          db[:variable_sets] << { id: 100, deployment_id: deployment_data_0[:id], created_at: Time.now }
          expect(db[:variable_sets].first['deploy_success']).to be_falsey
        end

        it 'has a foreign key association with deployments table' do
          expect {
            db[:variable_sets] << { id: 100, deployment_id: 646464, created_at: Time.now }
          }.to raise_error Sequel::ForeignKeyConstraintViolation
        end

        it 'cascades on deployment deletion' do
          db[:variable_sets] << { id: 100, deployment_id: deployment_data_0[:id], created_at: Time.now }
          db[:variable_sets] << { id: 200, deployment_id: deployment_data_0[:id], created_at: Time.now }
          db[:variable_sets] << { id: 300, deployment_id: deployment_data_1[:id], created_at: Time.now }

          expect(db[:variable_sets].count).to eq(3)

          db[:deployments].where(id: 1).delete

          expect(db[:variable_sets].count).to eq(1)
          expect(db[:variable_sets].where(deployment_id: deployment_data_0[:id]).count).to eq(0)
        end
      end

      describe 'variables table' do
        before do
          db[:variable_sets] << { id: 100, deployment_id: deployment_data_0[:id], created_at: Time.now }
          db[:variable_sets] << { id: 200, deployment_id: deployment_data_0[:id], created_at: Time.now }
          db[:variable_sets] << { id: 300, deployment_id: deployment_data_1[:id], created_at: Time.now }
        end

        it 'has a non null constraint for variables.variable_id' do
          expect {
            db[:variables] << { variable_name: 'var_1', variable_id: nil, variable_set_id: 100 }
          }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        it 'has a non null constraint for variables.variable_name' do
          expect {
            db[:variables] << { variable_name: nil, variable_id: 'var_id_1', variable_set_id: 100 }
          }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        it 'has a non null constraint for variables.variable_set_id' do
          expect {
            db[:variables] << { variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: nil }
          }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        it 'has a foreign key constraint on  variables.variable_set_id with variable_sets.id' do
          expect {
            db[:variables] << { id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 9999 }
          }.to raise_error(Sequel::ForeignKeyConstraintViolation)
        end

        it 'cascades on variable_sets deletion' do
          db[:variables] << { id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 100 }
          db[:variables] << { id: 2, variable_id: 'var_id_2', variable_name: 'var_2', variable_set_id: 100 }
          db[:variables] << { id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 200 }

          expect(db[:variables].count).to eq(3)

          db[:variable_sets].where(id: 100).delete

          expected_variable_data =
            {
              id: 3,
              is_local: true,
              provider_deployment: '',
              variable_id: 'var_id_3',
              variable_name: 'var_3',
              variable_set_id: 200,
            }

          expect(db[:variables].count).to eq(1)
          expect(db[:variables].first).to eq(expected_variable_data)
        end

        it 'cascades on deployment deletion' do
          db[:variables] << { id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 100 }
          db[:variables] << { id: 2, variable_id: 'var_id_2', variable_name: 'var_2', variable_set_id: 100 }
          db[:variables] << { id: 3, variable_id: 'var_id_3', variable_name: 'var_3', variable_set_id: 300 }

          expect(db[:variables].count).to eq(3)

          db[:deployments].where(id: 1).delete

          expect(db[:variables].count).to eq(1)
          expect(db[:variables].where(variable_set_id: 300).count).to eq(1)
        end

        it 'has variable_set_id and variable_name unique constraint' do
          db[:variables] << { id: 1, variable_id: 'var_id_1', variable_name: 'var_1', variable_set_id: 100 }

          expect {
            db[:variables] << { id: 2, variable_id: 'var_id_2', variable_name: 'var_1', variable_set_id: 100 }
          }.to raise_error(Sequel::UniqueConstraintViolation)
        end
      end

      describe 'instances table' do
        let(:instance_data) do
          {
            job: 'job',
            index: 1,
            deployment_id: deployment_data_0[:id],
            state: 'running',
            variable_set_id: db[:variable_sets].first[:id],
          }
        end

        before do
          db[:variable_sets] << { id: 100, deployment_id: deployment_data_0[:id], created_at: Time.now }
        end

        it 'does not allow null for variable_set_id column' do
          instance_data[:variable_set_id] = nil

          expect { db[:instances] << instance_data }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        it 'has a foreign key constraint between instances.variable_set_id and variable_sets.id' do
          instance_data[:variable_set_id] = 99999

          expect { db[:instances] << instance_data }.to raise_error(Sequel::ForeignKeyConstraintViolation)
        end
      end
    end

    describe '20170217000000_variables_instance_table_foreign_key_update' do
      let(:variable_set_id_constraint) do
        db.foreign_key_list(:instances).select { |v| v[:columns] == [:variable_set_id] }
      end

      it 'instances table has foreign key constraint on [variable_set_id]' do
        expected_constraint =
          case db.adapter_scheme
          when :sqlite
            {
              columns: [:variable_set_id],
              table: :variable_sets,
            }
          else
            {
              columns: [:variable_set_id],
              table: :variable_sets,
              key: [:id],
            }
          end

        expect(variable_set_id_constraint.size).to eq(1)
        expect(variable_set_id_constraint.first).to include(expected_constraint)
      end
    end

    describe '20170303175054_expand_template_json_column_lengths' do
      let(:large_json) { JSON.dump({ key: ('foo' * 1000) }) }

      before do
        db[:releases] << { name: 'FAKE_RELEASE_NAME' }
      end

      it 'allows large amounts of text in provides_json consumes_json columns' do
        expect {
          db[:templates] << {
            id: 1,
            name: 'FAKE_TEMPLATE_NAME',
            release_id: db[:releases].first[:id],
            version: 'FAKE_VERSION',
            blobstore_id: 'FAKE_BLOBSTORE_ID',
            sha1: "FAKE_SHA1",
            package_names_json: large_json,
            spec_json: large_json,
          }
        }.not_to raise_error

        expect(db[:templates].first[:spec_json]).to eq(large_json)
        expect(db[:templates].first[:package_names_json]).to eq(large_json)
      end
    end

    describe '20170328224049_associate_vm_info_with_vms_table' do
      before do
        db[:deployments] << { name: 'FAKE_DEPLOYMENT_NAME', }
        db[:variable_sets] << { deployment_id: db[:deployments].first[:id], created_at: Time.now }
        db[:instances] << {
          job: 'blah',
          index: 0,
          deployment_id: db[:deployments].first[:id],
          variable_set_id: db[:variable_sets].first[:id],
          state: 'running',
        }
      end

      it 'has a uniqueness constraint on vms.agent_id' do
        db[:vms] << { agent_id: 1, instance_id: db[:instances].first[:id] }

        expect {
          db[:vms] << { agent_id: 1, instance_id: db[:instances].first[:id] }
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a uniqueness constraint on vms.cid' do
        db[:vms] << { cid: 1, instance_id: db[:instances].first[:id] }

        expect {
          db[:vms] << { cid: 1, instance_id: db[:instances].first[:id] }
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a foreign key constraint between vms.instance_id and instances.id' do
        expect { db[:vms] << { instance_id: 999 } }.to raise_error(Sequel::ForeignKeyConstraintViolation)
      end

      it 'has a not null constraint on vms.instances_id' do
        expect { db[:vms] << { instance_id: nil } }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20170405144414_add_cross_deployment_links_support_for_variables' do
      before do
        db[:deployments] << { name: 'FAKE_DEPLOYMENT_NAME', }
        db[:variable_sets] << { deployment_id: db[:deployments].first[:id], created_at: Time.now }
      end

      it 'adds a new unique index for :variable_set_id, :variable_name, and :provider_deployment' do
        variable_data =
          {
            variable_id: 'var_id_3',
            variable_name: 'var_3',
            variable_set_id: db[:variable_sets].first[:id],
            provider_deployment: 'test',
          }

        db[:variables] << variable_data

        expect {
          db[:variables] << variable_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end

    describe '20170405181126_backfill_local_dns_records_and_drop_name' do
      before do
        db[:deployments] << { name: 'FAKE_DEPLOYMENT_NAME', }
        db[:variable_sets] << { deployment_id: db[:deployments].first[:id], created_at: Time.now }
        db[:instances] << {
          job: 'blah',
          index: 0,
          deployment_id: db[:deployments].first[:id],
          variable_set_id: db[:variable_sets].first[:id],
          state: 'running',
        }
        instance = db[:instances].first
        deployment = db[:deployments].first(id: instance[:deployment_id])

        db[:local_dns_records] << {
          instance_id: instance[:id],
          instance_group: instance[:job],
          az: instance[:availability_zone],
          network: 'FAKE_NETWORK_NAME',
          deployment: deployment[:name],
          ip: 'FAKE_IP',
        }
      end

      it 'does not cascade deletion of local_dns_records when deleting instances' do
        expect {
          db[:instances].delete
        }.to raise_error(Sequel::ForeignKeyConstraintViolation)
      end
    end

    describe '20170427194511_add_runtime_config_name_support' do
      it 'has a null constraint on runtime_configs.name' do
        expect {
          db[:runtime_configs] << { properties: 'FAKE_PROPERTIES', name: nil, created_at: Time.now }
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20170503205545_change_id_local_dns_to_bigint' do
      let(:large_integer_id) { 9223372036854775807 }
      let(:local_dns_blob_data) do
        {
          created_at: Time.now,
          version: 2,
        }
      end
      let(:agent_dns_version_data) do
        {
          agent_id: 'FAKE_AGENT_ID',
          dns_version: 2,
        }
      end

      it 'has allows large integers for local_dns_records.id' do
        db[:local_dns_records] << { id: large_integer_id, ip: 'FAKE_IP' }

        expect(db[:local_dns_records].where(id: large_integer_id).count).to eq(1)
      end

      it 'has allows large integers for local_dns_records.id' do
        local_dns_blob_data[:id] = large_integer_id
        db[:local_dns_blobs] << local_dns_blob_data

        expect(db[:local_dns_blobs].where(id: large_integer_id).count).to eq(1)
      end

      it 'has allows large integers for local_dns_records.version' do
        local_dns_blob_data[:version] = large_integer_id
        db[:local_dns_blobs] << local_dns_blob_data

        expect(db[:local_dns_blobs].where(version: large_integer_id).count).to eq(1)
      end

      it 'has allows large integers for agent_dns_versions.id' do
        agent_dns_version_data[:id] = large_integer_id
        db[:agent_dns_versions] << agent_dns_version_data

        expect(db[:agent_dns_versions].where(id: large_integer_id).count).to eq(1)
      end

      it 'has allows large integers for agent_dns_versions.dns_version' do
        agent_dns_version_data[:dns_version] = large_integer_id
        db[:agent_dns_versions] << agent_dns_version_data

        expect(db[:agent_dns_versions].where(dns_version: large_integer_id).count).to eq(1)
      end
    end

    describe '20170607182149_add_task_id_to_locks' do
      it 'has a null constraint on locks.task_id' do
        expect {
          db[:locks] << { name: 'FAKE_LOCK_NAME', uid: 'FAKE_UUID', task_id: nil, expired_at: Time.now }
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20170628221611_add_canonical_az_names_and_ids' do
      it 'has a uniqueness constraint on local_dns_encoded_azs.name' do
        local_dns_encoded_az_data = { name: 'FAKE_LOCAL_DNS_ENCODED_AZ_NAME' }
        db[:local_dns_encoded_azs] << local_dns_encoded_az_data

        expect {
          db[:local_dns_encoded_azs] << local_dns_encoded_az_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a null constraint on local_dns_encoded_azs.name' do
        expect {
          db[:local_dns_encoded_azs] << { name: nil }
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20170815175515_change_variable_ids_to_bigint' do
      let(:large_integer_id) { 9223372036854775807 }

      before do
        db[:deployments] << { name: 'FAKE_RELEASE_NAME' }
      end

      it 'has allows large integers for variable_sets.id' do
        db[:variable_sets] << {
          id: large_integer_id,
          deployment_id: db[:deployments].first[:id],
          created_at: Time.now,
        }

        expect(db[:variable_sets].where(id: large_integer_id).count).to eq(1)
      end

      it 'has allows large integers for variables.id' do
        db[:variable_sets] << { deployment_id: db[:deployments].first[:id], created_at: Time.now }
        db[:variables] << {
          id: large_integer_id,
          variable_set_id: db[:variable_sets].first[:id],
          variable_id: 'FAKE_VARIABLE_ID',
          variable_name: 'FAKE_VARIABLE_NAME',
        }

        expect(db[:variables].where(id: large_integer_id).count).to eq(1)
      end
    end

    describe '20170825141953_change_address_to_be_string_for_ipv6' do
      it 'has a uniqueness constraint on ip_addresses.address_str' do
        ip_address_data = { address_str: 'FAKE_ADDRESS_STR' }

        db[:ip_addresses] << ip_address_data
        expect {
          db[:ip_addresses] << ip_address_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a null constraint on ip_addresses.address_str' do
        expect {
          db[:ip_addresses] << { address_str: nil }
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20170915205722_create_dns_encoded_networks_and_instance_groups' do
      let(:local_dns_encoded_group_data) do
        { name: 'FAKE_NAME', deployment_id: db[:deployments].first[:id] }
      end

      before do
        db[:deployments] << { name: 'FAKE_DEPLOYMENT_NAME' }
      end

      it 'has a uniqueness constraint on local_dns_encoded_groups.name' do
        db[:local_dns_encoded_groups] << local_dns_encoded_group_data
        expect {
          db[:local_dns_encoded_groups] << local_dns_encoded_group_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a null constraint on local_dns_encoded_groups.name' do
        local_dns_encoded_group_data[:name] = nil

        expect {
          db[:local_dns_encoded_groups] << local_dns_encoded_group_data
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end

      it 'has a null constraint on local_dns_encoded_groups.deployment_id' do
        local_dns_encoded_group_data[:deployment_id] = nil

        expect {
          db[:local_dns_encoded_groups] << local_dns_encoded_group_data
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end

      it 'has a uniqueness constraint on local_dns_encoded_networks.name' do
        local_dns_encoded_network_data = { name: 'FAKE_NAME' }

        db[:local_dns_encoded_networks] << local_dns_encoded_network_data
        expect {
          db[:local_dns_encoded_networks] << local_dns_encoded_network_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a null constraint on local_dns_encoded_networks.name' do
        expect {
          db[:local_dns_encoded_networks] << { name: nil }
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20171030224934_convert_nil_configs_to_empty' do
      it 'has a null constraint on configs.content' do
        expect {
          db[:configs] << {
            type: 'FAKE_TYPE',
            name: 'FAKE_NAME',
            created_at: Time.now,
            content: nil,
          }
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20171113000000_add_links_api' do
      let(:instance_data) do
        {
          job: 'job',
          index: 1,
          deployment_id: db[:deployments].first[:id],
          state: 'running',
          variable_set_id: db[:variable_sets].first[:id],
        }
      end
      let(:link_consumer_data) do
        {
          deployment_id: db[:deployments].first[:id],
          instance_group: 'FAKE_INSTANCE_GROUP',
          name: 'FAKE_JOB',
          type: 'FAKE_TYPE',
        }
      end
      let(:link_provider_data) do
        {
          deployment_id: db[:deployments].first[:id],
          instance_group: 'FAKE_INSTANCE_GROUP',
          name: 'FAKE_JOB',
          type: 'FAKE_TYPE',
        }
      end
      let(:link_provider_intent_data) do
        {
          link_provider_id: db[:link_providers].first[:id],
          original_name: 'FAKE_ORIGINAL_NAME',
          type: 'FAKE_TYPE',
        }
      end
      let(:link_consumer_intent_data) do
        {
          link_consumer_id: db[:link_consumers].first[:id],
          original_name: 'FAKE_ORIGINAL_NAME',
          type: 'FAKE_TYPE',
        }
      end

      before do
        db[:deployments] << { name: 'FAKE_RELEASE_NAME' }
        db[:variable_sets] << { deployment_id: db[:deployments].first[:id], created_at: Time.now }

        db[:link_consumers] << link_consumer_data
        db[:link_providers] << link_provider_data

        db[:link_provider_intents] << link_provider_intent_data
        db[:link_consumer_intents] << link_consumer_intent_data
      end

      it 'has a uniqueness constraint on link_providers [deployment_id, instance_group, name, type]' do
        expect {
          db[:link_providers] << link_provider_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a uniqueness constraint on link_consumers [deployment_id, instance_group, name, type]' do
        expect {
          db[:link_consumers] << link_consumer_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a uniqueness constraint on link_provider_intents [link_provider_id, original_name, type]' do
        expect {
          db[:link_provider_intents] << link_provider_intent_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a uniqueness constraint on link_consumer_intents [link_consumer_id, original_name, type]' do
        expect {
          db[:link_consumer_intents] << link_consumer_intent_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end

      it 'has a uniqueness constraint on instances_links [link_id, instance_id]' do
        db[:instances] << instance_data
        db[:links] << {
          link_provider_intent_id: db[:link_provider_intents].first[:id],
          link_consumer_intent_id: db[:link_consumer_intents].first[:id],
          name: 'FAKE_LINK_NAME',
          link_content: 'FAKE_LINK_CONTENT'
        }

        instances_link_data = {
          instance_id: db[:instances].first[:id],
          link_id: db[:links].first[:id],
        }

        db[:instances_links] << instances_link_data
        expect {
          db[:instances_links] << instances_link_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end

    describe '20180119183014_add_stemcell_matches / 20180130182844_rename_stemcell_matches_to_stemcell_uploads' do
      let(:stemcell_uploads_data) do
        {
          name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
          version: '3468.19',
          cpi: 'aws-use1',
        }
      end

      it 'has a uniqueness constraint on stemcell_uploads [name, version, cpi]' do
        db[:stemcell_uploads] << stemcell_uploads_data

        expect {
          db[:stemcell_uploads] << stemcell_uploads_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end

    describe '20180613190204_links_api_longtext_support' do
      let(:large_json) { JSON.dump({ key: ('foo' * 1000) }) }

      let(:link_provider_data) do
        {
          deployment_id: db[:deployments].first[:id],
          instance_group: 'FAKE_INSTANCE_GROUP',
          name: 'FAKE_JOB',
          type: 'FAKE_TYPE',
        }
      end
      let(:link_provider_intent_data) do
        {
          link_provider_id: db[:link_providers].first[:id],
          original_name: 'FAKE_ORIGINAL_NAME',
          type: 'FAKE_TYPE',
          metadata: large_json,
        }
      end

      before do
        db[:deployments] << { name: 'FAKE_DEPLOYMENT_NAME' }
        db[:link_providers] << link_provider_data
      end

      it 'allows large amounts of text in provides_json consumes_json columns' do
        db[:link_provider_intents] << link_provider_intent_data
        expect(db[:link_provider_intents].first[:metadata]).to eq(large_json)
      end
    end

    describe '20181017210108_add_type_to_local_dns_encoded_instance_group' do
      let(:local_dns_encoded_group_data) do
        {
          type: 'FAKE_TYPE',
          name: 'FAKE_NAME',
          deployment_id: db[:deployments].first[:id],
        }
      end

      before do
        db[:deployments] << { name: 'FAKE_DEPLOYMENT_NAME' }
      end

      it 'has a uniqueness constraint on local_dns_encoded_instance_group [name, type, deployment_id]' do
        db[:local_dns_encoded_groups] << local_dns_encoded_group_data

        expect {
          db[:local_dns_encoded_groups] << local_dns_encoded_group_data
        }.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end

    describe '20190104135624_add_update_completed_to_release_versions' do
      let(:release_version_data) do
        {
          release_id: db[:releases].first[:id],
          version: 'FAKE_VERSION',
          commit_hash: 'UUID_FAKE_COMMIT_HASH',
          update_completed: nil,
        }
      end

      before do
        db[:releases] << { name: 'FAKE_RELEASE_NAME' }
      end

      it 'has a null constraint on release_versions.update_completed' do
        expect {
          db[:release_versions] << release_version_data
        }.to raise_error(Sequel::NotNullConstraintViolation)
      end
    end

    describe '20190114153103_add_index_to_tasks' do
      it 'have an index on tasks.type' do
        indexes_on_tasks = db.indexes(:tasks)

        expect(indexes_on_tasks.values.select { |i| i[:columns] == [:type] }).not_to be_empty
      end
    end
  end
end
