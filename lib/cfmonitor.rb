require 'nats/client'

module Console
	class CFMonitor
		HEALTH_SUFFIX="/healthz"
		HEALTH_DOWN = "down"

		attr_reader :nats_uri
		attr_reader :uaa, :uaaIndex, :uaaHostHolder
		attr_reader :dea, :deaIndex, :deaHostHolder
		attr_reader :router, :routerIndex, :routerHostHolder
		attr_reader :cc, :ccIndex, :ccHostHolder
		attr_reader :login, :loginIndex, :loginHostHolder
		attr_reader :hm, :hmIndex, :hmHostHolder

		@@components = Hash.new
		@@components_cache = nil

		def initialize(nats_uri)
			@nats_uri = nats_uri
			initProperties
			initComponentsInfo
		end

		def CFMonitor.components
			@@components_cache
		end

		private

		def initComponentsInfo
			["TERM", "INT"].each { |sig| trap(sig) { NATS.stop } }

			NATS.on_error { |err| puts "Server Error: #{err}"; exit! }

			NATS.start(:uri => @nats_uri) {
				nid = NATS.request('vcap.component.discover') { |response|
					NATS.stop
					parseDiscoverResponse(response)
				}
			}
		end

		def initProperties
			@uaa = Hash.new
			@dea = Hash.new
			@router = Hash.new
			@cc = Hash.new
			@login = Hash.new
			@hm = Hash.new

			@uaaHostHolder = Array.new
			@deaHostHolder = Array.new
			@routerHostHolder = Array.new
			@ccHostHolder = Array.new
			@loginHostHolder = Array.new
			@hmHostHolder = Array.new

			@uaaIndex=@deaIndex=@routerIndex=@loginIndex=@ccIndex=@hmIndex=0

			@@components["router"] = @router
			@@components["dea"] = @dea
			@@components["cloud_controller"] = @cc
			@@components["uaa"] = @uaa
			@@components["login_server"] = @login
			@@components["health_manager"] = @hm
		end

		def parseDiscoverResponse(response)
			response.each_line { |line|
				component = parseJsonToComponent(line)
				collectConponentsHealth(specifyComponent(component))
			}
			@@components_cache = @@components
		end

		def parseJsonToComponent (json_str)
			JSON.parse(json_str)
		end

		def specifyComponent (info)
			type = nil;
			case info["type"].downcase
				when "uaa" then
					if !@uaaHostHolder.include? (info["host"] + "/uaa")
						@uaa[@uaaIndex]=info.clone
						@uaa[@uaaIndex]["host"] = @uaa[@uaaIndex]["host"] + "/uaa"
						@uaa[@uaaIndex]["purehost"] = retriveHost info["host"]
						@uaaHostHolder.push @uaa[@uaaIndex]["host"]
						@uaaIndex+=1

						@login[@loginIndex]=info.clone
						@login[@loginIndex]["type"] = "Login"
						@login[@loginIndex]["host"] = @login[@loginIndex]["host"] + "/login"
						@login[@loginIndex]["purehost"] = retriveHost info["host"]
						@loginHostHolder.push @login[@loginIndex]["host"]
						@loginIndex+=1
						type = "uaa"
					end
				when "dea" then
					if !@deaHostHolder.include? info["host"]
						@dea[@deaIndex]=info
						@dea[@deaIndex]["host"] = @dea[@deaIndex]["host"]
						@dea[@deaIndex]["purehost"] = retriveHost info["host"]
						@deaHostHolder.push @dea[@deaIndex]["host"]
						@deaIndex+=1
						type = "dea"
					end
				when "router" then
					if !@routerHostHolder.include? info["host"]
						@router[@routerIndex]=info
						@router[@routerIndex]["host"] = @router[@routerIndex]["host"]
						@router[@routerIndex]["purehost"] = retriveHost info["host"]
						@routerHostHolder.push @router[@routerIndex]["host"]
						@routerIndex+=1
						type = "router"
					end
				when "cloudcontroller" then
					if !@ccHostHolder.include? info["host"]
						@cc[@ccIndex]=info
						@cc[@ccIndex]["host"] = @cc[@ccIndex]["host"]
						@cc[@ccIndex]["purehost"] = retriveHost info["host"]
						@ccHostHolder.push @cc[@ccIndex]["host"]
						@ccIndex+=1
						type = "cc"
					end
				when "healthmanager" then
					if !@hmHostHolder.include? info["host"]
						@hm[@hmIndex]=info
						@hm[@hmIndex]["host"] = @hm[@hmIndex]["host"]
						@hm[@hmIndex]["purehost"] = retriveHost info["host"]
						@hmHostHolder.push @hm[@hmIndex]["host"]
						@hmIndex+=1
						type = "hm"
					end
				else
					raise "Cannot parse response" + info
			end
			type
		end

		def collectConponentsHealth(type)
			case type.downcase
				when "uaa" then
					(0..@uaaIndex-1).each { |i|
						updateHealth(@uaa[i])
					}
					(0..@loginIndex-1).each { |i|
						updateHealth(@login[i])
					}
				when "dea" then
					(0..@deaIndex-1).each { |i|
						updateHealth(@dea[i])
					}
				when "cc" then
					(0..@ccIndex-1).each { |i|
						updateHealth(@cc[i])
					}
				when "router" then
					(0..@routerIndex-1).each { |i|
						updateHealth(@router[i])
					}
				when "hm" then
					(0..@hmIndex-1).each { |i|
						updateHealth(@hm[i])
					}
				else
					raise "Cannot collect health " + type
			end
		end

		def createHealthzUrl (host, credential)
			"http://" + credential[0]+":"+credential[1] + "@" + host + HEALTH_SUFFIX
		end

		def updateHealth(com)
			url = createHealthzUrl(com["host"], com["credentials"])
			result = `curl -s #{url}`
			if $?.to_i == 0
				if com["type"] == "Router"
					com["health"]=parseJsonToComponent(result)["health"]
				else
					com["health"]=result
				end

			else
				com["health"]=HEALTH_DOWN
			end
		end

		def retriveHost(hostWithPort)
			hostWithPort.slice(0, hostWithPort.index(":"))
		end
	end
end

