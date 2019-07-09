require "sinatra/activerecord"
require "sinatra"
require "httparty"
require "action_mailer"
require "./mailer.rb"
require 'bcrypt'

$paramForSignup = {}
$confirmationCode = ''

def signUpValidation
  isValid = true
  isValid = false if params[:first_name] == ''
  isValid = false if params[:last_name] == ''
  isValid = false if params[:email] == ''
  isValid = false if params[:password] == ''
  isValid = false if params[:birthday] == ''
  return isValid
end
def age(dateOfBirth)
  now = Time.new
  dob = dateOfBirth.split('-')
  dob = [dob[0].to_i, dob[1].to_i, dob[2].to_i]
  age = now.year - dob[0]
  if now.month > dob[1]
    age -= 1
  elsif now.day > dob[2]
    age -= 1
  end
  age
end
def emailValidation(email)
  true if email =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i
end


def send_email(rec, confirmation_code,last_name)
  Newsletter.confirmation(rec,confirmation_code, last_name).deliver_now
end

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database:"./database.sqlite3")
set :database, {adapter: "sqlite3", database: "./database.sqlite3"}
enable :sessions

class User < ActiveRecord::Base
end

class Post < ActiveRecord::Base
end

class Comment < ActiveRecord::Base
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
  user = User.find_by(email:params[:email])
  validity = signUpValidation
  age = age(params[:birthday])
  if validity == false
    @missedInformation = true
    p 'failed validation'
    p params[:birthday]
    erb :'users/signup'
  elsif age < 18 || age > 85
    @ageLimitalert = true
    erb :'users/signup'
  elsif !emailValidation(params[:email])
    @emailError = true
    erb :'users/signup'
  elsif user
    @alert = true
    p 'user exists'
    erb :'users/signup'
  else
    params[:password] = BCrypt::Password.create(params[:password])
    $confirmationCode = rand.to_s[2..10]
    $paramForSignup = params
    send_email(params[:email], $confirmationCode, params[:last_name])
    erb :'users/confirmSignUp'
  end
end

post '/users/confirmSignUp' do
  if params[:confirmationCode] == $confirmationCode
    @user = User.new($paramForSignup)
    if @user.save
      p "#{@user.first_name} was saved to the database"
    else
      p "something is not working"
    end
    p params[:confirmationCode]
    p $confirmationCode
    p $paramForSignup
    erb :'users/thanks'
  end
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
    userDecryptedPassword = BCrypt::Password.new(user.password)
    if userDecryptedPassword == given_password
      p "user authenticated successfully"
      session[:user_id] = user.id
      redirect '/users/feeds'
    else
      @alert = true
      erb :'/users/login'
    end
  end
end

get '/users/feeds' do
  if session[:user_id]
    @posts = JSON.parse(Post.all.order(created_at: :desc).to_json)
    @comments = []
    @posts.each do |post|
      @comments << JSON.parse((Comment.where("post_id = ?", post['id']).order(created_at: :desc).to_json))
    end
    erb :'/users/feeds'
  else
    redirect '/'
  end
end

post '/users/feeds' do
  params.merge!(commenter_id: "#{session[:user_id]}")
  @comment = Comment.new(params)
  if @comment.save
    p "#{@comment.id} was saved to the database"
  end
  redirect '/users/feeds'
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
