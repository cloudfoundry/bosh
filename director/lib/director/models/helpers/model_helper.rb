module Bosh::Director::ModelHelper
  def safe_find_or_create(options)
    Bosh::Common::Common.retryable(sleep: 0.1, tries: 2) { self.find_or_create options }
  end
end
