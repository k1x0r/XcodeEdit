//
// New.swift
//
// Created by k1x
//


import Foundation
import k2Utils

public extension PBXProject {
    
    // TODO remove root path
    func addXibsAndStoryboards(rootPath : URL) throws {
        for ref in groups {
            guard let group = ref.value else {
                continue
            }
            let path = allObjects.fullFilePaths[group.id]
            guard let name = group.name,
                  let url = path?.url(with: { _ in rootPath }),
                  let targ = target(named: name.substring(toLast: " ") ?? name) else {
                continue
            }
            

            let files = try FileManager.default.contentsOfDirectory(atPath: url.path).filter {
                return $0.hasSuffix("storyboard") || $0.hasSuffix("xib")
            }
            guard !files.isEmpty else {
                continue
            }
            print("Found files: \(files)")
            let resourcesPhase = targ.buildPhase(of: PBXResourcesBuildPhase.self)
            resourcesPhase.files.append(contentsOf: files.compactMap { fileName in
                guard !group.fileRefs.contains(where: { $0.value?.path == fileName }) else {
                    return nil
                }
                let reference = PBXFileReference(emptyObjectWithId: Guid.random, allObjects: allObjects)
                reference.path = fileName
                reference.fileEncoding = 4
//                reference.lastKnownFileType =
                group.addFileReference(allObjects.createReference(value: reference))
                let file = PBXBuildFile(emptyObjectWithId: Guid.random, allObjects: allObjects)
                file.fileRef = allObjects.createReference(value: reference)
                return allObjects.createReference(value: file)
            })
        }
    }
    
    public enum FrameworkType {
        case library
        case embeddedBinary
        case both
    }
    
    func addFramework(framework : PBXFileReference, frameworkType : FrameworkType, group groupRef: Reference<PBXGroup>? = nil, targetNames: [String]) throws {
        
        try addFramework(framework: framework, frameworkType: frameworkType, group: groupRef, targets: targetNames.map {
            guard let targ = target(named: $0) else {
                throw "Target with name: \"\($0)\" not found!".error()
            }
            return targ
        })
        
    }
    
    func addFramework(framework : PBXFileReference, frameworkType : FrameworkType, group groupRef: Reference<PBXGroup>? = nil, targets: [PBXTarget]) throws{
        guard let group = (groupRef ?? mainGroup).value else {
            throw "Main group is not found".error()
        }
        group.addFileReference(allObjects.createReference(value: framework))
        
        for target in targets {
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

    }
    
    

    func target(named name : String) -> PBXTarget? {
        return targets.first(where: { $0.value?.name == name })?.value
    }
    
    func newFrameworkReference(path : String, sourceTree : SourceTree = .relativeTo(.sdkRoot)) -> PBXFileReference {
        let framework = PBXFileReference(emptyObjectWithId: Guid.random, allObjects: allObjects)
        framework.path = path
        framework.name = path.substring(fromLast: "/") ?? path
        framework.sourceTree = sourceTree
        framework.lastKnownFileType = .framework
        return framework
    }
    
}

public extension PBXGroup {
    
    var frameworks : Set<Reference<PBXReference>> {
        return Set(fileRefs.filter({ $0.value?.lastKnownFileType == .framework }).map({ Reference<PBXReference>(allObjects: allObjects, id: $0.id) }))
    }
    
}

public extension PBXTarget {
    
    func buildPhase<T : PBXBuildPhase>(of type : T.Type) -> T {
        return buildPhases.first(where: { $0.value is T })?.value as? T ??
               addBuildPhase(type: T.self)
    }
    
    func addBuildPhase<T : PBXBuildPhase>(type : T.Type) -> T {
        let phase = type.init(emptyObjectWithId: Guid.random, allObjects: allObjects)
        let reference = allObjects.createReference(value: phase) as Reference<PBXBuildPhase>
        buildPhases.append(reference)
        return phase
    }
    
    /// Only used for singular setting
    /// Does not guarantee anything
    func setBuildSetting(key: String, value : Any) {
        for ref in buildConfigurationList.value?.buildConfigurations ?? [] {
            ref.value?.buildSettings[key] = value
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
