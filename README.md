# CopyProjectPath-Xcode

An Xcode plug-in to easily copy the path to your current workspace/project or open it in your preferred Terminal, by [@johankj](https://twitter.com/johankj).

![Example usage animation](https://raw.github.com/johankj/CopyProjectPath-Xcode/master/example-usage.gif)


## Installation

Clone the repo. Then build and run the Xcode project and the plug-in will automatically be installed in `~/Library/Application Support/Developer/Shared/Xcode/Plug-ins`. Relaunch Xcode.

```
$ git clone https://github.com/johankj/CopyProjectPath-Xcode.git
$ cd CopyProjectPath-Xcode
$ xcodebuild
```


## Usage

Click on the toolbar button to activate the current action.  
Press-and-hold the button to change to another action.

Tip: Hold the Alt-key down to reveal an option for opening in iTerm.


## New Xcode releases

When a new version of Xcode is released the plug-in is disabled by Xcode.  
If you want to enable it again you can run the following Terminal command. It writes the DVTPlugInCompatibilityUUID of the Xcode version in /Applications/Xcode.app into the Info.plist of this plug-in.  
Feel free to submit a pull-request if a new Xcode version is out, and the plug-in still works.

```
$ find ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins/JKJProjectPath.xcplugin -name Info.plist | xargs -I{} defaults write {} DVTPlugInCompatibilityUUIDs -array-add `defaults read /Applications/Xcode.app/Contents/Info DVTPlugInCompatibilityUUID`
```

## How it was build

The plug-in doesn’t interfere too much with Xcode, but it still took me quite a while to figure out how to add a toolbar button to the main toolbar of Xcode.

I started out with the only post on [reverse engineering Xcode](http://chen.do/blog/2013/10/22/reverse-engineering-xcode-with-dtrace/) and setup dtrace scripts as the following, to log all Objective-C messages and see if any of them were looking interesting.

```
sudo dtrace -q -n 'objc[PID]:[CLASS]:[+/-][METHOD]:entry { printf("%s %s\n", probemod, probefunc); }' > xcode.txt
# If you leave [CLASS] and [+/-][METHOD] empty, you log all Objective-C messages.
# Example of usage:
sudo dtrace -q -n 'objc70755::-toolbar?itemForItemIdentifier?willBeInsertedIntoToolbar?:entry { printf("%s %s\n", probemod, probefunc); }' > xcode.txt
```

As the logfile quickly grew, because basically every single ObjC call gets called, I decided to look into some of the NSNotifications and see if any of them had some clues.

Both approaches gave me a little information but nothing I really could use. It was searching through header-files from class-dumps of the Xcode frameworks (there exists many repositories on GitHub) and using [Interface Inspector](http://www.interface-inspector.com/) that pointed me to some interesting classes.

Then I could use [Hopper](http://hopperapp.com/) to disassemble IDEKit.framework and DVTKit.framework and see how the interesting methods were used.

Finally I also swizzled various methods to have a look at the arguments given to them and to get call other instance methods.

The Xcode-project itself is based on the [Xcode-template for Xcode Plug-ins](https://github.com/kattrali/Xcode-Plugin-Template).

## License

MIT License. See LICENSE.md for the full license.
