require "console/version"
require 'cfoundry'

module Console

  def cloudfoundry_client(target = "http://api.cloudfoundry.com" , token = nil)
    CFoundry::V2::Client.new(target, token)
  end

end
