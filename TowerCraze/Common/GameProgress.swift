import SwiftUI

struct AchievementDef: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String      // имя картинки из Resources/Art
}

struct LeaderRow: Identifiable {
    let id: Int
    let rank: Int
    let name: String
    let score: Int
    let isPlayer: Bool
}

/// Ачивки, лучшие результаты и локальный лидерборд (не путать с Foundation.Progress). Одна модель на приложение.
final class GameProgress: ObservableObject {
    @Published private(set) var unlocked: [String: Double] = [:]
    @Published private(set) var scores: [Int] = []
    @Published var toast: String? = nil

    let achievements: [AchievementDef]
    private let botNames: [String]
    private let botBase: Int
    private let botSpread: Int
    private let seed: UInt64
    private var toastToken = 0

    init(achievements: [AchievementDef], botNames: [String], botBase: Int, botSpread: Int, seed: UInt64) {
        self.achievements = achievements
        self.botNames = botNames
        self.botBase = botBase
        self.botSpread = botSpread
        self.seed = seed
        reload()
    }

    func reload() {
        unlocked = Store.shared.load("achievements", as: [String: Double].self) ?? [:]
        scores = Store.shared.load("scores", as: [Int].self) ?? []
    }

    var best: Int { scores.max() ?? 0 }
    var unlockedCount: Int { achievements.filter { unlocked[$0.id] != nil }.count }

    func isUnlocked(_ id: String) -> Bool { unlocked[id] != nil }

    func unlock(_ id: String) {
        guard unlocked[id] == nil, let def = achievements.first(where: { $0.id == id }) else { return }
        unlocked[id] = Date().timeIntervalSince1970
        Store.shared.save("achievements", unlocked)
        showToast("Achievement: " + def.title)
        Sound.shared.play("special", volume: 0.7)
    }

    func submit(_ score: Int) {
        guard score > 0 else { return }
        var list = scores
        list.append(score)
        list.sort(by: >)
        if list.count > 20 { list = Array(list.prefix(20)) }
        scores = list
        Store.shared.save("scores", list)
    }

    func showToast(_ text: String) {
        toastToken += 1
        let token = toastToken
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self = self, self.toastToken == token else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.toast = nil }
        }
    }

    /// Боты с фиксированными очками плюс лучший результат игрока.
    func leaderboard() -> [LeaderRow] {
        var rng = SeededRandom(seed: seed)
        var rows: [(String, Int, Bool)] = []
        for name in botNames {
            let score = botBase + Int(rng.next() % UInt64(max(1, botSpread)))
            rows.append((name, (score / 10) * 10, false))
        }
        if best > 0 { rows.append(("You", best, true)) }
        rows.sort { $0.1 > $1.1 }
        return rows.enumerated().map { LeaderRow(id: $0.offset, rank: $0.offset + 1, name: $0.element.0, score: $0.element.1, isPlayer: $0.element.2) }
    }

    /// Clear Data: стирает всё сохранённое и обновляет опубликованные значения.
    func clearAll() {
        Store.shared.clearAll()
        toastToken += 1
        toast = nil
        reload()
    }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func int(_ upper: Int) -> Int { Int(next() % UInt64(max(1, upper))) }
}

enum Format {
    static func number(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
}
