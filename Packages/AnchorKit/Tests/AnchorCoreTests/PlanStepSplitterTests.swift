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
        // Split steps stand alone on the boards, so each starts like a sentence.
        #expect(PlanStepSplitter.steps(from: "Review the content, and then sketch the layout; build the prototype")
                == ["Review the content", "Sketch the layout", "Build the prototype"])
    }

    @Test("Ordinals are how a plan was said, not part of a step")
    func ordinals() {
        #expect(PlanStepSplitter.steps(from: "1. 做项目页\n2、部署上线\n第三步：写说明\n- 发给老师")
                == ["做项目页", "部署上线", "写说明", "发给老师"])
        // A word that only starts with "先" stays whole.
        #expect(PlanStepSplitter.steps(from: "先锋") == ["先锋"])
    }

    @Test("A dictated paragraph loses its fillers, hedges and preface")
    func dictatedEnglish() {
        let said = "Um, I think to finish the first step of this thing, I need to first go look at the competitors of related things on Amazon in the second round. Then, maybe I also need to check other people's comments on Reddit. Then finally, combining the research feedback from our agent, I'll do some overall thinking and model building, and ultimately finish the product report."
        #expect(PlanStepSplitter.steps(from: said) == [
            "Look at the competitors of related things on Amazon in the second round",
            "Check other people's comments on Reddit",
            "Combining the research feedback from our agent, do some overall thinking and model building",
            "Finish the product report",
        ])
    }

    @Test("The same paragraph, said in Chinese")
    func dictatedChinese() {
        let said = "嗯，我觉得要完成这件事的第一步，我需要先去亚马逊上看一下第二轮相关东西的竞品。然后，可能我还需要去Reddit上看看别人的评论。然后最后，结合我们agent的调研反馈，我会做一些整体的思考和建模，最终完成产品报告。"
        #expect(PlanStepSplitter.steps(from: said) == [
            "去亚马逊上看一下第二轮相关东西的竞品",
            "去Reddit上看看别人的评论",
            "结合我们agent的调研反馈，做一些整体的思考和建模",
            "完成产品报告",
        ])
    }

    @Test("Fillers only go when they stand alone")
    func fillersKeepWords() {
        #expect(PlanStepSplitter.steps(from: "核对金额") == ["核对金额"])
        #expect(PlanStepSplitter.steps(from: "那个文件发给老师") == ["那个文件发给老师"])
        #expect(PlanStepSplitter.steps(from: "Buy an umbrella") == ["Buy an umbrella"])
    }

    @Test("A sentence with nothing to do stays out of the steps")
    func contextDropped() {
        #expect(PlanStepSplitter.steps(from: "嗯，这个周末的计划。先去图书馆借书，然后写读书笔记。")
                == ["去图书馆借书", "写读书笔记"])
        #expect(PlanStepSplitter.steps(from: "Okay, so here's the plan. Email the professor, then book the room.")
                == ["Email the professor", "Book the room"])
    }

    @Test("Only a lead-in \"go\" goes")
    func goStays() {
        #expect(PlanStepSplitter.steps(from: "Go to the store, then go check the mail")
                == ["Go to the store", "Check the mail"])
    }
}
