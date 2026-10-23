import Testing
@testable import AnchorCore

@Suite("Title length")
struct AnchorTitleLengthTests {
    @Test("A Chinese character takes the room of two Latin letters")
    func units() {
        #expect(AnchorTitleLength.units(of: "数据结构作业") == 12)
        #expect(AnchorTitleLength.units(of: "Homework") == 8)
        #expect(AnchorTitleLength.units(of: "Anchor 首页") == 11)
        #expect(AnchorTitleLength.units(of: "") == 0)
    }

    @Test("A title that fits stays whole")
    func fits() {
        let title = "数据结构作业，周五前交"
        #expect(AnchorTitleLength.split(title) == (title, ""))
    }

    @Test("Past the limit, the rest is kept, not dropped")
    func overflow() {
        let split = AnchorTitleLength.split("一二三四五六七八九十一二三四五六七八九十")
        #expect(split.title == "一二三四五六七八九十一二三四五六")
        #expect(split.rest == "七八九十")
        #expect(AnchorTitleLength.units(of: split.title) == AnchorTitleLength.limit)
    }

    @Test("A Latin word is not cut in half")
    func wordBreak() {
        let split = AnchorTitleLength.split("Finish the homepage redesign before Friday")
        #expect(split.title == "Finish the homepage redesign")
        #expect(split.rest == "before Friday")
    }

    @Test("A Chinese title breaks after a nearby comma, not inside a word")
    func clauseBreak() {
        let split = AnchorTitleLength.split("今天计划完成竞品分析初步调研，上午还有一个小组工作会议。")
        #expect(split.title == "今天计划完成竞品分析初步调研")
        #expect(split.rest == "上午还有一个小组工作会议。")
    }
}
