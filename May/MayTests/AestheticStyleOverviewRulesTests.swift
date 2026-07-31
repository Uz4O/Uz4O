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

        let ap202Style = AestheticBuildStyle.all[5]
        let ap202Case = ap202Style.overviewParts.first { $0.name == "机箱" }!

        precondition(ap202Style.title == "华硕灵光岛 AP202")
        precondition(ap202Style.overviewTotal(for: .black) == 1597)
        precondition(ap202Style.overviewTotal(for: .white) == 1647)
        precondition(ap202Style.minimumOverviewCost == 1138)
        precondition(ap202Case.originalPrice(for: .black) == 599)
        precondition(ap202Case.originalPrice(for: .white) == 649)

        let hyteStyle = AestheticBuildStyle.all[6]
        let hyteCase = hyteStyle.overviewParts.first { $0.name == "机箱" }!

        precondition(hyteStyle.title == "HYTE Y70 鱼缸机箱")
        precondition(hyteStyle.overviewTotal(for: .black) == 8463)
        precondition(hyteStyle.overviewTotal(for: .white) == 8563)
        precondition(hyteStyle.minimumOverviewCost == 3485)
        precondition(hyteCase.alternatives[0].price == 1700)

        let aocStyle = AestheticBuildStyle.all[7]
        precondition(aocStyle.title == "AOC 震天弓")
        precondition(aocStyle.overviewTotal(for: .black) == 1297)
        precondition(aocStyle.overviewTotal(for: .white) == 1307)
        precondition(aocStyle.minimumOverviewCost == 748)

        let bo400CGStyle = AestheticBuildStyle.all[8]
        precondition(bo400CGStyle.title == "乔思伯 BO400CG")
        precondition(bo400CGStyle.overviewTotal(for: .black) == 4697)
        precondition(bo400CGStyle.overviewTotal(for: .white) == 4797)
        precondition(bo400CGStyle.minimumOverviewCost == 2663)

        print("AestheticStyleOverviewRulesTests passed")
    }
}
