# pastabot
pastsbot, rewritten in ruby with some changes

# installing
```bash
wget https://raw.githubusercontent.com/hackers-pr/pastabot/main/pastabot
chmod +x pastabot
mv pastabot /usr/bin/local
echo {} > ~/.pastas.json
```

# using
to use the program, you must specify your token in the environment variable

```bash
TOKEN='your token' pastabot
```

## commands
```
ping
add [name] [pasta]
remove [name]
send [name]
```
