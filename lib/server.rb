require 'sinatra/base'
require 'console'
require 'json'
#require 'grit'



class Server < Sinatra::Base

  include Console

  set :root, File.expand_path('../../', __FILE__)

  before do

    @access_token = request.cookies["access_token"]
    if @access_token
      begin
        @client = cloudfoundry_client(nil, CFoundry::AuthToken.new(@access_token))
        login = @client.logged_in?
      rescue Exception => e
          puts e
          login = false
      end
    else
      login = false
    end

    if !login && request.path_info != '/login'
      redirect to('/login?redirect=true')
    end
  end

  get '/' do
    erb :index
  end

  get '/login' do
    erb :login
  end

  post '/login' do
    username = params['username']
    password = params['password']

    @client = cloudfoundry_client()
    access_token = @client.login(username,password)
    if access_token
      response.set_cookie("access_token", :value => access_token.auth_header.to_s )
      redirect to('/')
    end
  end

  get '/apps' do
    erb :index
  end

  get '/app/create' do
    erb :create_app
  end

  post '/app/create' do
    buildpack = params["buildpack"]
    name = params["name"]
    domain = params["domain"]

    app = @client.app
    app.name = name
    app.total_instances = 1 # <- set the number of instances you want
    app.memory = 512 # <- set the allocated amount of memory
    app.production = false # <- should the application run in production mode
    app.buildpack = buildpack # <- set the buildpack
    app.create!

    # zhaodch need to code here....

    guid = app.guid
    redirect to("/app/#{guid}")
  end

  get '/app/:guid' do |guid|
    app = @client.app_by_guid guid
    erb :app , :locals => {:app => app}
  end

  get '/api/orgs' do
    content_type :json

    orgs = @client.organizations_by_user_guid @client.current_user.guid
    puts "#{orgs}"
    orgs.to_json
  end

  get '/api/org/:guid' do |guid|
    content_type :json
    org = @client.Organization guid
    {:guid => org.guid, :name => org.name }.to_json
  end

  get '/api/apps' do
    nil
  end

end


require "cfoundry/v2/model"
module CFoundry::V2
  class Organization < Model
    def to_json(*a)
      hash = {
          :name => name,
          :spaces => spaces,
      }

      hash.to_json
    end
  end
end

module CFoundry::V2
  class Space < Model
    def to_json(*a)
      hash = {
          :name => name,
      }

      hash.to_json
    end
  end
end
