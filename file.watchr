def push_and_test
  `git log --pretty=format:'%h' -n 1 > _attachments/version`
  `couchapp push`
end

push_and_test()

watch( '.html$') {|match_data|
  push_and_test()
}
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
  result = `coffee --bare --map --compile #{match_data[0]} 2>&1`
  error = false
  puts result
  result.split('\n').each{|line|
    if line.match(/In /)  then
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

