require 'sinatra/base'
require 'console'
require 'client'
require 'json'
require 'console/svn'
require 'fileutils'
require 'restclient'
require 'sinatra/synchrony'
require 'model'
require 'rexml/document'

#require 'faraday'
#Faraday.default_adapter = :em_synchrony

class Server < Sinatra::Base
  register Sinatra::Synchrony

  include Console

  set :root, File.expand_path('../../', __FILE__)

  before do
    @access_token = request.cookies["access_token"]
    if @access_token
      begin
        @cfoundry_client = Client.new("http://api.cf2.youdao.com" , @access_token)
        @client = @cfoundry_client.client
        #@client = cloudfoundry_client(nil, CFoundry::AuthToken.new(@access_token))
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
    orgs = @client.organizations_by_user_guid @client.current_user.guid

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

    @cfoundry_client = Client.new("http://api.cf2.youdao.com" , nil)
    @client = @cfoundry_client.client
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

      when "delete"

        app.routes.each do |route|
          route.delete!
        end
        app.delete!

      else
        logger.error 'wrong action!'
    end
    if action == "delete"
      content_type :json
      {:result => true}.to_json
    else
      redirect to("/app/#{guid}")
    end

  end

  get '/test' do
    #Sinatra::Synchrony.overload_tcpsocket!
    RestClient.get 'http://rubygems.org/gems/rest-client'

    #html = Faraday.get "http://rubygems.org/gems/rest-client"

  end

  get '/api/app/:guid/instances' do |guid|
    content_type :json
    puts "querying instances"
    app = @client.app guid
    #app = { :healthy? => true, :instances => ["1"]}
    app.to_json
  end

  get '/api/app/:guid/stats' do |guid|
    content_type :json

    @cfoundry_client.get_app_health( guid ).to_json
  end

  get '/api/app/:guid/svnlog' do |guid|
    content_type :json
    svn = Svn.new(guid, nil)
    #puts "svn log #{svn.svn_app_dir}  --xml --limit 10  --username limy --password LMYlmy111"
    xml_doc = `svn log #{svn.svn_app_dir} --stop-on-copy --xml --limit 10  --username limy --password LMYlmy111`
    #puts xml_doc
    doc = REXML::Document.new(xml_doc)
    elm_a = doc.elements.to_a("//log/logentry")
    result  = []
    #puts elm_a.size

    (0..elm_a.size-1).each do |i|
      log = {
            :revision => elm_a[i].attributes["revision"],
            :author => elm_a[i].elements["author"][0],
            :date => elm_a[i].elements["date"][0],
            :msg => elm_a[i].elements["msg"][0]
      }
      result.push log
    end
    result.to_json
  end
end


