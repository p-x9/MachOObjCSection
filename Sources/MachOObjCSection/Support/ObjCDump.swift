//
//  ObjCDump.swift
//
//
//  Created by p-x9 on 2024/09/28
//
//

import Foundation
import MachOKit
import ObjCDump

/// Options that control how Objective-C class and category metadata is converted.
public struct ObjCInfoOptions: Sendable {
    /// Options used when converting protocols referenced by classes and categories.
    public var protocolInfoOptions: ObjCProtocolInfoOptions

    /// Creates options for Objective-C class and category metadata conversion.
    ///
    /// - Parameter protocolInfoOptions: Options used for protocols referenced from
    ///   a class or category protocol list.
    public init(
        protocolInfoOptions: ObjCProtocolInfoOptions = .recursive
    ) {
        self.protocolInfoOptions = protocolInfoOptions
    }

    /// Preserves the default behavior and expands referenced protocols recursively.
    public static let recursive = ObjCInfoOptions()

    /// Uses the protocol detail level needed for Objective-C header dumps.
    ///
    /// Header declarations need the names of directly adopted protocols, but they
    /// do not need to recursively materialize those protocols' members.
    public static let headerDump = ObjCInfoOptions(
        protocolInfoOptions: .directProtocolNames
    )
}

/// Options that control how Objective-C protocol metadata is converted.
public struct ObjCProtocolInfoOptions: Sendable {
    /// Controls how far referenced protocols are followed.
    public enum Traversal: Sendable {
        /// Expands referenced protocols recursively.
        case recursive

        /// Expands referenced protocols up to the specified number of reference edges.
        ///
        /// A depth of `0` does not include referenced protocols. A depth of `1`
        /// includes only directly referenced protocols.
        case depth(Int)
    }

    /// Controls how much information is materialized for referenced protocols.
    public enum ReferencedProtocolInfo: Sendable {
        /// Materializes full protocol information, including members and references.
        case full

        /// Materializes only the protocol name.
        case nameOnly
    }

    /// The traversal strategy used for protocols referenced by the current protocol.
    public var traversal: Traversal

    /// The amount of information to materialize for each referenced protocol.
    public var referencedProtocolInfo: ReferencedProtocolInfo

    /// Creates options for Objective-C protocol metadata conversion.
    ///
    /// - Parameters:
    ///   - traversal: How far referenced protocols should be followed.
    ///   - referencedProtocolInfo: How much information should be materialized for
    ///     each referenced protocol that is included by `traversal`.
    public init(
        traversal: Traversal = .recursive,
        referencedProtocolInfo: ReferencedProtocolInfo = .full
    ) {
        self.traversal = traversal
        self.referencedProtocolInfo = referencedProtocolInfo
    }

    /// Preserves the default behavior and expands referenced protocols recursively.
    public static let recursive = ObjCProtocolInfoOptions()

    /// Includes direct protocol references as name-only protocol information.
    ///
    /// For a protocol, this keeps the protocol's own members but represents directly
    /// referenced protocols by name only. For a class or category, pass this value
    /// to ``ObjCInfoOptions/init(protocolInfoOptions:)`` to apply the same policy
    /// to adopted protocols.
    public static let directProtocolNames = ObjCProtocolInfoOptions(
        traversal: .depth(1),
        referencedProtocolInfo: .nameOnly
    )
}

extension ObjCProtocolInfoOptions {
    fileprivate func nextForReferencedProtocol() -> ObjCProtocolInfoOptions? {
        switch traversal {
        case .recursive:
            return self
        case let .depth(depth):
            guard depth > 0 else { return nil }
            var next = self
            next.traversal = .depth(depth - 1)
            return next
        }
    }
}

// MARK: - IVar
extension ObjCIvarProtocol {
    public func info(in machO: MachOFile) -> ObjCIvarInfo? {
        guard let name = name(in: machO),
              let type = type(in: machO),
              let offset = offset(in: machO) else {
            return nil
        }
        return .init(
            name: name,
            typeEncoding: type,
            offset: numericCast(offset)
        )
    }

    public func info(in machO: MachOImage) -> ObjCIvarInfo? {
        let name = name(in: machO)
        guard let type = type(in: machO),
              let offset = offset(in: machO) else {
            return nil
        }
        return .init(
            name: name,
            typeEncoding: type,
            offset: numericCast(offset)
        )
    }
}

// MARK: - Property
extension ObjCProperty {
    public func info(
        isClassProperty: Bool = false
    ) -> ObjCPropertyInfo {
       .init(
            name: name,
            attributes: attributes,
            isClassProperty: isClassProperty
        )
    }
}

// MARK: - Method
extension ObjCMethod {
    public func info(
        isClassMethod: Bool = false
    ) -> ObjCMethodInfo {
        .init(
            name: name,
            typeEncoding: types,
            isClassMethod: isClassMethod
        )
    }
}

// MARK: - Protocol
extension ObjCProtocolProtocol {
    public func info(
        in machO: MachOFile,
        options: ObjCProtocolInfoOptions = .recursive
    ) -> ObjCProtocolInfo? {
        let name = mangledName(in: machO)

        let protocols = referencedProtocolInfos(in: machO, options: options)

        let classPropertiesList = classPropertyList(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let propertiesList = instancePropertyList(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let classMethodsList = classMethodList(in: machO)
        let classMethods = classMethodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let methodsList = instanceMethodList(in: machO)
        let methods = methodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: false) } ?? []

        let optionalClassMethodsList = optionalClassMethodList(in: machO)
        let optionalClassMethods = optionalClassMethodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let optionalMethodsList = optionalInstanceMethodList(in: machO)
        let optionalMethods = optionalMethodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Note:
        // `Objective-C` protocol does not currently support optional properties
        // https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.mm#L5255

        return .init(
            name: name,
            protocols: protocols,
            classProperties: classProperties,
            properties: properties,
            classMethods: classMethods,
            methods: methods,
            optionalClassProperties: [],
            optionalProperties: [],
            optionalClassMethods: optionalClassMethods,
            optionalMethods: optionalMethods
        )
    }

    public func info(
        in machO: MachOImage,
        options: ObjCProtocolInfoOptions = .recursive
    ) -> ObjCProtocolInfo? {
        let name = mangledName(in: machO)

        let protocols = referencedProtocolInfos(in: machO, options: options)

        let classPropertiesList = classPropertyList(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let propertiesList = instancePropertyList(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let classMethodsList = classMethodList(in: machO)
        let classMethods = classMethodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let methodsList = instanceMethodList(in: machO)
        let methods = methodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: false) } ?? []

        let optionalClassMethodsList = optionalClassMethodList(in: machO)
        let optionalClassMethods = optionalClassMethodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let optionalMethodsList = optionalInstanceMethodList(in: machO)
        let optionalMethods = optionalMethodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Note:
        // `Objective-C` protocol does not currently support optional properties
        // https://github.com/apple-oss-distributions/objc4/blob/01edf1705fbc3ff78a423cd21e03dfc21eb4d780/runtime/objc-runtime-new.mm#L5255

        return .init(
            name: name,
            protocols: protocols,
            classProperties: classProperties,
            properties: properties,
            classMethods: classMethods,
            methods: methods,
            optionalClassMethods: optionalClassMethods,
            optionalMethods: optionalMethods
        )
    }
}

extension ObjCProtocolProtocol {
    fileprivate func shallowInfo(in machO: MachOFile) -> ObjCProtocolInfo {
        .init(
            name: mangledName(in: machO),
            protocols: [],
            classProperties: [],
            properties: [],
            classMethods: [],
            methods: [],
            optionalClassProperties: [],
            optionalProperties: [],
            optionalClassMethods: [],
            optionalMethods: []
        )
    }

    fileprivate func shallowInfo(in machO: MachOImage) -> ObjCProtocolInfo {
        .init(
            name: mangledName(in: machO),
            protocols: [],
            classProperties: [],
            properties: [],
            classMethods: [],
            methods: [],
            optionalClassMethods: [],
            optionalMethods: []
        )
    }

    fileprivate func referenceInfo(
        in machO: MachOFile,
        options: ObjCProtocolInfoOptions
    ) -> ObjCProtocolInfo? {
        switch options.referencedProtocolInfo {
        case .full:
            return info(in: machO, options: options)
        case .nameOnly:
            return shallowInfo(in: machO)
        }
    }

    fileprivate func referenceInfo(
        in machO: MachOImage,
        options: ObjCProtocolInfoOptions
    ) -> ObjCProtocolInfo? {
        switch options.referencedProtocolInfo {
        case .full:
            return info(in: machO, options: options)
        case .nameOnly:
            return shallowInfo(in: machO)
        }
    }

    fileprivate func referencedProtocolInfos(
        in machO: MachOFile,
        options: ObjCProtocolInfoOptions
    ) -> [ObjCProtocolInfo] {
        guard let nextOptions = options.nextForReferencedProtocol() else {
            return []
        }
        return protocolList(in: machO)?
            .protocolInfos(in: machO, options: nextOptions) ?? []
    }

    fileprivate func referencedProtocolInfos(
        in machO: MachOImage,
        options: ObjCProtocolInfoOptions
    ) -> [ObjCProtocolInfo] {
        guard let nextOptions = options.nextForReferencedProtocol() else {
            return []
        }
        return protocolList(in: machO)?
            .protocolInfos(in: machO, options: nextOptions) ?? []
    }
}

extension ObjCProtocolListProtocol {
    fileprivate func referencedProtocolInfos(
        in machO: MachOFile,
        options: ObjCProtocolInfoOptions
    ) -> [ObjCProtocolInfo] {
        guard let nextOptions = options.nextForReferencedProtocol() else {
            return []
        }
        return protocolInfos(in: machO, options: nextOptions)
    }

    fileprivate func referencedProtocolInfos(
        in machO: MachOImage,
        options: ObjCProtocolInfoOptions
    ) -> [ObjCProtocolInfo] {
        guard let nextOptions = options.nextForReferencedProtocol() else {
            return []
        }
        return protocolInfos(in: machO, options: nextOptions)
    }

    fileprivate func protocolInfos(
        in machO: MachOFile,
        options: ObjCProtocolInfoOptions
    ) -> [ObjCProtocolInfo] {
        protocols(in: machO)?
            .compactMap { $1.referenceInfo(in: $0, options: options) } ?? []
    }

    fileprivate func protocolInfos(
        in machO: MachOImage,
        options: ObjCProtocolInfoOptions
    ) -> [ObjCProtocolInfo] {
        protocols(in: machO)?
            .compactMap { $1.referenceInfo(in: $0, options: options) } ?? []
    }
}

// MARK: - Class
extension ObjCClassProtocol {
    public func info(
        in machO: MachOFile,
        options: ObjCInfoOptions = .recursive
    ) -> ObjCClassInfo? {
        guard let data = classROData(in: machO),
              let (targetMachO, meta) = metaClass(in: machO),
              let metaData = meta.classROData(in: targetMachO),
              let name = data.name(in: machO) else {
            return nil
        }
        let imagePath = machO.imagePath

        // Cache `objcImageIndex` lookups so a class with multiple relative
        // list lists (protocol + property + method) only pays the dyld cache
        // header walk once. Classes with no relative list list never enter
        // these closures, so the lookup is skipped entirely.
        var _imageIndex: Int??
        var _targetMachOImageIndex: Int??
        func imageIndex() -> Int? {
            if let v = _imageIndex { return v }
            let v = machO.objcImageIndex
            _imageIndex = .some(v)
            return v
        }
        func targetMachOImageIndex() -> Int? {
            if let v = _targetMachOImageIndex { return v }
            let v = targetMachO.objcImageIndex
            _targetMachOImageIndex = .some(v)
            return v
        }

        let protocols = data
            .resolvedProtocolList(in: machO, imageIndex: imageIndex())
            .map { (m, list) in
                list.referencedProtocolInfos(
                    in: m,
                    options: options.protocolInfoOptions
                )
            } ?? []

        let ivarList = data.ivarList(in: machO)
        let ivars = ivarList?
            .ivars(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let properties = data
            .resolvedPropertyList(in: machO, imageIndex: imageIndex())
            .map { (m, list) in list.properties(in: m) }?
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let methods = data
            .resolvedMethodList(in: machO, imageIndex: imageIndex())
            .flatMap { (m, list) in list.methods(in: m) }?
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Meta
        let classProperties = metaData
            .resolvedPropertyList(in: targetMachO, imageIndex: targetMachOImageIndex())
            .map { (m, list) in list.properties(in: m) }?
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let classMethods = metaData
            .resolvedMethodList(in: targetMachO, imageIndex: targetMachOImageIndex())
            .flatMap { (m, list) in list.methods(in: m) }?
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let superClassName = superClassName(in: machO)

        return .init(
            name: name,
            version: version(for: data),
            imageName: imagePath,
            instanceSize: numericCast(data.instanceSize),
            superClassName: superClassName,
            protocols: protocols,
            ivars: ivars,
            classProperties: classProperties,
            properties: properties,
            classMethods: classMethods,
            methods: methods
        )
    }

    public func info(
        in machO: MachOImage,
        options: ObjCInfoOptions = .recursive
    ) -> ObjCClassInfo? {
        guard let (targetMachO, meta) = metaClass(in: machO) else {
            return nil
        }

        let data: ClassROData
        let metaData: ClassROData

        if let _data = classROData(in: machO) {
            data = _data
        } else if let rw = classRWData(in: machO) {
            if let _data = rw.classROData(in: machO) {
                data = _data
            } else if let ext = rw.ext(in: machO),
                      let _data = ext.classROData(in: machO) {
                data = _data
            } else {
                return nil
            }
        } else {
            return nil
        }

        if let _data = meta.classROData(in: targetMachO) {
            metaData = _data
        } else if let rw = meta.classRWData(in: targetMachO) {
            if let _data = rw.classROData(in: targetMachO) {
                metaData = _data
            } else if let ext = rw.ext(in: targetMachO),
                      let _data = ext.classROData(in: targetMachO) {
                metaData = _data
            } else {
                return nil
            }
        } else {
            return nil
        }

        guard let name = data.name(in: machO) else {
            return nil
        }

        // See `info(in: MachOFile)` for why these are cached locally.
        var _imageIndex: Int??
        var _targetMachOImageIndex: Int??
        func imageIndex() -> Int? {
            if let v = _imageIndex { return v }
            let v = machO.objcImageIndex
            _imageIndex = .some(v)
            return v
        }
        func targetMachOImageIndex() -> Int? {
            if let v = _targetMachOImageIndex { return v }
            let v = targetMachO.objcImageIndex
            _targetMachOImageIndex = .some(v)
            return v
        }

        let protocols = data
            .resolvedProtocolList(in: machO, imageIndex: imageIndex())
            .map { (m, list) in
                list.referencedProtocolInfos(
                    in: m,
                    options: options.protocolInfoOptions
                )
            } ?? []

        let ivarList = data.ivarList(in: machO)
        let ivars = ivarList?
            .ivars(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let properties = data
            .resolvedPropertyList(in: machO, imageIndex: imageIndex())
            .map { (m, list) in list.properties(in: m) }?
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let methods = data
            .resolvedMethodList(in: machO, imageIndex: imageIndex())
            .map { (m, list) in list.methods(in: m) }?
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Meta
        let classProperties = metaData
            .resolvedPropertyList(in: targetMachO, imageIndex: targetMachOImageIndex())
            .map { (m, list) in list.properties(in: m) }?
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let classMethods = metaData
            .resolvedMethodList(in: targetMachO, imageIndex: targetMachOImageIndex())
            .map { (m, list) in list.methods(in: m) }?
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let superClassName = superClassName(in: machO)

        return .init(
            name: name,
            version: version(in: machO),
            imageName: machO.path,
            instanceSize: numericCast(data.layout.instanceSize),
            superClassName: superClassName,
            protocols: protocols,
            ivars: ivars,
            classProperties: classProperties,
            properties: properties,
            classMethods: classMethods,
            methods: methods
        )
    }
}

// MARK: Category
extension ObjCCategoryProtocol {
    public func info(
        in machO: MachOImage,
        options: ObjCInfoOptions = .recursive
    ) -> ObjCCategoryInfo? {
        guard let name = name(in: machO),
              let className = className(in: machO) else {
            return nil
        }

        let protocols = protocolList(in: machO)?
            .referencedProtocolInfos(
                in: machO,
                options: options.protocolInfoOptions
            ) ?? []

        // Instance
        let propertiesList = instancePropertyList(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let methodsList = instanceMethodList(in: machO)
        let methods = methodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Meta
        let classPropertiesList = classPropertyList(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let classMethodsList = classMethodList(in: machO)
        let classMethods = classMethodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: true) } ?? []

        return .init(
            name: name,
            className: className,
            protocols: protocols,
            classProperties: classProperties,
            properties: properties,
            classMethods: classMethods,
            methods: methods
        )
    }

    public func info(
        in machO: MachOFile,
        options: ObjCInfoOptions = .recursive
    ) -> ObjCCategoryInfo? {
        guard let name = name(in: machO),
              let className = className(in: machO) else {
            return nil
        }

        let protocols = protocolList(in: machO)?
            .referencedProtocolInfos(
                in: machO,
                options: options.protocolInfoOptions
            ) ?? []

        // Instance
        let propertiesList = instancePropertyList(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let methodsList = instanceMethodList(in: machO)
        let methods = methodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Meta
        let classPropertiesList = classPropertyList(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let classMethodsList = classMethodList(in: machO)
        let classMethods = classMethodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: true) } ?? []

        return .init(
            name: name,
            className: className,
            protocols: protocols,
            classProperties: classProperties,
            properties: properties,
            classMethods: classMethods,
            methods: methods
        )
    }
}

// MARK: - Relative list resolution

// Note:
// When a relative list list exists for a given list kind, the corresponding
// regular list is guaranteed to be nil. The helpers below therefore consult
// the relative list list first and only fall back to the regular list when
// no relative list list is present.
fileprivate extension ObjCClassRODataProtocol {
    func resolvedMethodList(
        in machO: MachOFile,
        imageIndex: @autoclosure () -> Int?
    ) -> (MachOFile, ObjCMethodList)? {
        if let relative = methodRelativeListList(in: machO),
           let resolved = relative.list(in: machO, forImageIndex: imageIndex()) {
            return resolved
        }
        return methodList(in: machO).map { (machO, $0) }
    }

    func resolvedPropertyList(
        in machO: MachOFile,
        imageIndex: @autoclosure () -> Int?
    ) -> (MachOFile, ObjCPropertyList)? {
        if let relative = propertyRelativeListList(in: machO),
           let resolved = relative.list(in: machO, forImageIndex: imageIndex()) {
            return resolved
        }
        return propertyList(in: machO).map { (machO, $0) }
    }

    func resolvedProtocolList(
        in machO: MachOFile,
        imageIndex: @autoclosure () -> Int?
    ) -> (MachOFile, ObjCProtocolList)? {
        if let relative = protocolRelativeListList(in: machO),
           let resolved = relative.list(in: machO, forImageIndex: imageIndex()) {
            return resolved
        }
        return protocolList(in: machO).map { (machO, $0) }
    }

    func resolvedMethodList(
        in machO: MachOImage,
        imageIndex: @autoclosure () -> Int?
    ) -> (MachOImage, ObjCMethodList)? {
        if let relative = methodRelativeListList(in: machO),
           let resolved = relative.list(in: machO, forImageIndex: imageIndex()) {
            return resolved
        }
        return methodList(in: machO).map { (machO, $0) }
    }

    func resolvedPropertyList(
        in machO: MachOImage,
        imageIndex: @autoclosure () -> Int?
    ) -> (MachOImage, ObjCPropertyList)? {
        if let relative = propertyRelativeListList(in: machO),
           let resolved = relative.list(in: machO, forImageIndex: imageIndex()) {
            return resolved
        }
        return propertyList(in: machO).map { (machO, $0) }
    }

    func resolvedProtocolList(
        in machO: MachOImage,
        imageIndex: @autoclosure () -> Int?
    ) -> (MachOImage, ObjCProtocolList)? {
        if let relative = protocolRelativeListList(in: machO),
           let resolved = relative.list(in: machO, forImageIndex: imageIndex()) {
            return resolved
        }
        return protocolList(in: machO).map { (machO, $0) }
    }
}
