def log_error(message)
  puts message
  $stderr.puts message
  @db.save_doc({:collection => "error", :source => $PROGRAM_NAME, :datetime => Time.now.strftime("%Y-%m-%d %H:%M:%S"), :message => message})
end
