//
//  MachOFile+.swift
//
//
//  Created by p-x9 on 2024/07/19
//  
//

import Foundation
import MachOKit

extension MachOFile {
    var fileHandle: FileHandle {
        try! .init(forReadingFrom: url)
    }
}

extension MachOFile {
    var cache: DyldCache? {
        guard isLoadedFromDyldCache else { return nil }
        guard let cache = try? DyldCache(url: url) else {
            return nil
        }
        if let mainCache = cache.mainCache {
            return try? .init(
                subcacheUrl: cache.url,
                mainCacheHeader: mainCache.header
            )
        }
        return cache
    }

    func cache(for address: UInt64) -> DyldCache? {
        cacheAndFileOffset(for: address)?.0
    }

    func cacheAndFileOffset(for address: UInt64) -> (DyldCache, UInt64)? {
        guard let cache else { return nil }
        if let offset = cache.fileOffset(of: address) {
            return (cache, offset)
        }
        guard let mainCache = cache.mainCache else {
            return nil
        }

        if let offset = mainCache.fileOffset(of: address) {
            return (mainCache, offset)
        }

        guard let subCaches = mainCache.subCaches else {
            return nil
        }
        for subCache in subCaches {
            guard let cache = try? subCache.subcache(for: mainCache) else {
                continue
            }
            if let offset = cache.fileOffset(of: address) {
                return (cache, offset)
            }
        }
        return nil
    }
}

extension MachOFile {
    func isBind(
        _ offset: Int
    ) -> Bool {
        resolveBind(at: numericCast(offset)) != nil
    }
}
