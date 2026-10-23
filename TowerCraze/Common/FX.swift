import SpriteKit
import UIKit

/// Текстуры из Resources/Art и готовые эффекты для SpriteKit.
enum Art {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ name: String) -> SKTexture {
        if let t = cache[name] { return t }
        let t = SKTexture(imageNamed: name)
        t.filteringMode = .linear
        cache[name] = t
        return t
    }

    static func image(_ name: String) -> UIImage {
        UIImage(named: name) ?? UIImage()
    }

    /// Мягкая круглая точка для частиц (рисуется кодом, чтобы не зависеть от файлов).
    static let dot: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 16, y: 16), startRadius: 0, endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
            }
        }
        return SKTexture(image: img)
    }()

    static let spark: SKTexture = {
        let size = CGSize(width: 24, height: 24)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 12, y: 0)); p.addLine(to: CGPoint(x: 14, y: 10)); p.addLine(to: CGPoint(x: 24, y: 12))
            p.addLine(to: CGPoint(x: 14, y: 14)); p.addLine(to: CGPoint(x: 12, y: 24)); p.addLine(to: CGPoint(x: 10, y: 14))
            p.addLine(to: CGPoint(x: 0, y: 12)); p.addLine(to: CGPoint(x: 10, y: 10)); p.close()
            UIColor.white.setFill(); p.fill()
        }
        return SKTexture(image: img)
    }()
}

enum FX {
    /// Разлёт частиц в точке (одноразовый эмиттер, сам удаляется).
    static func burst(in parent: SKNode, at point: CGPoint, color: UIColor, count: Int = 24, speed: CGFloat = 180,
                      size: CGFloat = 0.35, lifetime: CGFloat = 0.6, texture: SKTexture = Art.dot, z: CGFloat = 50) {
        let e = SKEmitterNode()
        e.particleTexture = texture
        e.particleBirthRate = CGFloat(count) * 20
        e.numParticlesToEmit = count
        e.particleLifetime = lifetime
        e.particleLifetimeRange = lifetime * 0.5
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.6
        e.emissionAngleRange = .pi * 2
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1.0 / lifetime
        e.particleScale = size
        e.particleScaleRange = size * 0.5
        e.particleScaleSpeed = -size / lifetime
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        e.yAcceleration = -120
        e.position = point
        e.zPosition = z
        parent.addChild(e)
        e.run(.sequence([.wait(forDuration: Double(lifetime) * 2 + 0.2), .removeFromParent()]))
    }

    /// Всплывающий текст очков.
    static func floatText(in parent: SKNode, at point: CGPoint, text: String, color: UIColor, fontSize: CGFloat = 26, z: CGFloat = 60) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.position = point
        label.zPosition = z
        label.verticalAlignmentMode = .center
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = text
        shadow.fontSize = fontSize
        shadow.fontColor = UIColor.black.withAlphaComponent(0.35)
        shadow.position = CGPoint(x: 1.5, y: -2)
        shadow.zPosition = -1
        shadow.verticalAlignmentMode = .center
        label.addChild(shadow)
        label.setScale(0.4)
        parent.addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.18), .moveBy(x: 0, y: 18, duration: 0.18)]),
            .group([.moveBy(x: 0, y: 46, duration: 0.7), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]),
            .removeFromParent()
        ]))
    }

    /// Встряска узла (камера или поле).
    static func shake(_ node: SKNode, amount: CGFloat = 8, duration: Double = 0.3) {
        let data = node.userData ?? NSMutableDictionary()
        node.userData = data
        let origin: CGPoint
        if let saved = data["shakeOrigin"] as? NSValue {
            origin = saved.cgPointValue
        } else {
            origin = node.position
            data["shakeOrigin"] = NSValue(cgPoint: origin)
        }
        var actions: [SKAction] = []
        let steps = 8
        for i in 0..<steps {
            let k = amount * CGFloat(steps - i) / CGFloat(steps)
            actions.append(.move(to: CGPoint(x: origin.x + CGFloat.random(in: -k...k), y: origin.y + CGFloat.random(in: -k...k)), duration: duration / Double(steps)))
        }
        actions.append(.move(to: origin, duration: 0.02))
        actions.append(.run { node.userData?.removeObject(forKey: "shakeOrigin") })
        node.removeAction(forKey: "shake")
        node.run(.sequence(actions), withKey: "shake")
    }

    /// Кольцевая волна.
    static func ring(in parent: SKNode, at point: CGPoint, color: UIColor, radius: CGFloat, z: CGFloat = 45) {
        let ring = SKShapeNode(circleOfRadius: radius * 0.3)
        ring.strokeColor = color
        ring.lineWidth = 6
        ring.fillColor = .clear
        ring.glowWidth = 4
        ring.position = point
        ring.zPosition = z
        parent.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 3.4, duration: 0.45), .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
    }

    /// Непрерывный фон из падающих частиц (снег, перья, конфетти).
    static func ambient(in parent: SKNode, size: CGSize, texture: SKTexture, color: UIColor, birthRate: CGFloat, scale: CGFloat,
                        speed: CGFloat, alpha: CGFloat = 0.6, spin: CGFloat = 0, z: CGFloat = -5) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = texture
        e.particleBirthRate = birthRate
        e.particleLifetime = size.height / max(speed, 1) * 1.3
        e.particlePositionRange = CGVector(dx: size.width * 1.2, dy: 0)
        e.position = CGPoint(x: size.width / 2, y: size.height + 20)
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.35
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.4
        e.particleScale = scale
        e.particleScaleRange = scale * 0.6
        e.particleAlpha = alpha
        e.particleAlphaRange = alpha * 0.4
        e.particleRotationRange = .pi * 2
        e.particleRotationSpeed = spin
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.zPosition = z
        e.advanceSimulationTime(Double(e.particleLifetime))
        parent.addChild(e)
        return e
    }
}
