# word-saboteur
A simple multiplayer game

➡️➡️➡️ Access the live version here: https://word-saboteur.firebaseapp.com/ ⬅️⬅️⬅️

## Development

### Online IDE

Everything should run automatically inside Gitpod:

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/zommerfelds/word-saboteur)

Once the environment is set up, the game will be auto-compiled can be opened via port 8000:

![image](https://user-images.githubusercontent.com/1260622/179604035-fb7ca8d4-3845-4676-b4db-7a6df8a5b70a.png)

### Manual setup

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