package game;

import haxe.DynamicAccess;
import uuid.Uuid;
import js.html.URLSearchParams;
import firebase.Firebase;
import js.Browser;

using StringTools;

typedef Player = {name:String};
typedef GameData = {version:Int, players:DynamicAccess<Player>};

@:expose
class App {
	static function setText(str) {
		Browser.document.getElementById("my-text").innerHTML = str;
	}

	static function createGame() {
		if (db == null) {
			trace("Error: db is null");
			return;
		}

		final data:GameData = {
			version: 1,
			players: {},
		};
		db.collection("games").add(cast data).then(doc -> {
			trace("created game: " + doc.id);
			Browser.location.href = "?game=" + doc.id;
		});
	}

	static function enterName() {
		if (gameUrlParam == null) {
			trace("Error: gameUrlParam is null");
			return;
		}
		if (db == null) {
			trace("Error: db is null");
			return;
		}

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
		update.set('players.$playerId', {name: name});
		db.collection("games").doc(gameUrlParam).update(cast update).then(_ -> {
			Browser.location.reload(/* forceget= */ false);
		});
	}

	static var app:Null<firebase.app.App> = null;
	static var db:Null<firebase.firestore.Firestore> = null;
	static var gameUrlParam:Null<String> = null;

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

		final playerId = Browser.getLocalStorage().getItem("playerId");

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
			Browser.document.getElementById("state-game").style.display = "block";

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
				final playerName = playerData.name;
				var text = 'Welcome $playerName!<br>Game ID: $gameUrlParam<br><br>Players in the game:';
				final it = gameData.players.iterator();
				while (it.hasNext()) {
					@:nullSafety(Off)
					final player = it.next();
					text += "<br> - " + player.name;
				}
				setText(text);
			});
		}
	}
}
