require "console/version"
require 'cfoundry'

module Console

  def cloudfoundry_client(target = "http://api.cf2.youdao.com" , token = nil)
    target ||= "http://api.cf2.youdao.com"
    puts "target = #{target}, token= #{token}"
    CFoundry::V2::Client.new(target, token)
  end

end
