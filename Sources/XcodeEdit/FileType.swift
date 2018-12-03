//
// FileType.swift
//
// Created by k1x
//


import Foundation

public enum PBXFileType : String {
    case sourceCodeHeader       = "sourcecode.c.h"
    case sourceCodeObjC         = "sourcecode.c.objc"
    case framework              = "wrapper.framework"
    case propertyList           = "text.plist.strings"
    case sourceCodeObjCPlusPlus = "sourcecode.cpp.objcpp"
    case sourceCodeCPlusPlus    = "sourcecode.cpp.cpp"
    case xibFile                = "file.xib"
    case imageResourcePNG       = "image.png"
    case bundle                 = "wrapper.cfbundle"
    case archive                = "archive.ar"
    case html                   = "text.html"
    case text                   = "text"
    case xcodeProject           = "wrapper.pb-project"
    case folder                 = "folder"
    case assetCatalog           = "folder.assetcatalog"
    case sourceCodeSwift        = "sourcecode.swift"
    case application            = "wrapper.application"
    case playground             = "file.playground"
    case shellScript            = "text.script.sh"
    case markdown               = "net.daringfireball.markdown"
    case xmlPropertyList        = "text.plist.xml"
    case storyboard             = "file.storyboard"
    case textConfig             = "text.xcconfig"
    case wrapperConfig          = "wrapper.xcconfig"
    case xcDataModel            = "wrapper.xcdatamodel"
    case localizableStrings     = "file.strings"
    case systemLibrary          = "sourcecode.text-based-dylib-definition"
}

let fileTypeDictionary : [String : PBXFileType] = {
    let array : [([String], PBXFileType)] = [
        ([".h", ".hh", ".hpp", ".hxx"], .sourceCodeHeader),
        ([".c", ".m"], .sourceCodeObjC),
        ([".mm", ".cpp"], .sourceCodeCPlusPlus),
        ([".swift"], .sourceCodeSwift),
        ([".xcdatamodel"], .xcDataModel),
        ([".strings"], .xcDataModel),
        ([".plist"], .propertyList),
        ([".tbd"], .propertyList),
        ([".storyboard"], .storyboard),
        ([".xib"], .xibFile),
    ]
    return Dictionary(uniqueKeysWithValues: array.reduce(into: [(String , PBXFileType)](), { sum, val in
        sum.append(contentsOf: val.0.map { ($0, val.1) })
    }))
}()
