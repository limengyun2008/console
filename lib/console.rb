require "console/version"

module Console
  class Client
    attr_reader :client


    def client=(target, token)
      @client = CFoundry::V2::Client.new(target, token)
      @client
    end


  end

end
