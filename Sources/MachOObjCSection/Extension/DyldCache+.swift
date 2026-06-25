//
//  DyldCache+.swift
//  MachOObjCSection
//
//  Created by p-x9 on 2024/11/02
//
//

import Foundation
import MachOKit
#if compiler(>=6.0) || (compiler(>=5.10) && hasFeature(AccessLevelOnImport))
internal import FileIO
#else
@_implementationOnly import FileIO
#endif

extension FileHandleHolder<DyldCache, DyldCache.File> {
    fileprivate static let shared: FileHandleHolder<Owner, File> = .init()
}

extension DyldCache {
    internal typealias File = MemoryMappedFile

    var fileHandle: File {
        FileHandleHolder.shared.fileHandle(
            for: self,
            initialize: {
                try! .open(url: url, isWritable: false)
            }
        )
    }
}

extension DyldCache {
    var fileStartOffset: UInt64 {
        numericCast(
            header.sharedRegionStart - mainCacheHeader.sharedRegionStart
        )
    }
}

// MARK: - locate value
extension DyldCache {
    /// A tuple containing the DyldCache where the value was found and the resolved value itself.
    /// Useful because values may be located either in the current cache, the main cache,
    /// or one of its subcaches.
    typealias LocatedValue<V> = (cache: DyldCache, value: V)

    /// Locate a value for a given optional KeyPath within this cache hierarchy.
    ///
    /// This resolves the value by checking:
    /// 1. This cache
    /// 2. The main cache
    /// 3. Any subcaches derived from `mainCache`
    ///
    /// - Parameter keyPath: A keyPath returning an optional value.
    /// - Returns: A tuple of `(cache, value)` if resolved, or `nil` if not found.
    @inline(__always)
    func locateValue<V>(
        _ keyPath: KeyPath<DyldCache, V?>
    ) -> LocatedValue<V>? {
        locateValue({ $0[keyPath: keyPath] })
    }

    /// Locate a value using a custom resolver function running against each cache in the hierarchy.
    ///
    /// Resolution order:
    /// 1. This cache
    /// 2. The main cache
    /// 3. Each subcache of the main cache
    ///
    /// - Parameter resolver: A closure returning an optional value for a given DyldCache.
    /// - Returns: A tuple of `(cache, value)` if resolution is successful; otherwise `nil`.
    @inline(__always)
    func locateValue<V>(
        _ resolver: (DyldCache) throws -> V?
    ) rethrows -> LocatedValue<V>? {
        if let value = try resolver(self) {
            return (self, value)
        }

        guard let mainCache else { return nil }
        let uuid = header.layout.uuid

        if !isEqual(mainCache.header.layout.uuid, uuid),
           let value = try resolver(mainCache) {
            return (mainCache, value)
        }

        guard let subCaches = mainCache.subCaches else { return nil }
        let fileName = url.lastPathComponent
        for entry in subCaches {
            if fileName.hasSuffix(entry.fileSuffix) {
                continue
            }

            guard let subCache = try? entry.subcache(for: mainCache) else {
                continue
            }
            if let value = try resolver(subCache) {
                return (subCache, value)
            }
        }
        return nil
    }
}

// MARK: - Objective-C
extension DyldCache {
    var _objcOptimization: LocatedValue<ObjCOptimization>? {
        locateValue(\.objcOptimization)
    }

    var _oldObjcOptimization: LocatedValue<OldObjCOptimization>? {
        locateValue(\.oldObjcOptimization)
    }
}

extension DyldCache {
    var headerOptimizationRO64: ObjCHeaderOptimizationRO64? {
        guard cpu.is64Bit else { return nil }
        if let _objcOptimization {
            return _objcOptimization.value.headerOptimizationRO64(in: self)
        }
        if let _oldObjcOptimization {
            return _oldObjcOptimization.value.headerOptimizationRO64(in: self)
        }
        return nil
    }

    var headerOptimizationRO32: ObjCHeaderOptimizationRO32? {
        guard !cpu.is64Bit else { return nil }
        if let _objcOptimization {
            return _objcOptimization.value.headerOptimizationRO32(in: self)
        }
        if let _oldObjcOptimization {
            return _oldObjcOptimization.value.headerOptimizationRO32(in: self)
        }
        return nil
    }
}

extension DyldCache {
    var _headerOptimizationRO64: LocatedValue<ObjCHeaderOptimizationRO64>? {
        locateValue(\.headerOptimizationRO64)
    }

    var _headerOptimizationRO32: LocatedValue<ObjCHeaderOptimizationRO32>? {
        locateValue(\.headerOptimizationRO32)
    }
}

extension DyldCache {
    func _machO(at index: Int) -> LocatedValue<MachOFile>? {
        if let ro = _headerOptimizationRO64?.value,
           ro.contains(index: index) {
            let headers = locateValue({ ro.headerInfos(in: $0) })?.value
            guard let header = headers?.first(
                where: {
                    $0.index == index
                }
            ) else {
                return nil
            }
            return locateValue { header.machO(in: $0) }
        }
        if let ro = _headerOptimizationRO32?.value,
           ro.contains(index: index) {
            let headers = locateValue({ ro.headerInfos(in: $0) })?.value
            guard let header = headers?.first(
                where: {
                    $0.index == index
                }
            ) else {
                return nil
            }
            return locateValue { header.machO(in: $0) }
        }
        return nil
    }
}

// MARK: - mach-o
extension DyldCache {
    func machO(containing unslidAddress: UInt64) -> MachOFile? {
        for machO in self.machOFiles() {
            if machO.contains(unslidAddress: unslidAddress) {
                return machO
            }
        }
        return nil
    }
}

@inline(__always)
private func isEqual(_ lhs: uuid_t, _ rhs: uuid_t) -> Bool {
    lhs.0 == rhs.0 &&
    lhs.1 == rhs.1 &&
    lhs.2 == rhs.2 &&
    lhs.3 == rhs.3 &&
    lhs.4 == rhs.4 &&
    lhs.5 == rhs.5 &&
    lhs.6 == rhs.6 &&
    lhs.7 == rhs.7 &&
    lhs.8 == rhs.8 &&
    lhs.9 == rhs.9 &&
    lhs.10 == rhs.10 &&
    lhs.11 == rhs.11 &&
    lhs.12 == rhs.12 &&
    lhs.13 == rhs.13 &&
    lhs.14 == rhs.14 &&
    lhs.15 == rhs.15
}
