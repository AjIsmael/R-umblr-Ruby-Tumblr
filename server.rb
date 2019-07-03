require "sinatra/activerecord"
require "sinatra"

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database:"./database.sqlite3")

enable :sessions

class User < ActiveRecord::Base
end
