require 'sinatra/base'

class Server < Sinatra::Base

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

end