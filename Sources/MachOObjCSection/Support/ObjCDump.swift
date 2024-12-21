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
        let type = type(in: machO)
        guard let offset = offset(in: machO) else {
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

        let protocolList = protocols(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        let classPropertiesList = classProperties(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let propertiesList = instanceProperties(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let classMethodsList = classMethods(in: machO)
        let classMethods = classMethodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let methodsList = instanceMethods(in: machO)
        let methods = methodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: false) } ?? []

        let optionalClassMethodsList = optionalClassMethods(in: machO)
        let optionalClassMethods = optionalClassMethodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let optionalMethodsList = optionalInstanceMethods(in: machO)
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

        let protocolList = protocols(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        let classPropertiesList = classProperties(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let propertiesList = instanceProperties(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let classMethodsList = classMethods(in: machO)
        let classMethods = classMethodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let methodsList = instanceMethods(in: machO)
        let methods = methodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: false) } ?? []

        let optionalClassMethodsList = optionalClassMethods(in: machO)
        let optionalClassMethods = optionalClassMethodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: true) } ?? []

        let optionalMethodsList = optionalInstanceMethods(in: machO)
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
              let meta = metaClass(in: machO),
              let metaData = meta.classROData(in: machO),
              let name = data.name(in: machO) else {
            return nil
        }
        let protocolList = data.protocols(in: machO)
        var protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []
        if let relative = data.protocolRelativeListList(in: machO) {
            protocols = relative.lists(in: machO)
                .filter({ $0.0.imagePath == machO.imagePath })
                .flatMap { machO, list in
                    list.protocols(in: machO)?
                        .compactMap { $0.info(in: machO) } ?? []
                }
        }

        let ivarList = data.ivars(in: machO)
        let ivars = ivarList?
            .ivars(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let propertiesList = data.properties(in: machO)
        var properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []
        if let relative = data.propertyRelativeListList(in: machO) {
            properties = relative.lists(in: machO)
                .filter({ $0.0.imagePath == machO.imagePath })
                .flatMap { machO, list in
                    list.properties(in: machO)
                        .compactMap { $0.info(isClassProperty: false) }
                }
        }

        let methodsList = data.methods(in: machO)
        var methods = methodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: false) } ?? []
        if let relative = data.methodRelativeListList(in: machO) {
            methods = relative.lists(in: machO)
                .filter({ $0.0.imagePath == machO.imagePath })
                .flatMap { machO, list in
                    list.methods(in: machO)?
                        .compactMap { $0.info(isClassMethod: false) } ?? []
                }
        }

        // Meta
        let classPropertiesList = metaData.properties(in: machO)
        var classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []
        if let relative = metaData.propertyRelativeListList(in: machO) {
            classProperties = relative.lists(in: machO)
                .filter { $0.0.imagePath == machO.imagePath }
                .flatMap { machO, list in
                    list.properties(in: machO)
                        .compactMap { $0.info(isClassProperty: true) }
                }
        }

        let classMethodsList = metaData.methods(in: machO)
        var classMethods = classMethodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: true) } ?? []
        if let relative = metaData.methodRelativeListList(in: machO) {
            classMethods = relative.lists(in: machO)
                .filter({ $0.0.imagePath == machO.imagePath })
                .flatMap { machO, list in
                    list.methods(in: machO)?
                        .compactMap { $0.info(isClassMethod: true) } ?? []
                }
        }

        let superClassName = superClassName(in: machO)

        return .init(
            name: name,
            version: version(in: machO),
            imageName: machO.imagePath,
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
        guard let meta = metaClass(in: machO) else {
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

        if let _data = meta.classROData(in: machO) {
            metaData = _data
        } else if let rw = meta.classRWData(in: machO) {
            if let _data = rw.classROData(in: machO) {
                metaData = _data
            } else if let ext = rw.ext(in: machO),
                      let _data = ext.classROData(in: machO) {
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

        let protocolList = data.protocols(in: machO)
        var protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []
        if let relative = data.protocolRelativeListList(in: machO) {
            protocols = relative.lists(in: machO)
                .filter({ $0.0.path == machO.path })
                .flatMap { machO, list in
                    list.protocols(in: machO)?
                        .compactMap { $0.info(in: machO) } ?? []
                }
        }

        let ivarList = data.ivars(in: machO)
        let ivars = ivarList?
            .ivars(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let propertiesList = data.properties(in: machO)
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

        let methodsList = data.methods(in: machO)
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
        let classPropertiesList = metaData.properties(in: machO)
        var classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []
        if let relative = metaData.propertyRelativeListList(in: machO) {
            classProperties = relative.lists(in: machO)
                .filter { $0.0.ptr == machO.ptr }
                .flatMap { machO, list in
                    list.properties(in: machO)
                        .compactMap { $0.info(isClassProperty: true) }
                }
        }

        let classMethodsList = metaData.methods(in: machO)
        var classMethods = classMethodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: true) } ?? []
        if let relative = metaData.methodRelativeListList(in: machO) {
            classMethods = relative.lists(in: machO)
                .filter({ $0.0.ptr == machO.ptr })
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

        let protocolList = protocols(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let propertiesList = instanceProperties(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let methodsList = instanceMethods(in: machO)
        let methods = methodsList?
            .methods(in: machO)
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Meta
        let classPropertiesList = classProperties(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let classMethodsList = classMethods(in: machO)
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

        let protocolList = protocols(in: machO)
        let protocols = protocolList?
            .protocols(in: machO)?
            .compactMap { $0.info(in: machO) } ?? []

        // Instance
        let propertiesList = instanceProperties(in: machO)
        let properties = propertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: false) } ?? []

        let methodsList = instanceMethods(in: machO)
        let methods = methodsList?
            .methods(in: machO)?
            .compactMap { $0.info(isClassMethod: false) } ?? []

        // Meta
        let classPropertiesList = classProperties(in: machO)
        let classProperties = classPropertiesList?
            .properties(in: machO)
            .compactMap { $0.info(isClassProperty: true) } ?? []

        let classMethodsList = classMethods(in: machO)
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
