import SwiftUI
import Combine

@main
struct TowerCrazeApp: App {
    @StateObject private var app = TowerAppModel()

    var body: some Scene {
        WindowGroup {
            TowerRootView()
                .environmentObject(app)
                .environmentObject(app.progress)
                .environmentObject(app.stats)
                .preferredColorScheme(.light)
                .statusBar(hidden: true)
        }
    }
}

enum TowerScreen: Equatable {
    case site, game, blueprints, skyline, settings
}

/// Рекорды стройки, которые показываются на главном экране.
final class SiteStats: ObservableObject {
    @Published private(set) var bestFloors = 0
    @Published private(set) var totalBricks = 0
    @Published private(set) var runs = 0

    init() { reload() }

    func reload() {
        bestFloors = Store.shared.int("bestFloors")
        totalBricks = Store.shared.int("totalBricks")
        runs = Store.shared.int("runs")
    }

    func record(floors: Int, bricks: Int) {
        runs += 1
        totalBricks += bricks
        bestFloors = max(bestFloors, floors)
        Store.shared.setInt("runs", runs)
        Store.shared.setInt("totalBricks", totalBricks)
        Store.shared.setInt("bestFloors", bestFloors)
    }
}

struct RunResult {
    let score: Int
    let floors: Int
    let bricks: Int
    let newBest: Bool
}

final class TowerAppModel: ObservableObject {
    @Published var screen: TowerScreen = .site
    @Published var session: TowerSession?
    @Published var lastRun: RunResult?
    let progress: GameProgress
    let stats: SiteStats

    init() {
        Store.shared.prefix = "towercraze."
        progress = GameProgress(
            achievements: [
                AchievementDef(id: "first", title: "Ground Breaking", detail: "Clear your first group of bricks", icon: "brick_0"),
                AchievementDef(id: "chain", title: "Domino Effect", detail: "Reach a chain of three", icon: "brick_1"),
                AchievementDef(id: "tnt", title: "Controlled Blast", detail: "Set off a TNT crate", icon: "tnt"),
                AchievementDef(id: "big", title: "Wrecking Ball", detail: "Clear a group of eight bricks", icon: "brick_4"),
                AchievementDef(id: "floor5", title: "Five Storeys", detail: "Build five floors in one shift", icon: "floor"),
                AchievementDef(id: "floor15", title: "Skyscraper", detail: "Build fifteen floors in one shift", icon: "roof"),
                AchievementDef(id: "score", title: "Site Manager", detail: "Score 5000 points in one shift", icon: "brick_2"),
                AchievementDef(id: "bricks", title: "Master Mason", detail: "Clear 1000 bricks in total", icon: "brick_3")
            ],
            botNames: ["Bob", "Rosa", "Dmitri", "Kenji", "Fatima", "Liam", "Greta", "Omar", "Priya", "Hugo", "Wendy", "Mateo"],
            botBase: 900, botSpread: 7200, seed: 77)
        stats = SiteStats()
    }

    func go(_ s: TowerScreen) {
        if s != .game { session?.setPaused(true) }
        withAnimation(.easeInOut(duration: 0.28)) { screen = s }
    }

    func startRun() {
        lastRun = nil
        session = TowerSession(app: self)
        Sound.shared.play("whoosh", volume: 0.8)
        go(.game)
    }

    func finishRun(score: Int, floors: Int, bricks: Int) {
        let newBest = score > progress.best
        progress.submit(score)
        stats.record(floors: floors, bricks: bricks)
        if stats.totalBricks >= 1000 { progress.unlock("bricks") }
        lastRun = RunResult(score: score, floors: floors, bricks: bricks, newBest: newBest)
    }

    func leaveRun() {
        session?.setPaused(true)
        session = nil
        go(.site)
    }

    func clearData() {
        session = nil
        lastRun = nil
        progress.clearAll()
        stats.reload()
        Haptics.success()
        progress.showToast("All data cleared")
        go(.site)
    }
}

struct TowerRootView: View {
    @EnvironmentObject var app: TowerAppModel
    @EnvironmentObject var progress: GameProgress

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.62, green: 0.86, blue: 1).ignoresSafeArea()
            Group {
                switch app.screen {
                case .site: SiteView()
                case .game:
                    if let s = app.session { BuildView(session: s).id(ObjectIdentifier(s)) } else { SiteView() }
                case .blueprints: BlueprintsView()
                case .skyline: SkylineView()
                case .settings: SiteSettingsView()
                }
            }
            .transition(.opacity)
            if let text = progress.toast {
                SiteToast(text: text)
                    .allowsHitTesting(false)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onAppear { Sound.shared.playMusic("music", volume: 0.32) }
    }
}
