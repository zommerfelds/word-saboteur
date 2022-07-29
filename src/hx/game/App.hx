package game;

import firebase.Firebase;
import firebase.firestore.FieldValue;
import haxe.DynamicAccess;
import js.html.URLSearchParams;
import uuid.Uuid;

using StringTools;

typedef Player = {
	name:String,
	score:Int,
};

enum abstract GameState(String) {
	var WAITING_ROOM;
	var SABOTEUR_ENTERING_WORD;
	var GUESSING_WORD; // This includes giving a clue, which can happen via other communication channel.
	var GUESSED_WORD; // End of the round
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

enum Screen {
	Main;
	EnterName;
	Waiting;
	WaitingForSaboteur;
	SaboteurEnterWord;
	Guessing;
}

@:expose
class App extends hxd.App {
	final viewRoot = new h2d.Object();
	var currentScreen:Null<Screen> = null;

	function getPlayers(gameData:GameData):Map<String, Player> {
		final map:Map<String, Player> = [];
		final it = gameData.players.keyValueIterator();
		while (it.hasNext()) {
			final n = it.next();
			@:nullSafety(Off)
			map.set(n.key, n.value);
		}
		return map;
	}

	function getNumPlayers(gameData:GameData):Int {
		var count = 0;
		final it = gameData.players.iterator();
		while (it.hasNext()) {
			@:nullSafety(Off)
			it.next();
			count++;
		}
		return count;
	}

	// TODO: Think about race condition when multiple users start at the same time.
	//       Maybe Firesafe would help here.
	function startGame() {
		assertNotNull(playerId);
		assertNotNull(db);
		assertNotNull(currentGameData);

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
		update.set(GameDataFields.targetWords, [Words.getRandomWord(), Words.getRandomWord()]);
		update.set(GameDataFields.sabotageWord, null);
		db.collection("games").doc(gameUrlParam).update(cast update);
	}

	function enterSaboteurWord(inputFieldValue:String) {
		assertNotNull(db);
		assertNotNull(currentGameData);
		if (currentGameData.state != SABOTEUR_ENTERING_WORD)
			return;

		final word = inputFieldValue.trim();
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

	function guessWord(index:Int) {
		assertNotNull(currentGameData);
		assertNotNull(db);

		final update:DynamicAccess<Dynamic> = {};
		// update.set(GameDataFields.state, GUESSED_ALL_WORDS);
		update.set(GameDataFields.guessedWordIndexes, FieldValue.arrayUnion(index));
		db.collection("games").doc(gameUrlParam).update(cast update);
	}

	var app:Null<firebase.app.App> = null;
	var db:Null<firebase.firestore.Firestore> = null;
	var gameUrlParam:Null<String> = null;
	var currentGameData:Null<GameData> = null;
	var playerId:Null<String> = null;

	static inline function assertNotNull(value:Null<Dynamic>, message = "value can't be null") {
		if (value == null) {
			throw message;
		}
	};

	static function main() {
		new App();
	}

	final pak = new hxd.fmt.pak.FileSystem();

	override function init() {
		// Load resources from PAK file
		final loader = new hxd.net.BinaryLoader("build/res.pak");
		loader.onLoaded = (data) -> {
			pak.addPak(new hxd.fmt.pak.FileSystem.FileInput(data));
			hxd.Res.loader = new hxd.res.Loader(pak);
			init2();
		}
		loader.load();
	}

	function init2() {
		engine.backgroundColor = 0xff1a4758;
		s2d.addChild(viewRoot);

		final captureAllInputs = new h2d.Flow();
		captureAllInputs.fillHeight = true;
		captureAllInputs.fillWidth = true;
		captureAllInputs.enableInteractive = true;
		captureAllInputs.interactive.propagateEvents = true;
		captureAllInputs.interactive.onClick = (e) -> {
			js.Browser.document.getElementById("webgl").focus();
		};
		new h2d.Object(captureAllInputs);
		s2d.addChildAt(captureAllInputs, 1);

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

		final urlParams = new URLSearchParams(js.Browser.window.location.search);
		gameUrlParam = urlParams.get("game");

		playerId = js.Browser.getLocalStorage().getItem("playerId");

		final tf = new h2d.Text(hxd.res.DefaultFont.get(), viewRoot);
		tf.text = "Loading...";
		tf.scale(4);

		if (gameUrlParam == null) {
			initMainScreen();
		} else {
			startDataUpdateWatcher();
		}


	}

	function startDataUpdateWatcher() {
		assertNotNull(db);
		db.collection("games").doc(gameUrlParam).onSnapshot(data -> {
			final gameData:GameData = cast data.data();
			if (gameData == null) {
				trace("Can't fetch game data");
				js.Browser.location.href = "?";
				return;
			}
			trace("Game data: " + gameData);

			if (playerId == null) {
				if (currentScreen != EnterName) {
					initEnterNameScreen();
				}
				return;
			}

			final playerData = gameData.players.get(playerId);
			if (playerData == null) {
				js.Browser.getLocalStorage().removeItem("playerId");
				js.Browser.location.reload(/* forceget= */ false);
				return;
			}
			if (currentGameData != gameData) {
				currentGameData = gameData;
				switch (gameData.state) {
					case WAITING_ROOM:
						initWaitingScreen();
					case SABOTEUR_ENTERING_WORD if (gameData.saboteurPlayerId != playerId):
						initWaitingForSaboteurScreen();
					case SABOTEUR_ENTERING_WORD:
						initSaboteurEnterWordScreen();
					case GUESSING_WORD:
						initGuessingScreen();
					case GUESSED_WORD:
						initGuessingScreen();
				}
			}
			return;
		});
	}

	function initMainScreen() {
		currentScreen = Main;
		viewRoot.removeChildren();
		final flow = new h2d.Flow(viewRoot);
		flow.layout = Vertical;
		flow.verticalSpacing = 50;
		flow.padding = 100;
		flow.fillWidth = true;
		flow.fillHeight = true;

		final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		title.text = "Word Saboteur";
		title.scale(4);

		new Gui.Button(flow, "New game", createGame);
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
			startDataUpdateWatcher();
		});
	}

	function setGameId(newId) {
		gameUrlParam = newId;
		if (newId != null) {
			js.Browser.window.history.pushState('', '', '?game=' + newId);
		} else {
			js.Browser.window.history.pushState('', '', '?');
		}
	}

	function initEnterNameScreen() {
		currentScreen = EnterName;

		viewRoot.removeChildren();

		final flow = new h2d.Flow(viewRoot);
		flow.layout = Vertical;
		flow.verticalSpacing = 50;
		flow.padding = 100;
		flow.fillWidth = true;
		flow.fillHeight = true;

		final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		title.text = "Joining game";
		title.scale(4);

		final prompt = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		prompt.text = "Enter your name:";
		prompt.scale(2);

		final input = new Gui.TextInputWithMobileKeyboardSupport(hxd.res.DefaultFont.get(), flow);
		input.scale(2);
		input.inputWidth = Std.int(flow.innerWidth / input.scaleX);
		input.focus(); // On mobile, this only brings up the keyboard if the user previously clicked on something. It won't open if this is a page load.
		input.onEnter = () -> enterName(input.text);

		final joinButton = new Gui.Button(flow, "Join", () -> enterName(input.text));
		new Utils.UpdateFunctionObject(() -> {
			joinButton.interactive.visible = (input.text != "");
		}, joinButton);
	}

	function enterName(inputFieldValue:String) {
		assertNotNull(gameUrlParam);
		assertNotNull(db);

		final name = inputFieldValue.trim();
		if (name == "") {
			// TODO: show warning message.
			return;
		}

		playerId = Uuid.nanoId();
		trace("Setting local storage");
		js.Browser.getLocalStorage().setItem("playerId", playerId);

		final update:DynamicAccess<Player> = {};
		update.set('players.$playerId', {name: name, score: 0});
		db.collection("games").doc(gameUrlParam).update(cast update);
		// Data watcher will pickup the change and should init a new view.
	}

	function initWaitingScreen() {
		currentScreen = Waiting;
		assertNotNull(playerId);
		assertNotNull(currentGameData);
		assertNotNull(currentGameData.players);

		viewRoot.removeChildren();

		final flow = new h2d.Flow(viewRoot);
		flow.layout = Vertical;
		flow.verticalSpacing = 50;
		flow.padding = 100;
		flow.fillWidth = true;
		flow.fillHeight = true;

		final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		title.text = "Waiting room";
		title.scale(4);

		final prompt = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		final playerData = currentGameData.players.get(playerId);
		assertNotNull(playerData);

		prompt.text = 'Welcome ${playerData.name}!\n\nShare this game using the URL of this page.\n\nPlayers in the game:';
		for (player in getPlayers(currentGameData)) {
			prompt.text += "\n- " + player.name;
		}
		prompt.scale(2);

		final startGameButton = new Gui.Button(flow, "", startGame);
		startGameButton.interactive.visible = false;
		new Utils.UpdateFunctionObject(() -> {
			assertNotNull(currentGameData);
			assertNotNull(currentGameData.players);
			final ready = getNumPlayers(currentGameData) >= 3;
			startGameButton.interactive.visible = ready;
			startGameButton.text = ready ? "Start game" : "Need 3 players";
		}, startGameButton);
	}

	function initWaitingForSaboteurScreen() {
		currentScreen = WaitingForSaboteur;
		assertNotNull(currentGameData);
		assertNotNull(currentGameData.saboteurPlayerId);
		final saboteur = currentGameData.players[currentGameData.saboteurPlayerId];
		assertNotNull(saboteur);

		viewRoot.removeChildren();

		final flow = new h2d.Flow(viewRoot);
		flow.layout = Vertical;
		flow.verticalSpacing = 50;
		flow.padding = 100;
		flow.fillWidth = true;
		flow.fillHeight = true;

		final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		title.text = "Saboteur round";
		title.scale(4);

		final text = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		text.text = '${saboteur.name} is the saboteur!\n\nPlease wait for the saboteur to enter a word.';
		text.scale(2);
	}

	function initSaboteurEnterWordScreen() {
		currentScreen = SaboteurEnterWord;
		assertNotNull(currentGameData);

		viewRoot.removeChildren();

		final flow = new h2d.Flow(viewRoot);
		flow.layout = Vertical;
		flow.verticalSpacing = 50;
		flow.padding = 100;
		flow.fillWidth = true;
		flow.fillHeight = true;

		final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		title.text = "Saboteur round";
		title.scale(4);

		final text = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		text.text = 'You are the saboteur!\n\nThe target words are:';
		text.scale(2);

		final choicesFlow = new h2d.Flow(flow);
		choicesFlow.verticalSpacing = 10;
		choicesFlow.layout = Vertical;
		for (word in currentGameData.targetWords) {
			final button = new Gui.Button(choicesFlow, word, () -> {});
		}

		final prompt = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		prompt.text = 'Enter your sabotage word below:';
		prompt.scale(2);

		final input = new Gui.TextInputWithMobileKeyboardSupport(hxd.res.DefaultFont.get(), flow);
		input.scale(2);
		input.inputWidth = Std.int(flow.innerWidth / input.scaleX);
		input.focus();

		new Gui.Button(flow, "Done", () -> enterSaboteurWord(input.text));
	}

	function initGuessingScreen() {
		currentScreen = Guessing;
		assertNotNull(currentGameData);
		assertNotNull(currentGameData.clueGiverPlayerId);
		assertNotNull(currentGameData.sabotageWord);
		final clueGiver = currentGameData.players[currentGameData.clueGiverPlayerId];
		assertNotNull(clueGiver);

		viewRoot.removeChildren();

		final flow = new h2d.Flow(viewRoot);
		flow.layout = Vertical;
		flow.verticalSpacing = 50;
		flow.padding = 100;
		flow.fillWidth = true;
		flow.fillHeight = true;

		final title = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		title.text = "Guessing round";
		title.scale(4);

		final isClueGiver = currentGameData.clueGiverPlayerId == playerId;
		final isGuesser = !isClueGiver && currentGameData.saboteurPlayerId != playerId;
		final doneGuessing = currentGameData.guessedWordIndexes.length == 2
			|| currentGameData.guessedWordIndexes.indexOf(currentGameData.sabotageWordIndex) != -1;

		final text = new h2d.Text(hxd.res.DefaultFont.get(), flow);
		if (isClueGiver) {
			text.text = 'You are the clue giver! Please give a clue for your team mates.';
		} else if (isGuesser) {
			text.text = '${clueGiver.name} will give you a clue. Please guess the two correct words:';
		} else {
			text.text = 'Please wait for the others to pick two words. ${clueGiver.name} is the clue giver.';
		}
		text.scale(2);

		final choicesFlow = new h2d.Flow(flow);
		choicesFlow.verticalSpacing = 10;
		choicesFlow.layout = Vertical;
		final words = currentGameData.targetWords.copy();
		words.insert(currentGameData.sabotageWordIndex, currentGameData.sabotageWord);
		for (i in 0...3) {
			var buttonLabel = words[i];
			if (isClueGiver && currentGameData.sabotageWordIndex == i) {
				buttonLabel += " (sabotage)";
			}
			
			var color = 0xa0858585;
			if (currentGameData.guessedWordIndexes.indexOf(i) != -1) {
				if (currentGameData.sabotageWordIndex == i) {
					color = 0xa08f4731;
				} else {
					color = 0xa0318f42;
				}
			}
			new Gui.Button(choicesFlow, buttonLabel, () -> isGuesser && !doneGuessing ? guessWord(i) : null, color);
		}

		if (doneGuessing) {
			new Gui.Button(flow, "Next round", startGame);
		}
	}
}
