# LimeThreadSample
Demonstrative code for my [guide to threads in Lime](https://player03.com/openfl/threads-guide/). This sample uses [libnoise](https://github.com/memilian/libnoise/) to draw various patterns. Some of these patterns are very slow, and the main goal of this sample is to show various ways to execute slow operations without causing the app to freeze.

## Synchronous (you are here)
This branch demonstrates the simplest implementation. It runs all code immediately, making no attempt to keep the app from freezing. All other branches build off this one, showing what changes are required to implement each solution.

[You can see this branch in action here](https://player03.com/haxe/demo/threads/synchronous/index.html).

## [Thread](https://github.com/player-03/LimeThreadSample/tree/Thread)
This branch uses [Haxe's `Thread` class](https://api.haxe.org/sys/thread/Thread.html) to run the code in the background. This prevents the app from freezing but does little to ensure thread safety. Also, it doesn't work in HTML5, so there's no web demo.

## [BackgroundWorker](https://github.com/player-03/LimeThreadSample/tree/BackgroundWorker)
This branch uses [Lime's `BackgroundWorker` class](https://api.lime.software/lime/system/BackgroundWorker.html) instead of `Thread`. This fills the same role but improves thread safety and adds a basic form of HTML5 support.

[You can see the HTML5 version in action here](https://player03.com/haxe/demo/threads/bgworker/index.html). Note that the HTML5 version runs everything on the main thread, pausing at regular intervals to update the screen. This may lead to visible lag depending on your computer and browser.

It also runs threads with an "off switch," meaning you can cancel an ongoing job and start a new one. This is why you're allowed to click in the middle of a job to skip ahead.

## [ThreadPool](https://github.com/player-03/LimeThreadSample/tree/ThreadPool)
This branch uses [Lime's `ThreadPool` class](https://api.lime.software/lime/system/ThreadPool.html) to keep the background thread running at all times. This removes the overhead of starting and stopping the thread repeatedly.

[You can see the HTML5 version in action here](https://player03.com/haxe/demo/threads/threadpool/index.html), but since this version doesn't use threads, there's no appreciable difference in speed between it and the `BackgroundWorker` version.

You'll also notice that you can no longer click in the middle of a job, because `ThreadPool` isn't designed to interrupt ongoing jobs. The only options it offers are: (1) queue the job for later, (2) run both jobs side-by-side, or (3) shut everything down permanently. None of these would improve the demo, so they were left out.

## [Future](https://github.com/player-03/LimeThreadSample/tree/Future)
This branch uses [Lime's `Future` class](https://api.lime.software/lime/app/Future.html) to await the pattern. This uses `ThreadPool` under the hood, but it has a different API and lacks progress events.

[You can see the HTML5 version in action here](https://player03.com/haxe/demo/threads/future/index.html).
