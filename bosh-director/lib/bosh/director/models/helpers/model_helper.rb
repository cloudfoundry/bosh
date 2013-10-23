module Bosh::Director::ModelHelper
  def safe_find_or_create(options)
    Bosh::Common.retryable(sleep: 0.1, tries: 2, on: [Exception]) do
      find_or_create(options)
    end
  end
end
