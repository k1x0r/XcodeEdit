//
//  PBXObject.swift
//  XcodeEdit
//
//  Created by Tom Lokhorst on 2015-08-29.
//  Copyright © 2015 nonstrict. All rights reserved.
//

import Foundation

public typealias Fields = [String: Any]

public protocol PBXObjectProtocol : class {
    var fields: Fields { get }
    var allObjects: AllObjects { get }
    init(id: Guid, fields: Fields, allObjects: AllObjects) throws
    func applyChanges()
}

public /* abstract */ class PBXObject : PBXObjectProtocol {
    
  public var fields: Fields
  public let allObjects: AllObjects
    
  public let id: Guid
  open var isa: String {
      return type(of: self).isaName
  }

  open class var isaName : String {
      return String(describing: self)
  }
    
  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.id = id
    self.fields = fields
    self.allObjects = allObjects
  }
  
  public required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
    self.id = id
    self.fields = [:]
    self.allObjects = allObjects
  }
    
  open func applyChanges() {
    fields["isa"] = type(of: self).isaName
  }
}

public extension PBXObjectProtocol {
    
    func clone() -> Self {
        applyChanges()
        return try! type(of: self).init(id: Guid.random, fields: fields, allObjects: allObjects)
    }
    
    func clone(to newAllObjects: AllObjects, guid : Guid? = nil) -> Self {
        applyChanges()
        return try! type(of: self).init(id: guid ?? Guid.random, fields: fields, allObjects: newAllObjects)
    }
}


public /* abstract */ class PBXContainer : PBXObject {
}

public class PBXProject : PBXContainer {
  public var buildConfigurationList: Reference<XCConfigurationList>
  public var developmentRegion: String
  public var hasScannedForEncodings: Bool
  public var knownRegions: [String]
  public var mainGroup: Reference<PBXGroup>
  public var targets: [Reference<PBXTarget>]
  public var projectReferences: [ProjectReference]
  public var groups : [Reference<PBXGroup>]
    
  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.developmentRegion = try fields.string("developmentRegion")
    self.hasScannedForEncodings = try fields.bool("hasScannedForEncodings")
    self.knownRegions = try fields.strings("knownRegions")

    self.buildConfigurationList = allObjects.createReference(id: try fields.id("buildConfigurationList"))
    self.mainGroup = allObjects.createReference(id: try fields.id("mainGroup"))
    self.targets = allObjects.createReferences(ids: try fields.ids("targets"))
    self.groups = allObjects.createReferences()
    
    if fields["projectReferences"] == nil {
      self.projectReferences = []
    }
    else {
      let projectReferenceFields = try fields.fieldsArray("projectReferences")
      self.projectReferences = try projectReferenceFields
        .map { try ProjectReference(fields: $0, allObjects: allObjects) }
    }

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
    required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        fatalError("init(emptyObjectWithId:allObjects:) has not been implemented")
    }
    
    public override func applyChanges() {
        super.applyChanges()
        fields["targets"] = targets.map { $0.id.value }
        fields["buildConfigurationList"] = buildConfigurationList.id.value
        fields["mainGroup"] = mainGroup.id.value
        print("Changes applied...")
        
    }
    
  public class ProjectReference {
    public let ProductGroup: Reference<PBXGroup>
    public let ProjectRef: Reference<PBXFileReference>

    public required init(fields: Fields, allObjects: AllObjects) throws {
      self.ProductGroup = allObjects.createReference(id: try fields.id("ProductGroup"))
      self.ProjectRef = allObjects.createReference(id: try fields.id("ProjectRef"))
    }
  }
}

public /* abstract */ class PBXContainerItem : PBXObject {
}

public class PBXContainerItemProxy : PBXContainerItem {
}

public /* abstract */ class PBXProjectItem : PBXContainerItem {
}

public class PBXBuildFile : PBXProjectItem {
  public var fileRef: Reference<PBXReference>?
  public var settings : Any?

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.fileRef = allObjects.createOptionalReference(id: try fields.optionalId("fileRef"))
    self.settings = fields["settings"]
    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
  required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
      super.init(emptyObjectWithId: id, allObjects: allObjects)
  }
    
    public override func applyChanges() {
        super.applyChanges()
        fields["fileRef"] = fileRef?.id.value
        fields["settings"] = settings
    }
}


public /* abstract */ class PBXBuildPhase : PBXProjectItem {
  public var files: [Reference<PBXBuildFile>]

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.files = allObjects.createReferences(ids: try fields.ids("files"))

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }

  public init(id : Guid, allObjects : AllObjects) throws {
      self.files = []
      try super.init(id: id, fields: [:], allObjects: allObjects)
  }
    
    public required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
      self.files = []
      super.init(emptyObjectWithId: id, allObjects: allObjects)
  }

  // Custom function for R.swift
  public func addBuildFile(_ reference: Reference<PBXBuildFile>) {
    if files.contains(reference) { return }
    files.append(reference)
  }
    
  public override func applyChanges() {
     super.applyChanges()
     fields["files"] = files.map { $0.id.value }
  }
  
}

public class PBXCopyFilesBuildPhase : PBXBuildPhase {
  public var name: String?

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.name = try fields.optionalString("name")

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
    required public init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        super.init(emptyObjectWithId: id, allObjects: allObjects)
    }
    
    public override func applyChanges() {
        super.applyChanges()
        fields["name"] = name
    }
}

public class PBXFrameworksBuildPhase : PBXBuildPhase {
}

public class PBXHeadersBuildPhase : PBXBuildPhase {
}

public class PBXResourcesBuildPhase : PBXBuildPhase {
    
    public override func applyChanges() {
        super.applyChanges()
        fields["buildActionMask"] = 2147483647
        fields["runOnlyForDeploymentPostprocessing"] = 0
    }
}

public class PBXShellScriptBuildPhase : PBXBuildPhase {
  public let name: String?
  public let shellScript: String

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.name = try fields.optionalString("name")
    self.shellScript = try fields.string("shellScript")

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
    required public init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        fatalError("init(emptyObjectWithId:allObjects:) has not been implemented")
    }
}

public class PBXSourcesBuildPhase : PBXBuildPhase {
}

public class PBXBuildStyle : PBXProjectItem {
}

public class XCBuildConfiguration : PBXBuildStyle {
    
    public var name: String
    public var buildSettings: [String: Any]

    public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
        self.name = try fields.string("name")
        self.buildSettings = try fields.fields("buildSettings")
        
        try super.init(id: id, fields: fields, allObjects: allObjects)
    }
    
    internal init(other : XCBuildConfiguration, guid: Guid, name : String) throws {
        self.name = name
        self.buildSettings = other.buildSettings
        try super.init(id: guid, fields: other.fields, allObjects: other.allObjects)
    }
    
    required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        fatalError("init(emptyObjectWithId:allObjects:) has not been implemented")
    }
    
    public func copy(with guid : Guid, name : String) throws -> XCBuildConfiguration {
        return try XCBuildConfiguration(other: self, guid: guid, name : name)
    }
    
    open override func applyChanges() {
        super.applyChanges()

        fields["buildSettings"] = buildSettings
        fields["name"] = name
    }
    
}

public /* abstract */ class PBXTarget : PBXProjectItem {

    public var buildConfigurationList: Reference<XCConfigurationList>
    public var name: String
    public var productName: String
    public var buildPhases: [Reference<PBXBuildPhase>]
    public var dependencies: [Reference<PBXTargetDependency>]
    public var productType : String

    public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
        self.buildConfigurationList = allObjects.createReference(id: try fields.id("buildConfigurationList"))
        self.name = try fields.string("name")
        self.productName = try fields.string("productName")
        self.productType = try fields.string("productType")
        self.buildPhases = allObjects.createReferences(ids: try fields.ids("buildPhases"))
        self.dependencies = allObjects.createReferences(ids: try fields.ids("dependencies"))
        try super.init(id: id, fields: fields, allObjects: allObjects)
    }
    
    required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        self.buildConfigurationList = .null(allObjects: allObjects)
        self.name = ""
        self.productName = ""
        self.buildPhases = []
        self.dependencies = []
        self.productType = ""
        super.init(emptyObjectWithId: id, allObjects: allObjects)
    }
    
    public override func applyChanges() {
        super.applyChanges()

        fields["buildPhases"] = buildPhases.map { $0.id.value }
        fields["name"] = name
        fields["productName"] = productName
        fields["productType"] = productType
        fields["buildConfigurationList"] = buildConfigurationList.id.value
        fields["dependencies"] = dependencies.map { $0.id.value }
    }

}

public class PBXAggregateTarget : PBXTarget {
}

public class PBXLegacyTarget : PBXTarget {
}

public class PBXNativeTarget : PBXTarget {
    
    public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
        try super.init(id: id, fields: fields, allObjects: allObjects)
    }
    
    required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        fatalError("init(emptyObjectWithId:allObjects:) has not been implemented")
    }
}

public class PBXTargetDependency : PBXProjectItem {
  public var targetProxy: Reference<PBXContainerItemProxy>?

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    do {
        self.targetProxy = allObjects.createReference(id: try fields.id("targetProxy"))
    } catch {
        self.targetProxy = nil
    }
    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
   public required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
       super.init(emptyObjectWithId: id, allObjects: allObjects)
   }
    
    public override func applyChanges() {
        super.applyChanges()
        fields["targetProxy"] = targetProxy?.id.value
    }
    
}

public class XCConfigurationList : PBXProjectItem {
    
  public var buildConfigurations: [Reference<XCBuildConfiguration>]
  public var defaultConfigurationName: String?

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.buildConfigurations = allObjects.createReferences(ids: try fields.ids("buildConfigurations"))
    self.defaultConfigurationName = try fields.optionalString("defaultConfigurationName")

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
    required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        self.buildConfigurations = []
        self.defaultConfigurationName = ""
        super.init(emptyObjectWithId: id, allObjects: allObjects)
    }
    
  public func addBuildConfiguration(_ config : XCBuildConfiguration) {
    let ref = allObjects.createReference(value: config)
    buildConfigurations.append(ref)
  }
  
  public func configuration(named name : String) -> XCBuildConfiguration? {
      return buildConfigurations.first(where: {
          $0.value?.name == name
      })?.value
  }
    
  public var defaultConfiguration: XCBuildConfiguration? {
    for configuration in buildConfigurations {
      if let configuration = configuration.value, configuration.name == defaultConfigurationName {
        return configuration
      }
    }

    return nil
  }
    
    public override func applyChanges() {
        super.applyChanges()
        fields["buildConfigurations"] = buildConfigurations.map { $0.id.value }
    }
    
    public func deepClone() -> XCConfigurationList {
        let aClone = clone()
        aClone.buildConfigurations = buildConfigurations.compactMap({
            guard let cloneDependency = $0.value?.clone() else {
                return nil
            }
            return allObjects.createReference(value: cloneDependency)
        })
        return aClone
    }
    
}

public class PBXReference : PBXContainerItem {
  public var name: String?
  public var path: String?
  public var sourceTree: SourceTree
  public var fileEncoding : Int?

    public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.name = try fields.optionalString("name")
    self.path = try fields.optionalString("path")
    self.fileEncoding = fields["fileEncoding"] as? Int
    let sourceTreeString = try fields.string("sourceTree")
    guard let sourceTree = SourceTree(rawValue: sourceTreeString) else {
      throw AllObjectsError.wrongType(key: sourceTreeString)
    }
    self.sourceTree = sourceTree

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
    required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        sourceTree = .group
        super.init(emptyObjectWithId: id, allObjects: allObjects)
    }
    
    
    
    public override func applyChanges() {
        super.applyChanges()
        fields["name"] = name
        fields["path"] = path
        fields["sourceTree"] = sourceTree.rawValue
        fields["fileEncoding"] = fileEncoding

    }
}

public class PBXFileReference : PBXReference {
    
    public var lastKnownFileType : PBXFileType?
  
    public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
        if let lastKnownFileType = fields["lastKnownFileType"] as? String {
            self.lastKnownFileType = PBXFileType(rawValue: lastKnownFileType)
        }
        try super.init(id: id, fields: fields, allObjects: allObjects)
    }
    
    public required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        super.init(emptyObjectWithId: id, allObjects: allObjects)
    }
    
  // convenience accessor
    public var fullPath: Path? {
        return self.allObjects.fullFilePaths[self.id]
    }

    public override func applyChanges() {
        super.applyChanges()
        if let fileType = lastKnownFileType {
            fields["lastKnownFileType"] = fileType.rawValue
        }
    }
}

public class PBXReferenceProxy : PBXReference {

    public let remoteRef: Reference<PBXContainerItemProxy>

    public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
        self.remoteRef = allObjects.createReference(id: try fields.id("remoteRef"))
        try super.init(id: id, fields: fields, allObjects: allObjects)
    }
    
    required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
        fatalError("init(emptyObjectWithId:allObjects:) has not been implemented")
    }
    
}

public class PBXGroup : PBXReference {
  public var children: [Reference<PBXReference>]

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.children = allObjects.createReferences(ids: try fields.ids("children"))

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
  public required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
      self.children = []
      super.init(emptyObjectWithId: id, allObjects: allObjects)
  }
    
  public var subGroups: [Reference<PBXGroup>] {
    return children.compactMap { childRef in
      guard let _ = childRef.value as? PBXGroup else { return nil }
      return Reference(allObjects: childRef.allObjects, id: childRef.id)
    }
  }

  public var fileRefs: [Reference<PBXFileReference>] {
    return children.compactMap { childRef in
      guard let _ = childRef.value as? PBXFileReference else { return nil }
      return Reference(allObjects: childRef.allObjects, id: childRef.id)
    }
  }
    
    public func addChildGroup(_ groupRef: Reference<PBXGroup>) {
        let reference = Reference<PBXReference>(allObjects: groupRef.allObjects, id: groupRef.id)
        children.append(reference)
    }

  // Custom function for R.swift
  public func addFileReference(_ fileReference: Reference<PBXFileReference>) {
    if fileRefs.contains(fileReference) { return }
    let reference = Reference<PBXReference>(allObjects: fileReference.allObjects, id: fileReference.id)
    children.append(reference)
  }
 
    
    public override func applyChanges() {
        super.applyChanges()
        fields["children"] = children.map { $0.id.value }
    }
}

public class PBXVariantGroup : PBXGroup {
}

public class XCVersionGroup : PBXReference {
  public let children: [Reference<PBXFileReference>]

  public required init(id: Guid, fields: Fields, allObjects: AllObjects) throws {
    self.children = allObjects.createReferences(ids: try fields.ids("children"))

    try super.init(id: id, fields: fields, allObjects: allObjects)
  }
    
  required init(emptyObjectWithId id: Guid, allObjects: AllObjects) {
    fatalError("init(emptyObjectWithId:allObjects:) has not been implemented")
  }
    
}


public enum SourceTree: RawRepresentable, Hashable {
  case absolute
  case group
  case relativeTo(SourceTreeFolder)

  public init?(rawValue: String) {
    switch rawValue {
    case "<absolute>":
      self = .absolute

    case "<group>":
      self = .group

    default:
      guard let sourceTreeFolder = SourceTreeFolder(rawValue: rawValue) else { return nil }
      self = .relativeTo(sourceTreeFolder)
    }
  }

  public var rawValue: String {
    switch self {
    case .absolute:
      return "<absolute>"
    case .group:
      return "<group>"
    case .relativeTo(let folter):
      return folter.rawValue
    }
  }
}

public enum SourceTreeFolder: String, Equatable {
  case sourceRoot = "SOURCE_ROOT"
  case buildProductsDir = "BUILT_PRODUCTS_DIR"
  case developerDir = "DEVELOPER_DIR"
  case sdkRoot = "SDKROOT"
  case platformDir = "PLATFORM_DIR"

  public static func ==(lhs: SourceTreeFolder, rhs: SourceTreeFolder) -> Bool {
    return lhs.rawValue == rhs.rawValue
  }
}

public enum Path: Equatable {
  case absolute(String)
  case relativeTo(SourceTreeFolder, String)

  public func url(with urlForSourceTreeFolder: (SourceTreeFolder) -> URL) -> URL {
    switch self {
    case let .absolute(absolutePath):
      return URL(fileURLWithPath: absolutePath).standardizedFileURL

    case let .relativeTo(sourceTreeFolder, relativePath):
      let sourceTreeURL = urlForSourceTreeFolder(sourceTreeFolder)
      return sourceTreeURL.appendingPathComponent(relativePath).standardizedFileURL
    }
  }

  public static func ==(lhs: Path, rhs: Path) -> Bool {
    switch (lhs, rhs) {
    case let (.absolute(lpath), .absolute(rpath)):
      return lpath == rpath

    case let (.relativeTo(lfolder, lpath), .relativeTo(rfolder, rpath)):
      let lurl = URL(string: lfolder.rawValue)!.appendingPathComponent(lpath).standardized
      let rurl = URL(string: rfolder.rawValue)!.appendingPathComponent(rpath).standardized

      return lurl == rurl

    default:
      return false
    }
  }
}
