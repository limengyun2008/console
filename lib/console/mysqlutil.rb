require 'mysql2'

class MysqlUtil
	USER_TABLE_NAME = "mysql.yae_mysql_user"
	CREATE_USERTABLE_SQL = "create table if not exists #{USER_TABLE_NAME}(
            db_name VARCHAR(128)  PRIMARY KEY,
            db_user  VARCHAR(128) NOT NULL,
            db_passwd VARCHAR(128) NOT NULL
        );"
	RANDOM_LENGTH = 10

	attr_reader :client

	def initialize(config)
		if config.nil? || config["host"].nil? || config["port"].nil? || config["username"].nil? || config["username"].nil?
			raise "Mysql config is incorrect, please check it"
		end
		@config = config
		exec_async(CREATE_USERTABLE_SQL)

	end

	def createDB(username)
		if (username.nil?)
			raise "Your username is empty, please check it."
		end
		dbname = username + randomStr
		dbpwd = randomStr

		sql = "
CREATE DATABASE if not exists #{dbname};
INSERT INTO #{USER_TABLE_NAME}(db_name, db_user, db_passwd) VALUES('#{dbname}', '#{username}', '#{dbpwd}');
INSERT INTO mysql.user (Host,User,Password) VALUES('%','#{dbname}',PASSWORD('#{dbpwd}'));
INSERT INTO mysql.db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv,Create_priv,Drop_priv,Alter_priv) VALUES('%','#{dbname}','#{dbname}','Y','Y','Y','Y','Y','Y','Y');
FLUSH PRIVILEGES;
"
		puts sql
		exec_async(sql)

		return dbInfo = {"dbname" => dbname, "dbpwd" => dbpwd}
	end

	def removeDB(dbname, dbpasswd)
		if (dbname.nil? || dbpasswd.nil?)
			raise "Your username is empty, please check it."
		end

		sql = "
DELETE FROM mysql.user where user='#{dbname}';
DROP DATABASE if exists #{dbname};
DELETE FROM #{USER_TABLE_NAME} where db_name='#{dbname}';
DELETE FROM mysql.db where db='#{dbname}';"
		exec_async(sql)
	end

	def listUserDB(username)
		if (username.nil?)
			raise "Your username is empty, please check it."
		end
		sql = "SELECT db_name, db_passwd from #{USER_TABLE_NAME} where db_user='#{username}';"
		query_sync(sql)
	end


	private

	def initClient
		@client = Mysql2::Client.new(:host => @config["host"].to_s, :port => @config["port"].to_i, :username => @config["username"].to_s, :password => @config["password"].to_s, :encoding => 'utf8', :flags => Mysql2::Client::MULTI_STATEMENTS)
		@client.query_options.merge!(:cast_booleans => true)
	end

	def query_async(sql)
		initClient
		@client.query(sql, :async => true)
	end

	def exec_async(sql)
		initClient
		@client.query(sql, :async => true)
	end

	def query_sync(sql)
		initClient
		@client.query(sql, :async => false)
	end

	def exec_sync(sql)
		initClient
		@client.query(sql, :async => false)
	end

	def randomStr()
		chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
		newpass = ""
		1.upto(RANDOM_LENGTH) { |i|
			newpass << chars[rand(chars.size-1)]
		}
		return newpass
	end

end