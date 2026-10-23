import Foundation

// Логика Tower Craze: шахта 6 столбцов × 11 рядов, ряд 0 — нижний.
// Кран опускает пару кирпичей (её можно поворачивать). Соседние по стороне кирпичи одного цвета группой от трёх рассыпаются.
// Цементный блок стоит, пока рядом дважды не рассыплется группа. Динамит взрывает квадрат 3×3 при посадке или от соседнего взрыва.

enum BrickKind: Int {
    case color, cement, tnt
}

struct Brick: Equatable {
    let id: Int
    var color: Int
    var kind: BrickKind
    var hp: Int
}

struct Cell: Hashable {
    let c: Int
    let r: Int
}

struct Landing {
    let brick: Brick
    let cell: Cell
}

struct Dropped {
    var landings: [Landing] = []
    var overflow = false
}

struct BrickFall {
    let brick: Brick
    let from: Cell
    let to: Cell
}

struct CementHit {
    let brick: Brick
    let cell: Cell
    let destroyed: Bool
}

struct ClearStep {
    var cleared: [Landing] = []
    var explosions: [Cell] = []
    var cementHits: [CementHit] = []
    var falls: [BrickFall] = []
    var chain = 1
    var biggestGroup = 0
}

/// Пара кирпичей на крюке. rot: 0 — второй сверху, 1 — справа, 2 — снизу, 3 — слева. Одиночный динамит — b == nil.
struct CranePiece {
    var a: Brick
    var b: Brick?
    var rot: Int
    var col: Int

    var columns: [Int] {
        guard b != nil else { return [col] }
        switch rot {
        case 1: return [col, col + 1]
        case 3: return [col - 1, col]
        default: return [col]
        }
    }
}

final class TowerBoard {
    let cols = 6
    let rows = 11
    private(set) var grid: [[Brick?]]
    private var nextId = 1
    private var pendingTNT: [Cell] = []
    private(set) var colors = 4

    init() {
        grid = Array(repeating: [Brick?](repeating: nil, count: 11), count: 6)
    }

    func brick(_ cell: Cell) -> Brick? {
        guard cell.c >= 0, cell.c < cols, cell.r >= 0, cell.r < rows else { return nil }
        return grid[cell.c][cell.r]
    }

    func height(_ c: Int) -> Int {
        var h = 0
        for r in 0..<rows where grid[c][r] != nil { h = r + 1 }
        return h
    }

    var maxHeight: Int { (0..<cols).map { height($0) }.max() ?? 0 }

    func setColors(_ n: Int) { colors = max(3, min(6, n)) }

    private func make(_ color: Int, _ kind: BrickKind = .color) -> Brick {
        let b = Brick(id: nextId, color: color, kind: kind, hp: kind == .cement ? 2 : 1)
        nextId += 1
        return b
    }

    func newPiece(tnt: Bool) -> CranePiece {
        if tnt { return CranePiece(a: make(-1, .tnt), b: nil, rot: 0, col: 2) }
        return CranePiece(a: make(Int.random(in: 0..<colors)), b: make(Int.random(in: 0..<colors)), rot: 0, col: 2)
    }

    /// Сдвигает столбец крана так, чтобы пара помещалась в шахту.
    func clamp(_ p: CranePiece) -> CranePiece {
        var q = p
        let cs = q.columns
        if let lo = cs.min(), lo < 0 { q.col += -lo }
        if let hi = q.columns.max(), hi >= cols { q.col -= hi - (cols - 1) }
        return q
    }

    func rotate(_ p: CranePiece) -> CranePiece {
        guard p.b != nil else { return p }
        var q = p
        q.rot = (q.rot + 1) % 4
        return clamp(q)
    }

    /// Где приземлится каждый кирпич (для призрачной подсказки).
    func landingCells(_ p: CranePiece) -> [(Brick, Cell)] {
        guard let b = p.b else { return [(p.a, Cell(c: p.col, r: height(p.col)))] }
        switch p.rot {
        case 1, 3:
            let ca = p.col, cb = p.rot == 1 ? p.col + 1 : p.col - 1
            return [(p.a, Cell(c: ca, r: height(ca))), (b, Cell(c: cb, r: height(cb)))]
        case 2:
            let h = height(p.col)
            return [(b, Cell(c: p.col, r: h)), (p.a, Cell(c: p.col, r: h + 1))]
        default:
            let h = height(p.col)
            return [(p.a, Cell(c: p.col, r: h)), (b, Cell(c: p.col, r: h + 1))]
        }
    }

    func drop(_ p: CranePiece) -> Dropped {
        var out = Dropped()
        let spots = landingCells(clamp(p))
        if spots.contains(where: { $0.1.r >= rows }) {
            out.overflow = true
            return out
        }
        for (brick, cell) in spots {
            grid[cell.c][cell.r] = brick
            out.landings.append(Landing(brick: brick, cell: cell))
            if brick.kind == .tnt { pendingTNT.append(cell) }
        }
        return out
    }

    /// Цементный блок падает в случайный невысокий столбец. nil — места нет.
    func dropCement() -> Landing? {
        let open = (0..<cols).filter { height($0) < rows - 1 }
        guard !open.isEmpty else { return nil }
        let lowest = open.min(by: { height($0) < height($1) }) ?? open[0]
        let c = Bool.random() ? lowest : open.randomElement() ?? lowest
        let cell = Cell(c: c, r: height(c))
        let b = make(-1, .cement)
        grid[cell.c][cell.r] = b
        return Landing(brick: b, cell: cell)
    }

    private func neighbours(_ cell: Cell) -> [Cell] {
        [Cell(c: cell.c + 1, r: cell.r), Cell(c: cell.c - 1, r: cell.r), Cell(c: cell.c, r: cell.r + 1), Cell(c: cell.c, r: cell.r - 1)]
            .filter { $0.c >= 0 && $0.c < cols && $0.r >= 0 && $0.r < rows }
    }

    func groups() -> [[Cell]] {
        var seen: Set<Cell> = []
        var result: [[Cell]] = []
        for c in 0..<cols {
            for r in 0..<rows {
                let start = Cell(c: c, r: r)
                guard !seen.contains(start), let b = grid[c][r], b.kind == .color else { continue }
                var group: [Cell] = []
                var stack = [start]
                seen.insert(start)
                while let cur = stack.popLast() {
                    group.append(cur)
                    for n in neighbours(cur) where !seen.contains(n) {
                        if let nb = grid[n.c][n.r], nb.kind == .color, nb.color == b.color {
                            seen.insert(n)
                            stack.append(n)
                        }
                    }
                }
                result.append(group)
            }
        }
        return result
    }

    /// Один шаг рассыпания. nil — больше ничего не происходит.
    func resolve(chain: Int) -> ClearStep? {
        var step = ClearStep()
        step.chain = chain
        var clear: Set<Cell> = []
        for g in groups() where g.count >= 3 {
            g.forEach { clear.insert($0) }
            step.biggestGroup = max(step.biggestGroup, g.count)
        }
        // динамит: только что опущенный и соседний с рассыпавшейся группой
        var tntQueue = pendingTNT
        pendingTNT.removeAll()
        for cell in clear {
            for n in neighbours(cell) where grid[n.c][n.r]?.kind == .tnt { tntQueue.append(n) }
        }
        var exploded: Set<Cell> = []
        while let t = tntQueue.popLast() {
            guard !exploded.contains(t), grid[t.c][t.r]?.kind == .tnt else { continue }
            exploded.insert(t)
            step.explosions.append(t)
            for dc in -1...1 {
                for dr in -1...1 {
                    let n = Cell(c: t.c + dc, r: t.r + dr)
                    guard n.c >= 0, n.c < cols, n.r >= 0, n.r < rows, let nb = grid[n.c][n.r] else { continue }
                    if nb.kind == .tnt && !exploded.contains(n) { tntQueue.append(n) }
                    clear.insert(n)
                }
            }
        }
        // цемент рядом с рассыпавшимися кирпичами трескается
        var hitCement: Set<Cell> = []
        for cell in clear {
            for n in neighbours(cell) where !clear.contains(n) && !hitCement.contains(n) {
                if let nb = grid[n.c][n.r], nb.kind == .cement { hitCement.insert(n) }
            }
        }
        if clear.isEmpty { return nil }
        for n in hitCement {
            guard var nb = grid[n.c][n.r] else { continue }
            nb.hp -= 1
            if nb.hp <= 0 {
                clear.insert(n)
                step.cementHits.append(CementHit(brick: nb, cell: n, destroyed: true))
            } else {
                grid[n.c][n.r] = nb
                step.cementHits.append(CementHit(brick: nb, cell: n, destroyed: false))
            }
        }
        for cell in clear {
            if let b = grid[cell.c][cell.r] {
                step.cleared.append(Landing(brick: b, cell: cell))
                grid[cell.c][cell.r] = nil
            }
        }
        for c in 0..<cols {
            var write = 0
            for r in 0..<rows {
                if let b = grid[c][r] {
                    if r != write {
                        grid[c][write] = b
                        grid[c][r] = nil
                        step.falls.append(BrickFall(brick: b, from: Cell(c: c, r: r), to: Cell(c: c, r: write)))
                    }
                    write += 1
                }
            }
        }
        return step
    }

    /// Для экранов-примеров: заполнить шахту до заданной высоты без готовых групп.
    func fillDemo(heights: [Int]) {
        for c in 0..<cols {
            for r in 0..<min(rows, heights[c]) {
                var color = Int.random(in: 0..<colors)
                for _ in 0..<10 {
                    let left = c > 0 ? grid[c - 1][r]?.color : nil
                    let below = r > 0 ? grid[c][r - 1]?.color : nil
                    if color != left && color != below { break }
                    color = Int.random(in: 0..<colors)
                }
                grid[c][r] = (r == 0 && c % 3 == 1) ? make(-1, .cement) : make(color)
            }
        }
    }
}
