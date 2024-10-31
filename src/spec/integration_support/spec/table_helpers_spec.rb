require 'spec_helper'

module IntegrationSupport
  describe TableHelpers::Parser do
    let(:parser) { TableHelpers::Parser.new(source) }

    describe '#data' do
      let(:source) do
        %q({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": {
                "name": "Name",
                "version": "Version",
                "os": "OS",
                "cid": "CID"
            },
            "Rows": [
                {
                    "name": "stemcell",
                    "version": "3142*",
                    "os": "ubuntu-trusty",
                    "cid": "cid1"
                },
                {
                    "name": "stemcell",
                    "version": "3143*",
                    "os": "ubuntu-trusty",
                    "cid": "cid2"
                }
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
      end

      it 'parses the table' do
        expect(parser.data).to eq([
          { 'name' => 'stemcell', 'os' => 'ubuntu-trusty', 'version' => '3142*', 'cid' => 'cid1' },
          { 'name' => 'stemcell', 'os' => 'ubuntu-trusty', 'version' => '3143*', 'cid' => 'cid2' }
        ])
      end

      context 'when the output is non-json' do
        let(:source) do
          'I     Am    A     Table'
        end

        it 'raises an error' do
          expect { parser.data }.to raise_error('Be sure to pass `json: true` arg to bosh_runner.run')
        end
      end

      context 'when there are empty elements' do
        let(:source) do
          %q({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": {
                "name": "Name",
                "version": "Version",
                "os": "OS",
                "cid": "CID"
            },
            "Rows": [
                {
                    "name": "stemcell",
                    "version": "",
                    "os": "ubuntu-trusty",
                    "cid": "cid1"
                },
                {
                    "name": "stemcell",
                    "version": "3143*",
                    "os": "ubuntu-trusty",
                    "cid": "cid2"
                }
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
        end

        it 'parses the table' do
          expect(parser.data).to eq([
            { 'name' => 'stemcell', 'os' => 'ubuntu-trusty', 'version' => '', 'cid' => 'cid1' },
            { 'name' => 'stemcell', 'os' => 'ubuntu-trusty', 'version' => '3143*', 'cid' => 'cid2' }
          ])
        end
      end

      context 'multiple tables' do
        let(:source) do
          %q({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": {
                "name": "Name",
                "version": "Version",
                "os": "OS",
                "cid": "CID"
            },
            "Rows": [
                {
                    "name": "stemcell",
                    "version": "",
                    "os": "ubuntu-trusty",
                    "cid": "cid1"
                }
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        },
        {
            "Content": "releases",
            "Header": {
                "name": "Name",
                "version": "Version"
            },
            "Rows": [
                {
                    "name": "release",
                    "version": "1.2.3"
                }
            ],
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
        end

        it 'parses rows from all tables' do
          expect(parser.data).to eq([
            { 'name' => 'stemcell', 'os' => 'ubuntu-trusty', 'version' => '', 'cid' => 'cid1' },
            { 'name' => 'release', 'version' => '1.2.3' }
          ])
        end
      end

      context 'table has no rows' do
        let(:source) do
          %q({
    "Tables": [
        {
            "Content": "stemcells",
            "Header": {
                "name": "Name",
                "version": "Version",
                "os": "OS",
                "cid": "CID"
            },
            "Notes": [
                "(*) Currently deployed"
            ]
        }
    ],
    "Blocks": null,
    "Lines": [
        "Using environment 'micro' as user 'admin'",
        "Succeeded"
    ]
})
        end

        it 'parses the table and returns empty list' do
          expect(parser.data).to eq([])
        end
      end
    end
  end
end
