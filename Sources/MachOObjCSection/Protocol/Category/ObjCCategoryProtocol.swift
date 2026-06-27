//
//  ObjCCategoryProtocol.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/12/06
//
//

import Foundation
@_spi(Support) import MachOKit

public protocol ObjCCategoryProtocol: _FixupResolvable
where LayoutField == ObjCCategoryLayoutField,
      Layout: _ObjCCategoryLayoutProtocol
{
    associatedtype ObjCClass: ObjCClassProtocol
    associatedtype ObjCStubClass: ObjCStubClassProtocol
    typealias ObjCProtocolList = ObjCClass.ClassROData.ObjCProtocolList

    // var layout: Layout { get }
    var offset: Int { get }

    var isCatlist2: Bool { get }

    @_spi(Core)
    init(layout: Layout, offset: Int, isCatlist2: Bool)

    func name(in machO: MachOFile) -> String?
    func `class`(in machO: MachOFile) -> (MachOFile, ObjCClass)?
    func stubClass(in machO: MachOFile) -> (MachOFile, ObjCStubClass)?
    func className(in machO: MachOFile) -> String?
    func instanceMethodList(in machO: MachOFile) -> ObjCMethodList?
    func classMethodList(in machO: MachOFile) -> ObjCMethodList?
    func instancePropertyList(in machO: MachOFile) -> ObjCPropertyList?
    func classPropertyList(in machO: MachOFile) -> ObjCPropertyList?
    func protocolList(in machO: MachOFile) -> ObjCProtocolList?

    func name(in machO: MachOImage) -> String?
    func `class`(in machO: MachOImage) -> (MachOImage, ObjCClass)?
    func stubClass(in machO: MachOImage) -> (MachOImage, ObjCStubClass)?
    func className(in machO: MachOImage) -> String?
    func instanceMethodList(in machO: MachOImage) -> ObjCMethodList?
    func classMethodList(in machO: MachOImage) -> ObjCMethodList?
    func instancePropertyList(in machO: MachOImage) -> ObjCPropertyList?
    func classPropertyList(in machO: MachOImage) -> ObjCPropertyList?
    func protocolList(in machO: MachOImage) -> ObjCProtocolList?
}

extension ObjCCategoryProtocol {
    public func name(in machO: MachOFile) -> String? {
        let unresolved = unresolvedValue(of: .name)
        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        return fileHandle.readString(
            offset: fileOffset
        )
    }

    public func `class`(in machO: MachOFile) -> (MachOFile, ObjCClass)? {
        guard let (machO, cls) = _readClass(
            field: .cls,
            in: machO
        ) else { return nil }

        if cls.isStubClass { return nil }

        return (machO, cls)
    }

    public func stubClass(in machO: MachOFile) -> (MachOFile, ObjCStubClass)? {
        guard let (machO, cls) = _readStubClass(
            field: .cls,
            in: machO
        ) else { return nil }

        guard cls.isStubClass else { return nil }

        return (machO, cls)
    }

    public func className(in machO: MachOFile) -> String? {
        if let name = _readClassName(
            field: .cls,
            in: machO
        ) {
            return name
        }

        var offset = offset
        if let cache = machO.cache {
            offset += numericCast(
                cache.mainCacheHeader.sharedRegionStart
            )
        }

        if let section = machO.sectionNumber(for: .__objc_const),
           let symbol = machO.symbol(for: offset, inSection: section),
           symbol.name.starts(with: "__CATEGORY_"){
            let className = symbol.name
                .replacingOccurrences(of: "__CATEGORY_", with: "")
                .components(separatedBy: "_$_")
                .first
            return className
        }

        return nil
    }

    public func instanceMethodList(in machO: MachOFile) -> ObjCMethodList? {
        _readMethodList(
            field: .instanceMethods,
            in: machO
        )
    }

    public func classMethodList(in machO: MachOFile) -> ObjCMethodList? {
        _readMethodList(
            field: .classMethods,
            in: machO
        )
    }

    public func instancePropertyList(in machO: MachOFile) -> ObjCPropertyList? {
        _readPropertyList(
            field: .instanceProperties,
            in: machO
        )
    }

    public func classPropertyList(in machO: MachOFile) -> ObjCPropertyList? {
        _readPropertyList(
            field: ._classProperties,
            in: machO
        )
    }

    public func protocolList(in machO: MachOFile) -> ObjCProtocolList? {
        _readProtocolList(
            field: .protocols,
            in: machO
        )
    }
}

extension ObjCCategoryProtocol {
    public func name(in machO: MachOImage) -> String? {
        guard layout.name > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.name)) else {
            return nil
        }
        return .init(
            cString: ptr.assumingMemoryBound(to: CChar.self),
            encoding: .utf8
        )
    }

    public func `class`(in machO: MachOImage) -> (MachOImage, ObjCClass)? {
        guard layout.cls > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.cls)) else {
            return nil
        }

        var targetMachO = machO
        if !targetMachO.contains(ptr: ptr) {
            guard let cache = DyldCacheLoaded.current,
                  let _targetMachO = cache.machO(containing: ptr) else {
                return nil
            }
            targetMachO = _targetMachO
        }

        let offset: Int = numericCast(layout.cls) - Int(bitPattern: targetMachO.ptr)

        let layout = ptr.assumingMemoryBound(to: ObjCClass.Layout.self).pointee
        let cls: ObjCClass = .init(layout: layout, offset: offset)

        if cls.isStubClass { return nil }

        return (targetMachO, cls)
    }

    public func stubClass(in machO: MachOImage) -> (MachOImage, ObjCStubClass)? {
        guard layout.cls > 0 else { return nil }
        guard let ptr = UnsafeRawPointer(bitPattern: UInt(layout.cls)) else {
            return nil
        }

        var targetMachO = machO
        if !targetMachO.contains(ptr: ptr) {
            guard let cache = DyldCacheLoaded.current,
                  let _targetMachO = cache.machO(containing: ptr) else {
                return nil
            }
            targetMachO = _targetMachO
        }

        let offset: Int = numericCast(layout.cls) - Int(bitPattern: targetMachO.ptr)

        let layout = ptr.assumingMemoryBound(to: ObjCStubClass.Layout.self).pointee
        let cls: ObjCStubClass = .init(layout: layout, offset: offset)

        guard cls.isStubClass else { return nil }

        return (targetMachO, cls)
    }

    public func className(in machO: MachOImage) -> String? {
        guard let (machO, cls) = `class`(in: machO) else {
            if let section = machO.sectionNumber(for: .__objc_const),
               let symbol = machO.symbol(
                for: offset, inSection: section
               ),
               symbol.name.starts(with: "__CATEGORY_") {
                let className = symbol.name
                    .replacingOccurrences(of: "__CATEGORY_", with: "")
                    .components(separatedBy: "_$_")
                    .first
                return className
            }
            return nil
        }

        var data: ObjCClass.ClassROData?
        if let _data = cls.classROData(in: machO) {
            data = _data
        }
        if let rw = cls.classRWData(in: machO) {
            if let _data = rw.classROData(in: machO) {
                data = _data
            }
            if let ext = rw.ext(in: machO),
               let _data = ext.classROData(in: machO) {
                data = _data
            }
        }
        return data?.name(in: machO)
    }

    public func instanceMethodList(in machO: MachOImage) -> ObjCMethodList? {
        _readMethodList(
            at: numericCast(layout.instanceMethods),
            in: machO
        )
    }

    public func classMethodList(in machO: MachOImage) -> ObjCMethodList? {
        _readMethodList(
            at: numericCast(layout.classMethods),
            in: machO
        )
    }

    public func instancePropertyList(in machO: MachOImage) -> ObjCPropertyList? {
        _readPropertyList(
            at: numericCast(layout.instanceProperties),
            in: machO
        )
    }

    public func classPropertyList(in machO: MachOImage) -> ObjCPropertyList? {
        _readPropertyList(
            at: numericCast(layout._classProperties),
            in: machO
        )
    }

    public func protocolList(in machO: MachOImage) -> ObjCProtocolList? {
        _readProtocolList(
            at: numericCast(layout.protocols),
            in: machO
        )
    }
}

extension ObjCCategoryProtocol {
    @available(*, deprecated, renamed: "class(in:)", message: "Use `class(in:)` that returns machO that contains class")
    public func `class`(in machO: MachOFile) -> ObjCClass? {
        guard let (_, cls) = self.class(in: machO) else {
            return nil
        }
        return cls
    }

    @available(*, deprecated, renamed: "stubClass(in:)", message: "Use `stubCclass(in:)` that returns machO that contains class")
    public func stubClass(in machO: MachOFile) -> ObjCStubClass? {
        guard let (_, cls) = self.stubClass(in: machO) else {
            return nil
        }
        return cls
    }

    @available(*, deprecated, renamed: "class(in:)", message: "Use `class(in:)` that returns machO that contains class")
    func `class`(in machO: MachOImage) -> ObjCClass? {
        guard let (targetMachO, cls) = self.class(in: machO) else { return nil }
        let diff = Int(bitPattern: targetMachO.ptr) - Int(bitPattern: machO.ptr)
        return .init(
            layout: cls.layout,
            offset: cls.offset + diff
        )
    }

    @available(*, deprecated, renamed: "stubClass(in:)", message: "Use `stubCclass(in:)` that returns machO that contains class")
    func stubClass(in machO: MachOImage) -> ObjCStubClass? {
        guard let (targetMachO, cls) = self.stubClass(in: machO) else { return nil }
        let diff = Int(bitPattern: targetMachO.ptr) - Int(bitPattern: machO.ptr)
        return .init(
            layout: cls.layout,
            offset: cls.offset + diff
        )
    }
}

extension ObjCCategoryProtocol {
    private func _readClass(
        field: LayoutField,
        in machO: MachOFile
    ) -> (MachOFile, ObjCClass)? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }

        if isBind(field, in: machO) { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        var targetMachO = machO
        if !targetMachO.contains(unslidAddress: resolved.address),
           let cache = machO.cache(for: resolved.address),
           let machO = cache.machO(containing: resolved.address) {
            targetMachO = machO
        }

        let layout: ObjCClass.Layout = fileHandle.read(offset: fileOffset)
        let cls: ObjCClass = .init(
            layout: layout,
            offset: numericCast(resolved.offset)
        )
        return (targetMachO, cls)
    }

    func _readStubClass(
        field: LayoutField,
        in machO: MachOFile
    ) -> (MachOFile, ObjCStubClass)? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }

        if isBind(field, in: machO) { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        var targetMachO = machO
        if !targetMachO.contains(unslidAddress: resolved.address),
           let cache = machO.cache(for: resolved.address),
           let machO = cache.machO(containing: resolved.address) {
            targetMachO = machO
        }

        let layout: ObjCStubClass.Layout = fileHandle.read(offset: fileOffset)
        let cls: ObjCStubClass = .init(
            layout: layout,
            offset: numericCast(resolved.offset)
        )
        return (targetMachO, cls)
    }

    private func _readClassName(
        field: LayoutField,
        in machO: MachOFile
    ) -> String? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }

        if !isBind(field, in: machO) {
            let resolved = machO.resolveRebase(unresolved)
            if let name = ObjCClass._readClassName(
                resolved: resolved,
                in: machO,
                allowsStubClass: false
            ) {
                return name
            }
        }

        if let bindSymbolName = resolveBind(field, in: machO) {
            return bindSymbolName
                .replacingOccurrences(of: "_OBJC_CLASS_$_", with: "")
        }

        return nil
    }

    private func _readMethodList(
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCMethodList? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }
        guard unresolved.value & 1 == 0 else { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCMethodList.Header = fileHandle.read(offset: fileOffset)
        let list = ObjCMethodList(
            offset: numericCast(resolved.offset),
            header: header,
            is64Bit: machO.is64Bit
        )
        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }
        return list
    }

    private func _readPropertyList(
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCPropertyList? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }
        guard unresolved.value & 1 == 0 else { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCPropertyList.Header = fileHandle.read(offset: fileOffset)
        let list = ObjCPropertyList(
            offset: numericCast(resolved.offset),
            header: header,
            is64Bit: machO.is64Bit
        )
        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }
        return list
    }

    private func _readProtocolList(
        field: LayoutField,
        in machO: MachOFile
    ) -> ObjCProtocolList? {
        let unresolved = unresolvedValue(of: field)
        guard unresolved.value > 0 else { return nil }
        guard unresolved.value & 1 == 0 else { return nil }

        let resolved = machO.resolveRebase(unresolved)

        guard let (fileHandle, fileOffset) = machO.fileHandleAndOffset(forResolvedValue: resolved) else {
            return nil
        }

        let header: ObjCProtocolList.Header = fileHandle.read(offset: fileOffset)
        let list = ObjCProtocolList(
            offset: numericCast(resolved.offset),
            header: header
        )
        return list
    }
}

extension ObjCCategoryProtocol {
    private func _readMethodList(
        at offset: UInt64,
        in machO: MachOImage
    ) -> ObjCMethodList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(offset)
        ) else {
            return nil
        }

        let list = ObjCMethodList(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )

        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }

        return list
    }

    private func _readPropertyList(
        at offset: UInt64,
        in machO: MachOImage
    ) -> ObjCPropertyList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(offset)
        ) else {
            return nil
        }
        let list = ObjCPropertyList(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr),
            is64Bit: machO.is64Bit
        )

        if list.isValidEntrySize(is64Bit: machO.is64Bit) == false {
            // FIXME: Check
            return nil
        }

        return list
    }

    private func _readProtocolList(
        at offset: UInt64,
        in machO: MachOImage
    ) -> ObjCProtocolList? {
        guard offset > 0 else { return nil }
        guard offset & 1 == 0 else { return nil }

        guard let ptr = UnsafeRawPointer(
            bitPattern: UInt(offset)
        ) else {
            return nil
        }
        let list = ObjCProtocolList(
            ptr: ptr,
            offset: Int(bitPattern: ptr) - Int(bitPattern: machO.ptr)
        )

        return list
    }
}
