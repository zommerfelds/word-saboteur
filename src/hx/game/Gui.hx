package game;

class TextInputWithMobileKeyboardSupport extends h2d.TextInput {
	// Hidden input element used for mobile devices to toggle the onscreen keyboard.
	final inputElem:js.html.InputElement = cast js.Browser.document.getElementById("dummyInput");

	public var onEnter = () -> {};

	public function new(font, parent) {
		super(font, parent);
		backgroundColor = 0x80808080;
		textColor = 0xAAAAAA;

		// Clear the text in case a previous value was entered.
		inputElem.value = "";

		inputElem.onkeydown = (e) -> {
			if (e.key == "Enter") {
				onEnter();
			}
		};

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
			// TODO: Ctrl-A doesn't work right now, would need to consider the selection end?
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
	// To disable the button, use Button.interactive.visible = false.
	final buttonText = new h2d.Text(hxd.res.DefaultFont.get());

	public var text(get, set):String;

	static final tileCache:Map<Int, h2d.Tile> = [];

	public function new(parent, text, onClick, backgroundColor = 0xa0000000) {
		super(parent);
		padding = 30;
		verticalAlign = Middle;
		horizontalAlign = Middle;
		enableInteractive = true;
		fillWidth = true;
		interactive.onClick = (e) -> onClick();

		final cacheEntry = tileCache.get(backgroundColor);
		if (cacheEntry == null) {
			backgroundTile = makeTile(backgroundColor);
			tileCache.set(backgroundColor, backgroundTile);
		} else {
			backgroundTile = cacheEntry;
		}

		borderWidth = 8;
		borderHeight = 8;

		buttonText.text = text;
		buttonText.scale(2);
		addChild(buttonText);
		paddingBottom += Std.int(buttonText.getBounds().height * 0.3);
	}

	function makeTile(color) {
		final pixels = hxd.Res.border_01.toBitmap();
		pixels.lock();
		for (x in 0...pixels.width) {
			for (y in 0...pixels.height) {
				if (pixels.getPixel(x, y) == 0xa0000000) {
					pixels.setPixel(x, y, color);
				}
			}
		}
		pixels.unlock();
		return h2d.Tile.fromBitmap(pixels);
	}

	function get_text() {
		return buttonText.text;
	}

	function set_text(val) {
		return buttonText.text = val;
	}

	override function sync(ctx:h2d.RenderContext) {
		alpha = interactive.visible ? 1.0 : 0.5;
		super.sync(ctx);
	}
}
