# encoding: utf-8

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
require 'cfmonitor'
require 'console/mysqlutil'
require 'beaneater'
#require 'faraday'
#Faraday.default_adapter = :em_synchrony

class Server < Sinatra::Base
  register Sinatra::Synchrony

  include Console

  set :a, "aaa"

  set :root, File.expand_path('../../', __FILE__)

  @@beanstalk = Beaneater::Pool.new(['localhost:11300'])
  @@tube = @@beanstalk.tubes["create-app"]

	begin
		@@config = YAML.load_file("config/test.yml")
	rescue => e
		abort "ERROR: Failed loading config: #{e}"
	end

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

    puts "test a = #{settings.a}"
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
    org_guid = params["org"]


    org = @client.organization org_guid
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

    data = {
        :buildpack => buildpack,
        :name => name,
        :org_guid => org.guid,
        :target => @cfoundry_client.target,
        :token => @cfoundry_client.access_token,
        :app_guid => app.guid
    }
    @@tube.put data.to_json

    content_type :json

    {:result => 0, :app_guid => app.guid}.to_json

  end


  get '/app/:guid' do |guid|
    app = @client.app guid

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
          result = `svn co #{svn.svn_app_dir}  -r #{revision} --username #{@@config["svn"]["username"]} --password #{@@config["svn"]["password"]}`
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

    app.to_json
  end

  get '/api/app/:guid/stats' do |guid|
    content_type :json

    @cfoundry_client.get_app_stats( guid ).to_json
  end

  get '/api/app/:guid/create_log' do |guid|
    finished = false
    content_type :json
    logs = []
    tube = @@beanstalk.tubes[guid]
    while tube.peek(:ready)
      job = tube.reserve
      puts job.body

      if job.body == "finish"
        finished = true
        logs.push "正在跳转"
      else
        logs.push job.body.force_encoding('utf-8')
      end

      job.delete

    end
    {:result => 0, :finished => finished, :logs => logs}.to_json
  end



  get '/api/app/:guid/svnlog' do |guid|
    content_type :json
    svn = Svn.new(guid, nil)

    xml_doc = `svn log #{svn.svn_app_dir} --stop-on-copy --xml --limit 10  --username #{@@config["svn"]["username"]} --password #{@@config["svn"]["password"]}`
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

	get '/monitor' do
		monitor = Console::CFMonitor.new(@@config["nats_uri"])
		redirect to("/monitor/show")
	end

	get '/monitor/show' do
		erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
			erb :monitor, :locals => {:components => Console::CFMonitor.components}
		end
	end

	get '/appstats' do
		if @@config["stats_uri"].nil?
			redirect to("/appstats/error")
		end

		jsonResult = `curl -s #{@@config["stats_uri"]}`
		if $?.to_i == 0
			result = JSON.parse(jsonResult)
			droplets = result["droplets"]
			droplets.each { |appguid, droplet|
				app = @client.app appguid
				droplet["appname"] = app.name
				droplet["route"] = "No Route"

				begin
					droplet["route"] = app.url
				rescue => e
					puts app.routes.to_a.inspect
				end
			}
			erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
				erb :appstats, :locals => {:apperror => false, :appguid =>nil, :appstats => droplets}
			end
		else
			redirect to("/appstats/error")
		end
	end

	get '/appstats/:guid' do   |guid|
		if @@config["stats_uri"].nil?
			redirect to("/appstats/error")
		end

		jsonResult = `curl -s #{@@config["stats_uri"]}`
		if $?.to_i == 0
			result = JSON.parse(jsonResult)
			droplets = result["droplets"]
			droplet = droplets[guid]
			app = @client.app guid
			erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
				erb :appstats, :locals => {:apperror => false, :appguid => guid, :droplet => droplet, :app => app}
			end
		else
			redirect to("/appstats/error")
		end
	end

	get '/appstats/error' do
		erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
			erb :appstats, :locals => {:apperror => true}
		end
	end

	get '/db' do
		dbclient = MysqlUtil.new(@@config['mysql'])
		result = dbclient.listUserDB(usernameFromEmail(@current_user.email))
		adminUrl = @@config["mysql_admin"]
		dbUrl = @@config["mysql"]["host"] + ":" + @@config["mysql"]["port"].to_s

		erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
			erb :database, :locals => {:databases => result, :dbadmin => adminUrl.to_s, :dburl => dbUrl}
		end
	end

	get '/db/:dbname/:dbpasswd' do
		dbclient = MysqlUtil.new(@@config['mysql'])
		dbclient.removeDB(params[:dbname], params[:dbpasswd])

		redirect("/db")
	end

	get '/db/create' do
		dbclient = MysqlUtil.new(@@config['mysql'])
		dbclient.createDB(usernameFromEmail(@current_user.email))

		redirect("/db")
	end

	def usernameFromEmail(email)
		if email.nil?
			redirect("/login")
		end
		email.slice(0, email.index("@"))
	end

end

