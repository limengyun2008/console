# encoding: utf-8


require 'beaneater'
require 'json'
require 'cfoundry'


require_relative "../lib/console/svn"

# Connect to pool
beanstalk = Beaneater::Pool.new(['localhost:11300'])


beanstalk.jobs.register('create-app') do |job|

  begin
    data = JSON.parse(job.body)
    puts data
    buildpack = data["buildpack"]
    name = data["name"]
    org_guid = data["org_guid"]
    target = data["target"]
    token = data["token"]
    app_guid = data["app_guid"]

    puts app_guid

    token = CFoundry::AuthToken.new(token)
    client = CFoundry::V2::Client.new(target, token)
    org = client.organization org_guid
    space = nil
    for s in org.spaces
      if s.name == 'default'
        space = s
        break
      end
    end

    raise Exception, "error: this org has no default space." if space == nil
=begin

    app = client.app
    app.name = name
    app.total_instances = 1 # <- set the number of instances you want
    app.memory = 512 # <- set the allocated amount of memory

    app.space = space
    app.create!
=end

    tube = beanstalk.tubes[app_guid]
    tube.put "已开始处理"

    app = client.app app_guid
    tube.put "正在创建svn代码仓库 "
    svn = Svn.new(app.guid, buildpack)
    svn.mkdir_on_remote_svn_server

    tube.put "svn 创建完毕"
    tube.put "正在上传代码"
    svn.mkdir_on_local
    app.upload svn.local_app_dir
    tube.put "代码上传成功 "

    domain = client.domain_by_name  org.name + ".cf2.youdao.com"
    route = client.route
    route.host = name
    route.domain = domain
    route.space = space
    route.create!

    app.add_route(route)

    tube.put org.name + ".cf2.youdao.com 已绑定至应用"
    tube.put "应用启动中"
    app.start!
    tube.put "应用已启动"

    tube.put "finish"

=begin

    ! true do |log|
      puts log
      #puts "--------------------------------------"
      #
      #
      #(1...3).each do |i|
      #  @client.stream_url log  do |out|
      #    puts out
      #  end
      #
      #  sleep 5
      #end
    end
=end




  rescue Exception => e
    puts "exception :#{e}"
    puts e.backtrace
  end
=begin

=end

end


beanstalk.jobs.process!
