require 'sinatra/base'
require 'console'
#require 'grit'

class Server < Sinatra::Base

  #include Grit

  set :root, File.expand_path('../../', __FILE__)
  enable :sessions

  before do

  end

  get '/' do
    erb :index
  end

  get '/apps' do
    erb :index
  end

  get '/app/create' do
    erb :create_app
  end

  post '/app/create' do
    data = JSON.parse request.body.read

    type = data["type"]
    name = data["name"]
    domain = data["domain"]

    client = Client.new("1","2")
    redirect to('/app/1')
  end
end