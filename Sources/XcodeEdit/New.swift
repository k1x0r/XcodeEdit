//
// New.swift
//
// Created by k1x
//


import Foundation
import k2Utils

public extension PBXProject {
    
    static let knownTypes : Set<String> = ["storyboard", "xib", "strings", "cer"]
    static let knownHeaderTypes : Set<String> = ["h", "hh", "hpp"]

    
    func addHeaderFiles(rootPath : URL) throws {
        print("Adding xibs and storyboards with root url: \(rootPath)")
        let groups : [PBXGroup] = allObjects.objects.compactMap({
            $1 as? PBXGroup
        })

        for group in groups {
            let path = allObjects.fullFilePaths[group.id]
            guard let name = group.name,
                let url = path?.url(with: { _ in rootPath }) else {
                    continue
            }
            let directoryFiles = try FileManager.default.contentsOfDirectory(atPath: url.path)
            let resourceFiles = directoryFiles.filter {
                guard let ext = $0.substring(fromLast: ".") else { return false }
                return Me.knownHeaderTypes.contains(ext)
            }
            guard !resourceFiles.isEmpty else {
                continue
            }
            for fileName in resourceFiles {
                guard !group.children.contains(where: { $0.value?.path == fileName }) else {
                    continue
                }

                let reference = PBXFileReference(emptyObjectWithId: Guid.random, allObjects: allObjects)
                reference.path = fileName
                reference.fileEncoding = 4
                group.addFileReference(allObjects.createReference(value: reference))
            }
            
            print("Found files: \(resourceFiles)")
        }
    }
    
    // TODO remove root path
    func addXibsAndStoryboards(rootPath : URL) throws {
        print("Adding xibs and storyboards with root url: \(rootPath)")
        let groups : [PBXGroup] = allObjects.objects.compactMap({
            $1 as? PBXGroup
        })

        for group in groups {
            let path = allObjects.fullFilePaths[group.id]
            guard let name = group.name,
                  let url = path?.url(with: { _ in rootPath }),
                  let targ = target(named: name.substring(toLast: " ") ?? name) else {
                continue
            }
            let directoryFiles = try FileManager.default.contentsOfDirectory(atPath: url.path)
            let resourceFiles = directoryFiles.filter {
                guard let ext = $0.substring(fromLast: ".") else { return false }
                return Me.knownTypes.contains(ext)
            }
            guard !resourceFiles.isEmpty else {
                continue
            }
            let localizedDirectories = directoryFiles.filter {
                guard let ext = $0.substring(fromLast: ".") else { return false }
                return ext == "lproj"
            }
            var localized : [String : Set<String>] = [:]
            for dir in localizedDirectories {
                let localizedFiles = try FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent(dir).path)
                for file in localizedFiles {
                    guard let ext = file.substring(fromLast: "."), Me.knownTypes.contains(ext) else {
                        continue
                    }
                    localized[file, default: []].insert(dir)
                }
            }
            
            print("Found files: \(resourceFiles)")
            let resourcesPhase = targ.buildPhase(of: PBXResourcesBuildPhase.self)
            resourcesPhase.files.append(contentsOf: resourceFiles.compactMap { fileName in
                guard !group.fileRefs.contains(where: { $0.value?.path == fileName }) else {
                    return nil
                }
                let reference = PBXFileReference(emptyObjectWithId: Guid.random, allObjects: allObjects)
                reference.path = fileName
                reference.fileEncoding = 4
                group.addFileReference(allObjects.createReference(value: reference))
                let file = PBXBuildFile(emptyObjectWithId: Guid.random, allObjects: allObjects)
                file.fileRef = allObjects.createReference(value: reference)
                return allObjects.createReference(value: file)
            })
            resourcesPhase.files.append(contentsOf: localized.map({ (fileName, localizations) in
                let variantGroup = PBXVariantGroup(emptyObjectWithId: Guid.random, allObjects: allObjects)
                variantGroup.name = fileName
                variantGroup.sourceTree = .group
                variantGroup.children = localizations.map({ localization in
                    let fileRef = PBXFileReference(emptyObjectWithId: Guid.random, allObjects: allObjects)
                    fileRef.sourceTree = .group
                    fileRef.path = localization + "/" + fileName
                    fileRef.name = localization.substring(toLast: ".")
                    return allObjects.createReference(value: fileRef)
                })
                let variantRef : Reference<PBXReference> = allObjects.createReference(value: variantGroup)
                group.children.append(variantRef)
                let buildFile = PBXBuildFile(emptyObjectWithId: Guid.random, allObjects: allObjects)
                buildFile.fileRef = variantRef
                return allObjects.createReference(value: buildFile)
            }))
        }
    }
    
    public enum FrameworkType {
        case library
        case embeddedBinary
        case both
    }
    
    func addSourceFiles(files : [Reference<PBXReference>], group groupRef: Reference<PBXGroup>? = nil, targets: [PBXTarget]) throws {
        guard let group = (groupRef ?? mainGroup).value else {
            throw "Main group is not found".error()
        }
        group.children.append(contentsOf: files)
        for target in targets {
            let buildPhase = target.buildPhase(of: PBXSourcesBuildPhase.self)
            let buildFiles : [Reference<PBXBuildFile>] = files.map {
                let buildFile = PBXBuildFile(emptyObjectWithId: Guid.random, allObjects: self.allObjects)
                buildFile.fileRef = $0
                return allObjects.createReference(value: buildFile)
            }
            buildPhase.files.append(contentsOf: buildFiles)

        }

    }
    
    func addFramework(framework : PBXFileReference, group groupRef: Reference<PBXGroup>? = nil, targetNames: [(FrameworkType, String)]) throws {
        
        try addFramework(framework: framework, group: groupRef, targets: targetNames.map {
            guard let targ = target(named: $0.1) else {
                throw "Target with name: \"\($0)\" not found!".error()
            }
            return ($0.0, targ)
        })
        
    }
    
    func addFramework(framework : PBXFileReference, group groupRef: Reference<PBXGroup>? = nil, targets: [(FrameworkType, PBXTarget)]) throws{
        if framework.lastKnownFileType == nil {
           framework.lastKnownFileType = .framework
        }
        if let group = groupRef?.value {
            group.addFileReference(allObjects.createReference(value: framework))
        }
        
        for (frameworkType, target) in targets {
            switch frameworkType {
                case .embeddedBinary, .both:
                    let buildFile = PBXBuildFile(emptyObjectWithId: Guid.random, allObjects: allObjects)
                    buildFile.fileRef = allObjects.createReference(value: framework)
                    buildFile.settings = [
                        "ATTRIBUTES" : ["CodeSignOnCopy", "RemoveHeadersOnCopy"]
                    ]
                    let frameworksPhase = target.buildPhase(of: PBXCopyFilesBuildPhase.self)
                    frameworksPhase.addBuildFile(allObjects.createReference(value: buildFile))
                    if frameworkType == .both {
                        fallthrough
                    }
                case .library:
                    let buildFile = PBXBuildFile(emptyObjectWithId: Guid.random, allObjects: allObjects)
                    buildFile.fileRef = allObjects.createReference(value: framework)
                    let copyFilesPhase = target.buildPhase(of: PBXFrameworksBuildPhase.self)
                    copyFilesPhase.addBuildFile(allObjects.createReference(value: buildFile))
            }
        }
        
    }
    
    /// Completely get rid of the framework from all targets. This method guarantees that given frameworks won't be in groups and is removed from all the targets..
    /// Better to use loop of all the targets... or go by reference...??? when we go by reference we loop through all objects all the time. But here we just loop twice and we filter the dictionary and remove from the build phase. So this is definetely cheaper and much more effective.
    func removeFrameworks(frameworks : Set<Reference<PBXReference>>, groups : [PBXGroup]) {
//        let frameworksPlain = Set(frameworks.map({ Reference<PBXReference>(allObjects: allObjects, id: $0.id) }))
        for group in groups {
            group.children = group.children.filter { !frameworks.contains($0) }
        }
        var buildFileRefs = Set<Reference<PBXBuildFile>>()
        allObjects.objects = allObjects.objects.filter({ (key, value) in
            guard let buildFile = value as? PBXBuildFile, let fileRef = buildFile.fileRef else {
                return true
            }
            if frameworks.contains(fileRef) {
                _ = buildFileRefs.update(with: Reference(allObjects: allObjects, id: buildFile.id))
                return false
            } else {
                return true
            }
        })
        for (_, value) in allObjects.objects {
            guard let phase = value as? PBXBuildPhase else {
                continue
            }
            phase.files = phase.files.filter({ !buildFileRefs.contains($0) })
        }
        allObjects.objects = allObjects.objects.filter({ (key, value) in
            guard let fileRef = value as? PBXReference else {
                return true
            }
            return !frameworks.contains(where: { $0.id == fileRef.id })
        })
    }
    
    

    func target(named name : String) -> PBXTarget? {
        return targets.first(where: { $0.value?.name == name })?.value
    }
    
    func newFrameworkReference(path : String, sourceTree : SourceTree = .relativeTo(.sdkRoot), fileType : PBXFileType = .framework) -> PBXFileReference {
        let framework = PBXFileReference(emptyObjectWithId: Guid.random, allObjects: allObjects)
        framework.path = path
        framework.name = path.substring(fromLast: "/") ?? path
        framework.sourceTree = sourceTree
        framework.lastKnownFileType = fileType
        return framework
    }

    func newFileReference(name: String? = nil, path: String, sourceTree: SourceTree = .group) -> Reference<PBXReference> {
        let fileReference = PBXFileReference(emptyObjectWithId: Guid.random, allObjects: allObjects)
        fileReference.path = path
        fileReference.name = name ?? path.substring(fromLast: "/") ?? path
        fileReference.sourceTree = sourceTree
        let ref = allObjects.createReference(value: fileReference)
        return Reference(allObjects: fileReference.allObjects, id: ref.id)
    }
}

public extension PBXGroup {
    
    var frameworks : Set<Reference<PBXReference>> {
        return Set(fileRefs.filter({ $0.value?.lastKnownFileType == .framework }).map({ Reference<PBXReference>(allObjects: allObjects, id: $0.id) }))
    }
    
    func group(with name: String, sourceTree : SourceTree = .group) -> Reference<PBXGroup> {
        let group : Reference<PBXGroup>
        if let _group = subGroups.first(where: { $0.value?.path == name }) {
            group = _group
        } else {
            let newGroup = PBXGroup(emptyObjectWithId: Guid.random, allObjects: allObjects)
            newGroup.path = name
            newGroup.name = name
            newGroup.sourceTree = sourceTree
            let newGroupRef = allObjects.createReference(value: newGroup)
            addChildGroup(newGroupRef)
            group = newGroupRef
        }
        return group
    }
    
}

public extension PBXTarget {
    
    public typealias BuildPhaseAppend = (inout [Reference<PBXBuildPhase>], Reference<PBXBuildPhase>)->()
    
    func buildPhase<T : PBXBuildPhase>(of type : T.Type, append : BuildPhaseAppend? = nil) -> T {
        return buildPhases.first(where: { $0.value is T })?.value as? T ??
               addBuildPhase(type: T.self, append: append)
    }
    
    func addBuildPhase<T : PBXBuildPhase>(type : T.Type, append : BuildPhaseAppend? = nil) -> T {
        let phase = type.init(emptyObjectWithId: Guid.random, allObjects: allObjects)
        let reference = allObjects.createReference(value: phase) as Reference<PBXBuildPhase>
        if let append = append {
            append(&buildPhases, reference)
        } else {
            buildPhases.append(reference)
        }
        return phase
    }
    
    func deepClone() throws -> PBXTarget {
        let aClone : PBXTarget = clone()
        aClone.buildPhases = buildPhases.compactMap({
            guard let clonePhase = $0.value?.clone() else {
                return nil
            }
            return allObjects.createReference(value: clonePhase)
        })
        aClone.dependencies = dependencies.compactMap({
            guard let cloneDependency = $0.value?.clone() else {
                return nil
            }
            return allObjects.createReference(value: cloneDependency)
        })
        guard let buildConfigClone = buildConfigurationList.value?.deepClone() else {
            throw "Build configurations not found".error()
        }
        aClone.buildConfigurationList = allObjects.createReference(value: buildConfigClone)
        return aClone
    }
    
    /// Only used for singular setting
    /// Does not guarantee anything
    func setBuildSetting(key: String, value : Any) {
        for ref in buildConfigurationList.value?.buildConfigurations ?? [] {
            ref.value?.buildSettings[key] = value
        }
    }
    
    func updateBuildSettings(_ dict : [String : Any]) {
        for ref in buildConfigurationList.value?.buildConfigurations ?? [] {
            ref.value?.buildSettings.merge(dict, uniquingKeysWith: { $1 })
        }
    }
    
}

public extension Dictionary where Key == String, Value == Any {
    
    
    mutating func add(for key: String, values newValues: [String]) {
        var values : [String]
        if let string = self[key] as? String {
            values = [string]
        } else if let array = self[key] as? [String] {
            values = array
        } else {
            values = []
        }
        values.append(contentsOf: newValues)
        self[key] = values
    }
    
}

public struct PBXReferenceKey : Hashable {
    
    let path : String?
    let name : String?
    let sourceTree : SourceTree
    
}

public extension PBXReference {
    
    var key : PBXReferenceKey {
        return PBXReferenceKey(path: path, name: name, sourceTree: sourceTree)
    }
    
}
