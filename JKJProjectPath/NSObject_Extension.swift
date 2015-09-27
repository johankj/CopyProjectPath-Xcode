//
//  NSObject_Extension.swift
//
//  Created by Johan K. Jensen on 26/09/2015.
//  Copyright © 2015 Johan K. Jensen. All rights reserved.
//

import Foundation

extension NSObject {
    class func pluginDidLoad(bundle: NSBundle) {
        let appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? NSString
        if appName == "Xcode" {
        	if sharedPlugin == nil {
        		sharedPlugin = JKJProjectPath(bundle: bundle)
        	}
        }
    }
}