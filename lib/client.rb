require 'faraday'
Faraday.default_adapter = :em_synchrony

class Client
  attr_reader :client,:target

  def initialize(target, access_token)
    @access_token = access_token
    @target = target
    @token = CFoundry::AuthToken.new(@access_token)

    @client = CFoundry::V2::Client.new(@target, @token)
  end

  def get_app_health(appid)
    health_url = "#{@target}/v2/apps/#{appid}/stats"


    conn = Faraday.new(:url => health_url) do |faraday|
      faraday.request  :url_encoded             # form-encode POST params
      #faraday.response :logger                  # log requests to STDOUT
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
    end

    response = conn.get do |req|
      req.headers['Authorization'] = @access_token
    end

    if response.body != nil
      puts response.body
      json = JSON.parse(response.body)
      puts json
      if !json["code"] && !json["description"]
        return json
      end
    end

    {:stats => false}
  end

  def get_app_instances(appid)

  end

end