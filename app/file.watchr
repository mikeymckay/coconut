def push_and_test
#    `make combined`
  `git log --pretty=format:'%h' -n 1 > _attachments/version`
  `couchapp push`

  replace("_attachments/index.html", get_application_javascript_paths().map{|path| create_script_reference(path) }.join("\n"))
end

def get_application_javascript_paths
  javascriptFiles = ["app/config.js"]
  javascriptFiles.push(`find _attachments/models/  -name "*.js" | sed 's/_attachments\\///g'`.split(/\n/).sort())
  javascriptFiles.push(`find _attachments/views/  -name "*.js" | sed 's/_attachments\\///g'`.split(/\n/).sort())
  javascriptFiles.push "app/app.js"
  javascriptFiles.flatten!()
  return javascriptFiles
end

def create_script_reference (path)
  "<script type='text/javascript' src='#{path}'></script>"
end

def replace(file_path, contents)
  startString = "<!-- START -->"
  endString = "<!-- END -->"
  regExp = Regexp.new("#{startString}(.*)#{endString}", Regexp::MULTILINE)
  replacedResult = IO.read(file_path).gsub(regExp, "#{startString}\n#{contents}\n#{endString}")
  File.open(file_path, 'w') { |f| f.write(replacedResult) }
end

push_and_test()

#watch( '.html$') {|match_data|
#  push_and_test()
#}
watch( '.js$') {|match_data|
  push_and_test()
}
watch( '.*\.json$') {|match_data|
  push_and_test()
}
watch( '.css$') {|match_data|
  push_and_test()
}
watch( '(.*\.coffee$)' ) {|match_data|
  puts "\n"
  puts match_data[0]
  #result = `coffee --bare --compile #{match_data[0]} 2>&1`
  result = `coffee --map --bare --compile #{match_data[0]} 2>&1`
  error = false
  result.split('\n').each{|line|
    if line.match(/error/)  then
      error = true
      puts line
#      `mplayer -really-quiet "/usr/share/evolution/2.30/sounds/default_alarm.wav"`
      `notify-send "#{line}" -i /usr/share/icons/Humanity/status/128/dialog-warning.svg &`
    end
  }
  if not error
    push_and_test()
  end
}

