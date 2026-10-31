#if os(iOS)
import AnchorDesign
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import AnchorIOSFeatures

/// Not a check: draws every pet's every act with the app's own renderer, for
/// print and merchandise. Per pet: each act as PNG frames, a looping GIF and an
/// SVG key frame, a portrait, an overview sheet and the palette. Runs only when
/// `ANCHOR_PET_EXPORT` names a folder; `scripts/export-pets.sh` sets it and zips the result.
private let exportFolder = ProcessInfo.processInfo.environment["ANCHOR_PET_EXPORT"]
    .map { URL(fileURLWithPath: $0, isDirectory: true) }

@Suite("Desk pet export", .enabled(if: exportFolder != nil))
@MainActor
struct DeskPetExport {

    /// Room around the sprite for props (z's, confetti, a spout, sparkles).
    private static let side = 12
    private static let above = 14
    private static let below = 3
    /// Output pixels per sprite cell.
    private static let frameScale = 20
    private static let gifScale = 8
    private static let portraitScale = 40

    static let pets: [DeskPetKind] = DeskPetKind.allCases.filter { $0 != .off }

    /// What every pet does.
    static let everyone: [DeskPetAct] = [
        .idle, .move, .dash, .pebble, .look, .gaze, .yawn, .stretch, .nap, .sleep, .coffee, .reach, .water,
        .found, .offer, .type, .think, .wave, .celebrate, .fail, .happy, .petted, .startled,
    ]

    /// What only this pet does.
    static func own(_ kind: DeskPetKind) -> [DeskPetAct] {
        switch kind {
        case .crab: [.snap, .build, .angry, .sulk]
        case .whale: [.spout, .sing, .splash, .sulk]
        case .octopus: [.juggle, .read, .ink, .flee]
        case .hermit: [.polish, .hide, .peek]
        case .jelly: [.glow, .sway, .meditate, .zap, .flee]
        case .starfish: [.twinkle, .shades, .scope, .wish, .cling, .dizzy]
        case .off: []
        }
    }

    /// Frames in one loop, at 8 a second, as long as the act runs in the app.
    static func frames(_ act: DeskPetAct) -> Int {
        switch act {
        case .yawn, .happy, .startled, .zap: 12
        case .look, .stretch, .reach, .peek, .celebrate, .wave: 16
        case .found, .petted, .ink: 20
        case .offer, .angry, .dizzy, .polish, .snap, .spout: 24
        case .fail: 28
        case .idle, .move, .dash, .pebble, .flee, .water, .glow, .twinkle: 32
        case .gaze, .sway, .cling: 40
        case .nap, .sleep, .coffee, .type, .think, .build, .juggle, .shades, .sulk, .splash, .scope, .wish: 48
        case .hide: 56
        case .read, .meditate, .sing: 64
        }
    }

    /// The frame that shows the act best, for the SVG and the overview.
    static func key(_ act: DeskPetAct) -> Int {
        switch act {
        case .happy, .celebrate, .stretch: 5
        case .spout: 9
        case .found, .startled: 2
        case .peek: 12
        case .idle: 0
        default: frames(act) / 2
        }
    }

    static let names: [DeskPetAct: String] = [
        .idle: "发呆", .move: "走路", .dash: "小跑", .pebble: "搬宝贝", .look: "左右张望", .gaze: "凝望",
        .yawn: "打哈欠", .stretch: "伸懒腰", .nap: "打盹", .sleep: "睡觉", .coffee: "喝咖啡", .reach: "够东西",
        .water: "浇花", .found: "发现宝贝", .offer: "献宝", .type: "敲键盘", .think: "想一想", .wave: "挥手",
        .celebrate: "庆祝", .fail: "出错了", .happy: "开心跳", .petted: "被摸摸", .startled: "吓一跳",
        .angry: "生气", .sulk: "背过身闹别扭", .snap: "夹钳子", .build: "敲敲打打", .juggle: "抛泡泡",
        .read: "看书", .ink: "喷墨", .flee: "逃跑", .polish: "擦宝贝", .hide: "缩进壳里", .peek: "偷看",
        .glow: "发光", .sway: "摇摆听歌", .meditate: "冥想漂浮", .zap: "电一下", .spout: "喷水", .sing: "唱歌",
        .splash: "玩水", .twinkle: "闪闪发光", .shades: "戴墨镜", .scope: "望远镜", .wish: "许愿",
        .cling: "紧紧贴地", .dizzy: "转晕了",
    ]

    static let petNames: [DeskPetKind: String] = [
        .crab: "小螃蟹", .whale: "小鲸鱼", .octopus: "小章鱼", .hermit: "寄居蟹", .jelly: "小水母", .starfish: "小海星",
    ]

    @Test func exportEveryPetsEveryAct() throws {
        let root = try #require(exportFolder)
        let files = FileManager.default
        try? files.removeItem(at: root)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        var readme = "Anchor 宠物动作导出 · Every pet, every act\n\n"
        readme += "每个动作：frames/ 为逐帧透明 PNG（每像素格 \(Self.frameScale)px），.gif 为 8 帧每秒循环动画，"
        readme += ".svg 为代表帧的矢量图（每格一个方块，可无损放大印刷）。\n"
        readme += "Each act: frames/ are transparent PNGs (\(Self.frameScale)px per cell), the .gif loops at 8 fps, "
        readme += "the .svg is the key frame as vectors for print.\n"

        for kind in Self.pets {
            let look = DeskPetLook.of(kind)
            let pet = root.appending(path: kind.rawValue, directoryHint: .isDirectory)
            try files.createDirectory(at: pet, withIntermediateDirectories: true)
            let acts = Self.everyone + Self.own(kind)
            readme += "\n\(kind.rawValue) · \(Self.petNames[kind] ?? "") — \(acts.count) acts\n"

            var keys: [(DeskPetAct, CGImage)] = []
            for (index, act) in acts.enumerated() {
                let name = String(format: "%02d-%@", index + 1, act.rawValue)
                let folder = pet.appending(path: name, directoryHint: .isDirectory)
                let framesFolder = folder.appending(path: "frames", directoryHint: .isDirectory)
                try files.createDirectory(at: framesFolder, withIntermediateDirectories: true)
                let cells = try (0..<Self.frames(act)).map { try #require(image(kind, frame(look, act, $0))) }
                for (i, cell) in cells.enumerated() {
                    try write(png: scaled(cell, Self.frameScale),
                              to: framesFolder.appending(path: String(format: "%@-%03d.png", act.rawValue, i)))
                }
                try writeGIF(cells.map { scaled($0, Self.gifScale) }, to: folder.appending(path: "\(act.rawValue).gif"))
                let key = cells[min(Self.key(act), cells.count - 1)]
                try svg(key).write(to: folder.appending(path: "\(act.rawValue).svg"), atomically: true, encoding: .utf8)
                keys.append((act, key))
                readme += "  \(name)  \(Self.names[act] ?? "")  (\(cells.count) frames)\n"
            }

            let still = try #require(image(kind, DeskPetFrame(still: true)))
            try write(png: scaled(still, Self.portraitScale), to: pet.appending(path: "portrait.png"))
            try svg(still).write(to: pet.appending(path: "portrait.svg"), atomically: true, encoding: .utf8)
            try write(png: try #require(overview(kind, keys)), to: pet.appending(path: "overview.png"))
            try palette(look).write(to: pet.appending(path: "palette.txt"), atomically: true, encoding: .utf8)
        }
        try readme.write(to: root.appending(path: "README.txt"), atomically: true, encoding: .utf8)
    }

    // MARK: Drawing

    /// The act at frame `i`, facing the way the pet is drawn.
    private func frame(_ look: DeskPetLook, _ act: DeskPetAct, _ i: Int) -> DeskPetFrame {
        // Idle shows its blink; everything else runs as in the app.
        DeskPetFrame(act: act, progress: i, length: Self.frames(act), tick: i,
                     facing: look.profile == 0 ? 1 : look.profile, blink: act == .idle && (i == 20 || i == 23))
    }

    private static func size(_ look: DeskPetLook) -> (width: Int, height: Int) {
        (look.width + 2 * side, look.height + above + below)
    }

    /// One cell per pixel, on a clear background.
    private func image(_ kind: DeskPetKind, _ frame: DeskPetFrame) -> CGImage? {
        let look = DeskPetLook.of(kind)
        let size = Self.size(look)
        let view = Canvas { context, _ in
            DeskPetRenderer(look: look, kind: kind, context: context, left: Self.side,
                            ground: size.height - Self.below, pixel: 1).draw(frame)
        }
        .frame(width: CGFloat(size.width), height: CGFloat(size.height))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.cgImage
    }

    private func scaled(_ image: CGImage, _ factor: Int) -> CGImage {
        let context = CGContext(data: nil, width: image.width * factor, height: image.height * factor,
                                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
        return context.makeImage()!
    }

    /// Straight RGBA, row by row from the top.
    private func pixels(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    /// Each run of same-colored cells in a row as one square-edged rectangle.
    private func svg(_ image: CGImage) -> String {
        let bytes = pixels(image)
        let (w, h) = (image.width, image.height)
        var body = ""
        for y in 0..<h {
            var x = 0
            while x < w {
                let i = (y * w + x) * 4
                guard bytes[i + 3] > 127 else { x += 1; continue }
                let hex = String(format: "%02X%02X%02X", bytes[i], bytes[i + 1], bytes[i + 2])
                var run = 1
                while x + run < w {
                    let j = (y * w + x + run) * 4
                    guard bytes[j + 3] > 127,
                          String(format: "%02X%02X%02X", bytes[j], bytes[j + 1], bytes[j + 2]) == hex else { break }
                    run += 1
                }
                body += "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(run)\" height=\"1\" fill=\"#\(hex)\"/>\n"
                x += run
            }
        }
        let scale = Self.frameScale
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(w) \(h)" width="\(w * scale)" height="\(h * scale)" \
        shape-rendering="crispEdges">
        \(body)</svg>

        """
    }

    private func overview(_ kind: DeskPetKind, _ keys: [(DeskPetAct, CGImage)]) -> CGImage? {
        let sheet = VStack(alignment: .leading, spacing: 16) {
            Text("\(Self.petNames[kind] ?? "") · \(kind.rawValue)")
                .font(.system(size: 28, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(220), spacing: 12), count: 6), spacing: 12) {
                ForEach(keys.indices, id: \.self) { i in
                    VStack(spacing: 4) {
                        Image(decorative: scaled(keys[i].1, 4), scale: 1)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                        Text(String(format: "%02d %@", i + 1, keys[i].0.rawValue))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        Text(Self.names[keys[i].0] ?? "")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(width: 220)
                    .background(Color(white: 0.96), in: .rect(cornerRadius: 12))
                }
            }
        }
        .padding(28)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func palette(_ look: DeskPetLook) -> String {
        var lines = ["eye  #\(hex(AnchorColorTokens.deepSea))", "shine #FFFFFF"]
        for (letter, color) in look.palette.sorted(by: { $0.key < $1.key }) {
            lines.append("\(letter)    #\(hex(color))")
        }
        if look.strandColor != 0 { lines.append("strand #\(hex(look.strandColor))") }
        return lines.joined(separator: "\n") + "\n"
    }

    private func hex(_ value: UInt32) -> String { String(format: "%06X", value) }

    // MARK: Files

    private func write(png image: CGImage, to url: URL) throws {
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    private func writeGIF(_ images: [CGImage], to url: URL) throws {
        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, images.count, nil))
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)
        let delay = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.125,
                                                     kCGImagePropertyGIFUnclampedDelayTime: 0.125]] as CFDictionary
        for image in images { CGImageDestinationAddImage(destination, image, delay) }
        #expect(CGImageDestinationFinalize(destination))
    }
}
#endif
