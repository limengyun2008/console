require "cfoundry/v2/model"

module CFoundry::V2
  class Organization < Model
    def to_json(*a)
      hash = {
          :guid => guid,
          :name => name,
          :spaces => spaces
      }

      hash.to_json
    end
  end

  class Space < Model
    def to_json(*a)
      hash = {
          :name => name,
      }

      hash.to_json
    end
  end

  class App < Model
    def to_json(*a)
      hash = {
          :name => name,
          :stats => stats,
          :total_instances => total_instances,
          :instances => instances,
          :healthy? => healthy?
      }

      hash.to_json
    end

    class Instance
      def to_json(*a)
        hash = {
            :id => id,
            :manifest => @manifest
        }

        hash.to_json
      end
    end
  end
end