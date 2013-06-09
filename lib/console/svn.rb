class Svn

  attr_reader :local_app_dir, :svn_app_dir
  def initialize(guid, buildpack = nil)
    @buildpack = buildpack
    @guid = guid

    begin
      @config = YAML.load_file("config/test.yml")
    rescue => e
      abort "ERROR: Failed loading config: #{e}"
    end

    @svn_app_base = @config["svn"]["app_base"] #'https://dev.corp.youdao.com/svn/outfox/incubator/yaeapps/'
    @svn_template_base = @config["svn"]["template_base"] #'https://dev.corp.youdao.com/svn/outfox/incubator/yaetemplates/'
    @svn_username = @config["svn"]["username"] #'limy'
    @svn_password = @config["svn"]["password"] #'LMYlmy111'
    @local_base = @config["svn"]["local_base"] #'/home/lmy/yaeapps/'


    @local_app_dir = @local_base + @guid
    @svn_app_dir = @svn_app_base + @guid

  end


  def check_exist_on_remote
    result = `svn ls #{@svn_app_dir}  --username #{@svn_username} --password #{@svn_password}`

    $?.to_i == 0 ? true : false
  end

  def mkdir_on_remote_svn_server
    unless check_exist_on_remote
      #logger.info 'making dir on remote svn server...'

      svn_message = "create svn dir for app which guid=#{@guid}"
      template_addr = @svn_template_base + @buildpack

      result = `svn cp #{template_addr} #{@svn_app_dir} -m "#{svn_message}" --username #{@svn_username} --password #{@svn_password}`

      puts $?.to_i
      puts result
      raise SvnException, result unless $?.to_i == 0
    end

  end

  def check_exist_on_local

    result = `ls #{@local_app_dir}`
    $?.to_i == 0 ? true : false
  end

  def mkdir_on_local
    unless check_exist_on_local

      result = `cd #{@local_base} && svn co #{@svn_app_dir}  --username #{@svn_username} --password #{@svn_password}`

      raise Exception, result unless $?.to_i == 0
    end
  end

  #def push_app
  #
  #  FileUtils.cd(@local_app_dir) do |dir|
  #    #@client
  #  end
  #end
end


class SvnException < Exception
  def initialize(e)
    super(e)
  end
end