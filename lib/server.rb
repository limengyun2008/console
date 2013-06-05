require 'sinatra/base'
require 'console'
require 'json'
require 'console/svn'
require 'fileutils'
require 'cfmonitor'
require 'console/mysqlutil'


class Server < Sinatra::Base

	include Console

	set :root, File.expand_path('../../', __FILE__)

	begin
		@@config = YAML.load_file("config/test.yml")
	rescue => e
		abort "ERROR: Failed loading config: #{e}"
	end

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
		access_token = @client.login(username, password)
		if access_token
			response.set_cookie("access_token", :value => access_token.auth_header.to_s)
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
			erb :create_app, :locals => {:orgs => orgs}
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
		app.memory = 128 # <- set the allocated amount of memory
														#app.buildpack = buildpack
		app.space = space
		app.create!

		domain = @client.domain_by_name "limy.cf2.youdao.com"
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
		erb :app, :locals => {:app => app, :current_user => @current_user}
		erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
			erb :app, :locals => {:app => app}
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

				tmpdir = "#{Dir.tmpdir}/.apps"
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


	get '/api/orgs' do
		content_type :json

		orgs = @client.organizations_by_user_guid @client.current_user.guid
		#puts orgs[0].public_methods
		orgs.to_json
	end

	get '/api/org/:guid' do |guid|
		content_type :json
		org = @client.Organization guid
		{:guid => org.guid, :name => org.name}.to_json
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

	get '/monitor' do
		monitor = Console::CFMonitor.new(@@config["nats_uri"])
		redirect to("/monitor/show")
	end

	get '/monitor/show' do
		erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
			erb :monitor, :locals => {:components => Console::CFMonitor.components}
		end
	end

	get '/db' do
		dbclient = MysqlUtil.new(@@config['mysql'])
		result = dbclient.listUserDB(usernameFromEmail(@current_user.email))

		erb :layout, :layout => :base, :locals => {:current_user => @current_user} do
			erb :database, :locals => {:databases => result}
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
			}

			hash.to_json
		end
	end
end
