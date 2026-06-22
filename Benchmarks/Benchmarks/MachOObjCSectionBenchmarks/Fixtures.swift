import Benchmark
import Foundation
import MachOKit
import MachOObjCSection

enum BenchmarkFixtures {
    static var machOURL: URL {
        if let path = ProcessInfo.processInfo.environment["MACHO_OBJC_SECTION_BENCH_MACHO"],
           !path.isEmpty {
            return URL(fileURLWithPath: path)
        }

        let defaultPath = "/System/Applications/Freeform.app/Contents/MacOS/Freeform"
        if FileManager.default.fileExists(atPath: defaultPath) {
            return URL(fileURLWithPath: defaultPath)
        }

        if let executableURL = Bundle.main.executableURL {
            return executableURL
        }
        return URL(fileURLWithPath: CommandLine.arguments[0])
    }

    static var dyldCacheURL: URL? {
        guard let path = ProcessInfo.processInfo.environment["MACHO_OBJC_SECTION_BENCH_DYLD_CACHE"],
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    static var dyldCacheImageName: String {
        ProcessInfo.processInfo.environment["MACHO_OBJC_SECTION_BENCH_CACHE_IMAGE"] ?? "/Foundation"
    }

    static var hasDyldCache: Bool {
        #if canImport(Darwin)
        true
        #else
        dyldCacheURL != nil
        #endif
    }

    static func machOFile() -> MachOFile {
        do {
            return try loadMachOFile(url: machOURL)
        } catch {
            fatalError("Failed to load Mach-O benchmark fixture at \(machOURL.path): \(error)")
        }
    }

    static func cacheMachOFile(benchmark: Benchmark) -> MachOFile? {
        guard let cache = dyldCache() else {
            benchmark.error("Failed to load dyld shared cache benchmark fixture.")
            return nil
        }

        guard let machO = cache.machOFiles().first(where: {
            $0.imagePath.contains(dyldCacheImageName)
        }) else {
            benchmark.error("Failed to find dyld cache image matching \(dyldCacheImageName).")
            return nil
        }

        return machO
    }

    static func classInfoLimit(default defaultValue: Int = 100) -> Int {
        guard let value = ProcessInfo.processInfo.environment["MACHO_OBJC_SECTION_BENCH_CLASS_INFO_LIMIT"],
              let limit = Int(value),
              limit > 0 else {
            return defaultValue
        }
        return limit
    }

    static func dyldCache() -> DyldCache? {
        guard let dyldCacheURL else {
            return DyldCache.host
        }
        do {
            return try DyldCache(url: dyldCacheURL)
        } catch {
            fatalError("Failed to load dyld shared cache benchmark fixture at \(dyldCacheURL.path): \(error)")
        }
    }

    private static func loadMachOFile(url: URL) throws -> MachOFile {
        switch try MachOKit.loadFromFile(url: url) {
        case let .machO(machO):
            return machO
        case let .fat(fatFile):
            let machOFiles = try fatFile.machOFiles()
            if let machO = machOFiles.first(where: { $0.objc.classes64 != nil }) {
                return machO
            }
            if let machO = machOFiles.first(where: { $0.objc.classes32 != nil }) {
                return machO
            }
            guard let machO = machOFiles.first else {
                fatalError("Fat Mach-O benchmark fixture contains no Mach-O slices: \(url.path)")
            }
            return machO
        }
    }
}
