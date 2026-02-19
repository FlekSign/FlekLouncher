//
//  TabView.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/21.
//

import Foundation
import SwiftUI

struct LCTabView: View {
    @Binding var appDataFolderNames: [String]
    @Binding var tweakFolderNames: [String]
    
    @State private var selectedTab: Int = 0
    
    @State var errorShow = false
    @State var errorInfo = ""
    
    @State var previousSelectedTab : LCTabIdentifier = .apps
    
    @EnvironmentObject var sharedModel : SharedModel
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @State var shouldToggleMainWindowOpen = false
    @Environment(\.scenePhase) var scenePhase
    let pub = NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)
    
    
    var body: some View {
        Group {
            let appListView = LCAppListView(appDataFolderNames: $appDataFolderNames, tweakFolderNames: $tweakFolderNames)
            //let sourcesView = LCSourcesView()
                TabView(selection: $sharedModel.selectedTab) {
//                    if DataManager.shared.model.multiLCStatus != 2 {
//                        sourcesView
//                            .tabItem {
//                                Label("lc.tabView.sources".loc, systemImage: "books.vertical")
//                            }
//                            .tag(LCTabIdentifier.sources)
//                    }
                    appListView
                        .tabItem {
                            Label("lc.tabView.apps".loc, systemImage: "square.stack.3d.up.fill")
                        }
                        .tag(LCTabIdentifier.apps)
                    FlekstoreAppsListView(selectedTab: $selectedTab)
                        .tabItem {
                            Label("Flekstore", systemImage: "globe")
                        }
                        .tag(LCTabIdentifier.browse)
                    
                    LCSettingsView(appDataFolderNames: $appDataFolderNames, tweakFolderNames: $tweakFolderNames)
                        .tabItem {
                            Label("lc.tabView.settings".loc, systemImage: "gearshape.fill")
                        }
                        .tag(LCTabIdentifier.settings)
                }
        }
        .alert("lc.common.error".loc, isPresented: $errorShow) {
            Button("lc.common.ok".loc) {}
            Button("lc.common.copy".loc) { copyError() }
        } message: {
            Text(errorInfo)
        }
        .task {
            setupInitialRepositoriesIfNeeded()
            if !UserDefaults.standard.bool(forKey: "DidOpenSettingsOnce") {
                selectedTab = 3 // programmatically open Settings tab
                UserDefaults.standard.set(true, forKey: "DidOpenSettingsOnce")
            } else {
                selectedTab = 0
            }
            closeDuplicatedWindow()
            checkLastLaunchError()
            checkTeamId()
            checkBundleId()
            checkGetTaskAllow()
            checkPrivateContainerBookmark()
        }
        .onReceive(pub) { out in
            if let scene1 = sceneDelegate.window?.windowScene, let scene2 = out.object as? UIWindowScene, scene1 == scene2 {
                if shouldToggleMainWindowOpen {
                    DataManager.shared.model.mainWindowOpened = false
                }
            }
        }
        .onChange(of: sharedModel.selectedTab) { newValue in
            if newValue != LCTabIdentifier.search {
                previousSelectedTab = newValue
            }
        }
        .onOpenURL { url in
            dispatchURL(url: url)
        }
    }
    
    func dispatchURL(url: URL) {
        repeat {
            if url.isFileURL {
                sharedModel.selectedTab = .apps
                break
            }
            if url.scheme?.lowercased() == "sidestore" {
                sharedModel.selectedTab = .apps
                break
            }
            
            guard let host = url.host?.lowercased() else {
                return
            }
            
            switch host {
            case "livecontainer-launch", "install", "open-web-page", "open-url":
                sharedModel.selectedTab = .apps
            case "certificate":
                sharedModel.selectedTab = .settings
            case "source":
                sharedModel.selectedTab = .sources
            default:
                return
            }
            
        } while(false)
        
        sharedModel.deepLink = url
    }
    
    // MARK: - Programmatic tab switch helper
    func switchTab(to index: Int) {
        selectedTab = index
    }
    
    // MARK: - Existing helper functions
    func closeDuplicatedWindow() {
        if let session = sceneDelegate.window?.windowScene?.session, DataManager.shared.model.mainWindowOpened {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { e in
                print(e)
            }
        } else {
            shouldToggleMainWindowOpen = true
        }
        DataManager.shared.model.mainWindowOpened = true
    }
    
    func checkLastLaunchError() {
        var errorStr = UserDefaults.standard.string(forKey: "error")
        if errorStr == nil && UserDefaults.standard.bool(forKey: "SigningInProgress") {
            errorStr = "lc.signer.crashDuringSignErr".loc
            UserDefaults.standard.removeObject(forKey: "SigningInProgress")
        }
        guard let errorStr else { return }
        UserDefaults.standard.removeObject(forKey: "error")
        errorInfo = errorStr
        errorShow = true
    }
    
    func copyError() { UIPasteboard.general.string = errorInfo }
    
    
    func checkTeamId() {
        if let certificateTeamId = UserDefaults.standard.string(forKey: "LCCertificateTeamId") {
            if DataManager.shared.model.multiLCStatus != 2 {
                return
            }
            
            guard let primaryLCTeamId = Bundle.main.infoDictionary?["PrimaryLiveContainerTeamId"] as? String else {
                print("Unable to find PrimaryLiveContainerTeamId")
                return
            }
            if certificateTeamId != primaryLCTeamId {
                errorInfo = "lc.settings.multiLC.teamIdMismatch".loc
                errorShow = true
                return
            }
            return
        }
        
        guard let currentTeamId = LCSharedUtils.teamIdentifier() else {
            print("Failed to determine team id.")
            return
        }
        
        if DataManager.shared.model.multiLCStatus == 2 {
            guard let primaryLCTeamId = Bundle.main.infoDictionary?["PrimaryLiveContainerTeamId"] as? String else {
                print("Unable to find PrimaryLiveContainerTeamId")
                return
            }
            if currentTeamId != primaryLCTeamId {
                errorInfo = "lc.settings.multiLC.teamIdMismatch".loc
                errorShow = true
                return
            }
        }
        UserDefaults.standard.set(currentTeamId, forKey: "LCCertificateTeamId")
    }
    
    func checkBundleId() {
        if UserDefaults.standard.bool(forKey: "LCBundleIdChecked") {
            return
        }
        
        let task = SecTaskCreateFromSelf(nil)
        guard let value = SecTaskCopyValueForEntitlement(task, "application-identifier" as CFString, nil), let appIdentifier = value.takeRetainedValue() as? String else {
            errorInfo = "Unable to determine application-identifier"
            errorShow = true
            return
        }
        
        guard let bundleId = Bundle.main.bundleIdentifier else {
            return
        }
        
        var correctBundleId = ""
        if appIdentifier.count > 11 {
            let startIndex = appIdentifier.index(appIdentifier.startIndex, offsetBy: 11)
            correctBundleId = String(appIdentifier[startIndex...])
        }
        
        if(bundleId != correctBundleId) {
            errorInfo = "lc.settings.bundleIdMismatch %@ %@".localizeWithFormat(bundleId, correctBundleId)
            errorShow = true
        }
        UserDefaults.standard.set(true, forKey: "LCBundleIdChecked")
    }
    
    func checkGetTaskAllow() {
        let task = SecTaskCreateFromSelf(nil)
        guard let value = SecTaskCopyValueForEntitlement(task, "get-task-allow" as CFString, nil), (value.takeRetainedValue() as? NSNumber)?.boolValue ?? false else {
            errorInfo = "lc.settings.notDevCert".loc
            errorShow = true
            return
        }
    }
    
    private func setupInitialRepositoriesIfNeeded() {
        let didSetupKey = "DidSetupDefaultRepositories"
        
        guard !UserDefaults.standard.bool(forKey: didSetupKey) else {
            return
        }
        
        let defaultApps: [AppRepository] = [
            AppRepository(
                name: "FlekSt0re Lib",
                iconUrl: "https://flekstore.com/pro_app/icons/apple-touch-icon.png",
                sourceURL: "Default app catalog",
                isSelected: true
            ),
            AppRepository(
                name: "Nabzclan - App Store",
                iconUrl: "https://cdn.nabzclan.vip/popupv3/imgs/logo-tras.png",
                sourceURL: "https://appstore.nabzclan.vip/repos/altstore.php",
                isSelected: false
            ),
            AppRepository(
                name: "AppTesters IPA Repo",
                iconUrl: "https://apptesters.org/apptesters-512x512.png",
                sourceURL: "https://repository.apptesters.org/",
                isSelected: false
            ),
            AppRepository(
                name: "Quantum Source",
                iconUrl: "https://quarksources.github.io/assets/ElementQ-Circled.png",
                sourceURL: "https://quarksources.github.io/dist/quantumsource.min.json",
                isSelected: false
            )
        ]
        
        if let data = try? JSONEncoder().encode(defaultApps) {
            UserDefaults.standard.set(data, forKey: "savedRepositories")
        }
        UserDefaults.standard.set(true, forKey: didSetupKey)
        
    }
    func checkPrivateContainerBookmark() {
        if sharedModel.multiLCStatus == 2 {
            return
        }
        if LCUtils.appGroupUserDefault.object(forKey: "LCLaunchExtensionPrivateDocBookmark") != nil {
            return
        }
        
        guard let bookmark = LCUtils.bookmark(for: LCPath.docPath) else {
            errorInfo = "Failed to create bookmark for Documents folder?"
            errorShow = true
            return
        }
        LCUtils.appGroupUserDefault.set(bookmark, forKey: "LCLaunchExtensionPrivateDocBookmark")
    }
}
