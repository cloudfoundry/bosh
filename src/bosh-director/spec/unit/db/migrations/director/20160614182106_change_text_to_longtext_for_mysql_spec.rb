require 'db_spec_helper'

module Bosh::Director
  describe 'changed_text_to_longtext_for_mysql' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160614182106_change_text_to_longtext_for_mysql.rb' }

    before { DBSpecHelper.migrate_all_before(migration_file) }

    it 'ensures that fields allow texts longer than 65535 character' do
      DBSpecHelper.migrate(migration_file)

      really_long_links_spec = 'a' * 65536
      db[:deployments] << {name: 'deployment', link_spec_json: really_long_links_spec}

      expect(db[:deployments].map{|cp| cp[:link_spec_json].length}).to eq([really_long_links_spec.length])
    end

    it 'migrates data over without data loss' do
      db[:stemcells] << {
        name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
        operating_system: 'stemcell_os',
        version: '9999.1',
        cid: 'ami-12341234'
      }
      db[:releases] << {
        name: 'test_release',
      }
      db[:packages] << {
        release_id: 1,
        name: 'test_package',
        version: 'abcd1234',
        dependency_set_json: 'dependency_set_json',
      }
      db[:compiled_packages] << {
        build: 1,
        package_id: 1,
        sha1: 'abcd1234',
        blobstore_id: '1234abcd',
        dependency_key: 'dependency_key',
        dependency_key_sha1: 'abcd1234',
      }
      db[:deployments] << {
        name: 'deployment_with_teams',
        link_spec_json: 'link_spec_json'
      }
      db[:deployment_problems] << {
        deployment_id: 1,
        state: 'running',
        resource_id: 1,
        type: 'type',
        data_json: 'data_json',
        created_at: Time.now,
        last_seen_at: Time.now,
      }
      db[:deployment_properties] << {
        deployment_id: 1,
        name: 'property',
        value: 'value'
      }
      db[:director_attributes] << {
        name: 'director_attributes_name',
        value: 'director_attributes_value'
      }
      db[:events] << {
        user: 'user1',
        timestamp: Time.now,
        action: 'action',
        object_type: 'object_type',
        error: 'oh noes!',
        context_json: '{"error"=>"boo"}'
      }
      db[:instances] << {
        job: 'job',
        index: 1,
        deployment_id: 1,
        cloud_properties: 'cloud_properties',
        dns_records: 'dns_records',
        spec_json: 'spec_json',
        credentials_json: 'credentials_json',
        state: 'running'
      }
      db[:orphan_disks] << {
        disk_cid: 'disk_cid',
        deployment_name: 'deployment_name',
        instance_name: 'instance_name',
        cloud_properties_json: 'cloud_properties_json',
        created_at: Time.now
      }
      db[:persistent_disks] << {
        instance_id: 1,
        disk_cid: 1,
        cloud_properties_json: 'cloud_properties_json',
      }
      db[:templates] << {
        name: 'name',
        version: 'version',
        blobstore_id: 'blobstore_id',
        sha1: 'sha1',
        package_names_json: 'package_names_json',
        release_id: 1,
        logs_json: 'logs_json',
        properties_json: 'properties_json'
      }


      DBSpecHelper.migrate(migration_file)

      expect(db[:compiled_packages].map{|cp| cp[:dependency_key]}).to eq(['dependency_key'])
      expect(db[:deployment_problems].map{|cp| cp[:data_json]}).to eq(['data_json'])
      expect(db[:deployment_properties].map{|cp| cp[:value]}).to eq(['value'])
      expect(db[:deployments].map{|cp| cp[:link_spec_json]}).to eq(['link_spec_json'])
      expect(db[:director_attributes].map{|cp| cp[:value]}).to eq(['director_attributes_value'])
      expect(db[:events].map{|cp| cp[:error]}).to eq(['oh noes!'])
      expect(db[:events].map{|cp| cp[:context_json]}).to eq(['{"error"=>"boo"}'])
      expect(db[:instances].map{|cp| cp[:cloud_properties]}).to eq(['cloud_properties'])
      expect(db[:instances].map{|cp| cp[:dns_records]}).to eq(['dns_records'])
      expect(db[:instances].map{|cp| cp[:spec_json]}).to eq(['spec_json'])
      expect(db[:instances].map{|cp| cp[:credentials_json]}).to eq(['credentials_json'])
      expect(db[:orphan_disks].map{|cp| cp[:cloud_properties_json]}).to eq(['cloud_properties_json'])
      expect(db[:packages].map{|cp| cp[:dependency_set_json]}).to eq(['dependency_set_json'])
      expect(db[:persistent_disks].map{|cp| cp[:cloud_properties_json]}).to eq(['cloud_properties_json'])
      expect(db[:templates].map{|cp| cp[:package_names_json]}).to eq(['package_names_json'])
      expect(db[:templates].map{|cp| cp[:logs_json]}).to eq(['logs_json'])
      expect(db[:templates].map{|cp| cp[:properties_json]}).to eq(['properties_json'])
    end
  end
end
