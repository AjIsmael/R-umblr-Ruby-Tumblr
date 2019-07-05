require "sinatra/activerecord"
require "sinatra"

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database:"./database.sqlite3")
set :database, {adapter: "sqlite3", database: "./database.sqlite3"}
enable :sessions

class User < ActiveRecord::Base
end

class Post < ActiveRecord::Base
end


get "/" do
  puts "Running"
  erb :home
end

get "/users/signup" do
  if session[:user_id]
     redirect '/users/feeds'
  else
    @user = User.new
    erb :'users/signup'
  end
end

post '/users/signup' do
  @user = User.new(params)
  if @user.save
    p "#{@user.first_name} was saved to the database"
  end
  erb :'users/thanks'
end

get '/users/thanks' do
  erb :'users/thanks'
end

get '/users/login' do
  if session[:user_id]
    redirect '/users/feeds'
  else
    erb :'users/login'
  end
end

post '/users/login' do
  given_password = params[:password]
  user = User.find_by(email:params[:email])
  if user
    if user.password == given_password
      p "user authenticated successfully"
      session[:user_id] = user.id
    else
      p "invalid password"
    end
  end
end

get '/users/feeds' do
  if session[:user_id]
    @posts = JSON.parse(Post.all.order(created_at: :desc).to_json)
    erb :'/users/feeds'
  else
    redirect '/'
  end
end


get '/users/profile' do
  if session[:user_id]
    @user = User.find_by(id:session[:user_id])
    erb :'/users/profile'
  else
    redirect '/'
  end
end

post '/users/profile' do
  @user = User.find_by(id:session[:user_id])
  @user.update_attribute(:first_name, params[:first_name]) if params[:first_name]
  @user.update_attribute(:last_name, params[:last_name]) if params[:last_name]
  erb :'/users/profile'
end

get '/users/my-post' do
  if session[:user_id]
    @posts = JSON.parse((Post.where("user_id = ?", session[:user_id]).order(created_at: :desc).to_json))
    erb :'/users/my-post'
  else
    redirect '/'
  end
end

get '/users/post' do
  if session[:user_id]
    @post = Post.new
    erb :'users/post'
  else
    redirect '/'
  end
end

post '/users/post' do
  params.merge!(user_id: "#{session[:user_id]}")
  @post = Post.new(params)
  if @post.save
    p "#{@post.title} was saved to the database"
    p params
  end
  redirect '/'
end

# Delete request
post '/logout' do
  session.clear
  p 'user logged out successfully'
  redirect '/'
end
