require "sinatra/activerecord"
require "sinatra"
require "httparty"
require "action_mailer"
require "./mailer.rb"
require 'bcrypt'
require 'mimemagic'

$paramForSignup = {}
$accountToBeReset = {}
$confirmationCode = ''
$confirmationtrial = 0
$passwordResettrial = 0
$reactivateTrial = 0
$passwordChangeCode = ''
$reactivationCode = ''

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

def image_type_check(image)
  isValid = false
  if MimeMagic.by_magic(File.open(image)) != nil
    isValid = true if MimeMagic.by_magic(File.open(image)).mediatype == "image"
  end
  return isValid
end


def send_email(rec, confirmation_code,last_name)
  Newsletter.confirmation(rec,confirmation_code, last_name).deliver_now
end

def send_password_reset_email(rec, confirmation_code,last_name)
  Newsletter.passwordChange(rec,confirmation_code, last_name).deliver_now
end

def send_reactivation_email(rec, confirmation_code,last_name)
  Newsletter.reactivate(rec,confirmation_code, last_name).deliver_now
end
# #DEVELOPMENT
#
# ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database:"./database.sqlite3")
# set :database, {adapter: "sqlite3", database: "./database.sqlite3"}
#
# # DEPLOYED
# ActiveRecord::Base.establish_connection(ENV["DATABASE_URL"])
if ENV['RACK_ENV']
  require "active_record"
  ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
else
  set :database, {adapter: "sqlite3", database: "database.sqlite3"}
end



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
    @email = params[:email]
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
  else
    $confirmationtrial += 1
    if $confirmationtrial == 2
      @confirmationError = true
      erb :'/users/signup'
    else
      @alert = true
      erb :'/users/confirmSignUp'
    end
  end
end

get '/users/resetPassword' do
  if session[:user_id]
     redirect '/users/feeds'
  else
    @user = User.new
    erb :'users/signup'
  end
end

post '/users/resetPassword' do
  user = User.find_by(email:params[:email])
  if user
    $passwordChangeCode = rand.to_s[2..10]
    send_password_reset_email(params[:email], $passwordChangeCode, user.last_name)
    $accountToBeReset = user
    erb :'users/confirmationPasswordReset'
  else
    @PasswordResetResponse = true
  end
end

post '/users/confirmationPasswordReset' do
  if params[:confirmationPasswordReset] == $passwordChangeCode
    if params[:newPassword] != nil && params[:newPassword].strip != ''
          params[:newPassword] = BCrypt::Password.create(params[:newPassword])
          $accountToBeReset.update_attribute(:password,params[:newPassword])
    else
      @invalidSubmittion = true
    end
    erb :'users/login'
  else
    $passwordResettrial += 1
    if $passwordResettrial == 2
      @passwordResetConfirmationError = true
      erb :'/users/resetPassword'
    else
      @passwordResetalert = true
      erb :'/users/confirmationPasswordReset'
    end
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
    if user.status == 'canceled'
      @canceledAccountError = true
      erb :'/users/login'
    end
    userDecryptedPassword = BCrypt::Password.new(user.password)
    if userDecryptedPassword == given_password
      p "user authenticated successfully"
      session[:user_id] = user.id
      redirect '/users/feeds'
    else
      @alert = true
      erb :'/users/login'
    end
  else
    @alert = true
    erb :'/users/login'
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
  user = User.find_by(id:session[:user_id])
  name = "#{user.first_name} #{user.last_name}"
  params.merge!(name: name)
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
  userDecryptedPassword = BCrypt::Password.new(@user.password) if @user.password != nil
  if params[:currentPassword] != nil && params[:newPassword] != nil
    if params[:currentPassword].strip != '' && params[:newPassword].strip != ''
      if userDecryptedPassword == params[:currentPassword]
        params[:newPassword] = BCrypt::Password.create(params[:newPassword])
        @user.update_attribute(:password,params[:newPassword])
        @passwordChange = true
      else
        @passwordChangeError = true
      end
    end
  else
    @invalidSubmittion = true
  end
  if userDecryptedPassword == params[:PasswordForCanceling]
    params[:currentpassword] = BCrypt::Password.create(params[:password])
    @user.update_attribute(:status,"canceled")
    session.clear
    redirect '/'
  end

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
  if session[:user_id]
    if params[:title].strip == ''
      @alertTitle = true
      erb :'/users/post'
    elsif params[:content].strip == ''
      @alertContent = true
      erb :'/users/post'
    else
      if params[:image_url] != nil
        imageSize = File.size(params[:image_url][:tempfile])/1024
        p imageSize
        imageExtension = image_type_check(params[:image_url][:tempfile])
        randomNumber = rand.to_s[2..10]

        p imageExtension
        if imageSize > 500 || imageExtension == false
          @alertImage = true
          erb :'/users/post'
        else
          if !Dir.exist?("./public/Assets/img/#{session[:user_id]}")
            Dir.mkdir("./public/Assets/img/#{session[:user_id]}")
          end
          currentTime = Time.new
          tempArray = currentTime.to_s
          fileNameWithFormat = params[:image_url][:filename]
          @filename = tempArray.split(' ').join.split('-').join.split(':').join
          file = params[:image_url][:tempfile]
          params[:image_url] = "#{@filename}#{randomNumber}#{fileNameWithFormat}"
          File.open("./public/Assets/img/#{session[:user_id]}/#{@filename}#{randomNumber}#{fileNameWithFormat}", 'wb') do |f|
            f.write(file.read)
          end
          user = User.find_by(id:session[:user_id])
          name = "#{user.first_name} #{user.last_name}"
          params.merge!(user_id: "#{session[:user_id]}")
          params.merge!(name: name)
          @post = Post.new(params)
          if @post.save
            p "#{@post.title} was saved to the database"
            p params
          end
          redirect '/'
        end
      else
        params.merge!(user_id: "#{session[:user_id]}")
        user = User.find_by(id:session[:user_id])
        name = "#{user.first_name} #{user.last_name}"
        params.merge!(name: name)
        params[:image_url] = "none"
        @post = Post.new(params)
        if @post.save
          p "#{@post.title} was saved to the database"
          p params
        end
        redirect '/'
      end
    end
  else
    redirect '/'
  end

end

# Delete request
post '/logout' do
  session.clear
  p 'user logged out successfully'
  redirect '/'
end
