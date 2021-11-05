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
	sabotageWord:Null<String>, // TODO: this will allow cheating by inspecting the network data! Is it worth it to use some fancy private/public key approach? Or rather have private data on server?
	sabotageWordIndex:Int,
	guessedWordIndexes:Array<Int>,
};

@:expose
class App {
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

	static function createGame() {
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
			Browser.location.href = "?game=" + doc.id;
		});
	}

	static function enterName() {
		assertNotNull(gameUrlParam);
		assertNotNull(db);

		final input:js.html.InputElement = cast Browser.document.getElementById("player-name");
		final name = input.value.trim();
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
			Browser.location.reload(/* forceget= */ false);
		});
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

	static function guessWord(index: Int) {
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

	public static function main() {
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

		Browser.document.getElementById("state-loading").style.display = "none";
		if (gameUrlParam == null) {
			Browser.document.getElementById("state-mainmenu").style.display = "block";
		} else if (playerId == null) {
			db.collection("games").doc(gameUrlParam).get().then(doc -> {
				if (doc.data() == null) {
					trace("Can't fetch game data");
					Browser.location.href = "?";
					return;
				}
				trace("Game data: " + doc.data());
				Browser.document.getElementById("state-join").style.display = "block";
				return;
			});
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
					Browser.document.getElementById("state-generictext").style.display = "none";
					Browser.document.getElementById("state-saboteurenterword").style.display = "none";
					Browser.document.getElementById("state-waitingroom").style.display = "none";
					Browser.document.getElementById("state-guesswords").style.display = "none";
					Browser.document.getElementById("state-guessedwords").style.display = "none";
					switch (gameData.state) {
						case WAITING_ROOM:
							Browser.document.getElementById("state-waitingroom").style.display = "block";
							final playerName = playerData.name;
							var text = 'Welcome $playerName!<br>Game ID: $gameUrlParam<br><br>Players in the game:';
							for (player in getPlayers(gameData)) {
								text += "<br> - " + player.name;
							}
							setText(text, "text-waitingroom");
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
}
