package game;

class TextInputWithMobileKeyboardSupport extends h2d.TextInput {
	// Hidden input element used for mobile devices to toggle the onscreen keyboard.
	final inputElem:js.html.InputElement = cast js.Browser.document.getElementById("dummyInput");

	public function new(font, parent) {
		super(font, parent);
		backgroundColor = 0x80808080;
		textColor = 0xAAAAAA;

		// Clear the text in case a previous value was entered.
		inputElem.value = "";

		onClick = (e) -> {
			// This is only useful for mobile, but we do the same everywhere to reduce branching.
			// If it becomes necesarry to branch, the hxd.System.getValue(IsTouch) value can be used.
			inputElem.focus();
			inputElem.setSelectionRange(cursorIndex, cursorIndex);
		};
	}

	override function sync(ctx) {
		// Transfer text from the hidden input field, in case a touch screen is entering text into the input field.
		text = inputElem.value;
		if (js.Browser.document.activeElement == inputElem) {
			cursorIndex = inputElem.selectionStart;
		} else {
			cursorIndex = -1;
		}

		super.sync(ctx);
	}

	public override function focus() {
		inputElem.focus();
		super.focus();
	}
}

class Button extends h2d.Flow {
	public function new(parent, text, onClick) {
		super(parent);
		backgroundTile = h2d.Tile.fromColor(0x77777);
		padding = 30;
		verticalAlign = Middle;
		horizontalAlign = Middle;
		enableInteractive = true;
		fillWidth = true;
		interactive.onClick = (e) -> onClick();

		final buttonText = new h2d.Text(hxd.res.DefaultFont.get(), this);
		buttonText.text = text;
		buttonText.scale(2);
		paddingBottom += Std.int(buttonText.getBounds().height * 0.3);
	}
}
