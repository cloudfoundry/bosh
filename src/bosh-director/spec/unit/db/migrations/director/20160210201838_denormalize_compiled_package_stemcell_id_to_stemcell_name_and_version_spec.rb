require 'db_spec_helper'

module Bosh::Director
  describe 'add_vm_attributes_to_instance' do
    let(:db) { DBSpecHelper.db }
    let(:migration_file) { '20160210201838_denormalize_compiled_package_stemcell_id_to_stemcell_name_and_version.rb' }

    before do
      DBSpecHelper.migrate_all_before(migration_file)

      db[:stemcells] << {
        id: 1,
        name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
        operating_system: stemcell_os,
        version: '9999.1',
        cid: 'ami-12341234'
      }
      db[:releases] << {
        id: 1,
        name: 'test_release',
      }
      db[:packages] << {
        id: 1,
        release_id: 1,
        name: 'test_package',
        version: 'abcd1234',
        dependency_set_json: '{}',
      }
      db[:compiled_packages] << {
        id: 1,
        build: 1,
        package_id: 1,
        stemcell_id: 1,
        sha1: 'abcd1234',
        blobstore_id: '1234abcd',
        dependency_key: '{}',
        dependency_key_sha1: 'abcd1234',
      }
    end
    let(:stemcell_os) { 'ubuntu_trusty' }

    it 'runs drop_vm_env_json_from_instance migration and retains data' do
      DBSpecHelper.migrate(migration_file)

      expect(db[:compiled_packages].count).to eq(1)
      expect(db[:compiled_packages].first).to_not have_key(:stemcell_id)
      expect(db[:compiled_packages].first[:stemcell_os]).to eq('ubuntu_trusty')
      expect(db[:compiled_packages].first[:stemcell_version]).to eq('9999.1')
    end

    context 'when stemcell does not have os version' do
      let(:stemcell_os) { nil }

      it 'sets stemcell_os as stemcell name' do
        DBSpecHelper.migrate(migration_file)

        expect(db[:compiled_packages].count).to eq(1)
        expect(db[:compiled_packages].first).to_not have_key(:stemcell_id)
        expect(db[:compiled_packages].first[:stemcell_os]).to eq('bosh-aws-xen-hvm-ubuntu-trusty-go_agent')
        expect(db[:compiled_packages].first[:stemcell_version]).to eq('9999.1')
      end
    end
  end
end
