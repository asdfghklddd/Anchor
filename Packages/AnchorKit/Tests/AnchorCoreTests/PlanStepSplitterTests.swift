import Testing
@testable import AnchorCore

@Suite("Plan step splitter")
struct PlanStepSplitterTests {
    @Test("Each line is a step")
    func lines() {
        #expect(PlanStepSplitter.steps(from: "梳理现有信息架构\n\n确定首页内容层级\n") == ["梳理现有信息架构", "确定首页内容层级"])
    }

    @Test("A spoken sequence splits where the person moved on")
    func spoken() {
        #expect(PlanStepSplitter.steps(from: "先实现插入，然后实现删除操作，然后再补边界测试，最后写实验报告。")
                == ["实现插入", "实现删除操作", "补边界测试", "写实验报告"])
        #expect(PlanStepSplitter.steps(from: "Review the content, and then sketch the layout; build the prototype")
                == ["Review the content", "sketch the layout", "build the prototype"])
    }

    @Test("Ordinals are how a plan was said, not part of a step")
    func ordinals() {
        #expect(PlanStepSplitter.steps(from: "1. 做项目页\n2、部署上线\n第三步：写说明\n- 发给老师")
                == ["做项目页", "部署上线", "写说明", "发给老师"])
        // A word that only starts with "先" stays whole.
        #expect(PlanStepSplitter.steps(from: "先锋") == ["先锋"])
    }
}
