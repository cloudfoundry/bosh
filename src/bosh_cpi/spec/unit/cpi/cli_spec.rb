# encoding: UTF-8

require 'spec_helper'

describe Bosh::Cpi::Cli do
  describe '#run' do
    subject { described_class.new(lambda { |context, cpi_api_version| cpi }, logs_io, result_io) }
    let(:cpi) { instance_double('Bosh::Cloud') }
    let(:logs_io) { StringIO.new }
    let(:result_io) { StringIO.new }
    let(:debug_io) { StringIO.new }

    before(:each) do
      allow($stderr).to receive(:write) do |text|
        debug_io.write(text)
      end
    end

    def make_result_regexp(result,  error = 'null', log_string = 'fake-log')
      case result
        when String
          formatted_result = "\"#{Regexp.quote(result)}\""
        when nil
          formatted_result = 'null'
        when Hash
          formatted_result =  "#{Regexp.quote(JSON.dump(result))}"
        else
          formatted_result = "#{Regexp.quote(result.to_s)}"
      end

      /{"result":#{formatted_result},"error":#{error},"log":".*#{log_string}.*"}/
    end

    describe 'current_vm_id' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:current_vm_id).
            with(no_args)) { logs_io.write('fake-log') }.
            and_return('fake-vm-cid')

        subject.run <<-JSON
          {
            "method": "current_vm_id",
            "arguments": [],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp('fake-vm-cid'))
      end

      it 'logs the method name and request ID' do
        expect(cpi).to(receive(:current_vm_id).
            with(no_args)) { logs_io.write('fake-log') }.
            and_return('fake-vm-cid')

        subject.run <<-JSON
          {
            "method": "current_vm_id",
            "arguments": [],
            "context" : { "director_uuid" : "abc", "request_id": "123456" }
          }
        JSON

        expect(debug_io.string).to include('INFO')
        expect(debug_io.string).to include('[req_id 123456]')
        expect(debug_io.string).to include('Starting current_vm_id')
        expect(debug_io.string).to include('Finished current_vm_id')
      end

      it 'logs start time, end time, and duration' do
        start_time = Time.new(2016,12,12,1,0,0)
        end_time = Time.new(2016,12,12,1,1,30)
        allow(Time).to receive(:now).and_return(start_time, end_time)

        expect(cpi).to(receive(:current_vm_id).
            with(no_args)) { logs_io.write('fake-log') }.
            and_return('fake-vm-cid')

        subject.run <<-JSON
          {
            "method": "current_vm_id",
            "arguments": [],
            "context" : { "director_uuid" : "abc", "request_id": "123456" }
          }
        JSON

        expect(debug_io.string).to match(/90\.\d+ seconds/)
      end
    end

    describe 'create_stemcell' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:create_stemcell).
          with('fake-stemcell-image-path', {'cloud' => 'props'})) { logs_io.write('fake-log') }.
          and_return('fake-stemcell-cid')

        subject.run <<-JSON
          {
            "method": "create_stemcell",
            "arguments": [
              "fake-stemcell-image-path",
              {"cloud": "props"}
            ],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to  match(make_result_regexp('fake-stemcell-cid'))
      end
    end

    describe 'delete_stemcell' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:delete_stemcell).
          with('fake-stemcell-cid')) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "delete_stemcell",
            "arguments": ["fake-stemcell-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to  match(make_result_regexp(nil))
      end
    end

    describe 'create_vm' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to receive(:create_vm).
          with(
            'fake-agent-id',
            'fake-stemcell-cid',
            {'cloud' => 'props'},
            {'net' => 'props'},
            ['fake-disk-cid'],
            {'env' => 'props'},
          ) { logs_io.write('fake-log') }.
          and_return('fake-vm-cid')

        subject.run <<-JSON
          {
            "method": "create_vm",
            "arguments": [
              "fake-agent-id",
              "fake-stemcell-cid",
              {"cloud": "props"},
              {"net": "props"},
              ["fake-disk-cid"],
              {"env": "props"}
            ],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp('fake-vm-cid'))
      end
      context 'when cpi_version >=2' do
        let(:cpi) { instance_double('Bosh::CloudV2') }
        it 'return additional network based on cpi_version' do
          expect(cpi).to receive(:create_vm).
            with(
              'fake-agent-id',
              'fake-stemcell-cid',
              {'cloud' => 'props'},
              {'net' => 'props'},
              ['fake-disk-cid'],
              {'env' => 'props'},
              ) { logs_io.write('fake-log') }.
            and_return(['fake-vm-cid', {'public': 'network', 'private': 'network'}])

          subject.run <<-JSON
          {
            "method": "create_vm",
            "arguments": [
              "fake-agent-id",
              "fake-stemcell-cid",
              {"cloud": "props"},
              {"net": "props"},
              ["fake-disk-cid"],
              {"env": "props"}
            ],
            "context" : { "director_uuid" : "abc" }
          }
          JSON

          expect(result_io.string).to include('"fake-vm-cid",{"public":"network","private":"network"}')
        end
      end
    end

    describe 'delete_vm' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:delete_vm).
          with('fake-vm-cid')) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "delete_vm",
            "arguments": ["fake-vm-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'has_vm' do
      [true, false].each do |result|
        it 'takes json and calls specified method on the cpi' do
          expect(cpi).to(receive(:has_vm?).
            with('fake-vm-cid')) { logs_io.write('fake-log') }.
            and_return(result)

          subject.run <<-JSON
            {
              "method": "has_vm",
              "arguments": ["fake-vm-cid"],
              "context" : { "director_uuid" : "abc" }
            }
          JSON

          expect(result_io.string).to match(make_result_regexp(result))
        end
      end
    end

    describe 'reboot_vm' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:reboot_vm).
          with('fake-vm-cid')) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "reboot_vm",
            "arguments": ["fake-vm-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'info' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:info){ logs_io.write('fake-log') }.and_return({"stemcell_formats" => ["format"]}))

        subject.run <<-JSON
          {
            "method": "info",
            "arguments": [],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp({'stemcell_formats' => ['format']}))
      end

      context 'when cpi api_version is specifed' do
        let(:cpi) { instance_double('Bosh::CloudV2') }
        it 'should return info with default cpi api_version' do
          expect(cpi).to(receive(:info) {logs_io.write('fake-log')}.and_return({'stemcell_formats' => ['format'], 'api_version' => '42'}))

          subject.run <<-JSON
          {
            "method": "info",
            "arguments": [],
            "context" : { "director_uuid" : "abc" },
            "api_version": 1
          }
          JSON

          expect(result_io.string).to match(make_result_regexp({'stemcell_formats' => ['format'], 'api_version' => '42'}))
        end
      end

    end

    describe 'set_vm_metadata' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:set_vm_metadata).
          with('fake-vm-cid', {'metadata' => 'hash'})) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "set_vm_metadata",
            "arguments": [
              "fake-vm-cid",
              {"metadata": "hash"}
            ],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'set_disk_metadata' do
      it 'takes json and calls specified method on the cpi' do
        allow(cpi).to receive(:set_disk_metadata) { logs_io.write('fake-log') }.and_return(nil)

        subject.run <<-JSON
          {
            "method": "set_disk_metadata",
            "arguments": [
              "fake-disk-id",
              {"key": "value"}
            ],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(cpi).to have_received(:set_disk_metadata).with('fake-disk-id', {'key' => 'value'})
        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'create_disk' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:create_disk).
          with(100_000, 'fake-vm-cid', nil)) { logs_io.write('fake-log') }.
          and_return('fake-disk-cid')

        subject.run <<-JSON
          {
            "method": "create_disk",
            "arguments": [
              100000,
              "fake-vm-cid",
              null
            ],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp('fake-disk-cid'))
      end
    end

    describe 'has_disk' do
      [true, false].each do |result|
        it 'takes json and calls specified method on the cpi' do
          expect(cpi).to(receive(:has_disk?).
            with('fake-disk-cid')) { logs_io.write('fake-log') }.
            and_return(result)

          subject.run <<-JSON
            {
              "method": "has_disk",
              "arguments": ["fake-disk-cid"],
              "context" : { "director_uuid" : "abc" }
            }
          JSON

          expect(result_io.string).to match(make_result_regexp(result))
        end
      end
    end

    describe 'delete_disk' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:delete_disk).
          with('fake-disk-cid')) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "delete_disk",
            "arguments": ["fake-disk-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'attach_disk' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:attach_disk).
          with('fake-vm-cid', 'fake-disk-cid')) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "attach_disk",
            "arguments": ["fake-vm-cid", "fake-disk-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'detach_disk' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:detach_disk).
          with('fake-vm-cid', 'fake-disk-cid')) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "detach_disk",
            "arguments": ["fake-vm-cid", "fake-disk-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'snapshot_disk' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:snapshot_disk).
          with('fake-disk-cid', nil)) { logs_io.write('fake-log') }.
          and_return('fake-snapshot-cid')

        subject.run <<-JSON
          {
            "method": "snapshot_disk",
            "arguments": ["fake-disk-cid", null],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp('fake-snapshot-cid'))
      end
    end

    describe 'delete_snapshot' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:delete_snapshot).
          with('fake-snapshot-cid')) { logs_io.write('fake-log') }.
          and_return(nil)

        subject.run <<-JSON
          {
            "method": "delete_snapshot",
            "arguments": ["fake-snapshot-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'get_disks' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:get_disks).
          with('fake-vm-cid')) { logs_io.write('fake-log') }.
          and_return(['fake-disk-cid'])

        subject.run <<-JSON
          {
            "method": "get_disks",
            "arguments": ["fake-vm-cid"],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp(['fake-disk-cid']))
      end
    end

    describe 'resize_disk' do
      it 'takes json and calls specified method on the cpi' do
        allow(cpi).to(receive(:resize_disk) {logs_io.write('fake-log')}.and_return(nil))

        subject.run <<-JSON
          {
            "method": "resize_disk",
            "arguments": ["fake-disk-cid", 1024],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(cpi).to have_received(:resize_disk).with('fake-disk-cid', 1024)
        expect(result_io.string).to match(make_result_regexp(nil))
      end
    end

    describe 'calculate_vm_cloud_properties' do
      it 'takes json and calls specified method on the cpi' do
        expect(cpi).to(receive(:calculate_vm_cloud_properties).
          with({ 'ram' => 1024, 'cpu' => 2, 'ephemeral_disk_size' => 2048 })) { logs_io.write('fake-log') }.
          and_return('fake-vm-type')

        subject.run <<-JSON
          {
            "method": "calculate_vm_cloud_properties",
            "arguments": [{ "ram": 1024, "cpu": 2, "ephemeral_disk_size": 2048 }],
            "context" : { "director_uuid" : "abc" }
          }
        JSON

        expect(result_io.string).to match(make_result_regexp('fake-vm-type'))
      end
    end

    describe 'configure cloud' do
      it 'configures cloud with the director uuid' do
        allow(cpi).to receive(:get_disks)
        subject.run '{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid" :"abc"}}'

        expect(Bosh::Clouds::Config.uuid).to eq('abc')
      end
    end

    context 'when request json cannot be parsed' do
      it 'returns invalid_call error' do
        subject.run('invalid-json')
        expect(result_io.string).to match(/{"result":null,"error":{"type":"InvalidCall","message":"Request cannot be deserialized, details: \d+: unexpected token at 'invalid-json'","ok_to_retry":false},"log":/)
        expect(result_io.string).to include_the_backtrace
      end
    end

    context 'when request json method is not a string' do
      it 'returns invalid_call error' do
        subject.run('{"method":[]}')
        expect(result_io.string).to include('{"result":null,"error":{"type":"InvalidCall","message":"Method must be a String, got: \'[]\'","ok_to_retry":false},"log":')
      end
    end

    context 'when request json includes unknown method' do
      it 'returns invalid_call error' do
        subject.run('{"method":"unknown-method"}')
        expect(result_io.string).to include('{"result":null,"error":{"type":"Bosh::Clouds::NotImplemented","message":"Method is not known, got: \'unknown-method\'","ok_to_retry":false},"log":')
      end
    end

    context 'when request json does not include arguments' do
      it 'returns invalid_call error' do
        subject.run('{"method":"create_vm"}')
        expect(result_io.string).to include('{"result":null,"error":{"type":"InvalidCall","message":"Arguments must be an Array","ok_to_retry":false},"log":')
      end
    end

    context 'when request json arguments is not an array' do
      it 'returns invalid_call error' do
        subject.run('{"method":"create_vm","arguments":"string"}')
        expect(result_io.string).to include('{"result":null,"error":{"type":"InvalidCall","message":"Arguments must be an Array","ok_to_retry":false},"log":')
      end
    end

    context 'when request json includes CPI api_version which is not an integer' do
      it 'returns invalid_call error' do
        subject.run('{"method":"info", "arguments": [], "api_version": "1"}')
        expect(result_io.string).to include('{"result":null,"error":{"type":"InvalidCall","message":"CPI api_version requested must be an Integer","ok_to_retry":false},"log":')
      end
    end

    context 'when request json context does not include director uuid' do
      it 'returns invalid_call error' do
        subject.run('{"method":"create_vm","arguments":[]}')
        expect(result_io.string).to include('{"result":null,"error":{"type":"InvalidCall","message":"Request should include context with director uuid","ok_to_retry":false},"log":')
      end
    end

    context 'when request json arguments are not correct arguments for the method' do
      let(:cpi) { Bosh::Cloud.new({}) }

      it 'returns invalid_call error' do
        subject.run('{"method":"create_vm","arguments":["only-one-arg"],"context":{"director_uuid":"abc"}}')
        expect(result_io.string).to include_the_backtrace
        expect(result_io.string).to match(make_result_regexp(nil, '{"type":"InvalidCall","message":"Arguments are not correct, details: .*","ok_to_retry":false}', '.*'))
      end
    end

    context 'when result is not serializable to json' do
      pending 'returns invalid_result error'
    end

    context 'when error is a subclass of CpiError (cpi failure)' do
      class ErrorClass1 < Bosh::Clouds::CpiError; end

      it 'returns error with camelized name of the class to indicate that cpi failed' do
        expect(cpi).to receive(:get_disks).with('fake-vm-cid').and_raise(ErrorClass1, 'fake-error-message')
        subject.run('{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid":"abc"}}')
        expect(result_io.string).to include_the_backtrace
        expect(result_io.string).to match(make_result_regexp(nil, '{"type":"ErrorClass1","message":"fake-error-message","ok_to_retry":false}', '.*'))
        expect(debug_io.string).to include('Finished get_disks')
      end
    end

    context 'when error is a subclass of CloudError (infrastructure failure)' do
      class ErrorClass2 < Bosh::Clouds::CloudError; end

      it 'returns error with camelized name of the class to indicate that call to cloud/infrastructure failed' do
        expect(cpi).to receive(:get_disks).with('fake-vm-cid').and_raise(ErrorClass2, 'fake-error-message')
        subject.run('{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid":"abc"}}')
        expect(result_io.string).to include_the_backtrace
        expect(result_io.string).to match(make_result_regexp(nil, '{"type":"ErrorClass2","message":"fake-error-message","ok_to_retry":false}', '.*'))
      end
    end

    context 'when error is a subclass of RetriableCloudError' do
      class ErrorClass3 < Bosh::Clouds::RetriableCloudError; end

      context 'when it is ok to retry error' do
        let(:exception) { ErrorClass3.new(true) }

        it 'returns error with camelized name of the class to indicate ' +
           'that call to cloud/infrastructure failed and suggesting it should be retried' do
          expect(cpi).to receive(:get_disks).with('fake-vm-cid').and_raise(exception)
          subject.run('{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid":"abc"}}')
          expect(result_io.string).to match(make_result_regexp(nil, '{"type":"ErrorClass3","message":"ErrorClass3","ok_to_retry":true}', '.*'))
          expect(result_io.string).to include_the_backtrace
        end
      end

      context 'when it is not ok to retry error' do
        it 'returns error with camelized name of the class to indicate that call to cloud/infrastructure failed and suggesting it should not be retried' do
          expect(cpi).to receive(:get_disks).with('fake-vm-cid').and_raise(ErrorClass3.new(false), "Some error message")
          subject.run('{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid":"abc"}}')
          expect(result_io.string).to match(make_result_regexp(nil, '{"type":"ErrorClass3","message":"Some error message","ok_to_retry":false}', '.*'))
          expect(result_io.string).to include_the_backtrace
        end
      end
    end

    context 'when error is not a subclass of known Bosh::Clouds errors' do
      class ErrorClass4 < Exception; end

      it 'returns unknown error' do
        expect(cpi).to receive(:get_disks).with('fake-vm-cid').and_raise(ErrorClass4, 'fake-error-message')
        subject.run('{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid":"abc"}}')
        expect(result_io.string).to match(make_result_regexp(nil, '{"type":"Unknown","message":"fake-error-message","ok_to_retry":false}', '.*'))
        expect(result_io.string).to include_the_backtrace
      end
    end

    context 'when logger has invalid utf-8 characters in the message string' do
      class ErrorClass4 < Exception; end

      it 'writes the result response to the provided logger' do
        expect(cpi).to receive(:has_disk?).with('fake-disk-cid') do
          bad_encoding = "\255"
          expect(bad_encoding.valid_encoding?).to be(false)
          logs_io.print(bad_encoding)

          true
        end

        subject.run('{"method":"has_disk","arguments":["fake-disk-cid"],"context":{"director_uuid":"abc"}}')
        expect(result_io.string).to include('�')
      end

      it 'writes the error response to the provided logger' do
        expect(cpi).to receive(:has_disk?).with('fake-disk-cid') do
          bad_encoding = "\255"
          expect(bad_encoding.valid_encoding?).to be(false)
          logs_io.print(bad_encoding)

          raise ErrorClass4.new('fäke-error')
        end

        subject.run('{"method":"has_disk","arguments":["fake-disk-cid"],"context":{"director_uuid":"abc"}}')
        expect(result_io.string).to include('�', 'fäke-error')
        expect(result_io.string).to include_the_backtrace
      end
    end

    context 'when error class name contains sequential uppercase letters' do
      class ERRClass5 < Bosh::Clouds::CpiError; end

      it 'returns error with correctly camelized name' do
        expect(cpi).to receive(:get_disks).with('fake-vm-cid').and_raise(ERRClass5, 'fake-error-message')
        subject.run('{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid":"abc"}}')
        expect(result_io.string).to match(make_result_regexp(nil, '{"type":"ERRClass5","message":"fake-error-message","ok_to_retry":false}', '.*'))
        expect(result_io.string).to include_the_backtrace
      end
    end

    describe 'when cpi is invoked' do
      it 'it is called with context as argument' do
        obj = double
        expect(obj).to receive(:check_context).with({"director_uuid" => "abc"})
        cli = described_class.new(lambda { |context, cpi_api_version|
          obj.check_context(context)
          cpi
        }, logs_io, result_io)
        cli.run('{"method":"get_disks","arguments":["fake-vm-cid"],"context":{"director_uuid":"abc"}}')
      end
    end
  end

  matcher :include_the_backtrace do
    match do |actual_string|
      expect(actual_string).to include('cli.rb')
    end

    failure_message do |actual|
      "Expected '#{actual}' to include the backtrace ('...cli.rb:...')"
    end
  end
end
