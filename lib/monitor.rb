require 'rubygems'
require 'nats/client'
require 'json'

module Console
	class Monitor
		HEALTH_SUFFIX="/healthz"
		HEALTH_DOWN = "down"
		NATS_REUQUEST_INTERVAL = 60
		HEALTH_COLLECT_INTERLVAL = 10

		attr_reader :nats_uri
		attr_reader :uaa, :uaaIndex, :uaaHostHolder
		attr_reader :dea, :deaIndex, :deaHostHolder
		attr_reader :router, :routerIndex, :routerHostHolder
		attr_reader :cc, :ccIndex, :ccHostHolder
		attr_reader :login, :loginIndex, :loginHostHolder
		attr_reader :components

		def initialize(nats_uri)
			@nats_uri = nats_uri
			initProperties
			initComponentsInfo
			collectConponentsHealth
		end

		def initComponentsInfo
			Thread.new do
				loop {
					["TERM", "INT"].each { |sig| trap(sig) { NATS.stop } }

					NATS.on_error { |err| puts "Server Error: #{err}"; exit! }

					NATS.start(:uri => @nats_uri) {
						NATS.request('vcap.component.discover') { |response|
							puts "Got response for Components: '#{response}'"
							NATS.stop
							parseDiscoverResponse(response)
						}
					}
					sleep(NATS_REUQUEST_INTERVAL)
				}
			end
		end

		def initProperties
			@uaa = Hash.new
			@dea = Hash.new
			@router = Hash.new
			@cc = Hash.new
			@login = Hash.new

			@uaaHostHolder = Array.new
			@deaHostHolder = Array.new
			@routerHostHolder = Array.new
			@ccHostHolder = Array.new
			@loginHostHolder = Array.new

			@uaaIndex=@deaIndex=@routerIndex=@loginIndex=@ccIndex=0

			@components = Hash.new
			@components["uaa"] = @uaa
			@components["dea"] = @dea
			@components["login"] = @login
			@components["router"] = @router
			@components["cc"] = @cc
		end

		def parseDiscoverResponse(response)
			response.each_line { |line|
				component = parseJsonToComponent(line)
				specifyComponent(component)
			}
		end

		def parseJsonToComponent (json_str)
			JSON.parse(json_str)
		end

		def specifyComponent (info)
			case info["type"].downcase
				when "uaa" then
					if !@uaaHostHolder.include? (info["host"] + "/uaa")
						@uaa[@uaaIndex]=info.clone
						@uaa[@uaaIndex]["host"] = @uaa[@uaaIndex]["host"] + "/uaa"
						@uaa[@uaaIndex]["purehost"] =  retriveHost info["host"]
						@uaaHostHolder.push @uaa[@uaaIndex]["host"]
						@uaaIndex+=1

						@login[@loginIndex]=info.clone
						@login[@loginIndex]["type"] = "Login"
						@login[@loginIndex]["host"] = @login[@loginIndex]["host"] + "/login"
						@login[@loginIndex]["purehost"] = retriveHost info["host"]
						@loginHostHolder.push @login[@loginIndex]["host"]
						@loginIndex+=1

					end
				when "dea" then
					if !@deaHostHolder.include? info["host"]
						@dea[@deaIndex]=info
						@dea[@deaIndex]["host"] =  @dea[@deaIndex]["host"]
						@dea[@deaIndex]["purehost"] = retriveHost info["host"]
						@deaHostHolder.push @dea[@deaIndex]["host"]
						@deaIndex+=1
					end
				when "router" then
					if !@routerHostHolder.include? info["host"]
						@router[@routerIndex]=info
						@router[@routerIndex]["host"] =  @router[@routerIndex]["host"]
						@router[@routerIndex]["purehost"] = retriveHost info["host"]
						@routerHostHolder.push @router[@routerIndex]["host"]
						@routerIndex+=1
					end
				when "cloudcontroller" then
					if !@ccHostHolder.include? info["host"]
						@cc[@ccIndex]=info
						@cc[@ccIndex]["host"] =  @cc[@ccIndex]["host"]
						@cc[@ccIndex]["purehost"] = retriveHost info["host"]
						@ccHostHolder.push @cc[@ccIndex]["host"]
						@ccIndex+=1
					end
				else
					raise "Cannot parse response" + info
			end
		end

		def collectConponentsHealth
			@uaaCollector = Thread.new do
				loop {
					(0..@uaaIndex-1).each { |i|
						updateHealth(@uaa[i])
					}
					sleep(HEALTH_COLLECT_INTERLVAL)
				}
			end

			@loginCollector = Thread.new do
				loop {
					(0..@loginIndex-1).each { |i|
						updateHealth(@login[i])
					}
					sleep(HEALTH_COLLECT_INTERLVAL)
				}
			end

			@deaCollector = Thread.new do
				loop {
					(0..@deaIndex-1).each { |i|
						updateHealth(@dea[i])
					}
					sleep(HEALTH_COLLECT_INTERLVAL)
				}
			end

			@ccCollector = Thread.new do
				loop {
					(0..@ccIndex-1).each { |i|
						updateHealth(@cc[i])
					}
					sleep(HEALTH_COLLECT_INTERLVAL)
				}
			end

			@routerCollector = Thread.new do
				loop {
					(0..@routerIndex-1).each { |i|
						updateHealth(@router[i])
					}
					sleep(HEALTH_COLLECT_INTERLVAL)
				}
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

#monitor = Console::Monitor.new("nats://10.168.3.189:4222")
#result = Thread.new do
#	loop {
#		puts "------------------------------------------------------------"
#		monitor.uaaIndex.times { |i|
#			puts "UAA " + i.to_s + " : " + (monitor.uaa[i].to_s|| "nil")
#		}
#
#		monitor.loginIndex.times { |i|
#			puts "LOGIN " + i.to_s + " : " + (monitor.login[i].to_s|| "nil")
#		}
#
#		monitor.deaIndex.times { |i|
#			puts "DEA " + i.to_s + " : " + (monitor.dea[i].to_s|| "nil")
#		}
#
#		monitor.routerIndex.times { |i|
#			puts "ROUTER " + i.to_s + " : " + (monitor.router[i].to_s|| "nil")
#		}
#
#		monitor.ccIndex.times { |i|
#			puts "CC " + i.to_s + " : " + (monitor.cc[i].to_s|| "nil")
#		}
#
#		sleep(10)
#	}
#end
#result.join()