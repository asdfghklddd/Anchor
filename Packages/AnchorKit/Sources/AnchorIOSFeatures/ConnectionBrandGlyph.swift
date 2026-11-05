#if os(iOS)
import SwiftUI

/// Anchor's mark, traced from the launch logo so the 3D model and the app's own
/// logo are one shape. Fill it even-odd: the later contours are its holes.
struct ConnectionBrandGlyph: Shape {
    /// The traced box, in the units of `contours`.
    private static let box = CGSize(width: 1000, height: 988)
    static let aspect = box.width / box.height

    /// Corners round off this far along each edge. A dense curve stays a curve;
    /// a long straight edge keeps its line and turns only at the end.
    private static let cornerReach: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for flat in Self.contours {
            let points = stride(from: 0, to: flat.count - 1, by: 2).map {
                CGPoint(x: CGFloat(flat[$0]), y: CGFloat(flat[$0 + 1]))
            }
            for index in points.indices {
                let corner = points[index]
                let before = Self.step(from: corner, toward: points[(index + points.count - 1) % points.count])
                let after = Self.step(from: corner, toward: points[(index + 1) % points.count])
                if index == 0 { path.move(to: before) } else { path.addLine(to: before) }
                // Cubic, not quadratic: SCNShape on iOS extrudes nothing from a path with quad segments.
                path.addCurve(to: after, control1: Self.lerp(before, corner), control2: Self.lerp(after, corner))
            }
            path.closeSubpath()
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / Self.box.width, y: rect.height / Self.box.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }

    /// Two thirds of the way to the corner, where a quad's corner sits as a cubic's handle.
    private static func lerp(_ point: CGPoint, _ corner: CGPoint) -> CGPoint {
        CGPoint(x: point.x + (corner.x - point.x) * 2 / 3, y: point.y + (corner.y - point.y) * 2 / 3)
    }

    private static func step(from corner: CGPoint, toward other: CGPoint) -> CGPoint {
        let dx = other.x - corner.x, dy = other.y - corner.y
        let length = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let reach = min(cornerReach, length / 2) / length
        return CGPoint(x: corner.x + dx * reach, y: corner.y + dy * reach)
    }

    /// x, y pairs, one array per contour.
    private static let contours: [[Int16]] = [
        [833, 610, 864, 575, 874, 556, 874, 544, 872, 539, 864, 532, 846, 532, 833, 541, 827, 553, 827, 
         607],
        [504, 987, 515, 984, 571, 938, 611, 913, 637, 899, 674, 885, 730, 858, 769, 835, 810, 806, 849, 
         773, 887, 734, 909, 705, 936, 658, 940, 659, 947, 674, 953, 677, 958, 676, 963, 672, 973, 648, 
         992, 580, 1000, 525, 1000, 495, 993, 487, 985, 487, 976, 493, 929, 537, 845, 625, 818, 647, 
         794, 598, 734, 459, 621, 181, 555, 12, 549, 4, 542, 0, 458, 0, 454, 2, 447, 9, 441, 21, 439, 
         31, 369, 206, 181, 665, 176, 664, 153, 645, 138, 631, 122, 609, 124, 606, 155, 605, 162, 602, 
         165, 598, 165, 589, 158, 581, 100, 544, 20, 485, 9, 485, 2, 492, 0, 513, 4, 554, 10, 587, 25, 
         641, 35, 668, 42, 671, 46, 670, 52, 664, 56, 650, 59, 645, 87, 696, 113, 734, 138, 762, 182, 
         802, 207, 821, 256, 852, 367, 905, 396, 922, 438, 951, 481, 984, 494, 988, 503, 988],
        [659, 726, 640, 726, 613, 722, 592, 713, 574, 701, 561, 686, 553, 670, 546, 647, 546, 620, 544, 
         613, 539, 608, 532, 608, 528, 612, 513, 636, 481, 670, 466, 682, 433, 701, 400, 713, 360, 722, 
         314, 722, 291, 718, 291, 715, 303, 701, 313, 678, 326, 640, 381, 491, 384, 489, 618, 491, 680, 
         661, 687, 674, 692, 680, 706, 686, 713, 685, 722, 678, 730, 659, 734, 632, 745, 621, 757, 621, 
         763, 626, 767, 634, 768, 648, 765, 659, 753, 679, 737, 695, 719, 707, 698, 718, 677, 724, 660, 
         725],
        [597, 418, 403, 418, 402, 416, 474, 220, 498, 151, 501, 153, 526, 222, 528, 224, 551, 290, 559, 
         308, 579, 368, 598, 414],
        [521, 836, 444, 833, 380, 821, 334, 806, 310, 796, 271, 775, 265, 771, 263, 767, 265, 766, 308, 
         781, 361, 796, 437, 808, 460, 810, 529, 810, 596, 802, 648, 790, 693, 773, 723, 759, 783, 720, 
         860, 658, 875, 649, 883, 649, 885, 653, 882, 657, 872, 671, 831, 715, 792, 746, 744, 777, 697, 
         800, 634, 821, 570, 833, 522, 836],
    ]
}
#endif
