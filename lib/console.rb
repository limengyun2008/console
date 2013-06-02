require "console/version"
require 'cfoundry'
require 'json'
module Console



  def cloudfoundry_client(target = "http://api.cf2.youdao.com" , token = nil)
    target ||= "http://api.cf2.youdao.com"
    puts "target = #{target}, token= #{token}"
    CFoundry::V2::Client.new(target, token)
  end

  def get_app_health_url(appid)
    "http://api.cf2.youdao.com/app/#{appid}/instances"
  end
end
