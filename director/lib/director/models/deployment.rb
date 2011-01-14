module Bosh::Director::Models

  class Instance < Ohm::Model; end
  class Stemcell < Ohm::Model; end

  class Deployment < Ohm::Model
    attribute :name
    attribute :manifest

    collection :job_instances, Instance
    set :stemcells, Stemcell

    index :name

    def validate
      assert_present :name
      assert_unique :name
    end
  end
end
