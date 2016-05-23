require 'rest-client'

$configuration = JSON.parse(IO.read(File.dirname(__FILE__) + "/configuration.json"))

def send_email (recipients, html, subject, attachmentFilePaths = [])
  if recipients.kind_of?(Array)
    recipients = recipients.join(",")
  end

  RestClient.post("https://#{$configuration["mailgun_login"]}@api.mailgun.net/v2/coconut.mailgun.org/messages",{
    :from => "mmckay@rti.org",
    :to => recipients,
    :subject => subject,
    :text => "The non html version",
    :html => html,
    :attachment => attachmentFilePaths.map{|path| File.open(path)}
  })
end
