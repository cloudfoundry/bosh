require_relative '../../../../db_spec_helper'

module Bosh::Director
  describe '20180119183014_add_stemcell_matches.rb' do
    let(:db) {DBSpecHelper.db}

    before do
      DBSpecHelper.migrate_all_before(subject)
      DBSpecHelper.migrate(subject)
    end

    it 'creates the table' do
      db[:stemcell_matches] << {
        name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
        version: '3468.19',
        cpi: 'aws-use1',
      }

      expect(db[:stemcell_matches]).to contain_exactly(
        {
          id: 1,
          name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
          version: '3468.19',
          cpi: 'aws-use1',
        }
      )
    end

    it 'enforces uniqueness on name+version+cpi' do
      db[:stemcell_matches] << {
        name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
        version: '3468.19',
        cpi: 'aws-use1',
      }

      expect do
        db[:stemcell_matches] << {
          name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
          version: '3468.19',
          cpi: 'aws-use1',
        }
      end.to raise_error(Sequel::UniqueConstraintViolation)

      db[:stemcell_matches] << {
        name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
        version: '3468.19',
        cpi: 'aws-use2',
      }

      db[:stemcell_matches] << {
        name: 'bosh-aws-xen-hvm-ubuntu-trusty-go_agent',
        version: '3468.20',
        cpi: 'aws-use1',
      }

      db[:stemcell_matches] << {
        name: 'bosh-aws-xen-hvm-ubuntu-xenial-go_agent',
        version: '3468.19',
        cpi: 'aws-use1',
      }

      expect(db[:stemcell_matches].all.length).to eq(4)
    end
  end
end
