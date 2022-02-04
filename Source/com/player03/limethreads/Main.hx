package com.player03.limethreads;

import haxe.Timer;
import libnoise.generator.Billow;
import libnoise.generator.Perlin;
import libnoise.generator.RidgedMultifractal;
import libnoise.generator.Sphere;
import libnoise.generator.Voronoi;
import libnoise.ModuleBase;
import libnoise.QualityMode;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.utils.Assets;
import openfl.utils.ByteArray;
import sys.thread.Thread;

class Main extends Sprite {
	private var bitmap:Bitmap;
	private var rect:Rectangle;
	
	private var text:TextField;
	
	private var index:Int = 0;
	private var generators:Array<Generator>;
	
	public function new() {
		super();
		
		//Set up the bitmap to which patterns will be drawn.
		bitmap = new Bitmap(new BitmapData(stage.stageWidth, stage.stageHeight, false, 0xFFFFFFFF));
		addChild(bitmap);
		rect = new Rectangle(0, 0, bitmap.bitmapData.width, bitmap.bitmapData.height);
		
		//Set up a text field to display progress and results.
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
			new Generator(new Sphere(frequency)),
			new Generator(new RidgedMultifractal(frequency, persistence, 1, seed, quality)),
			new Generator(new Perlin(frequency, lacunarity, persistence, octaves, seed, quality)),
			new Generator(new Billow(frequency, lacunarity, persistence, octaves, seed, quality)),
			//In HTML5, Voronoi diagrams break if the seed gets too big.
			new Generator(new Voronoi(frequency * 2, 1, seed & 0x3FF, true), "Voronoi (distance)"),
			new Generator(new Voronoi(frequency * 2, 1, seed & 0x3FF, false))
		];
		
		stage.addEventListener(MouseEvent.CLICK, onClick);
		stage.addEventListener(MouseEvent.RIGHT_CLICK, onClick);
		
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
		
		showProgress();
		
		Thread.create(generateNoise.bind(generators[index]));
	}
	
	/**
	 * Displays the upcoming pattern's name. This no longer fails now that
	 * threads are available.
	 */
	private function showProgress():Void {
		text.text = 'Working on: ${generators[index].name}';
	}
	
	/**
	 * Generates the noise pattern, draws it to `bitmap`, and displays the time
	 * taken as text.
	 */
	private function generateNoise(generator:Generator):Void {
		var startTime:Float = Timer.stamp();
		
		//Allocate enough 32-bit ints to store every pixel.
		var bytes:ByteArray = new ByteArray(bitmap.bitmapData.width * bitmap.bitmapData.height);
		bytes.position = 0;
		
		//Run `getNormalizedValue()` for every pixel, going left-to-right then
		//top-to-bottom (the same way English text is arranged).
		for(y in 0...bitmap.bitmapData.height) {
			for(x in 0...bitmap.bitmapData.width) {
				var value:Int = Std.int(0xFF * generator.getNormalizedValue(x, y));
				
				bytes.writeInt(value << 16 | value << 8 | value);
			}
		}
		
		//Draw the image.
		bytes.position = 0;
		bitmap.bitmapData.setPixels(rect, bytes);
		bytes.clear();
		
		//Show how long it took.
		var elapsedTime:Float = Timer.stamp() - startTime;
		var timeString:String = Std.string(Std.int(elapsedTime * 100) / 100);
		text.text = "Pattern: " + generator.name
			+ "\nGenerated in: " + timeString + "s"
			+ "\nClick to continue";
	}
}

class Generator {
	public var name:String;
	public var module:ModuleBase;
	
	public function new(module:ModuleBase, ?name:String) {
		this.name = name != null ? name
			: Type.getClassName(Type.getClass(module)).split(".").pop();
		this.module = module;
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
