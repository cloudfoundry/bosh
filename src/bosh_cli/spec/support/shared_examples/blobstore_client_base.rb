module BaseSharedExamples
  def it_implements_base_client_interface
    delegation_args = [[:rest, :args], [:block, :block]]

    expected_interface = {
      create:  [[:req, :contents], [:opt, :id]],
      get:     [[:req, :id], [:opt, :file], [:opt, :options]],
      delete:  [[:req, :oid]],
      exists?: [[:req, :oid]],
    }

    expected_interface.each do |method, expected_params|
      it "implements base client interface method '#{method}' with proper signature" do
        actual_params = subject.method(method).parameters
        if actual_params == delegation_args
          # delegation is ok
        else
          expect(actual_params).to eq(expected_params)
        end
      end
    end
  end

  def it_calls_wrapped_client_methods(options)
    already_tested_methods = options.fetch(:except)

    describe '#create' do
      it "calls wrapped_client's create" do
        contents, id, result = 'fake-contents', 'fake-id', 'fake-result'
        expect(wrapped_client).to receive(:create).with(contents, id).and_return(result)
        expect(subject.create(contents, id)).to eq(result)
      end
    end

    unless already_tested_methods.include?(:get)
      describe '#get' do
        it "calls wrapped_client's get" do
          id, file, options, result = 'fake-id', 'fake-file', 'fake-options', 'fake-result'
          expect(wrapped_client).to receive(:get).with(id, file, options).and_return(result)
          expect(subject.get(id, file, options)).to eq(result)
        end
      end
    end

    describe '#delete' do
      it "calls wrapped_client's delete" do
        oid, result = 'fake-oid', 'fake-result'
        expect(wrapped_client).to receive(:delete).with(oid).and_return(result)
        expect(subject.delete(oid)).to eq(result)
      end
    end

    describe '#exists?' do
      it "calls wrapped_client's exists" do
        oid, result = 'fake-oid', 'fake-result'
        expect(wrapped_client).to receive(:exists?).with(oid).and_return(result)
        expect(subject.exists?(oid)).to eq(result)
      end
    end
  end
end

RSpec.configure do |config|
  config.extend(BaseSharedExamples)
end
