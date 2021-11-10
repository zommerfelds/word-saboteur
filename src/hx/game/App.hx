package game;

import firebase.firestore.FieldValue;
import haxe.DynamicAccess;
import uuid.Uuid;
import js.html.URLSearchParams;
import firebase.Firebase;
import js.Browser;

using StringTools;

typedef Player = {
	name:String,
	score:Int,
};

enum abstract GameState(String) {
	var WAITING_ROOM;
	var SABOTEUR_ENTERING_WORD;
	var GUESSING_WORD; // This includes giving a clue, which can happen via other communication channel.
}

// TODO: there is probably a way to automate this with a macro
enum abstract GameDataFields(String) to String {
	var version;
	var players;
	var state;
	var saboteurPlayerId;
	var clueGiverPlayerId;
	var targetWords;
	var sabotageWord;
	var sabotageWordIndex;
	var guessedWordIndexes;
}

typedef GameData = {
	version:Int,
	players:DynamicAccess<Player>,
	state:GameState,
	saboteurPlayerId:Null<String>,
	clueGiverPlayerId:Null<String>,
	targetWords:Array<String>,
	sabotageWord:Null<String>,
	// TODO: this will allow cheating by inspecting the network data! Is it worth it to use some fancy private/public key approach? Or rather have private data on server?
	sabotageWordIndex:Int,
	guessedWordIndexes:Array<Int>,
};

@:expose
class App extends hxd.App {
	static function setText(str, id = "my-text") {
		Browser.document.getElementById(id).innerHTML = str;
	}

	static function getPlayers(gameData:GameData):Map<String, Player> {
		final map:Map<String, Player> = [];
		final it = gameData.players.keyValueIterator();
		while (it.hasNext()) {
			final n = it.next();
			@:nullSafety(Off)
			map.set(n.key, n.value);
		}
		return map;
	}

	// TODO: Think about race condition when multiple users start at the same time.
	//       Maybe Firesafe would help here.
	static function startGame() {
		assertNotNull(playerId);
		assertNotNull(db);
		assertNotNull(currentGameData);
		if (currentGameData.state != WAITING_ROOM)
			return;

		final update:DynamicAccess<Dynamic> = {};
		update.set(GameDataFields.state, SABOTEUR_ENTERING_WORD);
		// TODO: pick those properties at random
		update.set(GameDataFields.saboteurPlayerId, playerId);
		var otherPlayerId = "";
		for (somePlayerId in getPlayers(currentGameData).keys()) {
			if (somePlayerId != playerId) {
				otherPlayerId = somePlayerId;
				break;
			}
		}
		update.set(GameDataFields.clueGiverPlayerId, otherPlayerId);
		update.set(GameDataFields.targetWords, ["word1", "word2"]);
		update.set(GameDataFields.sabotageWord, null);
		db.collection("games").doc(gameUrlParam).update(cast update);
	}

	static function enterSaboteurWord() {
		assertNotNull(db);
		assertNotNull(currentGameData);
		if (currentGameData.state != SABOTEUR_ENTERING_WORD)
			return;

		final input:js.html.InputElement = cast Browser.document.getElementById("input-saboteur");
		final word = input.value.trim();
		if (word == "") {
			// TODO: show warning message.
			return;
		}

		final update:DynamicAccess<Dynamic> = {};
		update.set(GameDataFields.state, GUESSING_WORD);
		update.set(GameDataFields.sabotageWord, word);
		update.set(GameDataFields.sabotageWordIndex, Std.random(3));
		update.set(GameDataFields.guessedWordIndexes, []);
		db.collection("games").doc(gameUrlParam).update(cast update);
	}

	static function guessWord(index:Int) {
		assertNotNull(currentGameData);
		assertNotNull(db);

		final update:DynamicAccess<Dynamic> = {};
		// update.set(GameDataFields.state, GUESSED_ALL_WORDS);
		update.set(GameDataFields.guessedWordIndexes, FieldValue.arrayUnion(index));
		db.collection("games").doc(gameUrlParam).update(cast update);

		final button:js.html.ButtonElement = cast Browser.document.getElementById('button-guess-$index');
		button.disabled = true;
		if (index == currentGameData.sabotageWordIndex) {
			button.style.backgroundColor = 'lightcoral';
		} else {
			button.style.backgroundColor = 'lightblue';
		}
	}

	static var app:Null<firebase.app.App> = null;
	static var db:Null<firebase.firestore.Firestore> = null;
	static var gameUrlParam:Null<String> = null;
	static var currentGameData:Null<GameData> = null;
	static var playerId:Null<String> = null;

	static inline function assertNotNull(value:Null<Dynamic>, message = "value can't be null") {
		if (value == null) {
			throw message;
		}
	};

	static function main() {
		new App();
	}

	override function init() {
		// TODO: load this from external file and remove from Git (because this is a public repo and people might want to try it out).
		final config = {
			apiKey: "AIzaSyCn_j8KKaUcUkOWOLQzmx4_XhjFJ0LrKmg",
			authDomain: "word-saboteur.firebaseapp.com",
			projectId: "word-saboteur",
			storageBucket: "word-saboteur.appspot.com",
			messagingSenderId: "823899627043",
			appId: "1:823899627043:web:f303532e7e235766fadb96",
			measurementId: "G-HZCQNYVN74"
		};

		app = Firebase.initializeApp(config);
		db = app.firestore();

		final urlParams = new URLSearchParams(Browser.window.location.search);
		gameUrlParam = urlParams.get("game");

		playerId = Browser.getLocalStorage().getItem("playerId");

		final tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
		tf.text = "Loading...";
		tf.scale(4);

		if (gameUrlParam == null) {
			initMainScreen();
		} else if (playerId == null) {
			initEnterNameScreen();
		} else {
			db.collection("games").doc(gameUrlParam).onSnapshot(data -> {
				final gameData:GameData = cast data.data();
				if (gameData == null) {
					trace("Can't fetch game data");
					Browser.location.href = "?";
					return;
				}
				trace("Game data: " + gameData);
				final playerData = gameData.players.get(playerId);
				if (playerData == null) {
					Browser.getLocalStorage().removeItem("playerId");
					Browser.location.reload(/* forceget= */ false);
					return;
				}
				if (currentGameData != gameData) {
					switch (gameData.state) {
						case WAITING_ROOM:
							initWaitingScreen();
						case SABOTEUR_ENTERING_WORD if (gameData.saboteurPlayerId != playerId):
							assertNotNull(gameData.saboteurPlayerId);
							final saboteur = gameData.players[gameData.saboteurPlayerId];
							assertNotNull(saboteur);
							Browser.document.getElementById("state-generictext").style.display = "block";
							// TODO: do we show the saboteur's name?
							setText('${saboteur.name} is entering a word');
						case SABOTEUR_ENTERING_WORD:
							final text = 'You are the saboteur!<br><br>The target words are:<br>${gameData.targetWords[0]}, ${gameData.targetWords[1]}<br><br>Enter your sabotage word below:';
							setText(text, "text-saboteur");
							Browser.document.getElementById("state-saboteurenterword").style.display = "block";
						case GUESSING_WORD if (gameData.saboteurPlayerId == playerId):
							Browser.document.getElementById("state-generictext").style.display = "block";
							setText('The other team is guessing the words now.');
						case GUESSING_WORD if (gameData.clueGiverPlayerId != playerId):
							assertNotNull(gameData.clueGiverPlayerId);
							assertNotNull(gameData.sabotageWord);
							final clueGiver = gameData.players[gameData.clueGiverPlayerId];
							assertNotNull(clueGiver);
							final text = '${clueGiver.name} will give you a clue. Please guess the two correct words:';
							final words = gameData.targetWords.copy();
							words.insert(gameData.sabotageWordIndex, gameData.sabotageWord);
							setText(text, "text-guess");
							for (i in 0...3) {
								Browser.document.getElementById('button-guess-$i').textContent = words[i];
							}
							Browser.document.getElementById("state-guesswords").style.display = "block";
						case GUESSING_WORD:
							Browser.document.getElementById("state-generictext").style.display = "block";
							setText('You are the clue giver! Please give a clue for your team mates.<br><br>Correct words: ${gameData.targetWords[0]}, ${gameData.targetWords[1]}<br>Wrong word: ${gameData.sabotageWord}');
					}
				}
				currentGameData = gameData;
				return;
			});
		}
	}

	function initMainScreen() {
		s2d.removeChildren();
		final flow = new h2d.Flow(s2d);
		flow.layout = Vertical;
		flow.verticalSpacing = 50;
		flow.padding = 100;
		flow.fillWidth = true;
		flow.fillHeight = true;

		final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		title.text = "Word Saboteur";
		title.scale(4);

		final button = new h2d.Flow(flow);
		button.backgroundTile = h2d.Tile.fromColor(0x77777);
		button.padding = 30;
		button.verticalAlign = Middle;
		button.horizontalAlign = Middle;
		button.paddingBottom += 20;
		button.enableInteractive = true;
		button.interactive.onClick = (e) -> {
			createGame();
		}

		final buttonText = new h2d.Text(hxd.res.DefaultFont.get(), button);
		buttonText.text = "New game";
		buttonText.scale(2);
	}

	
	function createGame() {
		assertNotNull(db);

		final data:GameData = {
			version: 1,
			players: {},
			state: WAITING_ROOM,
			clueGiverPlayerId: null,
			saboteurPlayerId: null,
			targetWords: [],
			sabotageWord: null,
			sabotageWordIndex: 0,
			guessedWordIndexes: [],
		};
		db.collection("games").add(cast data).then(doc -> {
			trace("created game: " + doc.id);
			setGameId(doc.id);
			initEnterNameScreen();
		});
	}

	function setGameId(newId) {
		gameUrlParam = newId;
		if (newId != null) {
			Browser.window.history.pushState('', '', '?game=' + newId);
		} else {
			Browser.window.history.pushState('', '', '?');
		}
	}

	function initEnterNameScreen() {
		// assertNotNull(gameUrlParam);
		assertNotNull(db);
		db.collection("games").doc(gameUrlParam).get().then(doc -> {
			if (doc.data() == null) {
				trace("Can't fetch game data");
				initMainScreen();
				return;
			}
			trace("Game data: " + doc.data());

			s2d.removeChildren();

			final flow = new h2d.Flow(s2d);
			flow.layout = Vertical;
			flow.verticalSpacing = 50;
			flow.padding = 100;
			flow.fillWidth = true;
			flow.fillHeight = true;

			final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
			title.text = "Word Saboteur - waiting room";
			title.scale(4);

			final prompt = new h2d.Text(hxd.res.DefaultFont.get(), flow);
			prompt.text = "Enter your name:";
			prompt.scale(2);

			final input = new h2d.TextInput(hxd.res.DefaultFont.get(), flow);
			input.scale(2);
			input.inputWidth = 200;
			input.backgroundColor = 0x80808080;
			input.textColor = 0xAAAAAA;

			final button = new h2d.Flow(flow);
			button.backgroundTile = h2d.Tile.fromColor(0x77777);
			button.padding = 30;
			button.verticalAlign = Middle;
			button.horizontalAlign = Middle;
			button.enableInteractive = true;
			button.interactive.onClick = (e) -> {
				enterName(input.text);
			}

			final buttonText = new h2d.Text(hxd.res.DefaultFont.get(), button);
			buttonText.text = "Join";
			buttonText.scale(2);
			button.paddingBottom += Std.int(buttonText.getBounds().height * 0.3);
			return;
		});
	}

	function enterName(inputFieldValue: String) {
		assertNotNull(gameUrlParam);
		assertNotNull(db);

		final name = inputFieldValue.trim();
		if (name == "") {
			// TODO: show warning message.
			return;
		}

		final playerId = Uuid.nanoId();
		trace("Setting local storage");
		Browser.getLocalStorage().setItem("playerId", playerId);

		final update:DynamicAccess<Player> = {};
		update.set('players.$playerId', {name: name, score: 0});
		db.collection("games").doc(gameUrlParam).update(cast update).then(_ -> {
			initWaitingScreen();
		});
	}

	function initWaitingScreen() {
		trace("TODO: waiting screen");
/*
		final playerName = playerData.name;
		var text = 'Welcome $playerName!<br>Game ID: $gameUrlParam<br><br>Players in the game:';
		for (player in getPlayers(gameData)) {
			text += "<br> - " + player.name;
		}
		setText(text, "text-waitingroom");
		*/
	}
}
