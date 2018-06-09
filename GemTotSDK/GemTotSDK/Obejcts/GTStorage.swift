//
//  GTStorage.swift
//  GemTotSDK
//
//  Copyright (c) 2014 PassKit, Inc.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

import UIKit


// Constant to hold a singleton instance
let _GlobalGTSharedStorageInstance = GTStorage()

class GTStorage: NSObject {
    
    // Singleton pattern
    class var sharedGTStorage:GTStorage {
        return _GlobalGTSharedStorageInstance
    }
    
    // Documents directory
    let _documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String

    /**
    *
    *  @brief   Retrieves an object from a plist store
    *
    *  @param   fromStore - the file name of the plist store
    *  @param   keyName - the key of the item to be retreives
    *
    *  @return  the objectValue of the key, or nil if no object exists for that key
    *
    */
    
    func getValue(forKey keyName: String, fromStore: String) -> Any? {
        if let path = check(store: fromStore)! as String? {
            let dict :NSDictionary? = NSDictionary(contentsOfFile: path)
        
            let objectValue = dict?.object(forKey: keyName)
        
            return objectValue
        } else {
            
            return nil
        }
    }
    
    /**
    *
    *  @brief   Write an object to a plist store
    *
    *  @param   value - the object to be written to the store
    *  @param   forKey - the key of the item to be written to
    *  @param   toStore - the file name of the plist store
    *
    *  @return  void
    *
    */
    
    func write(value: Any!, forKey: String, toStore: String) {
        guard let path = check(store: toStore)! as String?,
              let dict = NSMutableDictionary(contentsOfFile: path) else { return }
        dict.setValue(value, forKey: forKey)
        _ = dict.write(toFile: path, atomically: true)
    }

    /**
    *
    *  @brief   Checks that the plist store exists in the writable storage, if not then
    *           it copies default plist from the app bundle to  the writable documents
    *           folder
    *
    *  @param   storeName - the file name of the plist store 
    *
    *  @return  the full path to the store on success or nil on failure
    *
    */
    

    func check(store storeName: String) -> String? {
        
        let storePath = _documentsDirectory.appending(pathComponent: "\(storeName).plist")
        
        let fileManager = FileManager.default
        
        if (!fileManager.fileExists(atPath: storePath)) {
            if let bundle = Bundle.main.path(forResource: storeName, ofType:"plist") {
                // TODO : Should handle the error but for now assuming
                // that the error would not occur and hence try!
                try! fileManager.copyItem(atPath: bundle, toPath: storePath)
                return storePath
            } else {
                return nil
            }
        } else {
            return storePath
        }
    }
}
