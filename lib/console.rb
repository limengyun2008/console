require "console/version"

module Console
  class Client
    attr_reader :client

    def initialize(target=nil, token=nil)
      @client = CFoundry::V2::Client.new(target, token)
    end

    def client=(target, token)
      @client = CFoundry::V2::Client.new(target, token)
      @client
    end


  end

end
