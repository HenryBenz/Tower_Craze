import SpriteKit
import SwiftUI

/// Состояние стройки для интерфейса SwiftUI.
final class TowerSession: ObservableObject {
    @Published var score: Int = 0
    @Published var floors: Int = 0
    @Published var bricks: Int = 0
    @Published var timeFraction: Double = 1
    @Published var nextColors: [Int] = []
    @Published var nextIsTNT = false
    @Published var chain: Int = 0
    @Published var paused = false
    @Published var over = false
    @Published var showOver = false
    let scene: TowerScene
    weak var app: TowerAppModel?

    init(app: TowerAppModel) {
        self.app = app
        scene = TowerScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        scene.session = self
    }

    func setPaused(_ value: Bool) {
        paused = value
        scene.isPaused = value
    }

    func rotate() { scene.rotatePiece() }
    func drop() { scene.dropPiece() }
    func unlock(_ id: String) { app?.progress.unlock(id) }

    func gameOver() {
        guard !over else { return }
        over = true
        app?.finishRun(score: score, floors: floors, bricks: bricks)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self = self else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { self.showOver = true }
        }
    }
}

final class TowerScene: SKScene {
    weak var session: TowerSession?
    private var board = TowerBoard()

    private let background = SKSpriteNode()
    private let shaft = SKNode()
    private let slotLayer = SKNode()
    private let brickLayer = SKNode()
    private let craneLayer = SKNode()
    private let ghostLayer = SKNode()
    private let fxLayer = SKNode()
    private let meter = SKNode()
    private let arm = SKSpriteNode()
    private let hook = SKSpriteNode()

    private var sprites: [Int: SKSpriteNode] = [:]
    private var hanging: [SKSpriteNode] = []
    private var hangingIds: [Int] = []
    private var slots: [SKSpriteNode] = []
    private var floorSprites: [SKSpriteNode] = []
    private let roof = SKSpriteNode()

    private var piece: CranePiece?
    private var nextPiece: CranePiece?
    private var cell: CGFloat = 40
    private var origin = CGPoint.zero
    private var built = false
    private var busy = false
    private var dropsMade = 0
    private var tntProgress = 0
    private var timeLeft: Double = 9
    private var lastUpdate: TimeInterval = 0
    private var touchStartX: CGFloat = 0
    private var touchStartY: CGFloat = 0
    private var touchMoved = false
    private var swipeRotated = false
    private var touchArmed = false
    private var dustEmitter: SKEmitterNode?

    static let brickColors: [UIColor] = [
        UIColor(red: 0.94, green: 0.33, blue: 0.25, alpha: 1), UIColor(red: 1, green: 0.62, blue: 0.18, alpha: 1),
        UIColor(red: 1, green: 0.85, blue: 0.23, alpha: 1), UIColor(red: 0.37, green: 0.81, blue: 0.35, alpha: 1),
        UIColor(red: 0.25, green: 0.62, blue: 0.94, alpha: 1), UIColor(red: 0.66, green: 0.42, blue: 0.94, alpha: 1)
    ]

    private var timeTotal: Double { max(4.0, 9.0 - Double(session?.floors ?? 0) * 0.4) }

    override func didMove(to view: SKView) {
        guard !built, size.width >= 1, size.height >= 1 else { return }
        built = true
        backgroundColor = UIColor(red: 0.62, green: 0.86, blue: 1, alpha: 1)
        background.texture = Art.texture("bg_site")
        background.zPosition = -20
        addChild(background)
        addChild(shaft)
        shaft.addChild(slotLayer)
        shaft.addChild(ghostLayer)
        shaft.addChild(brickLayer)
        addChild(craneLayer)
        addChild(meter)
        addChild(fxLayer)
        ghostLayer.zPosition = 2
        brickLayer.zPosition = 3
        craneLayer.zPosition = 6
        fxLayer.zPosition = 30
        arm.texture = Art.texture("crane_arm")
        hook.texture = Art.texture("crane_hook")
        craneLayer.addChild(arm)
        craneLayer.addChild(hook)
        roof.texture = Art.texture("roof")
        meter.addChild(roof)
        for c in 0..<board.cols {
            for r in 0..<board.rows {
                let s = SKSpriteNode(texture: Art.texture("slot"))
                s.name = "\(c),\(r)"
                slotLayer.addChild(s)
                slots.append(s)
            }
        }
        board.setColors(4)
        piece = board.newPiece(tnt: false)
        nextPiece = board.newPiece(tnt: false)
        layout()
        showPiece(animated: true)
        DispatchQueue.main.async { [weak self] in self?.publishNext() }
        timeLeft = timeTotal
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard built else {
            if let v = view, size.width >= 1, size.height >= 1 { didMove(to: v) }
            return
        }
        layout()
    }

    // MARK: раскладка

    private func layout() {
        let meterW: CGFloat = 64
        let top: CGFloat = 128, bottom: CGFloat = 140
        let craneRows: CGFloat = 2.3
        let availW = size.width - 36 - meterW
        let availH = max(240, size.height - top - bottom)
        cell = floor(min(availW / CGFloat(board.cols), availH / (CGFloat(board.rows) + craneRows)))
        let bw = cell * CGFloat(board.cols)
        let bh = cell * CGFloat(board.rows)
        origin = CGPoint(x: 14 + (availW - bw) / 2, y: bottom + (availH - bh - craneRows * cell) / 2)
        background.size = fill(CGSize(width: 780, height: 1688), size)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        for s in slots {
            guard let parts = s.name?.split(separator: ",").compactMap({ Int($0) }), parts.count == 2 else { continue }
            s.size = CGSize(width: cell, height: cell)
            s.position = point(Cell(c: parts[0], r: parts[1]))
        }
        for c in 0..<board.cols {
            for r in 0..<board.rows {
                if let b = board.brick(Cell(c: c, r: r)), let s = sprites[b.id] {
                    s.setScale(1)
                    s.size = CGSize(width: cell * 0.96, height: cell * 0.96)
                    s.position = point(Cell(c: c, r: r))
                }
            }
        }
        for s in hanging {
            s.setScale(1)
            s.size = CGSize(width: cell * 0.96, height: cell * 0.96)
        }
        dustEmitter?.removeFromParent()
        dustEmitter = FX.ambient(in: self, size: size, texture: Art.texture("dust"), color: .white, birthRate: 1.5, scale: 0.25, speed: 30, alpha: 0.35, spin: 0.2, z: -10)
        arm.size = CGSize(width: bw + cell * 1.2, height: cell * 0.55)
        arm.position = CGPoint(x: origin.x + bw / 2, y: origin.y + bh + cell * (craneRows - 0.1))
        layoutMeter()
        showPiece(animated: false)
    }

    private func fill(_ image: CGSize, _ box: CGSize) -> CGSize {
        let k = max(box.width / image.width, box.height / image.height)
        return CGSize(width: image.width * k, height: image.height * k)
    }

    func point(_ c: Cell) -> CGPoint {
        CGPoint(x: origin.x + (CGFloat(c.c) + 0.5) * cell, y: origin.y + (CGFloat(c.r) + 0.5) * cell)
    }

    private var hangBaseY: CGFloat { origin.y + cell * CGFloat(board.rows) + cell * 0.6 }

    private func layoutMeter() {
        let x = size.width - 14 - 30
        let w: CGFloat = 56, h: CGFloat = 21
        let floors = session?.floors ?? 0
        while floorSprites.count < floors {
            let f = SKSpriteNode(texture: Art.texture("floor"), size: CGSize(width: w, height: h))
            meter.addChild(f)
            floorSprites.append(f)
            f.alpha = 0
            f.run(.sequence([.fadeIn(withDuration: 0.12), .moveBy(x: 0, y: 6, duration: 0.1), .moveBy(x: 0, y: -6, duration: 0.1)]))
        }
        let visible = min(floorSprites.count, 18)
        for (i, f) in floorSprites.enumerated() {
            let idx = i - (floorSprites.count - visible)
            f.isHidden = idx < 0
            f.position = CGPoint(x: x, y: origin.y + h / 2 + CGFloat(max(0, idx)) * (h - 2))
        }
        roof.size = CGSize(width: w + 4, height: 24)
        roof.position = CGPoint(x: x, y: origin.y + CGFloat(visible) * (h - 2) + 12)
    }

    // MARK: кран

    private func hangingPositions(_ p: CranePiece) -> [CGPoint] {
        let base = hangBaseY
        let x = origin.x + (CGFloat(p.col) + 0.5) * cell
        guard p.b != nil else { return [CGPoint(x: x, y: base)] }
        switch p.rot {
        case 1: return [CGPoint(x: x, y: base), CGPoint(x: x + cell, y: base)]
        case 3: return [CGPoint(x: x, y: base), CGPoint(x: x - cell, y: base)]
        case 2: return [CGPoint(x: x, y: base + cell), CGPoint(x: x, y: base)]
        default: return [CGPoint(x: x, y: base), CGPoint(x: x, y: base + cell)]
        }
    }

    private func texture(_ b: Brick) -> SKTexture {
        switch b.kind {
        case .cement: return Art.texture("cement")
        case .tnt: return Art.texture("tnt")
        case .color: return Art.texture("brick_\(b.color)")
        }
    }

    private func showPiece(animated: Bool) {
        guard let p = piece else { return }
        if hanging.isEmpty {
            var bricks = [p.a]
            if let b = p.b { bricks.append(b) }
            hangingIds = bricks.map { $0.id }
            for b in bricks {
                let s = SKSpriteNode(texture: texture(b), size: CGSize(width: cell * 0.96, height: cell * 0.96))
                craneLayer.addChild(s)
                hanging.append(s)
                if b.kind == .tnt {
                    s.run(.repeatForever(.sequence([.colorize(with: .red, colorBlendFactor: 0.3, duration: 0.3), .colorize(withColorBlendFactor: 0, duration: 0.3)])), withKey: "blink")
                }
            }
        }
        let pos = hangingPositions(p)
        for (i, s) in hanging.enumerated() where i < pos.count {
            if animated {
                s.removeAction(forKey: "move")
                s.run(.move(to: pos[i], duration: 0.09), withKey: "move")
            } else {
                s.position = pos[i]
            }
        }
        let topY = pos.map { $0.y }.max() ?? hangBaseY
        let hookX = pos.map { $0.x }.reduce(0, +) / CGFloat(max(1, pos.count))
        hook.size = CGSize(width: cell * 0.8, height: cell * 1.04)
        let hookPos = CGPoint(x: hookX, y: topY + cell * 0.72)
        if animated { hook.run(.move(to: hookPos, duration: 0.09)) } else { hook.position = hookPos }
        showGhost(p)
    }

    private func showGhost(_ p: CranePiece) {
        ghostLayer.removeAllChildren()
        let spots = board.landingCells(p)
        let blocked = spots.contains { $0.1.r >= board.rows }
        for (b, c) in spots where c.r < board.rows {
            let g = SKSpriteNode(texture: texture(b))
            g.size = CGSize(width: cell * 0.9, height: cell * 0.9)
            g.position = point(c)
            g.alpha = blocked ? 0.55 : 0.28
            if blocked {
                g.color = .red
                g.colorBlendFactor = 0.75
            }
            ghostLayer.addChild(g)
        }
    }

    private func publishNext() {
        guard let n = nextPiece else { return }
        session?.nextIsTNT = n.a.kind == .tnt
        var colors = [n.a.color]
        if let b = n.b { colors.append(b.color) }
        session?.nextColors = colors
    }

    private var canAct: Bool {
        guard let s = session else { return false }
        return built && !busy && !s.paused && !s.over && piece != nil
    }

    func rotatePiece() {
        guard canAct, let p = piece, p.b != nil else { return }
        piece = board.rotate(p)
        Sound.shared.play("swap", volume: 0.6)
        Haptics.light()
        showPiece(animated: true)
        for s in hanging { s.run(.sequence([.scale(to: 1.12, duration: 0.06), .scale(to: 1, duration: 0.08)])) }
    }

    private func moveTo(column c: Int) {
        guard canAct, let p = piece else { return }
        var q = p
        q.col = c
        q = board.clamp(q)
        guard q.col != p.col else { return }
        piece = q
        Sound.shared.play("tap", volume: 0.35)
        showPiece(animated: true)
    }

    // MARK: ввод

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let pt = t.location(in: self)
        touchStartX = pt.x
        touchStartY = pt.y
        touchMoved = false
        swipeRotated = false
        touchArmed = canAct
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchArmed = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, canAct, touchArmed else { return }
        let pt = t.location(in: self)
        if abs(pt.x - touchStartX) > 10 { touchMoved = true }
        if !swipeRotated && pt.y - touchStartY > cell * 1.1 && abs(pt.x - touchStartX) < cell {
            swipeRotated = true
            touchMoved = true
            rotatePiece()
            return
        }
        if touchMoved && !swipeRotated {
            let c = Int(floor((pt.x - origin.x) / cell))
            moveTo(column: max(0, min(board.cols - 1, c)))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let armed = touchArmed
        touchArmed = false
        guard let t = touches.first, canAct, armed else { return }
        if !touchMoved && !swipeRotated {
            let pt = t.location(in: self)
            // касание по шахте: кран едет в этот столбец и сразу опускает груз
            if pt.x >= origin.x && pt.x <= origin.x + cell * CGFloat(board.cols) {
                let c = Int(floor((pt.x - origin.x) / cell))
                if let p = piece {
                    var q = p
                    q.col = c
                    piece = board.clamp(q)
                    showPiece(animated: false)
                }
                dropPiece()
            }
        }
    }

    // MARK: опускание и рассыпание

    func dropPiece() {
        guard canAct, let p = piece else { return }
        busy = true
        let result = board.drop(p)
        if result.overflow {
            collapse()
            return
        }
        ghostLayer.removeAllChildren()
        hook.run(.sequence([.moveBy(x: 0, y: -cell * 0.3, duration: 0.08), .moveBy(x: 0, y: cell * 0.3, duration: 0.12)]))
        Sound.shared.play("whoosh", volume: 0.5)
        var longest = 0.0
        for landing in result.landings {
            guard let i = hangingIds.firstIndex(of: landing.brick.id), i < hanging.count else { continue }
            let s = hanging[i]
            s.removeAction(forKey: "move")
            s.move(toParent: brickLayer)
            sprites[landing.brick.id] = s
            let target = point(landing.cell)
            let t = 0.12 + Double(max(0, (s.position.y - target.y) / cell)) * 0.035
            longest = max(longest, t)
            s.run(.sequence([
                .move(to: target, duration: t),
                .scaleY(to: 0.82, duration: 0.05), .scaleY(to: 1, duration: 0.08)
            ]))
        }
        hanging.removeAll()
        hangingIds.removeAll()
        piece = nil
        run(.wait(forDuration: longest + 0.02)) { [weak self] in
            guard let self = self else { return }
            Sound.shared.play("pop", volume: 0.7)
            Haptics.medium()
            for landing in result.landings {
                FX.burst(in: self.fxLayer, at: CGPoint(x: self.point(landing.cell).x, y: self.point(landing.cell).y - self.cell * 0.45), color: UIColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 1), count: 8, speed: 70, size: 0.35, lifetime: 0.45, texture: Art.texture("dust"))
            }
            FX.shake(self.shaft, amount: 3, duration: 0.15)
            self.run(.wait(forDuration: 0.14)) { [weak self] in self?.resolve(chain: 1) }
        }
    }

    private func resolve(chain: Int) {
        guard let s = session else { return }
        guard let step = board.resolve(chain: chain) else {
            afterResolve()
            return
        }
        s.chain = chain
        if chain >= 3 { s.unlock("chain") }
        if step.biggestGroup >= 8 { s.unlock("big") }
        var colorCount = 0
        for e in step.explosions {
            let pt = point(e)
            FX.burst(in: fxLayer, at: pt, color: UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1), count: 50, speed: 300, size: 0.55, lifetime: 0.7, texture: Art.spark)
            FX.ring(in: fxLayer, at: pt, color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), radius: cell * 1.2)
            Sound.shared.play("boom", volume: 0.9)
            Haptics.heavy()
            FX.shake(self.shaft, amount: 12, duration: 0.35)
            s.unlock("tnt")
        }
        let destroyedCement = Set(step.cementHits.filter { $0.destroyed }.map { $0.brick.id })
        for hit in step.cementHits where !hit.destroyed {
            if let sp = sprites[hit.brick.id] {
                sp.run(.sequence([.colorize(with: .black, colorBlendFactor: 0.35, duration: 0.08), .moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: -6, y: 0, duration: 0.05), .moveBy(x: 3, y: 0, duration: 0.04)]))
                FX.burst(in: fxLayer, at: sp.position, color: .gray, count: 8, speed: 90, size: 0.3, lifetime: 0.4, texture: Art.texture("chip"))
            }
        }
        for c in step.cleared {
            if c.brick.kind == .color { colorCount += 1 }
            guard let sp = sprites[c.brick.id] else { continue }
            sprites[c.brick.id] = nil
            let color = c.brick.kind == .color ? TowerScene.brickColors[c.brick.color % 6] : UIColor.gray
            FX.burst(in: fxLayer, at: sp.position, color: color, count: destroyedCement.contains(c.brick.id) ? 16 : 10, speed: 160, size: 0.45, lifetime: 0.55, texture: Art.texture("chip"))
            sp.run(.sequence([.group([.scale(to: 1.25, duration: 0.1), .fadeAlpha(to: 0.6, duration: 0.1)]), .group([.scale(to: 0.1, duration: 0.14), .fadeOut(withDuration: 0.14), .rotate(byAngle: 0.8, duration: 0.14)]), .removeFromParent()]))
        }
        let gained = (step.cleared.count * 10 + step.explosions.count * 60) * chain
        s.score += gained
        s.bricks += colorCount
        tntProgress += colorCount
        if colorCount > 0 { s.unlock("first") }
        let newFloors = s.bricks / 20
        if newFloors > s.floors {
            s.floors = newFloors
            board.setColors(4 + (newFloors >= 3 ? 1 : 0) + (newFloors >= 6 ? 1 : 0))
            layoutMeter()
            Sound.shared.play("win", volume: 0.6)
            s.app?.progress.showToast("Floor \(newFloors) complete")
            if newFloors >= 5 { s.unlock("floor5") }
            if newFloors >= 15 { s.unlock("floor15") }
        }
        if s.score >= 5000 { s.unlock("score") }
        if let first = step.cleared.first {
            FX.floatText(in: fxLayer, at: point(first.cell), text: "+\(gained)", color: .white, fontSize: chain > 1 ? 30 : 24)
            if chain > 1 { FX.floatText(in: fxLayer, at: CGPoint(x: point(first.cell).x, y: point(first.cell).y + cell), text: "Chain x\(chain)", color: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), fontSize: 22) }
        }
        Sound.shared.play(chain > 1 ? "combo" : "match", volume: 0.8)
        run(.wait(forDuration: 0.25)) { [weak self] in
            guard let self = self else { return }
            var longest = 0.05
            for f in step.falls {
                guard let sp = self.sprites[f.brick.id] else { continue }
                let t = 0.1 + Double(f.from.r - f.to.r) * 0.04
                longest = max(longest, t)
                sp.run(.sequence([.move(to: self.point(f.to), duration: t), .scaleY(to: 0.88, duration: 0.04), .scaleY(to: 1, duration: 0.06)]))
            }
            self.run(.wait(forDuration: longest + 0.08)) { [weak self] in self?.resolve(chain: chain + 1) }
        }
    }

    private func afterResolve() {
        guard let s = session else { return }
        s.chain = 0
        dropsMade += 1
        if dropsMade % 6 == 0, let landing = board.dropCement() {
            let sp = SKSpriteNode(texture: texture(landing.brick))
            sp.size = CGSize(width: cell * 0.96, height: cell * 0.96)
            let target = point(landing.cell)
            sp.position = CGPoint(x: target.x, y: size.height + cell)
            brickLayer.addChild(sp)
            sprites[landing.brick.id] = sp
            sp.run(.sequence([.move(to: target, duration: 0.35), .scaleY(to: 0.8, duration: 0.05), .scaleY(to: 1, duration: 0.08)]))
            run(.wait(forDuration: 0.36)) { [weak self] in
                Sound.shared.play("boom", volume: 0.4)
                if let self = self { FX.shake(self.shaft, amount: 6, duration: 0.2) }
            }
            run(.wait(forDuration: 0.5)) { [weak self] in self?.nextTurn() }
            return
        }
        nextTurn()
    }

    private func nextTurn() {
        guard let s = session else { return }
        if board.maxHeight >= board.rows {
            collapse()
            return
        }
        piece = nextPiece.map { board.clamp($0) }
        let tnt = tntProgress >= 30
        if tnt { tntProgress -= 30 }
        nextPiece = board.newPiece(tnt: tnt)
        publishNext()
        showPiece(animated: false)
        for sp in hanging {
            sp.alpha = 0
            sp.run(.fadeIn(withDuration: 0.18))
        }
        timeLeft = timeTotal
        s.timeFraction = 1
        busy = false
    }

    private func collapse() {
        busy = true
        piece = nil
        Sound.shared.play("lose", volume: 0.9)
        Haptics.failure()
        FX.shake(shaft, amount: 16, duration: 0.6)
        for (_, sp) in sprites {
            let dx = CGFloat.random(in: -140...140)
            sp.run(.sequence([.wait(forDuration: Double.random(in: 0...0.3)), .group([.moveBy(x: dx, y: -size.height * 0.7, duration: 0.9), .rotate(byAngle: CGFloat.random(in: -3...3), duration: 0.9), .fadeOut(withDuration: 0.9)])]))
        }
        for sp in hanging { sp.run(.fadeOut(withDuration: 0.3)) }
        session?.gameOver()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 0 : min(0.1, currentTime - lastUpdate)
        lastUpdate = currentTime
        guard let s = session else { return }
        if s.paused && !isPaused { isPaused = true; return }
        guard canAct else { return }
        timeLeft -= dt
        let frac = max(0, timeLeft / timeTotal)
        if abs(frac - s.timeFraction) > 0.01 { s.timeFraction = frac }
        if timeLeft <= 0 {
            // вертикальная пара не помещается — перед сбросом поворачиваем её
            if let p = piece, p.b != nil, board.landingCells(p).contains(where: { $0.1.r >= board.rows }) {
                for _ in 0..<3 {
                    guard let cur = piece else { break }
                    let next = board.rotate(cur)
                    piece = next
                    if !board.landingCells(next).contains(where: { $0.1.r >= board.rows }) { break }
                }
                showPiece(animated: false)
            }
            dropPiece()
        }
    }

    /// Для экранов-примеров: частично построенная шахта.
    func demo(heights: [Int]) {
        board.fillDemo(heights: heights)
        for c in 0..<board.cols {
            for r in 0..<board.rows {
                if let b = board.brick(Cell(c: c, r: r)), sprites[b.id] == nil {
                    let sp = SKSpriteNode(texture: texture(b))
                    sp.size = CGSize(width: cell * 0.96, height: cell * 0.96)
                    sp.position = point(Cell(c: c, r: r))
                    brickLayer.addChild(sp)
                    sprites[b.id] = sp
                }
            }
        }
        showPiece(animated: false)
    }
}
