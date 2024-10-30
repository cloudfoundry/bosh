require 'simplecov'

SimpleCov.start do
  add_filter('/spec/')
  add_filter('/vendor/')
  merge_timeout(3600)
  root(BOSH_REPO_SRC_DIR)
end
