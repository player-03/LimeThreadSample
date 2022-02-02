package com.player03.limethreads;

import haxe.Timer;
import libnoise.generator.Billow;
import libnoise.generator.Perlin;
import libnoise.generator.RidgedMultifractal;
import libnoise.generator.Sphere;
import libnoise.generator.Voronoi;
import libnoise.ModuleBase;
import libnoise.QualityMode;
import lime.system.ThreadPool;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.utils.Assets;
import openfl.utils.ByteArray;

class Main extends Sprite {
	private var bitmap:Bitmap;
	private var rect:Rectangle;
	
	private var text:TextField;
	
	private var index:Int = 0;
	private var generators:Array<Generator>;
	
	private var threadPool:ThreadPool;
	private var workStartTime:Float = 0;
	
	public function new() {
		super();
		
		bitmap = new Bitmap(new BitmapData(stage.stageWidth, stage.stageHeight, false, 0xFFFFFFFF));
		addChild(bitmap);
		rect = new Rectangle(0, 0, bitmap.bitmapData.width, bitmap.bitmapData.height);
		
		text = new TextField();
		text.background = true;
		text.backgroundColor = 0xFFFFFF;
		text.defaultTextFormat = new TextFormat(
			Assets.getFont("assets/Vera.ttf").fontName,
			20, 0x000000, true);
		text.type = DYNAMIC;
		text.selectable = false;
		text.autoSize = LEFT;
		addChild(text);
		stage.addEventListener(MouseEvent.MOUSE_MOVE, updateText);
		
		//Use the values from libnoise's sample project.
		var frequency:Float = 0.01;
		var lacunarity:Float = 2.0;
		var persistence:Float = 0.5;
		var octaves:Int = 16;
		var seed:Int = Std.int(Math.random() * 0x7FFFFFFF);
		var quality:QualityMode = HIGH;
		
		//Use libnoise's most interesting patterns, but start with a very simple
		//one so the app doesn't take too long to begin.
		generators = [
			new Generator(new Sphere(frequency), 10000),
			new Generator(new RidgedMultifractal(frequency, persistence, 1, seed, quality), 5000),
			new Generator(new Perlin(frequency, lacunarity, persistence, octaves, seed, quality), 1500),
			new Generator(new Billow(frequency, lacunarity, persistence, octaves, seed, quality), 1500),
			//In HTML5, Voronoi diagrams break if the seed gets too big.
			new Generator(new Voronoi(frequency * 2, 1, seed & 0x3FF, true), 500, "Voronoi (distance)"),
			new Generator(new Voronoi(frequency * 2, 1, seed & 0x3FF, false), 500)
		];
		
		stage.addEventListener(MouseEvent.CLICK, onClick);
		stage.addEventListener(MouseEvent.RIGHT_CLICK, onClick);
		
		threadPool = new ThreadPool(generateNoise, 1, 3/4);
		threadPool.onProgress.add(showProgress);
		threadPool.onComplete.add(onComplete);
		
		//Generate the first pattern.
		onClick(null);
	}
	
	/**
	 * Keeps `text` adjacent to the mouse. This is an easy way to show the user
	 * whether the screen has frozen.
	 */
	private function updateText(e:MouseEvent):Void {
		//Make no attempt to keep the text onscreen, so that the user can get it
		//out of the way if they want.
		text.x = mouseX + 15;
		text.y = mouseY + 6;
	}
	
	/**
	 * Increments or decrements `index`, wrapping around if needed, then runs
	 * the generator at that index.
	 */
	private function onClick(e:MouseEvent):Void {
		if(StringTools.startsWith(text.text, "Working")) {
			return;
		}
		
		if(e != null) {
			index += e.type == MouseEvent.CLICK ? 1 : -1;
			if(index >= generators.length) {
				index = 0;
			} else if(index < 0) {
				index = generators.length - 1;
			}
		}
		
		showProgress(0);
		workStartTime = Timer.stamp();
		
		threadPool.queue({
			width: bitmap.bitmapData.width,
			height: bitmap.bitmapData.height,
			generator: generators[index]
		});
	}
	
	/**
	 * Displays the upcoming pattern's name. This no longer fails now that it
	 * executes asynchronously.
	 */
	private function showProgress(linesDone:Int):Void {
		text.text = 'Working on: ${generators[index].name}\nLines done: ${linesDone}/${bitmap.bitmapData.height}';
	}
	
	/**
	 * Generates the noise pattern and passes it to `onComplete()`.
	 */
	private function generateNoise(state:{ width:Int, height:Int, generator:Generator, ?y:Int, ?bytes:ByteArray }):Void {
		//Allocate enough 32-bit ints to store every pixel.
		if(state.bytes == null) {
			state.bytes = new ByteArray(state.width * state.height);
			state.bytes.position = 0;
		}
		
		//Determine how many rows to process this time.
		var startY:Int = state.y != null ? state.y : 0;
		state.y = startY + Math.ceil(state.generator.pixelsPerFrame / state.width);
		if(state.y > state.height) {
			state.y = state.height;
		}
		
		//Run `getNormalizedValue()` for every pixel, going left-to-right then
		//top-to-bottom (the same way English text is arranged).
		for(y in startY...state.y) {
			for(x in 0...state.width) {
				var value:Int = Std.int(0xFF * state.generator.getNormalizedValue(x, y));
				
				state.bytes.writeInt(value << 16 | value << 8 | value);
			}
		}
		
		//If done, send the bytes. Otherwise, send a progress update.
		if(state.y >= state.height) {
			threadPool.sendComplete({
				generator: state.generator,
				bytes: state.bytes
			});
		} else {
			threadPool.sendProgress(state.y);
		}
	}
	
	/**
	 * Draws the pattern to `bitmap` and displays the time taken as text.
	 */
	private function onComplete(message: { generator:Generator, bytes:ByteArray }):Void {
		//Draw the image.
		message.bytes.position = 0;
		bitmap.bitmapData.setPixels(rect, message.bytes);
		message.bytes.clear();
		
		//Show how long it took.
		var elapsedTime:Float = Timer.stamp() - workStartTime;
		var timeString:String = Std.string(Std.int(elapsedTime * 100) / 100);
		text.text = "Pattern: " + message.generator.name
			+ "\nGenerated in: " + timeString + "s"
			+ "\nClick to continue";
	}
}

class Generator {
	public var name:String;
	public var module:ModuleBase;
	public var pixelsPerFrame:Int;
	
	public function new(module:ModuleBase, pixelsPerFrame:Int, ?name:String) {
		this.name = name != null ? name
			: Type.getClassName(Type.getClass(module)).split(".").pop();
		this.module = module;
		this.pixelsPerFrame = pixelsPerFrame;
	}
	
	public function getNormalizedValue(x:Float, y:Float, ?z:Float = 0):Float {
		var value:Float = (1 + this.module.getValue(x, y, 0)) / 2;
		
		if(value > 1) {
			value = 1;
		} else if(value < 0) {
			value = 0;
		}
		
		return value;
	}
}
