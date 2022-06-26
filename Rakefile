task default: :install

task :uninstall do
  rm '/usr/local/bin/pastabot'
end

task install: :uninstall do
  install 'pastabot', '/usr/local/bin', mode: 0755, owner: 'root', group: 'root'
  File.write(File.join(Dir.home(ENV['SUDO_USER']), 'pastas.json'), '{}')
end
