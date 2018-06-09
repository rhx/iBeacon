//
//  GTExtensionString.swift
//  GemTotSDK
//
//  Created by Kapil Sachdeva on 10/6/15.
//  Copyright © 2015 PassKit, Inc. All rights reserved.
//

import Foundation

extension String {
    func appending(pathComponent: String) -> String {
        let nsSt = self as NSString
        return nsSt.appendingPathComponent(pathComponent)
    }
}
