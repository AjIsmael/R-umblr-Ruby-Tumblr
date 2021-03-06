require "action_mailer"
# set which directory ActionMailer should use
ActionMailer::Base.view_paths = File.dirname(__FILE__)

# ActionMailer configuration
ActionMailer::Base.smtp_settings = {
  address:    "smtp.gmail.com",
  port:       '587',
  user_name:  ENV['User_email'],
  password:   ENV['User_email_password'],
  authentication: :plain
}

class Newsletter < ActionMailer::Base
  default from: "from@example.com"
  def confirmation(recipent, confirmationCode, last_name)
    @recipent = recipent
    @confirmationCode = confirmationCode
    @last_name = last_name
    mail(to: recipent, subject: 'Thank you for signing up to Aj\'s Environmental Blog')
  end
end

class Newsletter < ActionMailer::Base
  default from: "from@example.com"
  def passwordChange(recipent, passwordChangeCode, last_name)
    @recipent = recipent
    @passwordChangeCode = passwordChangeCode
    @last_name = last_name
    mail(to: recipent, subject: 'Request for password change to Aj\'s Environmental Blog')
  end
end

class Newsletter < ActionMailer::Base
  default from: "from@example.com"
  def reactivate(recipent, reactivationCode, last_name)
    @recipent = recipent
    @reactivationCode = reactivationCode
    @last_name = last_name
    mail(to: recipent, subject: 'Welcome back to Aj\'s Environmental Blog')
  end
end
