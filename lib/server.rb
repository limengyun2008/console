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

  #include Grit

  set :root, File.expand_path('../../', __FILE__)
  enable :sessions

  before do
    puts "#{params}"



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
    access_token = "1"
=begin
      client = Client.new()
      access_token = client.login(username, password)
    rescue
      access_token = nil
=end

    if access_token
      response.set_cookie("foo", :value => "bar" )
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


    redirect to('/app/1')
  end
end