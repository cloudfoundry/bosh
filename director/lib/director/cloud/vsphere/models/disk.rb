module VSphereCloud::Models
  class Disk < Ohm::Model
    attribute :path
    attribute :datacenter
    attribute :datastore
    attribute :size
  end
end
