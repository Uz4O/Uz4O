import Foundation

@main
struct AestheticStyleOverviewRulesTests {
    static func main() {
        let style = AestheticBuildStyle.all[0]
        let casePart = style.overviewParts.first { $0.name == "机箱" }!

        precondition(style.title == "联立 VISION COMPACT")
        precondition(style.overviewTotal(for: .black) == 6520)
        precondition(style.overviewTotal(for: .white) == 6580)
        precondition(style.minimumOverviewCost == 2735)
        precondition(casePart.originalPrice(for: .black) == 679)
        precondition(casePart.originalPrice(for: .white) == 739)
        precondition(casePart.alternatives[0].price == 450)

        let rogStyle = AestheticBuildStyle.all[1]
        let rogWater = rogStyle.overviewParts.first { $0.name == "一体式水冷" }!

        precondition(rogStyle.title == "ROG 创世神 701")
        precondition(rogStyle.overviewTotal(for: .black) == 8496)
        precondition(rogStyle.overviewTotal(for: .white) == 8596)
        precondition(rogStyle.minimumOverviewCost == 3476)
        precondition(rogWater.originalPrice(for: .black) == 2599)
        precondition(rogWater.originalPrice(for: .white) == 2699)
        precondition(rogWater.alternatives.last?.price == 899)

        let phantomStyle = AestheticBuildStyle.all[2]
        let phantomFans = phantomStyle.overviewParts.first { $0.name == "风扇与控制器" }!

        precondition(phantomStyle.title == "未知玩家 幻翼")
        precondition(phantomStyle.overviewTotal(for: .black) == 3637)
        precondition(phantomStyle.minimumOverviewCost == 1257)
        precondition(phantomFans.price == 1339)
        precondition(phantomFans.alternatives[0].price == 59)

        let bo400Style = AestheticBuildStyle.all[3]
        let bo400Fans = bo400Style.overviewParts.first { $0.name == "风扇套装" }!

        precondition(bo400Style.title == "乔思伯 BO400")
        precondition(bo400Style.overviewTotal(for: .black) == 4497)
        precondition(bo400Style.overviewTotal(for: .white) == 4597)
        precondition(bo400Style.minimumOverviewCost == 1663)
        precondition(bo400Fans.alternatives[0].price == 165)

        let xingcanStyle = AestheticBuildStyle.all[4]
        let xingcanFans = xingcanStyle.overviewParts.first { $0.name == "风扇套装" }!

        precondition(xingcanStyle.title == "星璨辰")
        precondition(xingcanStyle.overviewTotal(for: .black) == 1884)
        precondition(xingcanStyle.minimumOverviewCost == 1363)
        precondition(xingcanFans.price == 686)
        precondition(xingcanFans.alternatives[0].price == 165)

        print("AestheticStyleOverviewRulesTests passed")
    }
}
