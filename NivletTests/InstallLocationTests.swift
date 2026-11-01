import Foundation
import Testing
@testable import Nivlet

struct InstallLocationTests {
    @Test(arguments: [
        "/Volumes/Nivlet/Nivlet.app",
        "/private/var/folders/xy/T/AppTranslocation/2A6E-41C1/d/Nivlet.app",
    ])
    func diskImageCopiesAreDetected(path: String) {
        #expect(InstallLocation.isDiskImage(URL(filePath: path)))
    }

    @Test(arguments: [
        "/Applications/Nivlet.app",
        "/Users/someone/Applications/Nivlet.app",
        "/Users/someone/Library/Developer/Xcode/DerivedData/Nivlet/Build/Products/Debug/Nivlet.app",
    ])
    func installedCopiesAreNotDetected(path: String) {
        #expect(!InstallLocation.isDiskImage(URL(filePath: path)))
    }

    @Test func updatePageNamesTheInstalledVersion() throws {
        let url = InstallLocation.updatePage()
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "nivlet.ashique.work")
        #expect(components.path == "/releases/")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        #expect(items["installed"] == Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(items["build"] == Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }
}
