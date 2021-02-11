//
//  AllObjects.swift
//  XcodeEdit
//
//  Created by Tom Lokhorst on 2017-03-27.
//  Copyright © 2017 nonstrict. All rights reserved.
//

import Foundation

public enum AllObjectsError: Error {
  case fieldMissing(obj : Fields, key: String)
  case wrongType(obj : Fields, key: String)
  case objectMissing(obj : Fields, id: Guid)
}

public enum ReferenceError: Error {
  case deadReference(type: String, id: Guid, keyPath: String, ref: Guid)
  case orphanObject(type: String, id: Guid)
}

public extension String {
    
    static let kAllowedGuidCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890-")

    var guidStyle : String {
        return String(uppercased().replacingOccurrences(of: ".", with: "-").unicodeScalars.filter( { Self.kAllowedGuidCharacters.contains($0) }))
    }
    
}

public struct Guid : Hashable, Comparable {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }
    
  public static var random : Guid {
     return Guid(UUID().uuidString)
  }

  static public func ==(lhs: Guid, rhs: Guid) -> Bool {
    return lhs.value == rhs.value
  }

  public var hashValue: Int {
    return value.hashValue
  }

  static public func <(lhs: Guid, rhs: Guid) -> Bool {
    return lhs.value < rhs.value
  }
}

public struct Reference<Value : PBXObject> : Hashable, Comparable {
  public let allObjects: AllObjects

  public let id: Guid

  public init(allObjects: AllObjects, id: Guid) {
    self.allObjects = allObjects
    self.id = id
  }
    
  public static func null(allObjects: AllObjects) -> Reference {
      return Reference(allObjects: allObjects, id: Guid(""))
  }

  public var value: Value? {
    guard let object = allObjects.objects[id] as? Value else { return nil }

    return object
  }

  static public func ==(lhs: Reference<Value>, rhs: Reference<Value>) -> Bool {
    return lhs.id == rhs.id
  }

  public var hashValue: Int {
    return id.hashValue
  }

  static public func <(lhs: Reference<Value>, rhs: Reference<Value>) -> Bool {
    return lhs.id < rhs.id
  }
}

public class AllObjects {
  public var objects: [Guid: PBXObject] = [:]
  public var fullFilePaths: [Guid: Path] = [:]
  public var refCounts: [Guid: Int] = [:]
  public var projectUrl = URL(fileURLWithPath: "")
    
    
  public func objectsOfType<T>() -> [T] {
    return objects.compactMap({
        $1 as? T
    })
  }

  public func createReferences<Value>(ids: [Guid]) -> [Reference<Value>] {
    return ids.map(createReference)
  }
    
  public func createReferences<Value>() -> [Reference<Value>] where Value : PBXObject {
    return objects.compactMap { (key, value) -> Reference<Value>? in
        guard value is Value else {
            return nil
        }
        refCounts[key, default: 0] += 1
        return Reference(allObjects: self, id: key)
    }
  }
    
  public func createOptionalReference<Value>(id: Guid?) -> Reference<Value>? {
    guard let id = id else { return nil }
    return createReference(id: id)
  }

  public func createReference<Value>(id: Guid) -> Reference<Value> {
    refCounts[id, default: 0] += 1

    let ref: Reference<Value> = Reference(allObjects: self, id: id)
    return ref
  }

  public func createReference<Value>(value: Value) -> Reference<Value> {
    refCounts[value.id, default: 0] += 1

    objects[value.id] = value
    let ref: Reference<Value> = Reference(allObjects: self, id: value.id)
    return ref
  }

  public func removeReference<Value>(_ ref: Reference<Value>?) {
    guard let ref = ref else { return }
    guard let count = refCounts[ref.id], count > 0 else {
      assertionFailure("refCount[\(ref.id)] is \(refCounts[ref.id]?.description ?? "nil")")
      return
    }

    refCounts[ref.id] = count - 1

    if count == 1 {
      objects[ref.id] = nil
    }
  }

  public func createFreshGuid(from original: Guid) -> Guid {
    // If original isn't a PBXIdentifier, just return a UUID
    guard let identifier = PBXIdentifier(string: original.value) else {
      return Guid(UUID().uuidString)
    }

    // Ten attempts at generating fresh identifier
    for _ in 0..<10 {
      let guid = Guid(identifier.createFreshIdentifier().stringValue)

      if objects.keys.contains(guid) {
        continue
      }

      return guid
    }

    // Fallback to UUID
    return Guid(UUID().uuidString)
  }

  public static func createObject(_ id: Guid, fields: Fields, allObjects: AllObjects) throws -> PBXObject {
    let isa = try fields.string("isa")
    if let type = types[isa] {
      return try type.init(id: id, fields: fields, allObjects: allObjects)
    }

    // Fallback
    assertionFailure("Unknown PBXObject subclass isa=\(isa)")
    return try PBXObject(id: id, fields: fields, allObjects: allObjects)
  }

  public func validateReferences() throws {

    let refKeys = Set(refCounts.keys)
    let objKeys = Set(objects.keys)

    let deadRefs = refKeys.subtracting(objKeys).sorted()
    let orphanObjs = objKeys.subtracting(refKeys).sorted()

    var errors: [ReferenceError] = []
    for (id, object) in objects {

      for (path, guid) in findGuids(object) {
        if !objKeys.contains(guid) {
          let error = ReferenceError.deadReference(type: object.isa, id: id, keyPath: path, ref: guid)
          errors.append(error)
        }
      }
    }

    for id in orphanObjs {
      guard let object = objects[id] else { continue }

      let error = ReferenceError.orphanObject(type: object.isa, id: id)
      errors.append(error)
    }

    if !deadRefs.isEmpty || !orphanObjs.isEmpty {
      throw ProjectFileError.internalInconsistency(errors)
    }
  }
}

private func referenceGuid(_ obj: Any) -> Guid? {

  // Should figure out a better way to test obj is of type Reference<T>
  let m = Mirror(reflecting: obj)
  guard m.displayStyle == Mirror.DisplayStyle.`struct` else { return nil }

  return m.descendant("id") as? Guid
}


private func findGuids(_ obj: Any) -> [(String, Guid)] {

  var result: [(String, Guid)] = []

  for child in Mirror(reflecting: obj).children {

    guard let label = child.label else { continue }
    let value = child.value

    let m = Mirror(reflecting: value)
    if m.displayStyle == Mirror.DisplayStyle.`struct` {
      if let guid = referenceGuid(value) {
        result.append((label, guid))
      }
    }
    if m.displayStyle == Mirror.DisplayStyle.optional
      || m.displayStyle == Mirror.DisplayStyle.collection
    {
      for item in m.children {
        if let guid = referenceGuid(item.value) {
          result.append((label, guid))
        }
      }
    }
    if m.displayStyle == Mirror.DisplayStyle.optional {
      if let element = m.children.first {
        for item in Mirror(reflecting: element.value).children {
          let vals = findGuids(item.value)
            .map { arg in ("\(label).\(arg.0)", arg.1) }
          result.append(contentsOf: vals)
        }
      }
    }
  }

  return result
}

protocol OverrideIsaName : class {
    static var overrideIsaName : String { get }
}

let xcObjectTypes = [
    PBXProject.self,
    PBXContainerItemProxy.self,
    PBXBuildFile.self,
    PBXCopyFilesBuildPhase.self,
    PBXFrameworksBuildPhase.self,
    PBXHeadersBuildPhase.self,
    PBXResourcesBuildPhase.self,
    PBXShellScriptBuildPhase.self,
    PBXSourcesBuildPhase.self,
    PBXBuildStyle.self,
    XCBuildConfiguration.self,
    PBXAggregateTarget.self,
    PBXLegacyTarget.self,
    PBXNativeTarget.self,
    PBXTargetDependency.self,
    XCConfigurationList.self,
    PBXReference.self,
    PBXReferenceProxy.self,
    PBXFileReference.self,
    PBXGroup.self,
    PBXVariantGroup.self,
    XCVersionGroup.self
]



private let types: [String: PBXObject.Type] = Dictionary(uniqueKeysWithValues: xcObjectTypes.map({ ( $0.isaName , $0 ) }))


