require 'bosh/cpi/registry_client'

# Shim for legacy usage (https://www.pivotaltracker.com/story/show/116920309)
# Also, note that the dependency on 'bosh_cpi' gem can be removed once this
# shim class is deleted.
module Bosh::Registry
  class Client < Bosh::Cpi::RegistryClient ; end
end
