import CoreGraphics
import Testing
import AnchorDesign

@Suite("Harbor launch choreography")
struct HarborLaunchChoreographyTests {
    private let size = CGSize(width: 402, height: 874)
    private typealias Scene = HarborLaunchChoreography

    private func scene(reduceMotion: Bool = false, skippedAt: Double? = nil) -> Scene {
        Scene(size: size, timing: .init(reduceMotion: reduceMotion, skippedAt: skippedAt))
    }

    @Test func logoFadesInThenTouchesTheSurfaceAtImpact() {
        let scene = scene()
        #expect(scene.logo(at: 0).opacity == 0)
        #expect(scene.logo(at: Scene.appearEnd).opacity == 1)
        let atImpact = scene.logo(at: Scene.impactTime - 0.0001).center.y
        #expect(abs(atImpact - scene.impactY) < 1)
    }

    @Test func logoSinksBelowTheSurfaceAndSettlesAtRest() {
        let scene = scene()
        let settled = scene.logo(at: Scene.exitStart)
        #expect(abs(settled.center.y - scene.restY) < 2)
        #expect(abs(settled.rotationDegrees) < 0.5)
        #expect(scene.restY - scene.logoSide / 2 > scene.restingWaterline)
    }

    @Test func spraySurfacesOnlyAfterImpactAndClearsBeforeTheText() {
        let scene = scene()
        #expect(scene.droplets(at: Scene.impactTime - 0.01).isEmpty)
        #expect(scene.droplets(at: Scene.impactTime + 0.02).count == 14)
        #expect(scene.droplets(at: Scene.impactTime + 0.9).isEmpty)
        #expect(!scene.bubbles(at: Scene.impactTime + 0.3).isEmpty)
    }

    @Test func sloganRevealsAfterTheWordmarkAndLeavesWithTheTide() {
        let scene = scene()
        #expect(scene.wordmark(at: Scene.wordmarkStart).opacity == 0)
        #expect(scene.slogan(at: Scene.wordmarkStart + 0.1).opacity == 0)
        let shown = scene.slogan(at: Scene.sloganStart + Scene.textReveal)
        #expect(shown.opacity == 1 && shown.blur == 0)
        #expect(scene.slogan(at: Scene.exitStart + Scene.exitDuration * 0.5).opacity == 0)
    }

    @Test func tideRisesPastTheTopAndTheSceneEndsTransparent() {
        let scene = scene()
        #expect(scene.waterline(at: 0) == size.height)
        #expect(scene.waterline(at: Scene.waterIntro) == scene.restingWaterline)
        #expect(Scene.waterIntro < Scene.impactTime)
        let end = scene.timing.total
        #expect(scene.waterline(at: end) < 0)
        #expect(scene.sceneOpacity(at: end) == 0)
        #expect(scene.sceneOpacity(at: Scene.exitStart) == 1)
    }

    @Test func tapShortensTheSequenceOnlyBeforeTheTide() {
        let early = Scene.Timing(reduceMotion: false, skippedAt: 0.4)
        #expect(early.exitBegins == 0.4)
        #expect(early.total == 0.4 + Scene.skipExitDuration)
        let late = Scene.Timing(reduceMotion: false, skippedAt: Scene.exitStart + 0.1)
        #expect(late == Scene.Timing(reduceMotion: false))
    }

    @Test func reducedMotionShowsAStillHarborAndAShortFade() {
        let scene = scene(reduceMotion: true)
        let pose = scene.logo(at: 0)
        #expect(pose.opacity == 1 && pose.center.y == scene.restY && pose.rotationDegrees == 0)
        #expect(scene.droplets(at: 0.7).isEmpty && scene.ripples(at: 0.7).isEmpty && scene.bubbles(at: 0.7).isEmpty)
        #expect(scene.slogan(at: 0).opacity == 1)
        #expect(scene.surfaceOffset(x: 100, at: 0) == scene.surfaceOffset(x: 100, at: 0.5))
        #expect(scene.timing.total == Scene.reducedHold + Scene.reducedFade)
    }

    @Test func landscapeKeepsTheRestingLogoOnScreen() {
        let scene = Scene(size: CGSize(width: 874, height: 402), timing: .init(reduceMotion: false))
        #expect(scene.restY + scene.logoSide / 2 <= 402)
        #expect(scene.restY - scene.logoSide / 2 > scene.restingWaterline)
    }
}
