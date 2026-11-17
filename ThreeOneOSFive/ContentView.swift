import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        MatinoAimView()
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}
import SwiftUI

struct RemotePatchItem: Identifiable, Codable {
    var id: String
    var name: String
    var game: String
    var category: String
    var status_text: String
    var filename: String?
    var isInjecting: Bool = false
    var isInjected: Bool = false
    var isExtracting: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, game, category, status_text, filename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.game = (try? container.decode(String.self, forKey: .game)) ?? "normal"
        self.category = (try? container.decode(String.self, forKey: .category)) ?? "aim"
        self.status_text = (try? container.decode(String.self, forKey: .status_text)) ?? "SAFE"
        self.filename = try? container.decode(String.self, forKey: .filename)
        self.isInjecting = false
        self.isInjected = false
    }

    init(id: String, name: String, game: String, category: String, status_text: String, filename: String? = nil) {
        self.id = id
        self.name = name
        self.game = game
        self.category = category
        self.status_text = status_text
        self.filename = filename
        self.isInjecting = false
        self.isInjected = false
    }
}

struct MatinoAimView: View {
    @State private var selectedGame: String = "normal" // "normal" or "max"
    @State private var selectedTab: Int = 0 // 0: AIM, 1: HOLOGRAM, 2: SKIN MOD, 3: COMPATIBILITY, 4: MORE
    @State private var patches: [RemotePatchItem] = []
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false

    private let serverURL = "http://84.46.255.192:27612"

    var currentCategory: String {
        switch selectedTab {
        case 0: return "aim"
        case 1: return "hologram"
        case 2: return "body"
        default: return "aim"
        }
    }

    var filteredPatches: [RemotePatchItem] {
        patches.filter { item in
            let matchesGame = item.game.lowercased() == selectedGame.lowercased()
            let matchesCat = (selectedTab == 0 && item.category == "aim") ||
                             (selectedTab == 1 && (item.category == "hologram" || item.category == "body")) ||
                             (selectedTab == 2 && item.category == "body")
            return matchesGame && matchesCat
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header Title
                Text(selectedTab == 0 ? "AIM" : (selectedTab == 1 ? "HOLOGRAM" : (selectedTab == 2 ? "SKIN MOD" : "COMPATIBILITY")))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Official Info Banner (MATINO X)
                        officialInfoCard

                        // Online Aim Patches Banner
                        onlinePatchesCard

                        // Game Switcher (FREE FIRE NORMAL / MAX)
                        gameSelector

                        // Subtitle: FF NORMAL / SELECT PATCH
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 13))
                                Text(selectedGame == "normal" ? "FF NORMAL" : "FF MAX")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text("SELECT PATCH")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(white: 0.5))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        // Patches List
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPatches) { patch in
                                patchRow(patch)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 80)
                    }
                }

                // Custom Bottom Tab Bar
                bottomTabBar
            }
        }
        .onAppear {
            fetchRemotePatches()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("MATINO X"), message: Text(alertMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Official Info Card
    private var officialInfoCard: some View {
        HStack {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flame.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("MATINO X")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(.white)
                    Text("MATINO X • OFFICIAL INFO")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.6))
                }
            }
            Spacer()
            // Telegram Action Pill
            Button(action: {
                if let url = URL(string: "https://t.me/YAGAMIxIOS") {
                    UIApplication.shared.open(url)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(white: 0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Online Patches Banner
    private var onlinePatchesCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(white: 0.3), lineWidth: 1.5)
                    .frame(width: 44, height: 44)
                Image(systemName: "scope")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedTab == 0 ? "AIM" : "MODS")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("ONLINE AIM PATCHES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(white: 0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(white: 0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Game Switcher
    private var gameSelector: some View {
        HStack(spacing: 8) {
            Button(action: { selectedGame = "normal" }) {
                VStack(spacing: 3) {
                    Text("FREE FIRE")
                        .font(.system(size: 13, weight: .heavy))
                    Text("NORMAL")
                        .font(.system(size: 10, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedGame == "normal" ? Color(white: 0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedGame == "normal" ? Color(white: 0.4) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(.white)
            }

            Button(action: { selectedGame = "max" }) {
                VStack(spacing: 3) {
                    Text("FREE FIRE MAX")
                        .font(.system(size: 13, weight: .heavy))
                    Text("MAX")
                        .font(.system(size: 10, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedGame == "max" ? Color(white: 0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedGame == "max" ? Color(white: 0.4) : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(.white)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(white: 0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Patch Row
    private func patchRow(_ patch: RemotePatchItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(patch.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("FREE FIRE • \(patch.game.uppercased())")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(white: 0.55))
                Text(patch.status_text)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(patch.status_text.contains("SAFE") ? Color(red: 0.3, green: 0.85, blue: 0.4) : .yellow)
            }
            Spacer()

            HStack(spacing: 8) {
                // INJECT Button
                Button(action: { injectPatch(patch) }) {
                    Text(patch.isInjected ? "ACTIVE" : (patch.isInjecting ? "..." : "INJECT"))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(patch.isInjected ? Color.green.opacity(0.3) : Color(white: 0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(patch.isInjected ? Color.green : Color(white: 0.28), lineWidth: 1)
                                )
                        )
                }
                .disabled(patch.isInjecting || patch.isExtracting)

                // EXTRACT Button (Removes / Restores original files)
                Button(action: { extractPatch(patch) }) {
                    Text(patch.isExtracting ? "..." : "EXTRACT")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.45))
                        .frame(width: 74, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                                )
                        )
                }
                .disabled(patch.isInjecting || patch.isExtracting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(white: 0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom Tab Bar
    private var bottomTabBar: some View {
        HStack {
            tabButton(title: "AIM", icon: "scope", index: 0)
            tabButton(title: "HOLOGRAM", icon: "cube.transparent", index: 1)
            tabButton(title: "SKIN MOD", icon: "sparkles", index: 2)
            tabButton(title: "COMPATIBILITY", icon: "iphone", index: 3)
            tabButton(title: "More", icon: "ellipsis", index: 4)
        }
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(Color(white: 0.05).ignoresSafeArea(edges: .bottom))
        .overlay(
            Rectangle()
                .fill(Color(white: 0.15))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(selectedTab == index ? .white : Color(white: 0.4))
        }
    }

    // MARK: - Network & Inject Logic
    private func fetchRemotePatches() {
        guard let url = URL(string: "\(serverURL)/api/patches?t=" + String(Int(Date().timeIntervalSince1970))) else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 6.0

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            struct Resp: Codable { let all_patches: [RemotePatchItem]? }
            if let decoded = try? JSONDecoder().decode(Resp.self, from: data), let items = decoded.all_patches {
                DispatchQueue.main.async {
                    self.patches = items
                }
            }
        }.resume()
    }

    private func injectPatch(_ patch: RemotePatchItem) {
        guard let idx = patches.firstIndex(where: { $0.id == patch.id }) else { return }
        patches[idx].isInjecting = true

        // Look for target bundle
        let bundleID = patch.game == "max" ? "com.dts.freefiremax" : "com.dts.freefireth"
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
            patches[idx].isInjecting = false
            alertMessage = "Free Fire (\(patch.game.uppercased())) is not installed on this device!"
            showAlert = true
            return
        }

        // Try downloading patch from server if exists
        let downloadURL = "\(serverURL)/api/patches/\(patch.id)/download?tenant=vesper"
        if let url = URL(string: downloadURL) {
            URLSession.shared.downloadTask(with: url) { tempURL, _, error in
                DispatchQueue.main.async {
                    self.patches[idx].isInjecting = false
                    if let temp = tempURL {
                        // Apply package
                        if let data = try? Data(contentsOf: temp), let decoded = try? PatchPackageCodec.decode(data, password: nil) { _ = try? DevicePatchService.apply(project: decoded.project) }
                    }
                    self.patches[idx].isInjected = true
                    self.alertMessage = "\(patch.name) injected successfully into Free Fire!"
                    self.showAlert = true
                }
            }.resume()
        } else {
            patches[idx].isInjecting = false
            patches[idx].isInjected = true
            alertMessage = "\(patch.name) injected successfully!"
            showAlert = true
        }
    }

    private func extractPatch(_ patch: RemotePatchItem) {
        guard let idx = patches.firstIndex(where: { $0.id == patch.id }) else { return }
        patches[idx].isExtracting = true

        let bundleID = patch.game == "max" ? "com.dts.freefiremax" : "com.dts.freefireth"
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
            patches[idx].isExtracting = false
            alertMessage = "Free Fire (\(patch.game.uppercased())) container not found!"
            showAlert = true
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Try restoring via DevicePatchService if receipt exists
            var restored = false
            if let receipts = try? PatchTransaction.allReceipts(backupRoot: (try? PatchProjectLibrary.backupRootURL()) ?? URL(fileURLWithPath: NSTemporaryDirectory())) {
                for r in receipts {
                    if let _ = try? DevicePatchService.restore(receipt: r, allowChangedTargets: true) {
                        restored = true
                    }
                }
            }

            // 2. Clean temporary injected patch files in documents if any
            let fm = FileManager.default
            let contURL = URL(fileURLWithPath: containerPath)
            let filesToRemove = [patch.filename ?? "", "\(patch.id).3105", "patch.3105"]
            for f in filesToRemove where !f.isEmpty {
                let p1 = contURL.appendingPathComponent("Documents").appendingPathComponent(f)
                let p2 = contURL.appendingPathComponent("Library").appendingPathComponent(f)
                try? fm.removeItem(at: p1)
                try? fm.removeItem(at: p2)
            }

            DispatchQueue.main.async {
                self.patches[idx].isExtracting = false
                self.patches[idx].isInjected = false
                self.alertMessage = "\(patch.name) extracted & removed from Free Fire successfully!"
                self.showAlert = true
            }
        }
    }
}
