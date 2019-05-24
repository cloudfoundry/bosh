require File.expand_path('../../../spec_helper', __FILE__)

describe Bosh::Director::ProblemHandlers::InvalidProblem do
  class ErrorHandler < Bosh::Director::ProblemHandlers::Base
    register_as :err

    def initialize(resource_id, data)
      super
      handler_error('foobar')
    end
  end

  it 'is being used as a handler for problems that cannot represent themselves anymore' do
    handler = Bosh::Director::ProblemHandlers::Base.create_by_type(:err, 42, {})
    expect(handler).to be_kind_of(Bosh::Director::ProblemHandlers::InvalidProblem)
    expect(handler.instance_problem?).to be_falsey
    expect(handler.description).to eq('Problem (err 42) is no longer valid: foobar')
  end
end
