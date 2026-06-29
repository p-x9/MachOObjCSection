import XCTest
@testable import MachOObjCSection
@testable import MachOKit


final class MachOObjCSectionTests: XCTestCase {
    private var machOImage: MachOImage!
    private var machOFile: MachOFile!
    private var cache: DyldCache!
    private var machOFileInCache: MachOFile!

    override func setUp() {
        // Image
        machOImage = MachOImage(name: "Foundation")!

        // File
        let path = "/System/Applications/Freeform.app/Contents/MacOS/Freeform"
        let url = URL(fileURLWithPath: path)
        guard let file = try? MachOKit.loadFromFile(url: url) else {
            XCTFail("Failed to load file")
            return
        }
        switch file {
        case let .fat(fatFile):
            machOFile = try! fatFile.machOFiles()[1]
        case let .machO(machO):
            machOFile = machO
        }

        // Cache
        let arch = "arm64e"
        let cachePath = "/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_\(arch)"
        let cacheUrl = URL(fileURLWithPath: cachePath)
        cache = try! DyldCache(url: cacheUrl)
        machOFileInCache = cache.machOFiles().first(where: {
            $0.imagePath.contains("/Foundation")
        })!
    }
}

extension MachOObjCSectionTests {
    func testImageInfoInImage() {
        let machO = machOImage!
        guard let imageInfo = machO.objc.imageInfo else { return }
        dump(imageInfo: imageInfo)
    }

    func testImageInfoInFile() {
        let machO = machOFile!
        guard let imageInfo = machO.objc.imageInfo else { return }
        dump(imageInfo: imageInfo)
    }

    func testImageInfoInCacheFile() {
        let machO = machOFileInCache!
        guard let imageInfo = machO.objc.imageInfo else { return }
        dump(imageInfo: imageInfo)
    }
}

extension MachOObjCSectionTests {
    func testMethodsInImage() {
        let machO = machOImage!
        guard let lists = machO.objc.methods else { return }
        for list in lists {
            print("Count:", list.count, "EntrySize:", list.entrySize)
            dump(list: list, in: machO)
        }
    }

    func testMethodsInFile() {
        let machO = machOFile!
        guard let lists = machO.objc.methods else { return }
        for list in lists {
            print("Count:", list.count, "EntrySize:", list.entrySize)
            dump(list: list, in: machO)
        }
    }

    func testMethodsInCacheFile() {
        let machO = machOFileInCache!
        guard let lists = machO.objc.methods else { return }
        for list in lists {
            print("Count:", list.count, "EntrySize:", list.entrySize)
            dump(list: list, in: machO)
        }
    }
}

// MARK: - ObjC Classes
extension MachOObjCSectionTests {
    func testClassesInImage() {
        let machO = machOImage!
        guard let classes = machO.objc.classes64 else { return }
        for cls in classes {
            guard let info = cls.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse class")
                continue
            }
            print(info.headerString)
        }
    }

    func testClassesInFile() {
        let machO = machOFile!
        guard let classes = machO.objc.classes64 else { return }
        for cls in classes.prefix(100) {
            guard let info = cls.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse class")
                continue
            }
            print(info.headerString)
        }
    }

    func testClassesInCacheFile() {
        let machO = machOFileInCache!
        guard let classes = machO.objc.classes64 else { return }
        for cls in classes {
            guard let info = cls.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse class")
                continue
            }
            print(info.headerString)
        }
    }
}

// MARK: - ObjC Non Lazy Classes
extension MachOObjCSectionTests {
    func testNonLazyClassesInImage() {
        let machO = machOImage!
        guard let classes = machO.objc.nonLazyClasses64 else { return }
        for cls in classes {
            guard let info = cls.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse class")
                continue
            }
            print(info.headerString)
        }
    }

    func testNonLazyClassesInFile() {
        let machO = machOFile!
        guard let classes = machO.objc.nonLazyClasses64 else { return }
        for cls in classes {
            guard let info = cls.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse class")
                continue
            }
            print(info.headerString)
        }
    }

    func testNonLazyClassesInCacheFile() {
        let machO = machOFileInCache!
        guard let classes = machO.objc.nonLazyClasses64 else { return }
        for cls in classes {
            guard let info = cls.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse class")
                continue
            }
            print(info.headerString)
        }
    }
}

// MARK: - ObjC Protocols
extension MachOObjCSectionTests {
    func testProtocolsInImage() {
        let machO = machOImage!
        guard let protocols = machO.objc.protocols64 else { return }
        for proto in protocols {
            guard let info = proto.info(in: machO, options: .directProtocolNames) else {
                XCTFail("Failed to parse protocol")
                continue
            }
            print(info.headerString)
        }
    }

    func testProtocolsInFile() {
        let machO = machOFile!
        guard let protocols = machO.objc.protocols64 else { return }
        for proto in protocols {
            guard let info = proto.info(in: machO, options: .directProtocolNames) else {
                XCTFail("Failed to parse protocol")
                continue
            }
            print(info.headerString)
        }
    }

    func testProtocolsInCacheFile() {
        let machO = machOFileInCache!
        guard let protocols = machO.objc.protocols64 else { return }
        for proto in protocols {
            guard let info = proto.info(in: machO, options: .directProtocolNames) else {
                XCTFail("Failed to parse protocol")
                continue
            }
            print(info.headerString)
        }
    }
}

// MARK: - ObjC Categories
extension MachOObjCSectionTests {
    func testCategoriesInImage() {
        let machO = machOImage!
        guard let categories = machO.objc.categories64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }

    func testCategoriesInFile() {
        let machO = machOFile!
        guard let categories = machO.objc.categories64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }

    func testCategoriesInCacheFile() {
        let machO = machOFileInCache!
        guard let categories = machO.objc.categories64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }
}

// MARK: - ObjC Non Lazy Categories
extension MachOObjCSectionTests {
    func testNonLazyCategoriesInImage() {
        let machO = machOImage!
        guard let categories = machO.objc.nonLazyCategories64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }

    func testNonLazyCategoriesInFile() {
        let machO = machOFile!
        guard let categories = machO.objc.nonLazyCategories64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }

    func testNonLazyCategoriesInCacheFile() {
        let machO = machOFileInCache!
        guard let categories = machO.objc.nonLazyCategories64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }
}

// MARK: - ObjC Categories (Swift Stub)
extension MachOObjCSectionTests {
    func testCategories2InImage() {
        let machO = machOImage!
        guard let categories = machO.objc.categories2_64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }

    func testCategories2InFile() {
        let machO = machOFile!
        guard let categories = machO.objc.categories2_64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }

    func testCategories2InCacheFile() {
        let machO = machOFileInCache!
        guard let categories = machO.objc.categories2_64 else { return }
        for cat in categories {
            guard let info = cat.info(in: machO, options: .headerDump) else {
                XCTFail("Failed to parse category")
                continue
            }
            print(info.headerString)
        }
    }
}

// MARK: - ObjC is Loaded
extension MachOObjCSectionTests {
    func testIsLoadedMachOImage() {
        guard let cache: DyldCacheLoaded = .current else { return }
        for machO in cache.machOImages() {
            print(machO.objc.isLoaded, machO.path ?? "Unknown")
        }
    }
}
