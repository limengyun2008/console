require 'sinatra/base'
require 'console'
require 'json'
#require 'grit'


=begin

#!/usr/bin/env ruby
require 'uaa'
token_issuer = CF::UAA::TokenIssuer.new("https://uaa.cloudfoundry.com", "vmc")
puts token_issuer.prompts.inspect
token = token_issuer.implicit_grant_with_creds(username: "<your_username>", password: "<your_password>")
token_info = TokenCoder.decode(token.info["access_token"], nil, nil, false) #token signature not verified
puts token_info["user_name"]

=end

class Server < Sinatra::Base

  include Console

  set :root, File.expand_path('../../', __FILE__)
  #enable :sessions


  before do

    @access_token = request.cookies["access_token"]
    if @access_token
      begin
        @client = cloudfoundry_client(:token => @access_token)
        login = client.logged_in?
      rescue Exception
        login = false
      end
    else
      login = false
    end

    login = true
    if !login && request.path_info != '/login'
      redirect to('/login')
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
      response.set_cookie("access_token", :value => access_token )
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

    app.space = client.spaces.first # <- assign the application to a space

    app.create!

    guid = app.guid
    redirect to("/app/#{guid}")
  end

  get '/app/:guid' do |guid|
    app = @client.app_by_guid guid
    erb :app , :locals => {:app => app}
  end

  get '/api/orgs' do
    content_type :json

    orgs = @client.orgs_by_manager_guid @client.current_user.guid
    orgs = { :a => 1, :b => 2}
    orgs.to_json
  end

  get '/api/org/:guid' do |guid|
    content_type :json
    org = @client.Organization guid
    {:guid => org.guid, :name => org.name }.to_json
  end

  get '/api/apps' do
    content_type :json
    apps = { :a => 1, :b => 2}
    apps.to_json
  end

end