//
//  XCProjectFile.swift
//  XcodeEdit
//
//  Created by Tom Lokhorst on 2015-08-12.
//  Copyright (c) 2015 nonstrict. All rights reserved.
//

import Foundation

public enum ProjectFileError : Error, CustomStringConvertible {
  case invalidData
  case notXcodeproj
  case missingPbxproj
  case internalInconsistency([ReferenceError])

  public var description: String {
    switch self {
    case .invalidData:
      return "Data in .pbxproj file not in expected format"

    case .notXcodeproj:
      return "Path is not a .xcodeproj package"

    case .missingPbxproj:
      return "project.pbxproj file missing"

    case .internalInconsistency(let errors):
      var str = "project.pbxproj is internally inconsistent.\n\n"

      for error in errors {
        switch error {
        case let .deadReference(type, id, keyPath, ref):
          str += " - \(type) (\(id.value)) references missing \(keyPath) \(ref.value)\n"

        case let .orphanObject(type, id):
          str += " - \(type) (\(id.value)) is not used\n"
        }
      }

      str += "\nPerhaps a merge conflict?\n"

      return str
    }
  }
}

public class XCProjectFile {
  public let project: PBXProject
  let fields: Fields
  var format: PropertyListSerialization.PropertyListFormat
  let allObjects = AllObjects()
  var xcodeprojURL : URL

  public convenience init(xcodeprojURL: URL, ignoreReferenceErrors: Bool = false) throws {
    let pbxprojURL = xcodeprojURL.appendingPathComponent("project.pbxproj", isDirectory: false)
    let data = try Data(contentsOf: pbxprojURL)
    try self.init(xcodeprojURL: xcodeprojURL, propertyListData: data, ignoreReferenceErrors: ignoreReferenceErrors)
    
  }

  public convenience init(xcodeprojURL: URL, propertyListData data: Data, ignoreReferenceErrors: Bool = false) throws {

    let options = PropertyListSerialization.MutabilityOptions()
    var format: PropertyListSerialization.PropertyListFormat = PropertyListSerialization.PropertyListFormat.binary
    let obj = try PropertyListSerialization.propertyList(from: data, options: options, format: &format)

    guard let fields = obj as? Fields else {
      throw ProjectFileError.invalidData
    }
    try self.init(xcodeprojURL: xcodeprojURL, fields: fields, format: format, ignoreReferenceErrors: ignoreReferenceErrors)
  }

  private init(xcodeprojURL : URL, fields: Fields, format: PropertyListSerialization.PropertyListFormat, ignoreReferenceErrors: Bool = false) throws {
    self.xcodeprojURL = xcodeprojURL
    guard let objects = fields["objects"] as? [String: Fields] else {
        throw AllObjectsError.wrongType(obj: fields, key: "objects")
    }

    for (key, obj) in objects {
      allObjects.objects[Guid(key)] = try AllObjects.createObject(Guid(key), fields: obj, allObjects: allObjects)
    }

    let rootObjectId = Guid(try fields.string("rootObject"))
    guard let projectFields = objects[rootObjectId.value] else {
        throw AllObjectsError.objectMissing(obj: objects, id: rootObjectId)
    }

    guard let project = allObjects.objects[rootObjectId] as? PBXProject else {
        throw "No project object found!".error()
    }
        // = try PBXProject(id: rootObjectId, fields: projectFields, allObjects: allObjects)
    guard let mainGroup = project.mainGroup.value else {
        throw AllObjectsError.objectMissing(obj: [:], id: project.mainGroup.id)
    }

    if !ignoreReferenceErrors {
      _ = allObjects.createReference(id: rootObjectId)
      try allObjects.validateReferences()
    }

    self.fields = fields
    self.format = format
    self.project = project
    self.allObjects.fullFilePaths = paths(mainGroup, prefix: "")
  }

  internal static func projectName(from url: URL) throws -> String {

    let subpaths = url.pathComponents
    guard let last = subpaths.last,
          let range = last.range(of: ".xcodeproj")
    else {
      throw ProjectFileError.notXcodeproj
    }

    return String(last[..<range.lowerBound])
  }
  
    public func addHeaderFiles() throws {
        try project.addHeaderFiles(rootPath: xcodeprojURL.deletingLastPathComponent())
    }
    
    public func addXibsAndStoryboards() throws {
        try project.addXibsAndStoryboards(rootPath: xcodeprojURL.deletingLastPathComponent())
    }
    
  private func paths(_ current: PBXGroup, prefix: String) -> [Guid: Path] {

    var ps: [Guid: Path] = [:]

    let fileRefs = current.fileRefs.compactMap { $0.value } +
                   current.subGroups.compactMap { $0.value }
    for file in fileRefs {
      guard let path = file.path else { continue }

      switch file.sourceTree {
      case .group:
        switch current.sourceTree {
        case .absolute:
          ps[file.id] = .absolute(prefix + "/" + path)

        case .group:
          ps[file.id] = .relativeTo(.sourceRoot, prefix + "/" + path)

        case .relativeTo(let sourceTreeFolder):
          ps[file.id] = .relativeTo(sourceTreeFolder, prefix + "/" + path)
        }

      case .absolute:
        ps[file.id] = .absolute(path)

      case let .relativeTo(sourceTreeFolder):
        ps[file.id] = .relativeTo(sourceTreeFolder, path)
      }
    }

    let subGroups = current.subGroups.compactMap { $0.value }
    for group in subGroups {
      if let path = group.path {
        
        let str: String

        switch group.sourceTree {
        case .absolute:
          str = path

        case .group:
          str = prefix + "/" + path

        case .relativeTo(.sourceRoot):
          str = path

        case .relativeTo(.buildProductsDir):
          str = path

        case .relativeTo(.developerDir):
          str = path

        case .relativeTo(.sdkRoot):
          str = path

        case .relativeTo(.platformDir):
          str = path
        }

        ps += paths(group, prefix: str)
      }
      else {
        ps += paths(group, prefix: prefix)
      }
    }

    return ps
  }
    
}
