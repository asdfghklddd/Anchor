// Role: the pairing card's 3D anchor (SceneKit), plus the check mark that replaces it.

#if os(iOS)
import AnchorDesign
import SceneKit
import SwiftUI
import UIKit

/// The pairing card's centerpiece. While it looks for the Mac, the anchor floats
/// in 3D. When the link comes up it turns once, draws in on itself and a check
/// pops out of the spot where it vanished.
struct ConnectionHero: View {
    let isConnected: Bool
    let size: CGFloat
    /// Turns true when the check lands, so the card's words change with it.
    @Binding var revealed: Bool

    @AnchorReducedMotion private var reduceMotion
    @State private var stage: ConnectionAnchorStage?
    @State private var showsAnchor = false
    @State private var showsCheck = false
    @State private var drawsCheck = false
    @State private var ripples = false
    @State private var landings = 0

    /// The turn's near edge swings past the mark's own bounds, so the model draws in a larger view.
    private static let overscan: CGFloat = 1.35

    var body: some View {
        ZStack {
            // The same mark, flat, holds the place from the first frame while the model warms up.
            if stage == nil, !isConnected {
                ConnectionBrandGlyph()
                    .fill(ConnectionAnchorStage.faceGradient, style: FillStyle(eoFill: true))
                    .aspectRatio(ConnectionBrandGlyph.aspect, contentMode: .fit)
                    .frame(width: size, height: size)
                    .transition(.opacity)
            }
            if showsAnchor, let stage {
                ConnectionAnchorView(stage: stage)
                    .frame(width: size * Self.overscan, height: size * Self.overscan)
                    .allowsHitTesting(false)
            }
            ripple(delay: 0, reach: 1.45)
            ripple(delay: 0.09, reach: 1.2)
            ConnectionCheckMark(drawn: drawsCheck)
                .frame(width: size * 0.64, height: size * 0.64)
                .scaleEffect(showsCheck || reduceMotion ? 1 : 0.2)
                .opacity(showsCheck ? 1 : 0)
        }
        .frame(width: size, height: size)
        .sensoryFeedback(.success, trigger: landings)
        .accessibilityHidden(true)
        .task(id: isConnected) {
            if isConnected { await connect() } else { await search() }
        }
    }

    private func ripple(delay: Double, reach: CGFloat) -> some View {
        Circle()
            .strokeBorder(ConnectionCheckMark.tint.opacity(0.42), lineWidth: ripples ? 0.5 : 4)
            .frame(width: size * 0.5, height: size * 0.5)
            .scaleEffect(ripples ? reach * 2 : 1)
            .opacity(ripples ? 0 : (showsCheck ? 1 : 0))
            .animation(ripples ? .easeOut(duration: 0.72).delay(delay) : nil, value: ripples)
    }

    private func connect() async {
        // Opened while already linked, or told to keep still: nothing to watch turn.
        guard let stage, showsAnchor, !reduceMotion else {
            land(celebrates: stage != nil)
            if stage != nil { showsAnchor = false }
            return
        }
        stage.playConnected()
        guard await pause(ConnectionAnchorStage.collapse) else { return }
        land(celebrates: true)
        guard await pause(0.3) else { return }
        showsAnchor = false
    }

    private func land(celebrates: Bool) {
        let pop: Animation = reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.56)
        withAnimation(pop) { showsCheck = true }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.13)) { drawsCheck = true }
        withAnimation(AnchorMotion.panel) { revealed = true }
        guard celebrates else { return }
        landings += 1
        AnchorSound.shared.play(.rejoin)
        if !reduceMotion { ripples = true }
    }

    private func search() async {
        withAnimation(AnchorMotion.panel) {
            showsCheck = false
            revealed = false
        }
        drawsCheck = false
        ripples = false
        if let stage {
            // Back from a dropped link: the anchor grows out of where the check was.
            stage.playSearching(moves: !reduceMotion, grows: !reduceMotion)
            showsAnchor = true
            return
        }
        // Let the native sheet start moving before the model takes the GPU.
        guard await pause(0.08) else { return }
        let built = ConnectionAnchorStage()
        await built.prepare()
        guard !Task.isCancelled else { return }
        built.playSearching(moves: !reduceMotion, grows: false)
        stage = built
        showsAnchor = true
    }

    /// False when the link changed in the meantime and another sequence has taken over.
    private func pause(_ seconds: Double) async -> Bool {
        do { try await Task.sleep(for: .seconds(seconds)) } catch { return false }
        return !Task.isCancelled
    }
}

/// The check that replaces the anchor: a lit disc with its stroke drawn in.
private struct ConnectionCheckMark: View {
    static let tint = Color(red: 0.16, green: 0.78, blue: 0.47)
    let drawn: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red: 0.32, green: 0.90, blue: 0.56), Self.tint,
                                                  Color(red: 0.05, green: 0.60, blue: 0.40)],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: Self.tint.opacity(0.42), radius: side * 0.12, y: side * 0.07)
                // Light falling on the upper half, so the disc sits with the 3D anchor.
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: side * 0.8, height: side * 0.56)
                    .blur(radius: side * 0.02)
                    .offset(y: -side * 0.17)
                Checkmark()
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(.white, style: StrokeStyle(lineWidth: side * 0.105, lineCap: .round, lineJoin: .round))
                    .frame(width: side * 0.5, height: side * 0.38)
                    .shadow(color: .black.opacity(0.14), radius: side * 0.02, y: side * 0.015)
            }
            .frame(width: side, height: side)
        }
    }

    private struct Checkmark: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            return path
        }
    }
}

/// Hosts the SceneKit view. A flat copy holds the place while the scene prepares.
private struct ConnectionAnchorView: UIViewRepresentable {
    let stage: ConnectionAnchorStage
    func makeUIView(context: Context) -> SCNView { stage.view }
    func updateUIView(_ view: SCNView, context: Context) {}
}

/// Anchor's mark extruded into a real model, lit, with the moves the card plays on it.
@MainActor
final class ConnectionAnchorStage {
    /// When the turn has nearly finished and the model has drawn in to nothing.
    static let collapse: Double = 1.12
    /// The logo's own blues.
    private static let top = (red: 0.30, green: 0.76, blue: 1.0)
    private static let bottom = (red: 0.05, green: 0.47, blue: 0.97)
    static let faceGradient = LinearGradient(
        colors: [Color(red: top.red, green: top.green, blue: top.blue),
                 Color(red: bottom.red, green: bottom.green, blue: bottom.blue)],
        startPoint: .top, endPoint: .bottom)

    let view = SCNView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
    private let scene = SCNScene()
    /// Bobs and tips, like something afloat.
    private let float = SCNNode()
    private let turn = SCNNode()
    private let shrink = SCNNode()

    init() {
        view.scene = scene
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.isUserInteractionEnabled = false
        view.autoenablesDefaultLighting = false

        scene.rootNode.addChildNode(float)
        float.addChildNode(turn)
        turn.addChildNode(shrink)
        shrink.addChildNode(SCNNode(geometry: Self.model()))

        let camera = SCNCamera()
        camera.fieldOfView = 24
        camera.wantsHDR = false
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        // Frames the mark's 10.2 units at the size the hero expects, with the overscan around it.
        cameraNode.position = SCNVector3(0, 0, 32.4)
        scene.rootNode.addChildNode(cameraNode)

        scene.lightingEnvironment.contents = Self.studio()
        scene.lightingEnvironment.intensity = 1.5

        let key = SCNLight()
        key.type = .directional
        key.intensity = 620
        key.color = UIColor.white
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.75, -0.5, 0)
        scene.rootNode.addChildNode(keyNode)
    }

    func prepare() async {
        _ = await view.prepare([scene])
    }

    /// Starts facing front, so it takes over from the flat mark without a jump.
    func playSearching(moves: Bool, grows: Bool) {
        [float, turn, shrink].forEach { $0.removeAllActions() }
        float.position = SCNVector3Zero
        float.eulerAngles = SCNVector3Zero
        turn.eulerAngles = SCNVector3(0, moves ? 0 : -0.2, 0)
        shrink.scale = SCNVector3(1, 1, 1)
        guard moves else { return }
        if grows {
            shrink.scale = SCNVector3(0.4, 0.4, 0.4)
            let swell = SCNAction.scale(to: 1.05, duration: 0.3)
            swell.timingMode = .easeOut
            let settle = SCNAction.scale(to: 1, duration: 0.2)
            settle.timingMode = .easeInEaseOut
            shrink.runAction(.sequence([swell, settle]))
        }
        turn.runAction(.sequence([
            Self.gentle(.rotateTo(x: 0, y: -Self.sway, z: 0, duration: 1.5)),
            .repeatForever(.sequence([
                Self.gentle(.rotateTo(x: 0, y: Self.sway, z: 0, duration: 2.8)),
                Self.gentle(.rotateTo(x: 0, y: -Self.sway, z: 0, duration: 2.8)),
            ])),
        ]))
        let rise = Self.gentle(.moveBy(x: 0, y: 0.24, z: 0, duration: 2.1))
        float.runAction(.repeatForever(.sequence([rise, Self.gentle(.moveBy(x: 0, y: -0.24, z: 0, duration: 2.1))])))
        float.runAction(.repeatForever(.sequence([
            Self.gentle(.rotateTo(x: -0.07, y: 0, z: 0.025, duration: 3.3)),
            Self.gentle(.rotateTo(x: 0.07, y: 0, z: -0.025, duration: 3.3)),
        ])))
    }

    /// One full turn from wherever the sway has it, then in on itself before the turn quite ends.
    func playConnected() {
        let yaw = turn.presentation.eulerAngles.y
        let position = float.presentation.position
        let tilt = float.presentation.eulerAngles
        [float, turn, shrink].forEach { $0.removeAllActions() }
        turn.eulerAngles.y = yaw
        float.position = position
        float.eulerAngles = tilt

        let level = SCNAction.group([.move(to: SCNVector3Zero, duration: 0.4),
                                     .rotateTo(x: 0, y: 0, z: 0, duration: 0.4)])
        level.timingMode = .easeOut
        float.runAction(level)

        let windUp = SCNAction.rotateTo(x: 0, y: CGFloat(yaw) - 0.28, z: 0, duration: 0.16)
        windUp.timingMode = .easeOut
        let around = SCNAction.rotateTo(x: 0, y: .pi * 2, z: 0, duration: 1.0)
        around.timingFunction = ConnectionAnchorEasing.turn
        turn.runAction(.sequence([windUp, around]))

        let breath = SCNAction.scale(to: 1.09, duration: 0.1)
        breath.timingMode = .easeOut
        let inward = SCNAction.scale(to: 0.001, duration: 0.26)
        inward.timingFunction = ConnectionAnchorEasing.inward
        shrink.runAction(.sequence([.wait(duration: Self.collapse - 0.36), breath, inward]))
    }

    private static let sway: CGFloat = 0.36

    private static func gentle(_ action: SCNAction) -> SCNAction {
        action.timingMode = .easeInEaseOut
        return action
    }

    /// The mark, centered on the origin with its height in scene units and its top up.
    private static func model() -> SCNGeometry {
        let height = 100 / ConnectionBrandGlyph.aspect
        let glyph = ConnectionBrandGlyph().path(in: CGRect(x: 0, y: 0, width: 100, height: height))
        var placed = CGAffineTransform(scaleX: 0.1, y: -0.1).translatedBy(x: -50, y: -height / 2)
        let outline = UIBezierPath(cgPath: glyph.cgPath.copy(using: &placed) ?? glyph.cgPath)
        outline.usesEvenOddFillRule = true
        outline.flatness = 0.012

        let shape = SCNShape(path: outline, extrusionDepth: 1.25)
        shape.chamferMode = .both
        shape.chamferRadius = 0.07

        let face = material(contents: gradient([UIColor(red: top.red, green: top.green, blue: top.blue, alpha: 1),
                                                UIColor(red: bottom.red, green: bottom.green, blue: bottom.blue, alpha: 1)]),
                            metalness: 0.25, roughness: 0.3)
        let side = material(contents: UIColor(red: 0, green: 0.34, blue: 0.84, alpha: 1), metalness: 0.05, roughness: 0.5)
        let rim = material(contents: UIColor(red: 0.34, green: 0.76, blue: 1, alpha: 1), metalness: 0.1, roughness: 0.34)
        shape.materials = [face, face, side, rim, rim]
        return shape
    }

    private static func material(contents: Any, metalness: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = contents
        material.metalness.contents = metalness
        material.roughness.contents = roughness
        return material
    }

    private static func gradient(_ colors: [UIColor]) -> UIImage {
        let size = CGSize(width: 4, height: 128)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cgColors = colors.map(\.cgColor) as CFArray
            guard let shade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil)
            else { return }
            context.cgContext.drawLinearGradient(shade, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    /// A soft studio to reflect: a bright overhead, a cool floor, and a window for the highlight to sweep past.
    private static func studio() -> UIImage {
        let size = CGSize(width: 512, height: 256)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let colors = [UIColor(white: 1, alpha: 1), UIColor(red: 0.62, green: 0.82, blue: 0.95, alpha: 1),
                          UIColor(red: 0.08, green: 0.22, blue: 0.40, alpha: 1)].map(\.cgColor) as CFArray
            if let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.48, 1]) {
                cg.drawLinearGradient(sky, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            cg.setFillColor(UIColor.white.cgColor)
            for x in stride(from: CGFloat(30), to: size.width, by: 150) {
                cg.fill(CGRect(x: x, y: 50, width: 38, height: 90))
            }
        }
    }
}

/// Runs on SceneKit's render thread, so these must stay free of any actor.
private enum ConnectionAnchorEasing {
    nonisolated static let turn: @Sendable (Float) -> Float = { t in
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }
    nonisolated static let inward: @Sendable (Float) -> Float = { t in t * t * t }
}
#endif
