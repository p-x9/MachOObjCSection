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

extension MachOFile {
    // WORKAROUND: Due to a bug in MachOKit, the imagePath of a machO obtained from ObjCHeaderInfoRO may sometimes be an empty string.
    fileprivate var imagePath: String {
        loadCommands.info(of: LoadCommand.idDylib)?
            .dylib(in: self)
            .name ?? ""
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
    public func info(in machO: MachOFile) -> ObjCProtocolInfo? {
        let name = mangledName(in: machO)

        let protocolList = protocolList(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $1.info(in: $0) } ?? []

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

    public func info(in machO: MachOImage) -> ObjCProtocolInfo? {
        let name = mangledName(in: machO)

        let protocolList = protocolList(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $1.info(in: $0) } ?? []

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

// MARK: - Class
extension ObjCClassProtocol {
    public func info(in machO: MachOFile) -> ObjCClassInfo? {
        guard let data = classROData(in: machO),
              let (targetMachO, meta) = metaClass(in: machO),
              let metaData = meta.classROData(in: targetMachO),
              let name = data.name(in: machO) else {
            return nil
        }
        let imagePath = machO.imagePath

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

        let protocolList = data.protocolList(in: machO)
        var protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $1.info(in: $0) } ?? []
        if let relative = data.protocolRelativeListList(in: machO) {
            let entries = relative.entries(in: machO)
            let idx = imageIndex()
            if let entry = entries.first(where: { $0.imageIndex == idx }),
               let (machO, list) = relative.list(in: machO, for: entry) {
                protocols = list.protocols(in: machO)?
                    .compactMap { $1.info(in: $0) } ?? []
            }
        }

        let ivarList = data.ivarList(in: machO)
        let ivars = ivarList?
            .ivars(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let propertiesList = data.propertyList(in: machO)
        var properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []
        if let relative = data.propertyRelativeListList(in: machO) {
            let entries = relative.entries(in: machO)
            let idx = imageIndex()
            if let entry = entries.first(where: { $0.imageIndex == idx }),
               let (machO, list) = relative.list(in: machO, for: entry) {
                properties = list.properties(in: machO)
                    .compactMap { $0.info(isClassProperty: false) }
            }
        }

        let methodsList = data.methodList(in: machO)
        var methods = methodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: false) } ?? []
        if let relative = data.methodRelativeListList(in: machO) {
            let entries = relative.entries(in: machO)
            let idx = imageIndex()
            if let entry = entries.first(where: { $0.imageIndex == idx }),
               let (machO, list) = relative.list(in: machO, for: entry) {
                methods = list.methods(in: machO)?
                    .compactMap { $0.info(isClassMethod: false) } ?? []
            }
        }

        // Meta
        let classPropertiesList = metaData.propertyList(in: targetMachO)
        var classProperties = classPropertiesList?
            .properties(in: targetMachO)
            .compactMap { $0.info(isClassProperty: true) } ?? []
        if let relative = metaData.propertyRelativeListList(in: targetMachO) {
            let entries = relative.entries(in: targetMachO)
            let idx = targetMachOImageIndex()
            if let entry = entries.first(where: { $0.imageIndex == idx }),
               let (machO, list) = relative.list(in: targetMachO, for: entry) {
                classProperties = list.properties(in: machO)
                    .compactMap { $0.info(isClassProperty: false) }
            }
        }

        let classMethodsList = metaData.methodList(in: targetMachO)
        var classMethods = classMethodsList?
            .methods(in: targetMachO)?
            .compactMap { $0.info(isClassMethod: true) } ?? []
        if let relative = metaData.methodRelativeListList(in: targetMachO) {
            let entries = relative.entries(in: targetMachO)
            let idx = targetMachOImageIndex()
            if let entry = entries.first(where: { $0.imageIndex == idx }),
               let (machO, list) = relative.list(in: targetMachO, for: entry) {
                classMethods = list.methods(in: machO)?
                    .compactMap { $0.info(isClassMethod: false) } ?? []
            }
        }

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

    public func info(in machO: MachOImage) -> ObjCClassInfo? {
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

        let protocolList = data.protocolList(in: machO)
        var protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $1.info(in: $0) } ?? []
        if let relative = data.protocolRelativeListList(in: machO) {
            protocols = relative.lists(in: machO)
                .filter({ $0.0.ptr == machO.ptr })
                .flatMap { machO, list in
                    list.protocols(in: machO)?
                        .compactMap { $1.info(in: $0) } ?? []
                }
        }

        let ivarList = data.ivarList(in: machO)
        let ivars = ivarList?
            .ivars(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let propertiesList = data.propertyList(in: machO)
        var properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []
        if let relative = data.propertyRelativeListList(in: machO) {
            properties = relative.lists(in: machO)
                .filter({ $0.0.ptr == machO.ptr })
                .flatMap { machO, list in
                    list.properties(in: machO)
                        .compactMap { $0.info(isClassProperty: false) }
                }
        }

        let methodsList = data.methodList(in: machO)
        var methods = methodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: false) } ?? []
        if let relative = data.methodRelativeListList(in: machO) {
            methods = relative.lists(in: machO)
                .filter({ $0.0.ptr == machO.ptr })
                .flatMap { machO, list in
                    list.methods(in: machO)
                        .compactMap { $0.info(isClassMethod: false) }
                }
        }

        // Meta
        let classPropertiesList = metaData.propertyList(in: targetMachO)
        var classProperties = classPropertiesList?
            .properties(in: targetMachO)
            .compactMap { $0.info(isClassProperty: true) } ?? []
        if let relative = metaData.propertyRelativeListList(in: targetMachO) {
            classProperties = relative.lists(in: targetMachO)
                .filter { $0.0.ptr == targetMachO.ptr }
                .flatMap { machO, list in
                    list.properties(in: machO)
                        .compactMap { $0.info(isClassProperty: true) }
                }
        }

        let classMethodsList = metaData.methodList(in: targetMachO)
        var classMethods = classMethodsList?
            .methods(in: targetMachO)
            .compactMap { $0.info(isClassMethod: true) } ?? []
        if let relative = metaData.methodRelativeListList(in: targetMachO) {
            classMethods = relative.lists(in: targetMachO)
                .filter({ $0.0.ptr == targetMachO.ptr })
                .flatMap { machO, list in
                    list.methods(in: machO)
                        .compactMap { $0.info(isClassMethod: true) }
                }
        }

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
    public func info(in machO: MachOImage) -> ObjCCategoryInfo? {
        guard let name = name(in: machO),
              let className = className(in: machO) else {
            return nil
        }

        let protocolList = protocolList(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $1.info(in: $0) } ?? []

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

    public func info(in machO: MachOFile) -> ObjCCategoryInfo? {
        guard let name = name(in: machO),
              let className = className(in: machO) else {
            return nil
        }

        let protocolList = protocolList(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $1.info(in: $0) } ?? []

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
