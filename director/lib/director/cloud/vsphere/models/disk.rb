module VSphereCloud::Models
  class Disk < Ohm::Model
    attribute :path
    attribute :datacenter
    attribute :size
  end
end
