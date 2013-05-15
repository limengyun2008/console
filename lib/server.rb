require 'sinatra/base'
require 'console'
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
    puts "#{params}"
    puts "#{request.path_info}"

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


    type = params["type"]
    name = params["name"]
    domain = params["domain"]

    @client.create_app()
    redirect to('/app/1')
  end
end