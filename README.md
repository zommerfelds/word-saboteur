# word-saboteur
A simple multiplayer game

## Development

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/zommerfelds/word-saboteur)

Setup environment
```
sudo apt-get install haxe -y
mkdir ~/haxelib && haxelib setup ~/haxelib
haxelib install game.hxml
npm install -g firebase-tools
```

1. Install Haxe plugin

Serve the app:
```
python -m http.server
```

Compile & watch:
```
watch -x bash -c 'haxe game.hxml |& tail -n4'
```