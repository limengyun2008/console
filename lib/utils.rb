require 'grit'

module Console
	class Utils

		@@baseAppGitDir = "/home/vcap/gitDir/"
		@@baseAppGitUrl = "http://git.corp.youdao.com/"

		PhpProjectGitUrl = "https://github.com/appfog/af-php-base.git"
		JavaProjectGitUrl = "https://github.com/appfog/af-php-base.git"
		PythonProjectGitUrl = "https://github.com/appfog/af-php-base.git"
		NodeJsProjectGitUrl = "https://github.com/appfog/af-php-base.git"
		RubyProjectGitUrl = "https://github.com/appfog/af-php-base.git"

		class << self
			def pushNewApp(client, domain)
				app = client.app
				initAppDirAndGitUrl(client.current_user.email, app.name)
				puts "Init Git directory for " + client.current_user.email + " app name: " + app.name
				if appAvailable?
					puts "Create app dir for app " + app.name
				else
					raise NameError, "Cannot create app dir for " + app.name + ", please check whether it has been used"
				end
				createAppDir
				cloneBaseCode(app.buildpack)
				if app.buildpack == "java"
					buildApp
				end
				doPushApp(client, domain)

			end

			def appAvailable?
				Dir.exist?(@@currentAppDir) && Dir[@@currentAppDir + '/*'].empty?
			end

			def createAppDir
				begin
					FileUtils.mkdir(@@currentAppDir, {:noop => true, :verbose => true})
				rescue IOError
					puts "Cannot create app dir for IOERROR"
				end
			end

			def cloneBaseCode(buildpack)
				giturl = case buildpack
									 when "java" then JavaProjectGitUrl
									 when "python" then PythonProjectGitUrl
									 when "php" then PhpProjectGitUrl
									 when "nodejs" then NodeJsProjectGitUrl
									 when "ruby" then RubyProjectGitUrl
									 else nil
								 end
				if giturl == nil
					raise ArgumentError, "No match buildpack for input "+ buildpack
				end

				repo = Grit::Repo.new(@@currentAppDir, {})
				repo.fork_bare_from(giturl, {:quiet => true})

			end


			def updateCode(app, commit)
				initAppDirAndGitUrl(client.current_user.email, app.name)
				puts "Update code for " + client.current_user.email + " app name : " + app.name
				#TODO
			end

			def initAppDirAndGitUrl(username, appname)
				@@currentAppDir = @@baseAppGitDir + username + "/" + appname
				@@currentGitUrl = @@baseAppGitUrl + username + "/" + appname
			end

			def buildApp
				#TODO
			end

			def doPushApp(client, domain)
				app = client.app

				route = create_route(client.route, domain, app.name, app.space)

				bind_route(route, app) if app

				path = @@currentAppDir

				app.upload(path)

				app.start!(true)
			end

			def create_route(route, domain, host, space)
				route.host = host
				route.domain = domain
				route.space = space
				route.create!
				route
			end

			def bind_route(route, app)
				app.add_route(route)
			end

		end

	end

end