require 'spec_helper'
require 'bosh/dev/table_parser'

module Bosh
  module Dev
    describe TableParser do
      subject(:table_parser) { TableParser.new(table) }

      context 'when table has multi-columns' do
        let(:table) do
          <<-EOT
+------+------------+-------------+
| Name | Versions   | Commit Hash |
+------+------------+-------------+
| bosh | 13.67-dev* | f694e3d2+   |
+------+------------+-------------+
(*) Currently deployed
(+) Uncommitted changes

Releases total: 1
          EOT
        end

        describe '#to_a' do
          it 'should be return an array of hashes with key from headers and values from the rows' do
            expect(table_parser.to_a).to eq([{ name: 'bosh', versions: '13.67-dev*', commit_hash: 'f694e3d2+' }])
          end
        end
      end

      context 'when table has multi-rows' do
        let(:table) do
          <<-EOT
+---------------+---------+--------------+
| Name          | Version | CID          |
+---------------+---------+--------------+
| bosh-stemcell | 882     | ami-fac68793 |
| bosh-stemcell | 896     | ami-b47b3add |
+---------------+---------+--------------+

Stemcells total: 2
          EOT
        end

        describe '#to_a' do
          it 'should be return an array of hashes with key from headers and values from the rows' do
            expect(table_parser.to_a).to eq([
                                              { name: 'bosh-stemcell', version: '882', cid: 'ami-fac68793' },
                                              { name: 'bosh-stemcell', version: '896', cid: 'ami-b47b3add' }
                                            ])
          end
        end
      end
    end
  end
end