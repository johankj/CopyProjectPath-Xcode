//
//  JKJProjectPath.m
//  JKJProjectPath
//
//  Created by Johan K. Jensen on 26/09/2015.
//  Copyright © 2015 Johan K. Jensen. All rights reserved.
//

#import <objc/runtime.h>

#import "JKJProjectPath.h"
#import "Aspects.h"

static NSString *JKJCopyProjectPathToolbarItemIdentifier = @"JKJCopyProjectPathToolbarItemIdentifier";

@interface NSObject ()
- (void)setAllowedItemIdentifiers:(NSArray*)arg1;
- (void)setDefaultItemIdentifiers:(NSArray*)arg1;
- (id)proxyForToolbarItemElement:(id)arg1 errorMessage:(id)arg2; //IDEToolbarItemProxy
@end

@interface JKJProjectPath()
@property (nonatomic, strong) NSBundle *bundle;
@end

@implementation JKJProjectPath

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        // reference to plugin's bundle, for resource acccess
        self.bundle = plugin;
        NSLog(@"LOADED ###############################################################################################################################################################################################################################################################################################################################################################################################################################################################################################");
// +[IDEWorkspaceToolbarItemProvider itemForItemIdentifier:forToolbarInWindow:]:
        [objc_getClass("IDEWorkspaceToolbarItemProvider") aspect_hookSelector: @selector(itemForItemIdentifier:forToolbarInWindow:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
//            int itemCount = 0;
            [info.originalInvocation invoke];
//            [info.originalInvocation getReturnValue:&itemCount];
            
            NSLog(@"arguments: %@ ####################################################################################################################################################################", info.arguments);
            
//            [info.originalInvocation setReturnValue:&itemCount];
        } error:nil];
        
        Class cls = NSClassFromString(@"IDEWorkspaceToolbarItemProvider");
        NSString *selector = @"itemForItemIdentifier:forToolbarInWindow:";
        SEL originalSelector = NSSelectorFromString(selector);
        SEL newSelector = NSSelectorFromString([@"JKJ_swizzled_toolbar_" stringByAppendingString:selector]);
        [self swizzleClassMethodWithClass: cls originalSelector: originalSelector swizzledSelector: newSelector];

        [objc_getClass("IDEToolbarDelegate") aspect_hookSelector:@selector(_initializeItemIdentifiersForToolbarDefinitionExtension:) withOptions:AspectPositionInstead usingBlock:^(id<AspectInfo> info) {
            NSLog(@"before %@", [info.arguments[0] valueForKey:@"defaultToolbarItems"]);
            
            id item = [info.arguments[0] valueForKey:@"defaultToolbarItems"][0];
            
            id res = [NSClassFromString(@"IDEToolbarItemProxy") proxyForToolbarItemElement:item errorMessage:nil];
            NSLog(@"__ %@",[res performSelector:@selector(toolbarItemIdentifier)]);
            
            [info.originalInvocation invoke];
            
            id itemIdentifiers = [info.instance toolbarAllowedItemIdentifiers:info.instance];
            [info.instance setAllowedItemIdentifiers:[itemIdentifiers arrayByAddingObject:@"THISISMYTESTIDENTIFIER"]];
            NSLog(@"++++ %@", [info.instance toolbarAllowedItemIdentifiers:info.instance]);
            
            itemIdentifiers = [info.instance toolbarDefaultItemIdentifiers:info.instance];
            [info.instance setDefaultItemIdentifiers:[itemIdentifiers arrayByAddingObject:@"THISISMYTESTIDENTIFIER"]];
            
            NSLog(@"arguments: %@ ################", info.arguments);
            
        } error:nil];
        
        
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}



- (void)swizzleClassMethodWithClass:(Class)class originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector
{
    if (class) {
        Method originalMethod;
        Method swizzledMethod;
        originalMethod = class_getClassMethod(class, originalSelector);
        swizzledMethod = class_getClassMethod(class, swizzledSelector);
        
        if ((originalMethod != nil) && (swizzledMethod != nil)) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
}

- (void)swizzleClass:(Class)class originalSelector:(SEL)originalSelector swizzledSelector:(SEL)swizzledSelector instanceMethod:(BOOL)instanceMethod
{
    if (class) {
        Method originalMethod;
        Method swizzledMethod;
        if (instanceMethod) {
            originalMethod = class_getInstanceMethod(class, originalSelector);
            swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        } else {
            originalMethod = class_getClassMethod(class, originalSelector);
            swizzledMethod = class_getClassMethod(class, swizzledSelector);
        }
  
        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
}


+ (NSToolbarItem *)toolbarItemForPreferences {
    Class DVTViewControllerToolbarItem = NSClassFromString(@"DVTViewControllerToolbarItem");
    NSToolbarItem *settingsItem = (NSToolbarItem *)[[DVTViewControllerToolbarItem alloc] initWithItemIdentifier:JKJCopyProjectPathToolbarItemIdentifier];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSImage *image = nil; //[[NSImage alloc] initByReferencingFile:[bundle pathForResource:@"toolbar_icon" ofType:@"png"]];
    
    settingsItem.target = self;
    settingsItem.action = @selector(showPluginMenu:);
    
    settingsItem.toolTip = @"Settings for Plugins";
    settingsItem.label = @"Plugins";
    settingsItem.image = image;
    
    return settingsItem;
}

+ (void)showPluginMenu:(id)sender {
    
    NSLog(@"showPluginMenu: %@", sender);
}

@end



@implementation NSObject (JKJSwizzle)

+ (id) JKJ_swizzled_toolbar_itemForItemIdentifier:(id)itemIdentifier forToolbarInWindow:(id)window {
    NSLog(@"/////// SWIZZLE %@ %@", itemIdentifier, window);
    NSString *bundleID = [[NSBundle bundleForClass:self] bundleIdentifier];
    if ([itemIdentifier isEqualToString:bundleID]) {
        return nil;
//        return [self toolbarItemForPreferences];
    }
    id res = [self JKJ_swizzled_toolbar_itemForItemIdentifier:itemIdentifier forToolbarInWindow:window];
    NSLog(@"#### %@", res);
    return res;
}

//- (id) JKJ_swizzled_toolbar__initializeItemIdentifiersForToolbarDefinitionExtension:(id)extension {
//    NSLog(@"/////// SWIZZLE2 %@", extension);
//    id res = [self JKJ_swizzled_toolbar__initializeItemIdentifiersForToolbarDefinitionExtension:extension];
//    NSLog(@"#### %@", res);
//    return res;
//}

@end
