require 'faraday'
#Faraday.default_adapter = :em_synchrony

class Client
  attr_reader :client,:target

  def initialize(target, token)
    @target = target
    @client = CFoundry::V2::Client.new(target, token)
  end

  def get_app_health(appid)
    health_url = "http://limengyun.com" # "#{@target}/app/#{appid}/instances"
    response = Faraday.get health_url

    if response.body != nil
      #json = JSON.parse(response.body)
      puts response.body
      true
    end

    false
  end

  def get_app_instances(appid)

  end

end