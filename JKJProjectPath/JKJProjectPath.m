//
//  JKJProjectPath.m
//  JKJProjectPath
//
//  Created by Johan K. Jensen on 27/09/2015.
//  Copyright © 2015 Johan K. Jensen. All rights reserved.
//

#import "JKJProjectPath.h"
#import "JKJButtonViewController.h"

#pragma mark Xcode Interfaces

// The following interfaces already have implementation in Xcode (DVTKit or IDEKit).
// They are only declared here so we can compile the code.
// I’ve tried to declare them as a category on their super-class.

@interface NSObject (IDEWorkspaceWindowController)
+ (id)workspaceWindowControllers;
@end

@interface NSObject (IDEToolbarDelegate)
@property(copy) NSArray *allowedItemIdentifiers;
@property(copy) NSDictionary *toolbarItemProviders;
@end

@interface NSPopUpButton (DVTToolbarViewControllerAdditions)
+ (id)dvt_toolbarPopUpButtonWithMenu:(NSMenu*)menu buttonType:(NSBezelStyle)style;
@end

@interface NSButton (DVTDelayedMenuButton)
@property(nonatomic) BOOL showsMenuIndcatorOnlyWhileMouseInside;
- (void)setMenu:(NSMenu*)menu;
@end

@interface NSCell (DVTDelayedMenuButtonCell)
@property struct CGPoint menuIndicatorInset;
@property BOOL useNSButtonImageDrawing;
- (void) setActiveImage:(NSImage*)image;
- (void) setArrowImage:(NSImage*)image;
@end

@interface NSImage (DVTKit)
+ (instancetype) dvt_cachedImageNamed:(NSString*)name fromBundleForClass:(Class)cls;
@end

#pragma mark - JKJProjectPath

@interface JKJProjectPath ()
@property (nonatomic, retain) NSBundle *bundle;
@end

static NSString *JKJProjectPathButtonIdentifier = @"JKJProjectPathButtonIdentifier";

@implementation JKJProjectPath

+ (void)pluginDidLoad:(NSBundle*)pluginBundle {
    static JKJProjectPath *sharedPlugin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
        sharedPlugin.bundle = pluginBundle;
    });
}

- (id)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateToolbar) name:NSWindowDidBecomeKeyNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
}


- (void)updateToolbar {
    @try {
        NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") workspaceWindowControllers];
        for (NSWindow *window in [workspaceWindowControllers valueForKey:@"window"]) {
            [self registerToolbarButtonAndProviderForWindow:window];
            [self insertToolbarButtonForWindow:window];
        }
    }
    @catch (NSException *exception) {}
}

- (void)registerToolbarButtonAndProviderForWindow:(NSWindow*)window {
    NSObject<NSToolbarDelegate>* delegate = window.toolbar.delegate;
    NSArray *allowedIdentifiers = [delegate allowedItemIdentifiers];
    NSMutableDictionary *providers = [delegate toolbarItemProviders].mutableCopy;
    if (![allowedIdentifiers containsObject:JKJProjectPathButtonIdentifier]) {
        allowedIdentifiers = [allowedIdentifiers arrayByAddingObject:JKJProjectPathButtonIdentifier];
        providers[JKJProjectPathButtonIdentifier] = self;
        [delegate setValue:allowedIdentifiers forKey:@"_allowedItemIdentifiers"];
        [delegate setValue:providers forKey:@"_toolbarItemProviders"];
    }
}

- (void)insertToolbarButtonForWindow:(NSWindow*)window {
    for (NSToolbarItem *item in window.toolbar.items) {
        if ([item.itemIdentifier isEqualToString:JKJProjectPathButtonIdentifier])
            return;
    }
    NSInteger index = 3;
    [window.toolbar insertItemWithItemIdentifier:JKJProjectPathButtonIdentifier
                                         atIndex:index];
}

- (void)removeToolbarButtonForWindow:(NSWindow*)window {
    NSInteger index = NSNotFound;
    for (int i = 0; i < window.toolbar.items.count; i++) {
        NSToolbarItem *item = window.toolbar.items[i];
        if ([item.itemIdentifier isEqualToString:JKJProjectPathButtonIdentifier]) {
            index = i;
            break;
        }
    }
    if (index != NSNotFound) {
        [window.toolbar removeItemAtIndex:index];
    }
}

- (id)toolbarItemForToolbarInWindow:(NSWindow*)window {
    Class DVTViewControllerToolbarItem = NSClassFromString(@"DVTViewControllerToolbarItem");
    NSToolbarItem *exterminatorItem = (NSToolbarItem*)[[DVTViewControllerToolbarItem alloc] initWithItemIdentifier:JKJProjectPathButtonIdentifier];
    
    exterminatorItem.target = self;
    exterminatorItem.toolTip = @"Copy Project Path";
    exterminatorItem.label = @"CopyProjectPath";
    // Interface Inspector.app says that the other icons have a height of 25, so…
    exterminatorItem.maxSize = NSMakeSize(32, 25);
    exterminatorItem.view = [self createButton];
    
//    Class buttonVC = NSClassFromString(@"DVTGenericButtonViewController");
    Class buttonVC = [JKJButtonViewController class]; // Instead of DVTGenericButtonViewController as we don’t use a nib-file and that causes a crash on exit
    [exterminatorItem setValue:[[buttonVC alloc] initWithNibName:nil bundle:nil] forKey:@"viewController"];
    return exterminatorItem;
}

#pragma mark - Factories

- (NSMenu*)createMenu {
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    NSMenuItem *item1 = [theMenu addItemWithTitle:@"Copy Project Path" action:@selector(copyProjectPath) keyEquivalent:@""];
    item1.target = self;
    
    NSMenuItem *item2 = [theMenu addItemWithTitle:@"Reveal Project in Finder" action:@selector(revealProjectInFinder) keyEquivalent:@""];
    item2.target = self;
    
    NSMenuItem *item3 = [theMenu addItemWithTitle:@"Open Project in Terminal" action:@selector(openProjectInTerminal) keyEquivalent:@""];
    item3.target = self;
    
    NSMenuItem *item3alt = [theMenu addItemWithTitle:@"Open Project in iTerm" action:@selector(openProjectIniTerm) keyEquivalent:@""];
    item3alt.target = self;
    item3alt.alternate = YES;
    item3alt.keyEquivalentModifierMask = NSAlternateKeyMask;
    return theMenu;
}

- (NSButton*)createButton {
    // Here we create a DVTDelayedMenuButton
    // It has the same functionality as the Run-button, where you can press-and-hold
    // to get a menu with more options.
    
    // If only a toolbarButton is required, the method +[NSButton dvt_toolbarButtonWithImage:buttonType:]
    // is a good choice.
    // The Scheme-selector seems to be something like the following
    // +[NSPopUpButton dvt_toolbarPopUpButtonWithMenu:buttonType:]
    
    NSButton *button = [NSClassFromString(@"DVTDelayedMenuButton") new];
    [button setMenu:[self createMenu]];
    NSImage *downArrow = [NSImage dvt_cachedImageNamed:@"smallPullDownArrow" fromBundleForClass:NSClassFromString(@"DVTImagePopUpButtonCell")];
    [[button cell] setArrowImage:downArrow];
    [button setShowsMenuIndcatorOnlyWhileMouseInside:YES];
    [[button cell] setUseNSButtonImageDrawing:YES];
    [[button cell] setMenuIndicatorInset:CGPointMake(1, 2)];
    [[button cell] setBordered:YES];
    [[button cell] setBezelStyle:NSTexturedRoundedBezelStyle]; // This one is especially important unless you miss the ‘90s. :p
    [[button cell] setImageScaling:NSImageScaleNone];
    [[button cell] setImagePosition:NSImageOnly];
    
    // There’s some nice icons in /Applications/Xcode.app/Contents/SharedFrameworks/DVTKit.framework/Versions/A/Resources/
    NSImage *activeImage = [NSImage dvt_cachedImageNamed:@"DVTInFieldCopyToClipboard" fromBundleForClass:NSClassFromString(@"DVTTheme")];
    activeImage.template = YES;
    [[button cell] setActiveImage:activeImage];
    return button;
}


#pragma mark - MenuActions

- (void)copyProjectPath {
    NSString *workspacePath = [self getWorkspacePath];
    NSString *workspacePathWithTilde = [workspacePath stringByReplacingOccurrencesOfString:NSHomeDirectory() withString:@"~"];
    
    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    [pasteBoard declareTypes:@[NSStringPboardType] owner:nil];
    [pasteBoard setString: workspacePathWithTilde forType:NSStringPboardType];
}

- (void)revealProjectInFinder {
    NSString *workspacePath = [self getWorkspacePath];
    NSURL *fileURL = [NSURL fileURLWithPath:workspacePath];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[fileURL]];
}

- (void)openProjectInTerminal {
    NSString *workspacePath = [[self getWorkspacePath] stringByDeletingLastPathComponent];
    if (workspacePath) {
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:@[@"-a", @"Terminal", workspacePath]];
    }
}

- (void)openProjectIniTerm {
    NSString *workspacePath = [[self getWorkspacePath] stringByDeletingLastPathComponent];
    if (workspacePath) {
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:@[@"-a", @"iTerm", workspacePath]];
    }
}

#pragma mark - Helpers

- (NSString*)getWorkspacePath {
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") valueForKey:@"workspaceWindowControllers"];
    
    id workSpace;
    for (id controller in workspaceWindowControllers) {
        if ([[controller valueForKey:@"window"] isEqual:[NSApp keyWindow]]) { // TODO: Perhaps compare with the window the button belongs to
            workSpace = [controller valueForKey:@"_workspace"];
        }
    }
    
    NSString *workspacePath = [[workSpace valueForKey:@"representingFilePath"] valueForKey:@"_pathString"];
    return workspacePath;
}


@end
