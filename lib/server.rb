require 'sinatra/base'
require 'console'
require 'json'
require 'console/svn'
require 'fileutils'
require 'restclient'
require 'sinatra/synchrony'

require 'faraday'
Faraday.default_adapter = :em_synchrony

class Server < Sinatra::Base
  register Sinatra::Synchrony

  include Console

  set :root, File.expand_path('../../', __FILE__)

  before do
    @access_token = request.cookies["access_token"]
    if @access_token
      begin
        @client = cloudfoundry_client(nil, CFoundry::AuthToken.new(@access_token))
        @current_user = @client.current_user
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
    #puts @client.public_methods
    orgs = @client.organizations_by_user_guid @client.current_user.guid
    #puts @client.public_methods

    erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
      erb :index, :locals => {:orgs => orgs}
    end


  end

  get '/login' do
    erb :login, :layout => :base
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
    orgs = @client.organizations_by_user_guid @client.current_user.guid
    erb :index, :locals => {:orgs => orgs}
  end

  get '/app/create' do
    orgs = @client.organizations_by_user_guid @client.current_user.guid
    erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
      erb :create_app , :locals => {:orgs => orgs}
    end

  end

  post '/app/create' do
    buildpack = params["buildpack"]
    name = params["name"]
    org = params["org"]

    org = @client.organization org
    space = nil
    for s in org.spaces
      if s.name == 'default'
        space = s
        break
      end
    end

    raise Exception, "error: this org has no default space." if space == nil

    app = @client.app
    app.name = name
    app.total_instances = 1 # <- set the number of instances you want
    app.memory = 512 # <- set the allocated amount of memory
    #app.buildpack = buildpack
    app.space = space
    app.create!

    domain = @client.domain_by_name  org.name + ".cf2.youdao.com"
    route = @client.route
    route.host = name
    route.domain = domain
    route.space = space
    route.create!

    app.add_route(route)

    svn = Svn.new(app.guid, buildpack)
    svn.mkdir_on_remote_svn_server
    svn.mkdir_on_local
    app.upload svn.local_app_dir

    app.start!(true)

    redirect to("/app/#{app.guid}")
  end


  get '/app/:guid' do |guid|
    app = @client.app guid
   # puts app.public_methods
    erb :app , :locals => {:app => app, :current_user => @current_user}
    erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
      erb :app , :locals => {:app => app}
    end
  end

  post '/app/:guid' do |guid|
    app = @client.app guid

    action = params["action"]

    case action
      when "start"
        app.start!
      when "stop"
        app.stop!
      when "restart"
        app.restart!
      when "update"
        revision = params["revision"]

        tmpdir =  "#{Dir.tmpdir}/.apps"
        FileUtils.mkdir_p tmpdir
        FileUtils.rm_rf "#{tmpdir}/#{guid}"
        Dir.chdir tmpdir do |dir|
          svn = Svn.new(app.guid)
          result = `svn co #{svn.svn_app_dir}  -r #{revision}  --username limy --password LMYlmy111`
          raise SvnException, result unless $?.to_i == 0
          app.upload "#{dir}/#{guid}"
          logger.info "uploading #{dir}/#{guid}"
          app.restart!(true)
        end

      else
        logger.error 'wrong action!'
    end

    redirect to("/app/#{guid}")
  end

  get '/test' do
    #Sinatra::Synchrony.overload_tcpsocket!

    html = Faraday.get "http://rubygems.org/gems/rest-client"
    html.body
    #'html'
  end

  get '/api/app/:guid/instances' do |guid|
    content_type :json
    puts "querying instances"
    app = @client.app guid
    #app = { :healthy? => true, :instances => ["1"]}
    app.to_json
  end

  get '/api/app/:guid/health' do |guid|
    content_type :json

    app = @client.app guid

    app.to_json
  end

  get '/api/org/:guid' do |guid|
    content_type :json
    org = @client.Organization guid
    {:guid => org.guid, :name => org.name }.to_json
  end

  get '/api/org/:guid/apps' do |guid|
    content_type :json

    spaces = @client.spaces_by_organization_guid "af78c950-6a67-4277-aa27-f2a246f46e0e"
    apps = @client.apps_by_organization_guid "af78c950-6a67-4277-aa27-f2a246f46e0e"
    apps.to_json
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
          :guid => guid,
          :name => name,
          :spaces => spaces
      }

      hash.to_json
    end
  end

  class Space < Model
    def to_json(*a)
      hash = {
          :name => name,
      }

      hash.to_json
    end
  end

  class App < Model
    def to_json(*a)
      hash = {
          :name => name,
          :stats => stats,
          :total_instances => total_instances,
          :instances => instances,
          :healthy? => healthy?
      }

      hash.to_json
    end

    class Instance
      def to_json(*a)
        hash = {
            :id => id,
            :manifest => @manifest
        }

        hash.to_json
      end
    end
  end
end
