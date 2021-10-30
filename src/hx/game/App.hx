package game;

import js.html.URLSearchParams;
import firebase.Firebase;
import js.Browser;

@:expose
class App {
	static function setText(str) {
		Browser.document.getElementById("my-text").textContent = str;
	}

	static function createGame() {
		if (db == null) {
            trace("Error: db is null");
			return;
        }

		db.collection("games").add(cast {
			"version": 1,
		}).then(doc -> {
			trace("created game: " + doc.id);
			Browser.location.href = "?game=" + doc.id;
		});
	}

	static var app:Null<firebase.app.App> = null;
	static var db:Null<firebase.firestore.Firestore> = null;

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

		/*
            // Code examples:

			final snapShot = db.collection("test-collection").doc("1ZZjYI35tgBslLoyzHsV").get();
			snapShot.then(data -> {
				setText("Data: " + data.data());
			});

			db.collection("test-collection").doc("1ZZjYI35tgBslLoyzHsV").onSnapshot(data -> {
				setText("Data: " + data.data());
			});
		 */

		final urlParams = new URLSearchParams(Browser.window.location.search);
		final gameUrlParam = urlParams.get("game");

		if (gameUrlParam == null) {
			Browser.document.getElementById("loading").style.display = "none";
			Browser.document.getElementById("mainmenu").style.display = "block";
		} else {
			Browser.document.getElementById("loading").style.display = "none";
			Browser.document.getElementById("game").style.display = "block";
			setText("You joined game " + gameUrlParam);
		}
	}
}
