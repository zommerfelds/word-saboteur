package game;

class TextInputWithMobileKeyboardSupport extends h2d.TextInput {
	final inputElem:js.html.InputElement = cast js.Browser.document.getElementById("dummyInput");

	public function new(font, parent) {
		super(font, parent);
		backgroundColor = 0x80808080;
		textColor = 0xAAAAAA;

		// Clear the text in case a previous value was entered.
		inputElem.value = "";

		if (hxd.System.getValue(IsTouch)) {
			onClick = (e) -> {
				inputElem.focus();
                inputElem.setSelectionRange(cursorIndex, cursorIndex);
			};
		}
	}

	override function sync(ctx) {
		if (hxd.System.getValue(IsTouch)) {
			text = inputElem.value;
			cursorIndex = inputElem.selectionStart;
            selectionSize = 1;
		}
        super.sync(ctx);
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