require 'rubygems'
require 'couchrest'

require './send_sms'
require './send_email'
require './log_error'

@db = CouchRest.database("http://localhost:5984/zanzibar")

def thresholds_without_notifications
  date_to_start_notifying = "2016-05-18"

  @db.all_docs({
    :startkey => "threshold",
    :endkey => "thresholdz",
    :include_docs => true
  })["rows"].map {|threshold| 
    threshold = threshold["doc"]
    if threshold["EndDate"] and threshold["EndDate"] >= date_to_start_notifying and not (threshold["SMS Sent To"] or threshold["Email Sent To"])
      threshold
    end
  }.compact
end

config = @db.get("coconut.config")

puts "Found #{thresholds_without_notifications.length} new thresholds requiring notification."

thresholds_without_notifications.each do |threshold_without_notification|
  # Send SMS
  sms_recipients = config["Threshold SMS Recipients"]
  email_recipients = config["Threshold Email Recipients"]
  sms_recipients.each do |recipient|
    send_sms(recipient,threshold_without_notification['Threshold Description'] + ": " + threshold_without_notification['Description'])
  end

  # Send email
  email_subject = "Threshold Exceeded In: #{threshold_without_notification['LocationName']}"
  email_text = "
    #{threshold_without_notification['Threshold Description']}:<br/>
    #{threshold_without_notification['Description']}<br/>
    <a href='http://localhost:5984/zanzibar/_design/zanzibar/index.html#show/issue/#{threshold_without_notification['_id']}'>View Issue</a>
  "
  send_email(email_recipients,email_text,email_subject)

  # Update doc
  threshold_without_notification["SMS Sent To"] = sms_recipients
  threshold_without_notification["Email Sent To"] = email_recipients
  @db.save_doc threshold_without_notification
end
