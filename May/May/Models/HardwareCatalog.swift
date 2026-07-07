import Foundation

struct HardwareCatalogItem: Equatable, Identifiable {
    let id: String
    let name: String
    let brand: String
    let detail: String
}

struct HardwareCatalogGroup: Equatable, Identifiable {
    var id: String { title }

    let title: String
    let items: [HardwareCatalogItem]
}

struct HardwareCatalogFilter: Equatable, Identifiable {
    var id: String { title }

    let title: String
    let groups: [HardwareCatalogGroup]
}

enum HardwareCatalog {
    static let cpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "i9-14900ks", name: "i9-14900KS", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i9-14900kf", name: "i9-14900KF", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i9-14900k", name: "i9-14900K", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i7-14700kf", name: "i7-14700KF", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i7-14700k", name: "i7-14700K", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i7-14700", name: "i7-14700", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i5-14600kf", name: "i5-14600KF", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i5-14600k", name: "i5-14600K", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i5-14490f", name: "i5-14490F", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i5-14400f", name: "i5-14400F", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i5-14400", name: "i5-14400", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i3-14100f", name: "i3-14100F", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "i3-14100", name: "i3-14100", brand: "Intel", detail: "14代 Raptor Lake Refresh · LGA1700"),
        HardwareCatalogItem(id: "u9-285k", name: "Ultra 9 285K", brand: "Intel", detail: "15代酷睿Ultra Arrow Lake · LGA1851"),
        HardwareCatalogItem(id: "u9-285", name: "Ultra 9 285", brand: "Intel", detail: "15代酷睿Ultra Arrow Lake · LGA1851"),
        HardwareCatalogItem(id: "u7-265k", name: "Ultra 7 265K", brand: "Intel", detail: "15代酷睿Ultra Arrow Lake · LGA1851"),
        HardwareCatalogItem(id: "u7-265", name: "Ultra 7 265", brand: "Intel", detail: "15代酷睿Ultra Arrow Lake · LGA1851"),
        HardwareCatalogItem(id: "u5-245k", name: "Ultra 5 245K", brand: "Intel", detail: "15代酷睿Ultra Arrow Lake · LGA1851"),
        HardwareCatalogItem(id: "u5-245", name: "Ultra 5 245", brand: "Intel", detail: "15代酷睿Ultra Arrow Lake · LGA1851"),
        HardwareCatalogItem(id: "u5-235", name: "Ultra 5 235", brand: "Intel", detail: "15代酷睿Ultra Arrow Lake · LGA1851"),
        HardwareCatalogItem(id: "r9-9950x3d", name: "R9 9950X3D", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r9-9900x", name: "R9 9900X", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r7-9850x3d", name: "R7 9850X3D", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r7-9800x3d-v2", name: "R7 9800X3D v2", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r7-9800x3d", name: "R7 9800X3D", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r7-9700x", name: "R7 9700X", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r5-9600x", name: "R5 9600X", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r5-9500f", name: "R5 9500F", brand: "AMD", detail: "锐龙9000 (Zen5) · AM5"),
        HardwareCatalogItem(id: "r9-7950x3d", name: "R9 7950X3D", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r9-7950x", name: "R9 7950X", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r9-7900x", name: "R9 7900X", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r9-7900", name: "R9 7900", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r7-7800x3d", name: "R7 7800X3D", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r7-7700x", name: "R7 7700X", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r7-7700", name: "R7 7700", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r5-7600x", name: "R5 7600X", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r5-7600", name: "R5 7600", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "r5-7500f", name: "R5 7500F", brand: "AMD", detail: "锐龙7000 (Zen4) · AM5"),
        HardwareCatalogItem(id: "i9-13900ks", name: "i9-13900KS", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i9-13900kf", name: "i9-13900KF", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i9-13900k", name: "i9-13900K", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i9-13900", name: "i9-13900", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i7-13700kf", name: "i7-13700KF", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i7-13700k", name: "i7-13700K", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i7-13700", name: "i7-13700", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-13600kf", name: "i5-13600KF", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-13600k", name: "i5-13600K", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-13490f", name: "i5-13490F", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-13400f", name: "i5-13400F", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-13400", name: "i5-13400", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i3-13100f", name: "i3-13100F", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i3-13100", name: "i3-13100", brand: "Intel", detail: "13代 Raptor Lake · LGA1700"),
        HardwareCatalogItem(id: "i9-12900ks", name: "i9-12900KS", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i9-12900kf", name: "i9-12900KF", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i9-12900k", name: "i9-12900K", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i9-12900", name: "i9-12900", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i7-12700kf", name: "i7-12700KF", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i7-12700k", name: "i7-12700K", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i7-12700", name: "i7-12700", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-12600kf", name: "i5-12600KF", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-12600k", name: "i5-12600K", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-12500", name: "i5-12500", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-12490f", name: "i5-12490F", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-12400f", name: "i5-12400F", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i5-12400", name: "i5-12400", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i3-12100f", name: "i3-12100F", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "i3-12100", name: "i3-12100", brand: "Intel", detail: "12代 Alder Lake · LGA1700"),
        HardwareCatalogItem(id: "r9-5950x", name: "R9 5950X", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r9-5900x", name: "R9 5900X", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r7-5800x3d", name: "R7 5800X3D", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r7-5800x", name: "R7 5800X", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r7-5700x", name: "R7 5700X", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r7-5700g", name: "R7 5700G", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r7-5700", name: "R7 5700", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r5-5600x", name: "R5 5600X", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r5-5600g", name: "R5 5600G", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r5-5600", name: "R5 5600", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "r5-5500", name: "R5 5500", brand: "AMD", detail: "锐龙5000 (Zen3) · AM4"),
        HardwareCatalogItem(id: "i9-11900kf", name: "i9-11900KF", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i9-11900k", name: "i9-11900K", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i9-10900kf", name: "i9-10900KF", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i9-10900k", name: "i9-10900K", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i7-11700kf", name: "i7-11700KF", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i7-11700k", name: "i7-11700K", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i7-11700", name: "i7-11700", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i7-10700kf", name: "i7-10700KF", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i7-10700k", name: "i7-10700K", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i7-10700", name: "i7-10700", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-11600kf", name: "i5-11600KF", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-11600k", name: "i5-11600K", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-11500", name: "i5-11500", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-11400f", name: "i5-11400F", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-11400", name: "i5-11400", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-10600kf", name: "i5-10600KF", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-10600k", name: "i5-10600K", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-10500", name: "i5-10500", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-10400f", name: "i5-10400F", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i5-10400", name: "i5-10400", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i3-11100", name: "i3-11100", brand: "Intel", detail: "11代 Rocket Lake · LGA1200"),
        HardwareCatalogItem(id: "i3-10105f", name: "i3-10105F", brand: "Intel", detail: "10代 Comet Lake · LGA1200"),
        HardwareCatalogItem(id: "i3-10105", name: "i3-10105", brand: "Intel", detail: "10代 Comet Lake · LGA1200")
    ]

    static let gpus: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "rtx-5090", name: "RTX 5090", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5090-d-v2", name: "RTX 5090 D V2", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5090-d", name: "RTX 5090 D", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5080", name: "RTX 5080", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5070-ti", name: "RTX 5070 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5070", name: "RTX 5070", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5060-ti", name: "RTX 5060 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5060", name: "RTX 5060", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-5050", name: "RTX 5050", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4090-d", name: "RTX 4090 D", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4080-super", name: "RTX 4080 Super", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4080", name: "RTX 4080", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4070-ti-super", name: "RTX 4070 Ti Super", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4070-ti", name: "RTX 4070 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4070-super", name: "RTX 4070 SUPER", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4070", name: "RTX 4070", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4060-ti", name: "RTX 4060 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-4060", name: "RTX 4060", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3090-ti", name: "RTX 3090 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3090", name: "RTX 3090", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3080-ti", name: "RTX 3080 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3080", name: "RTX 3080", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3070-ti", name: "RTX 3070 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3070", name: "RTX 3070", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3060-ti", name: "RTX 3060 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3060", name: "RTX 3060", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-3050", name: "RTX 3050", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-2080-ti", name: "RTX 2080 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-2070-super", name: "RTX 2070 Super", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-2060-super", name: "RTX 2060 Super", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rtx-2060", name: "RTX 2060", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1660-ti", name: "GTX 1660 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1660-super", name: "GTX 1660 Super", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1650", name: "GTX 1650", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1080-ti", name: "GTX 1080 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1080", name: "GTX 1080", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1070-ti", name: "GTX 1070 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1070", name: "GTX 1070", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1060-6gb", name: "GTX 1060 (6GB)", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1060-5gb", name: "GTX 1060 (5GB)", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1060-3gb", name: "GTX 1060 (3GB)", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1050-ti", name: "GTX 1050 Ti", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "gtx-1050", name: "GTX 1050", brand: "NVIDIA", detail: "NVIDIA"),
        HardwareCatalogItem(id: "rx-9070-xt", name: "RX 9070 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-9070-gre", name: "RX 9070 GRE", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-9060-xt-8gb", name: "RX 9060 XT (8GB)", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-9060-xt-12gb", name: "RX 9060 XT (12GB)", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-9060-xt-16gb", name: "RX 9060 XT (16GB)", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7900-xtx", name: "RX 7900 XTX", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7900-xt", name: "RX 7900 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7900-gre", name: "RX 7900 GRE", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7850-xt", name: "RX 7850 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7800-xt", name: "RX 7800 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7750-xt", name: "RX 7750 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7700-xt", name: "RX 7700 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7650-gre", name: "RX 7650 GRE", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7600-xt", name: "RX 7600 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-7600", name: "RX 7600", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6950-xt", name: "RX 6950 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6900-xt", name: "RX 6900 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6800-xt", name: "RX 6800 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6800", name: "RX 6800", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6750-xt", name: "RX 6750 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6750-gre", name: "RX 6750 GRE", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6700-xt", name: "RX 6700 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6700", name: "RX 6700", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6650-xt", name: "RX 6650 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6650-gre", name: "RX 6650 GRE", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6600-xt", name: "RX 6600 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6600", name: "RX 6600", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-6500-xt", name: "RX 6500 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-5700-xt", name: "RX 5700 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-5700", name: "RX 5700", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-5600-xt", name: "RX 5600 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-5600", name: "RX 5600", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-5500-xt", name: "RX 5500 XT", brand: "AMD", detail: "AMD"),
        HardwareCatalogItem(id: "rx-5500", name: "RX 5500", brand: "AMD", detail: "AMD")
    ]

    static let motherboards: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "gigabyte-b860-ds3h", name: "B860 DS3H", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860-ds3h-wifi6e", name: "B860 DS3H WIFI6E", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860-eagle-wifi6e", name: "B860 EAGLE WIFI6E", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "msi-b860-gaming-plus", name: "B860 GAMING PLUS WIFI", brand: "微星", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860i-pro-ice", name: "B860I AORUS PRO ICE (ITX)", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-elite", name: "B860M AORUS ELITE", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-elite-wifi6e", name: "B860M AORUS ELITE WIFI6E", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-elite-wifi6e-ice", name: "B860M AORUS ELITE WIFI6E ICE", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-pro-wifi7", name: "B860M AORUS PRO WIFI7", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-c", name: "B860M C", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-d3hp", name: "B860M D3HP", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-ds3h", name: "B860M DS3H", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-ds3h-wifi6e", name: "B860M DS3H WIFI6E", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-e-g5", name: "B860M E GEN5", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-eagle-plus", name: "B860M EAGLE PLUS WIFI6E", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-gaming-x", name: "B860M GAMING X", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-gaming-x-wifi6e", name: "B860M GAMING X WIFI6E", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-b860m-k-g5", name: "B860M K GEN5", brand: "技嘉", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "msi-b860m-mortar", name: "MAG B860M MORTAR WIFI (迫击炮)", brand: "微星", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "msi-b860i-edge-ti", name: "MPG B860I EDGE TI WIFI", brand: "微星", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "asus-b860m-k", name: "PRIME B860M-K", brand: "华硕", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "msi-pro-b860m-a", name: "PRO B860M-A WIFI", brand: "微星", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "asus-b860-a-gaming", name: "ROG STRIX B860-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "asus-b860-g-gaming", name: "ROG STRIX B860-G GAMING WIFI", brand: "华硕", detail: "Intel · LGA1851 · B860"),
        HardwareCatalogItem(id: "gigabyte-h810m-gaming-wifi6", name: "H810M GAMING WIFI6 GEN5", brand: "技嘉", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "msi-h810m-gaming-wifi6e", name: "H810M GAMING WIFI6E", brand: "微星", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "gigabyte-h810m-h", name: "H810M H", brand: "技嘉", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "gigabyte-h810m-h-g5", name: "H810M H GEN5", brand: "技嘉", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "gigabyte-h810m-s2h", name: "H810M S2H", brand: "技嘉", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "gigabyte-h810m-s2h-g5", name: "H810M S2H GEN5", brand: "技嘉", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "asus-h810m-a", name: "PRIME H810M-A", brand: "华硕", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "asus-h810m-a-wifi", name: "PRIME H810M-A WIFI", brand: "华硕", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "asus-h810m-e-csm", name: "PRIME H810M-E-CSM", brand: "华硕", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "asus-h810m-k", name: "PRIME H810M-K", brand: "华硕", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "asus-h810m-k-csm", name: "PRIME H810M-K-CSM", brand: "华硕", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "msi-pro-h810m-b", name: "PRO H810M-B WIFI6E", brand: "微星", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "msi-pro-h810m-g", name: "PRO H810M-G WIFI6E", brand: "微星", detail: "Intel · LGA1851 · H810"),
        HardwareCatalogItem(id: "msi-z890-tomahawk", name: "MAG Z890 TOMAHAWK WIFI (战斧导弹)", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890m-gaming-plus", name: "MAG Z890M GAMING PLUS WIFI (MATX)", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890-godlike", name: "MEG Z890 GODLIKE (超神)", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890-unify-x", name: "MEG Z890 UNIFY-X (暗影)", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890-carbon-wifi", name: "MPG Z890 CARBON WIFI (暗黑)", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890-edge-ti", name: "MPG Z890 EDGE TI WIFI (刀锋钛)", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890i-edge-ti", name: "MPG Z890I EDGE TI WIFI (ITX)", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890-p", name: "PRIME Z890-P", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890-p-wifi", name: "PRIME Z890-P WIFI", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890m-plus-wifi", name: "PRIME Z890M-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-pro-z890-p", name: "PRO Z890-P WIFI", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-pro-z890-s", name: "PRO Z890-S WIFI", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-pro-z890-s-white", name: "PRO Z890-S WIFI WHITE", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-pro-z890-s-wifi6e", name: "PRO Z890-S WIFI6E", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890-hero", name: "ROG MAXIMUS Z890 HERO", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890-hero-btf", name: "ROG MAXIMUS Z890 HERO BTF", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890-a-gaming", name: "ROG STRIX Z890-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890-f-gaming", name: "ROG STRIX Z890-F GAMING WIFI", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "asus-z890-plus-wifi", name: "TUF GAMING Z890-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-elite-wifi7", name: "Z890 AORUS ELITE WIFI7", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-elite-wifi7-ice", name: "Z890 AORUS ELITE WIFI7 ICE", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-elite-x-ice", name: "Z890 AORUS ELITE X ICE", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-master-ai", name: "Z890 AORUS MASTER AI TOP", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-pro-ice", name: "Z890 AORUS PRO ICE", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-xtreme-ai", name: "Z890 AORUS XTREME AI TOP", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-d-plus", name: "Z890 D PLUS", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-eagle-plus", name: "Z890 EAGLE PLUS", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890-gaming-plus", name: "Z890 GAMING PLUS WIFI", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "msi-z890-gaming-wifi6e", name: "Z890 GAMING WIFI6E", brand: "微星", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-gaming-x-wifi7", name: "Z890 GAMING X WIFI7", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-ud", name: "Z890 UD", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890-ud-wifi6e", name: "Z890 UD WIFI6E", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890i-ultra", name: "Z890I AORUS ULTRA (ITX)", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-z890m-force-duo", name: "Z890M FORCE DUO X WIFI7", brand: "技嘉", detail: "Intel · LGA1851 · Z890"),
        HardwareCatalogItem(id: "gigabyte-b760-ds3h-g5", name: "B760 DS3H GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760-ds3h-wifi-g5", name: "B760 DS3H WIFI6E GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760-gaming-x-g5", name: "B760 GAMING X GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760-gaming-x-wifi-g5", name: "B760 GAMING X WIFI6E GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-elite-g5", name: "B760M AORUS ELITE GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-elite-wifi-g5", name: "B760M AORUS ELITE WIFI6E GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-c-v2", name: "B760M C V2", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-c-v3", name: "B760M C V3", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-d3hp", name: "B760M D3HP", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-d3hp-d4", name: "B760M D3HP DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-d3hp-wifi6", name: "B760M D3HP WIFI6", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-ds3h-d4-g5", name: "B760M DS3H DDR4 GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-ds3h-wifi-d4-g5", name: "B760M DS3H WIFI6E DDR4 GEN5", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-gaming-plus-d4", name: "B760M GAMING PLUS WIFI DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "gigabyte-b760m-k-v2-d4", name: "B760M K V2 DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-b760m-project-zero", name: "B760M PROJECT ZERO", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-b760-tomahawk-wifi-d4", name: "MAG B760 TOMAHAWK WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-b760m-gaming-plus-wifi-d4", name: "MAG B760M GAMING PLUS WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-b760m-mortar-wifi", name: "MAG B760M MORTAR WIFI", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-b760m-mortar-wifi-ii", name: "MAG B760M MORTAR WIFI II", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-plus-csm", name: "PRIME B760-PLUS-CSM", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760m-f-d4", name: "PRIME B760M-F D4", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760m-f-wifi", name: "PRIME B760M-F WIFI", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760m-plus", name: "PRIME B760M-PLUS", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760m-r-d4", name: "PRIME B760M-R D4", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-pro-b760-p-ii", name: "PRO B760-P II", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-pro-b760m-a-wifi-d4-ii", name: "PRO B760M-A WIFI DDR4 II", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-pro-b760m-b-d4", name: "PRO B760M-B DDR4", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-pro-b760m-g-d5", name: "PRO B760M-G DDR5", brand: "微星", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-creator", name: "ProArt B760-CREATOR", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-a-wifi", name: "ROG STRIX B760-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-a-wifi-d4", name: "ROG STRIX B760-A GAMING WIFI D4", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-g-wifi-d4", name: "ROG STRIX B760-G GAMING WIFI D4", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-i-wifi", name: "ROG STRIX B760-I GAMING WIFI", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-plus-wifi", name: "TUF GAMING B760-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "asus-b760-btf-wifi", name: "TX GAMING B760-BTF WIFI (天选)", brand: "华硕", detail: "Intel · LGA1700 · B760"),
        HardwareCatalogItem(id: "msi-h610m-bomber-d4", name: "H610M BOMBER DDR4 (爆破弹)", brand: "微星", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-d2vx-si-v2", name: "H610M D2VX SI V2 DDR4", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-d3h-wifi-d4", name: "H610M D3H WIFI DDR4", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-d3w-d4", name: "H610M D3W DDR4", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-d3w-wifi6", name: "H610M D3W WIFI6", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-h", name: "H610M H", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-h-v3-d4", name: "H610M H V3 DDR4", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-hd3p", name: "H610M HD3P", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-k-d4-g5", name: "H610M K DDR4 GEN5", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-k-g5", name: "H610M K GEN5", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-s2-d4", name: "H610M S2 DDR4", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "gigabyte-h610m-s2-v2", name: "H610M S2 V2", brand: "技嘉", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-a", name: "PRIME H610M-A", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-a-wifi", name: "PRIME H610M-A WIFI", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-d", name: "PRIME H610M-D", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-e", name: "PRIME H610M-E", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-f-d4-r2", name: "PRIME H610M-F D4 R2.0", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-f-wifi", name: "PRIME H610M-F WIFI", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-f-wifi-d4", name: "PRIME H610M-F WIFI D4", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-k", name: "PRIME H610M-K", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-k-argb", name: "PRIME H610M-K ARGB", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-k-d4-argb", name: "PRIME H610M-K D4 ARGB", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-k-d4-argb-csm", name: "PRIME H610M-K D4 ARGB-CSM", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-h610m-r", name: "PRIME H610M-R", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "msi-pro-h610m-a-wifi-d4", name: "PRO H610M-A WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-pro-h610m-ct2", name: "Pro H610M-CT2 D4-CSM", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "msi-pro-h610m-e-d4", name: "PRO H610M-E DDR4", brand: "微星", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "msi-pro-h610m-g-d4", name: "PRO H610M-G DDR4", brand: "微星", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "msi-pro-h610m-g-wifi-d4", name: "PRO H610M-G WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "asus-pro-h610t", name: "Pro H610T-CSM", brand: "华硕", detail: "Intel · LGA1700 · H610"),
        HardwareCatalogItem(id: "msi-z790-tomahawk-wifi", name: "MAG Z790 TOMAHAWK WIFI", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-tomahawk-wifi-d4", name: "MAG Z790 TOMAHAWK WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-torpedo", name: "MAG Z790 TORPEDO", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-ace-max", name: "MEG Z790 ACE MAX", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-godlike-max", name: "MEG Z790 GODLIKE MAX", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-carbon-wifi-ii", name: "MPG Z790 CARBON WIFI II", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-edge-ti-max", name: "MPG Z790 EDGE TI MAX WIFI (WIFI 7)", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-edge-wifi-d4", name: "MPG Z790 EDGE WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790i-edge-wifi", name: "MPG Z790I EDGE WIFI (ITX)", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-a-wifi", name: "PRIME Z790-A WIFI", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-p", name: "PRIME Z790-P", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-p-d4", name: "PRIME Z790-P D4", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-p-wifi", name: "PRIME Z790-P WIFI", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-p-wifi-d4", name: "PRIME Z790-P WIFI D4", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-apex-encore", name: "ROG MAXIMUS Z790 APEX ENCORE", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-dark-hero", name: "ROG MAXIMUS Z790 DARK HERO", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-formula", name: "ROG MAXIMUS Z790 FORMULA", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-hero", name: "ROG MAXIMUS Z790 HERO", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-hero-btf", name: "ROG MAXIMUS Z790 HERO BTF", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-hero-eva", name: "ROG MAXIMUS Z790 HERO EVA-02 EDITION", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-a-gaming", name: "ROG STRIX Z790-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-a-gaming-s", name: "ROG STRIX Z790-A GAMING WIFI S", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-e-gaming-ii", name: "ROG STRIX Z790-E GAMING WIFI II", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-f-gaming-ii", name: "ROG STRIX Z790-F GAMING WIFI II", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-h-gaming", name: "ROG STRIX Z790-H GAMING WIFI", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-btf-wifi", name: "TUF GAMING Z790-BTF WIFI", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "asus-z790-plus-d4", name: "TUF GAMING Z790-PLUS D4", brand: "华硕", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-elite-x", name: "Z790 AORUS ELITE X", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-elite-x-ax", name: "Z790 AORUS ELITE X AX", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-elite-x-wifi7", name: "Z790 AORUS ELITE X WIFI7", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-xtreme-x-ice", name: "Z790 AORUS XTREME X ICE", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-d", name: "Z790 D", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-d-ac", name: "Z790 D AC (rev. 1.0)", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-d-wifi", name: "Z790 D WIFI (rev. 1.0)", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-gaming-plus-wifi", name: "Z790 GAMING PLUS WIFI", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-gaming-pro-wifi", name: "Z790 GAMING PRO WIFI", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-gaming-wifi", name: "Z790 GAMING WIFI", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-gaming-x-ax", name: "Z790 GAMING X AX (rev. 2.x)", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-project-zero", name: "Z790 PROJECT ZERO WIFI DDR5", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-s-d4", name: "Z790 S DDR4 (rev. 1.0)", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790-s-wifi-d4", name: "Z790 S WIFI DDR4", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-z790m-elite-ax-ice", name: "Z790M AORUS ELITE AX ICE", brand: "技嘉", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790m-gaming-plus", name: "Z790M GAMING PLUS WIFI", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "msi-z790-mpower", name: "Z790MPOWER WIFI", brand: "微星", detail: "Intel · LGA1700 · Z790"),
        HardwareCatalogItem(id: "gigabyte-b850m-elite", name: "B850M AORUS ELITE WIFI7 (电竞精英)", brand: "技嘉", detail: "AMD · AM5 · B850"),
        HardwareCatalogItem(id: "gigabyte-b850m-eagle", name: "B850M EAGLE WIFI7 (鹰击)", brand: "技嘉", detail: "AMD · AM5 · B850"),
        HardwareCatalogItem(id: "gigabyte-b850m-force", name: "B850M FORCE WIFI6E (战力)", brand: "技嘉", detail: "AMD · AM5 · B850"),
        HardwareCatalogItem(id: "msi-b850m-gaming-plus", name: "B850M GAMING PLUS WIFI", brand: "微星", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "msi-b850m-gaming-pro", name: "B850M GAMING PRO WIFI", brand: "微星", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "msi-b850m-power", name: "B850M POWER", brand: "微星", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "asus-b850m-awy", name: "B850M-AWY WIFI", brand: "华硕", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "msi-b850m-mortar", name: "MAG B850M MORTAR (迫击炮)", brand: "微星", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "msi-b850m-mortar-wifi", name: "MAG B850M MORTAR WIFI (迫击炮)", brand: "微星", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "msi-b850-edge-ti", name: "MPG B850 EDGE TI WIFI", brand: "微星", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "asus-prime-b850m-f", name: "PRIME B850M-F", brand: "华硕", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "asus-prime-b850m-r", name: "PRIME B850M-R", brand: "华硕", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "msi-b850m-p-wifi", name: "PRO B850M-P WIFI", brand: "微星", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "asus-b850-g-chuixue", name: "ROG STRIX B850-G GAMING WIFI (小吹雪)", brand: "华硕", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "asus-b850m-e-wifi", name: "TUF GAMING B850M-E WIFI 重炮手", brand: "华硕", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "asus-b850m-wifi", name: "TUF GAMING B850M-PLUS WIFI 重炮手", brand: "华硕", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "asus-b850m-tuf", name: "TUF GAMING B850M-PLUS 重炮手", brand: "华硕", detail: "AMD · AM5 · B850M"),
        HardwareCatalogItem(id: "gigabyte-x870-elite-wifi7", name: "X870 AORUS ELITE WIFI7 ICE (精英 WIFI7)", brand: "技嘉", detail: "AMD · AM5 · X870"),
        HardwareCatalogItem(id: "gigabyte-x870-elite-ice", name: "X870 AORUS ELITE X3D ICE (电竞精英)", brand: "技嘉", detail: "AMD · AM5 · X870"),
        HardwareCatalogItem(id: "gigabyte-x870-stealth", name: "X870 AORUS STEALTH ICE (隐形战机)", brand: "技嘉", detail: "AMD · AM5 · X870"),
        HardwareCatalogItem(id: "gigabyte-x870i-pro", name: "X870I AORUS PRO (迷你 PRO ITX)", brand: "技嘉", detail: "AMD · AM5 · X870"),
        HardwareCatalogItem(id: "msi-x870e-gaming-plus", name: "MAG X870E GAMING PLUS WIFI", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-x870e-tomahawk", name: "MAG X870E TOMAHAWK WIFI (战斧导弹)", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-x870e-godlike", name: "MEG X870E GODLIKE", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-x870e-godlike-max", name: "MEG X870E GODLIKE MAX", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-x870e-ace-max", name: "MEG X870E ACE MAX", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-x870e-carbon-max", name: "MPG X870E CARBON MAX WIFI (暗黑)", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-x870e-carbon", name: "MPG X870E CARBON WIFI (暗黑)", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-x870e-edge-ti", name: "MPG X870E EDGE TI WIFI (刀锋钛)", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "msi-pro-x870-p", name: "PRO X870-P WIFI", brand: "微星", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "asus-x870e-apex", name: "ROG CROSSHAIR X870E APEX", brand: "华硕", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "asus-x870e-neo", name: "ROG X870E NEO", brand: "华硕", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "asus-x870e-hero", name: "ROG CROSSHAIR X870E DARK HERO", brand: "华硕", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "asus-x870e-extreme", name: "ROG CROSSHAIR X870E EXTREME", brand: "华硕", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "asus-x870e-glacial", name: "ROG X870E GLACIAL 冰川", brand: "华硕", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "asus-x870e-chuixue", name: "ROG STRIX X870E-A GAMING WIFI (吹雪)", brand: "华硕", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "gigabyte-x870e-master-ice", name: "X870E AORUS MASTER X3D ICE (旗舰大师)", brand: "技嘉", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "gigabyte-x870e-pro-ice", name: "X870E AORUS PRO X3D ICE (旗舰电竞)", brand: "技嘉", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "gigabyte-x870e-xtreme-ai", name: "X870E AORUS XTREME X3D AI TOP (超级电竞)", brand: "技嘉", detail: "AMD · AM5 · X870E"),
        HardwareCatalogItem(id: "gigabyte-b650-elite-ice", name: "B650 AORUS ELITE AX ICE (精英 AX)", brand: "技嘉", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "gigabyte-b650m-elite-ax", name: "B650M AORUS ELITE AX (精英 AX)", brand: "技嘉", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "msi-b650m-gaming-plus", name: "B650M GAMING PLUS WIFI", brand: "微星", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "msi-b650m-wifi-ape", name: "B650M WIFI APE", brand: "微星", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "asus-b650m-awy", name: "B650M-AWY WIFI", brand: "华硕", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "msi-b650m-mortar", name: "MAG B650M MORTAR (迫击炮)", brand: "微星", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "msi-b650m-mortar-wifi", name: "MAG B650M MORTAR WIFI (迫击炮)", brand: "微星", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "asus-prime-b650m-f", name: "PRIME B650M-F", brand: "华硕", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "asus-prime-b650m-r", name: "PRIME B650M-R", brand: "华硕", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "msi-b650m-b", name: "PRO B650M-B", brand: "微星", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "msi-b650m-e", name: "PRO B650M-E", brand: "微星", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "asus-b650m-e-wifi", name: "TUF GAMING B650M-E WIFI 重炮手", brand: "华硕", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "asus-b650m-wifi", name: "TUF GAMING B650M-PLUS WIFI 重炮手", brand: "华硕", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "asus-b650m-tuf", name: "TUF GAMING B650M-PLUS 重炮手", brand: "华硕", detail: "AMD · AM5 · B650"),
        HardwareCatalogItem(id: "gigabyte-b650e-pro-x", name: "B650E AORUS PRO X USB4 (专业 PRO X)", brand: "技嘉", detail: "AMD · AM5 · B650E"),
        HardwareCatalogItem(id: "gigabyte-b650e-eagle", name: "B650E EAGLE (鹰击)", brand: "技嘉", detail: "AMD · AM5 · B650E"),
        HardwareCatalogItem(id: "gigabyte-b650e-eagle-wifi", name: "B650E EAGLE WIFI6E (鹰击)", brand: "技嘉", detail: "AMD · AM5 · B650E"),
        HardwareCatalogItem(id: "msi-x670e-gaming-plus", name: "MAG X670E GAMING PLUS WIFI", brand: "微星", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "msi-x670e-tomahawk", name: "MAG X670E TOMAHAWK WIFI (战斧导弹)", brand: "微星", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "msi-x670e-ace", name: "MEG X670E ACE (战神)", brand: "微星", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "msi-x670e-godlike", name: "MEG X670E GODLIKE (超神)", brand: "微星", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "msi-x670e-carbon", name: "MPG X670E CARBON WIFI (暗黑)", brand: "微星", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "asus-x670e-pro", name: "PRIME X670E-PRO WIFI", brand: "华硕", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "msi-pro-x670-p", name: "PRO X670-P WIFI", brand: "微星", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "asus-x670e-apex", name: "ROG CROSSHAIR X670E APEX", brand: "华硕", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "asus-x670e-extreme", name: "ROG CROSSHAIR X670E EXTREME", brand: "华硕", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "asus-x670e-gen", name: "ROG CROSSHAIR X670E GENE", brand: "华硕", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "asus-x670e-hero", name: "ROG CROSSHAIR X670E HERO", brand: "华硕", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "asus-x670e-chuixue", name: "ROG STRIX X670E-A GAMING WIFI (吹雪)", brand: "华硕", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "asus-x670e-plus", name: "TUF GAMING X670E-PLUS", brand: "华硕", detail: "AMD · AM5 · X670E"),
        HardwareCatalogItem(id: "gigabyte-a520i-ac", name: "A520I AC (ITX)", brand: "技嘉", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "gigabyte-a520m-a-pro", name: "A520M A PRO", brand: "技嘉", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "gigabyte-a520m-ds3h-v2", name: "A520M DS3H V2", brand: "技嘉", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "gigabyte-a520m-h-argb", name: "A520M H ARGB", brand: "技嘉", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "gigabyte-a520m-k-v2", name: "A520M K V2", brand: "技嘉", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "msi-mag-a520m-a", name: "MAG A520M A (专业版)", brand: "微星", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "msi-mag-a520m-vector", name: "MAG A520M VECTOR WIFI (矢量)", brand: "微星", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "asus-a520m-e", name: "PRIME A520M-E", brand: "华硕", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "asus-a520m-e-csm", name: "PRIME A520M-E/CSM", brand: "华硕", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "asus-a520m-k", name: "PRIME A520M-K", brand: "华硕", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "asus-a520m-r", name: "PRIME A520M-R", brand: "华硕", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "asus-a520m-r-csm", name: "PRIME A520M-R-CSM", brand: "华硕", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "msi-pro-a520m-a", name: "PRO A520M-A (专业版)", brand: "微星", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "msi-pro-a520m-vdh", name: "PRO A520M-VDH", brand: "微星", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "asus-a520m-plus", name: "TUF GAMING A520M-PLUS", brand: "华硕", detail: "AMD · AM4 · A520"),
        HardwareCatalogItem(id: "gigabyte-b450-elite-v2", name: "B450 AORUS ELITE V2", brand: "技嘉", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "msi-b450-carbon-pro", name: "B450 GAMING PRO CARBON (电竞专业碳纤)", brand: "微星", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "msi-b450-carbon-ac", name: "B450 GAMING PRO CARBON AC", brand: "微星", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "msi-b450-tomahawk", name: "B450 TOMAHAWK (战斧)", brand: "微星", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "gigabyte-b450m-ds3h-v3", name: "B450M DS3H V3", brand: "技嘉", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "gigabyte-b450m-ds3h-wifi", name: "B450M DS3H WIFI", brand: "技嘉", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "gigabyte-b450m-h", name: "B450M H", brand: "技嘉", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "gigabyte-b450m-k", name: "B450M K", brand: "技嘉", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "msi-b450m-mortar", name: "B450M MORTAR (迫击炮)", brand: "微星", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "msi-b450m-mortar-max", name: "B450M MORTAR MAX (迫击炮)", brand: "微星", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "msi-b450m-pro-vdh-max", name: "B450M PRO-VDH MAX (专业-VDH)", brand: "微星", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450m-a", name: "PRIME B450M-A", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450m-a-ii", name: "PRIME B450M-A II/CSM", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450m-k", name: "PRIME B450M-K", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450m-k-ii", name: "PRIME B450M-K II", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450-plus-gaming", name: "TUF B450-PLUS GAMING", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450m-pro-gaming", name: "TUF B450M-PRO GAMING", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450-plus-ii", name: "TUF GAMING B450-PLUS II", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450m-plus-ii", name: "TUF GAMING B450M-PLUS II", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "asus-b450m-pro-ii", name: "TUF GAMING B450M-PRO II", brand: "华硕", detail: "AMD · AM4 · B450"),
        HardwareCatalogItem(id: "gigabyte-b550-elite", name: "B550 AORUS ELITE", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550-elite-ax-v2", name: "B550 AORUS ELITE AX V2", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550-eagle", name: "B550 EAGLE", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550-eagle-wifi", name: "B550 EAGLE WIFI", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550i-pro-ax", name: "B550I AORUS PRO AX (ITX)", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550m-elite-ax", name: "B550M AORUS ELITE AX", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550m-pro-p", name: "B550M AORUS PRO-P", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550m-gaming-x-wifi", name: "B550M GAMING X WIFI", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550m-h-argb", name: "B550M H ARGB", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550m-k", name: "B550M K", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "gigabyte-b550m-k-wifi6e", name: "B550M K WIFI6E", brand: "技嘉", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550-tomahawk", name: "MAG B550 TOMAHAWK (战斧)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550-tomahawk-max", name: "MAG B550 TOMAHAWK MAX WIFI (战斧 MAX)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550m-bazooka", name: "MAG B550M BAZOOKA (火箭炮)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550m-mortar", name: "MAG B550M MORTAR (迫击炮)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550m-mortar-wifi", name: "MAG B550M MORTAR WIFI (迫击炮)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550-unify-x", name: "MEG B550 UNIFY-X (暗黑-X)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550-carbon-wifi", name: "MPG B550 GAMING CARBON WIFI (电竞碳纤)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550-gaming-plus", name: "MPG B550 GAMING PLUS (电竞加强版)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-b550i-edge-wifi", name: "MPG B550I GAMING EDGE WIFI (ITX 刀锋)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550m-k", name: "PRIME B550M-K", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550m-k-argb", name: "PRIME B550M-K ARGB", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550m-k-argb-csm", name: "PRIME B550M-K ARGB-CSM", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-pro-b550-vc", name: "PRO B550-VC (矢量 WIFI)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-pro-b550m-a", name: "PRO B550M-A (专业版)", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "msi-pro-b550m-vdh-wifi", name: "PRO B550M-VDH WIFI", brand: "微星", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550-plus-wifi-ii", name: "TUF GAMING B550-PLUS (WIFI II)", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550-plus-wifi", name: "TUF GAMING B550-PLUS (WIFI)", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550m-e", name: "TUF GAMING B550M-E", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550m-e-wifi", name: "TUF GAMING B550M-E WIFI", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550m-plus", name: "TUF GAMING B550M-PLUS", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-b550m-plus-wifi", name: "TUF GAMING B550M-PLUS (WIFI)", brand: "华硕", detail: "AMD · AM4 · B550"),
        HardwareCatalogItem(id: "asus-x470-hero", name: "ROG CROSSHAIR VII HERO", brand: "华硕", detail: "AMD · AM4 · X470"),
        HardwareCatalogItem(id: "asus-x470-hero-wifi", name: "ROG CROSSHAIR VII HERO (WIFI)", brand: "华硕", detail: "AMD · AM4 · X470"),
        HardwareCatalogItem(id: "asus-x470-f-gaming", name: "ROG STRIX X470-F GAMING", brand: "华硕", detail: "AMD · AM4 · X470"),
        HardwareCatalogItem(id: "asus-x470-i-gaming", name: "ROG STRIX X470-I GAMING (ITX)", brand: "华硕", detail: "AMD · AM4 · X470"),
        HardwareCatalogItem(id: "msi-x570-godlike", name: "MEG X570 GODLIKE (超神)", brand: "微星", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "msi-x570-unify", name: "MEG X570 UNIFY (暗黑)", brand: "微星", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "msi-x570s-unify-x", name: "MEG X570S UNIFY-X MAX (暗黑-X 极致版)", brand: "微星", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "msi-x570-edge-wifi", name: "MPG X570 GAMING EDGE WIFI (电竞刀锋)", brand: "微星", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "msi-x570s-carbon-ii", name: "MPG X570S GAMING CARBON WIFI II (电竞碳纤)", brand: "微星", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "asus-x570-p", name: "PRIME X570-P", brand: "华硕", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "asus-x570-dark-hero", name: "ROG CROSSHAIR VIII DARK HERO", brand: "华硕", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "asus-x570-hero-wifi", name: "ROG CROSSHAIR VIII HERO (WIFI)", brand: "华硕", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "asus-x570-impact", name: "ROG CROSSHAIR VIII IMPACT (迷你旗舰)", brand: "华硕", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "asus-x570-e-wifi-ii", name: "ROG STRIX X570-E GAMING WIFI II", brand: "华硕", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "asus-x570-f-gaming", name: "ROG STRIX X570-F GAMING", brand: "华硕", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "asus-x570-i-gaming", name: "ROG STRIX X570-I GAMING (ITX)", brand: "华硕", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "gigabyte-x570-elite-wifi6", name: "X570 AORUS ELITE WIFI6", brand: "技嘉", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "gigabyte-x570-master", name: "X570 AORUS MASTER", brand: "技嘉", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "gigabyte-x570-pro-wifi6", name: "X570 AORUS PRO WIFI6", brand: "技嘉", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "gigabyte-x570i-pro-wifi6", name: "X570I AORUS PRO WIFI6 (ITX)", brand: "技嘉", detail: "AMD · AM4 · X570"),
        HardwareCatalogItem(id: "gigabyte-b460-hd3", name: "B460 HD3", brand: "技嘉", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "gigabyte-b460m-pro", name: "B460M AORUS PRO", brand: "技嘉", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "gigabyte-b460m-d3h", name: "B460M D3H", brand: "技嘉", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "gigabyte-b460m-ds3h", name: "B460M DS3H", brand: "技嘉", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "gigabyte-b460m-power", name: "B460M POWER", brand: "技嘉", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "msi-b460-torpedo", name: "MAG B460 TORPEDO", brand: "微星", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-b460i-plus", name: "PRIME B460I-PLUS", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-b460m-a", name: "PRIME B460M-A", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-b460m-k", name: "PRIME B460M-K", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "msi-pro-b460m-pro", name: "PRO B460M PRO", brand: "微星", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "msi-pro-b460m-vdh-wifi", name: "PRO B460M PRO-VDH WIFI", brand: "微星", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-pro-b460m-c", name: "Pro B460M-C/CSM", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-b460-f", name: "ROG STRIX B460-F GAMING", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-b460-g", name: "ROG STRIX B460-G GAMING", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-b460-h", name: "ROG STRIX B460-H GAMING", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "asus-b460-i", name: "ROG STRIX B460-I GAMING", brand: "华硕", detail: "Intel · LGA1200 · B460"),
        HardwareCatalogItem(id: "gigabyte-b560-pro-ax", name: "B560 AORUS PRO AX", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560i-pro-ax", name: "B560I AORUS PRO AX (ITX)", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560m-elite", name: "B560M AORUS ELITE", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560m-d3h", name: "B560M D3H", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560m-ds3h", name: "B560M DS3H", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560m-ds3h-plus", name: "B560M DS3H PLUS", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560m-gaming-hd", name: "B560M GAMING HD", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560m-h", name: "B560M H", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b560m-h-v2", name: "B560M H V2", brand: "技嘉", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-p", name: "B560M-P", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-ex-b560m-v5", name: "EX-B560M-V5", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "msi-b560-torpedo", name: "MAG B560 TORPEDO", brand: "微星", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "msi-b560m-mortar-wifi", name: "MAG B560M MORTAR WIFI (迫击炮)", brand: "微星", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "msi-b560i-edge-wifi", name: "MPG B560I GAMING EDGE WIFI (ITX)", brand: "微星", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-prime-plus", name: "PRIME B560-PLUS", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-prime-plus-ac", name: "PRIME B560-PLUS AC-HES", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-a", name: "PRIME B560M-A", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-a-ac", name: "PRIME B560M-A AC", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-a-csm", name: "PRIME B560M-A/CSM", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-k-csm", name: "PRIME B560M-K/CSM", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "msi-pro-b560m-plus", name: "PRO B560M PLUS", brand: "微星", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "msi-pro-b560m-pro", name: "PRO B560M PRO", brand: "微星", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-pro-b560m-c", name: "Pro B560M-C/CSM", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-pro-b560m-ct", name: "Pro B560M-CT/CSM", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "msi-pro-b560m-g", name: "PRO B560M-G", brand: "微星", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-a-wifi", name: "ROG STRIX B560-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-e-wifi", name: "ROG STRIX B560-E GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-f-wifi", name: "ROG STRIX B560-F GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-g-wifi", name: "ROG STRIX B560-G GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-i-wifi", name: "ROG STRIX B560-I GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560-plus-wifi", name: "TUF GAMING B560-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-e", name: "TUF GAMING B560M-E", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-plus", name: "TUF GAMING B560M-PLUS", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "asus-b560m-plus-wifi", name: "TUF GAMING B560M-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1200 · B560"),
        HardwareCatalogItem(id: "gigabyte-b660-ds3h-ac", name: "B660 DS3H AC", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660-ds3h-ac-d4", name: "B660 DS3H AC DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660-gaming-x", name: "B660 GAMING X", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660i-pro-d4", name: "B660I AORUS PRO DDR4 (ITX)", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660m-elite-ax-d4", name: "B660M AORUS ELITE AX DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660m-elite-d4", name: "B660M AORUS ELITE DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660m-gaming-x", name: "B660M GAMING X", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660m-gaming-x-ax", name: "B660M GAMING X AX", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660m-gaming-x-ax-d4", name: "B660M GAMING X AX DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "gigabyte-b660m-power-d4", name: "B660M POWER DDR4", brand: "技嘉", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "msi-b660m-e-d4", name: "MAG B660M E DDR4", brand: "微星", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "msi-b660m-mortar-wifi", name: "MAG B660M MORTAR WIFI", brand: "微星", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "asus-b660-prime-a", name: "PRIME B660-A", brand: "华硕", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "asus-b660m-k", name: "PRIME B660M-K", brand: "华硕", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "msi-pro-b660m-g-d4", name: "PRO B660M-G DDR4", brand: "微星", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "asus-b660-a-wifi", name: "ROG STRIX B660-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "asus-b660-g-wifi", name: "ROG STRIX B660-G GAMING WIFI", brand: "华硕", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "asus-b660-plus-wifi", name: "TUF GAMING B660-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1700 · B660"),
        HardwareCatalogItem(id: "asus-h370-f", name: "ROG STRIX H370-F GAMING", brand: "华硕", detail: "Intel · LGA1200 · H370"),
        HardwareCatalogItem(id: "asus-h370-i", name: "ROG STRIX H370-I GAMING", brand: "华硕", detail: "Intel · LGA1200 · H370"),
        HardwareCatalogItem(id: "gigabyte-h410m-d2vx-si", name: "H410M D2VX SI", brand: "技嘉", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "gigabyte-h410m-h", name: "H410M H", brand: "技嘉", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "gigabyte-h410m-s2h", name: "H410M S2H", brand: "技嘉", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "gigabyte-h410m-s2h-v2", name: "H410M S2H V2", brand: "技嘉", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "asus-h410i-plus", name: "PRIME H410I-PLUS", brand: "华硕", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "asus-h410i-plus-csm", name: "PRIME H410I-PLUS/CSM", brand: "华硕", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "asus-h410m-e", name: "PRIME H410M-E", brand: "华硕", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "asus-h410m-e-csm", name: "PRIME H410M-E/CSM", brand: "华硕", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "asus-h410m-f", name: "PRIME H410M-F", brand: "华硕", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "msi-pro-h410i-wifi", name: "PRO H410I PRO WIFI (ITX)", brand: "微星", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "msi-pro-h410m-pro", name: "PRO H410M PRO", brand: "微星", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "asus-pro-h410t", name: "Pro H410T/CSM", brand: "华硕", detail: "Intel · LGA1200 · H410"),
        HardwareCatalogItem(id: "gigabyte-h470-hd3", name: "H470 HD3", brand: "技嘉", detail: "Intel · LGA1200 · H470"),
        HardwareCatalogItem(id: "gigabyte-h470m-d3h", name: "H470M D3H", brand: "技嘉", detail: "Intel · LGA1200 · H470"),
        HardwareCatalogItem(id: "gigabyte-h470m-ds3h", name: "H470M DS3H", brand: "技嘉", detail: "Intel · LGA1200 · H470"),
        HardwareCatalogItem(id: "asus-h470m-plus", name: "PRIME H470M-PLUS", brand: "华硕", detail: "Intel · LGA1200 · H470"),
        HardwareCatalogItem(id: "asus-h470-i", name: "ROG STRIX H470-I GAMING", brand: "华硕", detail: "Intel · LGA1200 · H470"),
        HardwareCatalogItem(id: "gigabyte-h510i-pro", name: "H510I PRO (ITX)", brand: "技嘉", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "gigabyte-h510m-h", name: "H510M H", brand: "技嘉", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "gigabyte-h510m-k", name: "H510M K", brand: "技嘉", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "gigabyte-h510m-k-v2", name: "H510M K V2", brand: "技嘉", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "gigabyte-h510m-s2", name: "H510M S2", brand: "技嘉", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "gigabyte-h510m-s2h", name: "H510M S2H", brand: "技嘉", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "gigabyte-h510m-s2h-v2", name: "H510M S2H V2", brand: "技嘉", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "msi-mag-h510m-bomber", name: "MAG H510M BOMBER (爆破弹)", brand: "微星", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "msi-pro-h510i-wifi", name: "PRO H510I PRO WIFI (ITX)", brand: "微星", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "msi-pro-h510m-pro", name: "PRO H510M PRO", brand: "微星", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "msi-pro-h510m-e", name: "PRO H510M PRO-E", brand: "微星", detail: "Intel · LGA1200 · H510"),
        HardwareCatalogItem(id: "asus-h570-plus", name: "PRIME H570-PLUS", brand: "华硕", detail: "Intel · LGA1200 · H570"),
        HardwareCatalogItem(id: "asus-h570m-plus", name: "PRIME H570M-PLUS", brand: "华硕", detail: "Intel · LGA1200 · H570"),
        HardwareCatalogItem(id: "msi-z490-ace", name: "MEG Z490 ACE", brand: "微星", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "msi-z490-godlike", name: "MEG Z490 GODLIKE", brand: "微星", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "msi-z490i-unify", name: "MEG Z490I UNIFY (ITX)", brand: "微星", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "msi-z490-edge-wifi", name: "MPG Z490 GAMING EDGE WIFI", brand: "微星", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-extreme", name: "ROG MAXIMUS XII EXTREME", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-hero-wifi", name: "ROG MAXIMUS XII HERO WIFI", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-a", name: "ROG STRIX Z490-A GAMING", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-e", name: "ROG STRIX Z490-E GAMING", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-f", name: "ROG STRIX Z490-F GAMING", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-g-wifi", name: "ROG STRIX Z490-G GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-h", name: "ROG STRIX Z490-H GAMING", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-i", name: "ROG STRIX Z490-I GAMING", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-plus", name: "TUF GAMING Z490-PLUS", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "asus-z490-plus-wifi", name: "TUF GAMING Z490-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490-elite", name: "Z490 AORUS ELITE", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490-master", name: "Z490 AORUS MASTER", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490-pro-ax", name: "Z490 AORUS PRO AX", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490-xtreme", name: "Z490 AORUS XTREME", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490-xtreme-wf", name: "Z490 AORUS XTREME WATERFORCE", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490-gaming-x", name: "Z490 GAMING X", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490-ud", name: "Z490 UD", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "msi-z490-a-pro", name: "Z490-A PRO", brand: "微星", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490i-ultra", name: "Z490I AORUS ULTRA (ITX)", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "gigabyte-z490m-gaming-x", name: "Z490M GAMING X", brand: "技嘉", detail: "Intel · LGA1200 · Z490"),
        HardwareCatalogItem(id: "msi-z590-tomahawk", name: "MAG Z590 TOMAHAWK WIFI (战斧)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-torpedo", name: "MAG Z590 TORPEDO (鱼雷)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-ace", name: "MEG Z590 ACE (战神)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-godlike", name: "MEG Z590 GODLIKE (超神)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-unify", name: "MEG Z590 UNIFY (暗影)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590i-unify", name: "MEG Z590I UNIFY (ITX 迷你板)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-carbon-ek", name: "MPG Z590 CARBON EK X (水冷定制版)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-carbon-wifi", name: "MPG Z590 GAMING CARBON WIFI (暗黑板)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-edge-wifi", name: "MPG Z590 GAMING EDGE WIFI (刀锋)", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-gaming-plus", name: "MPG Z590 GAMING PLUS", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-p", name: "PRIME Z590-P", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-extreme", name: "ROG MAXIMUS XIII EXTREME", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-glacial", name: "ROG MAXIMUS XIII EXTREME GLACIAL", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-hero", name: "ROG MAXIMUS XIII HERO (Z590)", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-a", name: "ROG STRIX Z590-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-e", name: "ROG STRIX Z590-E GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-f", name: "ROG STRIX Z590-F GAMING WIFI", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-i", name: "ROG STRIX Z590-I GAMING WIFI (ITX)", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "asus-z590-plus-wifi", name: "TUF GAMING Z590-PLUS WIFI", brand: "华硕", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-elite", name: "Z590 AORUS ELITE", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-elite-ax", name: "Z590 AORUS ELITE AX", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-master", name: "Z590 AORUS MASTER", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-pro-ax", name: "Z590 AORUS PRO AX", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-xtreme", name: "Z590 AORUS XTREME", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-xtreme-wf", name: "Z590 AORUS XTREME WATERFORCE", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-gaming-x", name: "Z590 GAMING X", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-pro-wifi", name: "Z590 PRO WIFI", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-ud", name: "Z590 UD", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-ud-ac", name: "Z590 UD AC", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-vision-d", name: "Z590 VISION D", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590-vision-g", name: "Z590 VISION G", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z590-a-pro", name: "Z590-A PRO", brand: "微星", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "gigabyte-z590i-ultra", name: "Z590I AORUS ULTRA (ITX)", brand: "技嘉", detail: "Intel · LGA1200 · Z590"),
        HardwareCatalogItem(id: "msi-z690-tomahawk-wifi-d4", name: "MAG Z690 TOMAHAWK WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "msi-z690-carbon-wifi", name: "MPG Z690 CARBON WIFI", brand: "微星", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "msi-z690-edge-ti-wifi", name: "MPG Z690 EDGE TI WIFI", brand: "微星", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "msi-z690-edge-wifi-d4", name: "MPG Z690 EDGE WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "msi-z690-a-pro-d5", name: "PRO Z690-A DDR5", brand: "微星", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "msi-z690-a-pro-wifi-d4", name: "PRO Z690-A WIFI DDR4", brand: "微星", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "asus-z690-hero", name: "ROG MAXIMUS Z690 HERO", brand: "华硕", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "asus-z690-a-gaming", name: "ROG STRIX Z690-A GAMING WIFI", brand: "华硕", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "gigabyte-z690-tachyon", name: "Z690 AORUS TACHYON", brand: "技嘉", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "gigabyte-z690-edge-wifi-d4", name: "Z690 EDGE WIFI DDR4", brand: "技嘉", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "gigabyte-z690-ud", name: "Z690 UD", brand: "技嘉", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "gigabyte-z690-ud-ax", name: "Z690 UD AX V2 (rev. 1.0)", brand: "技嘉", detail: "Intel · LGA1700 · Z690"),
        HardwareCatalogItem(id: "gigabyte-z690m-elite-d4", name: "Z690M AORUS ELITE DDR4", brand: "技嘉", detail: "Intel · LGA1700 · Z690")
    ]

    static let rams: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "ram-6000-cl28", name: "芝奇/海盗船 DDR5-6000 CL28", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6000MHz · CL28"),
        HardwareCatalogItem(id: "ram-6000-cl30", name: "芝奇/海盗船 DDR5-6000 CL30", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6000MHz · CL30"),
        HardwareCatalogItem(id: "ram-6000-cl32", name: "芝奇/海盗船 DDR5-6000 CL32", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6000MHz · CL32"),
        HardwareCatalogItem(id: "ram-6000-cl36", name: "芝奇/海盗船 DDR5-6000 CL36", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6000MHz · CL36"),
        HardwareCatalogItem(id: "ram-corsair-veng-ddr5-32-6000", name: "Corsair Vengeance RGB", brand: "Corsair", detail: "DDR5 · 32GB (16GBx2) · 6000MHz"),
        HardwareCatalogItem(id: "ram-6400-cl30", name: "芝奇/海盗船 DDR5-6400 CL30", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6400MHz · CL30"),
        HardwareCatalogItem(id: "ram-6400-cl32", name: "芝奇/海盗船 DDR5-6400 CL32", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6400MHz · CL32"),
        HardwareCatalogItem(id: "ram-6400-cl34", name: "芝奇/海盗船 DDR5-6400 CL34", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6400MHz · CL34"),
        HardwareCatalogItem(id: "ram-6400-cl36", name: "芝奇/海盗船 DDR5-6400 CL36", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6400MHz · CL36"),
        HardwareCatalogItem(id: "ram-6400-cl40", name: "芝奇/海盗船 DDR5-6400 CL40", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6400MHz · CL40"),
        HardwareCatalogItem(id: "ram-6800-cl32", name: "芝奇/海盗船 DDR5-6800 CL32", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6800MHz · CL32"),
        HardwareCatalogItem(id: "ram-6800-cl34", name: "芝奇/海盗船 DDR5-6800 CL34", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6800MHz · CL34"),
        HardwareCatalogItem(id: "ram-6800-cl36", name: "芝奇/海盗船 DDR5-6800 CL36", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6800MHz · CL36"),
        HardwareCatalogItem(id: "ram-6800-cl38", name: "芝奇/海盗船 DDR5-6800 CL38", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 6800MHz · CL38"),
        HardwareCatalogItem(id: "ram-7200-cl32", name: "芝奇/海盗船 DDR5-7200 CL32", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 7200MHz · CL32"),
        HardwareCatalogItem(id: "ram-7200-cl34", name: "芝奇/海盗船 DDR5-7200 CL34", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 7200MHz · CL34"),
        HardwareCatalogItem(id: "ram-7200-cl36", name: "芝奇/海盗船 DDR5-7200 CL36", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 7200MHz · CL36"),
        HardwareCatalogItem(id: "ram-7200-cl38", name: "芝奇/海盗船 DDR5-7200 CL38", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 7200MHz · CL38"),
        HardwareCatalogItem(id: "ram-7200-cl40", name: "芝奇/海盗船 DDR5-7200 CL40", brand: "芝奇/海盗船", detail: "DDR5 · 32GB (16GBx2) · 7200MHz · CL40")
    ]

    static let storages: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "sn850x", name: "Western Digital WD Black SN850X", brand: "Western Digital", detail: "1TB · PCIe 4.0"),
        HardwareCatalogItem(id: "990pro", name: "Samsung 990 PRO", brand: "Samsung", detail: "1TB · PCIe 4.0"),
        HardwareCatalogItem(id: "p44pro", name: "Solidigm P44 Pro", brand: "Solidigm", detail: "1TB · PCIe 4.0"),
        HardwareCatalogItem(id: "kc3000", name: "Kingston KC3000", brand: "Kingston", detail: "1TB · PCIe 4.0"),
        HardwareCatalogItem(id: "tiplus7100", name: "ZhiTai TiPlus 7100", brand: "ZhiTai", detail: "1TB · PCIe 4.0")
    ]

    static let powerSupplies: [HardwareCatalogItem] = [
        HardwareCatalogItem(id: "psu-cooler-master-v750", name: "Cooler Master V750 Gold V2", brand: "Cooler Master", detail: "750W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-corsair-rm750e", name: "Corsair RM750e", brand: "Corsair", detail: "750W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-evga-750gt", name: "EVGA SuperNOVA 750 GT", brand: "EVGA", detail: "750W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-huntkey-mvp750", name: "Huntkey MVP K750", brand: "Huntkey", detail: "750W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-msi-a750gl", name: "MSI MAG A750GL PCIE5", brand: "MSI", detail: "750W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-seasonic-gx750", name: "Seasonic Focus GX-750", brand: "Seasonic", detail: "750W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-cooler-master-v850", name: "Cooler Master V850 Gold V2", brand: "Cooler Master", detail: "850W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-corsair-rm850e", name: "Corsair RM850e", brand: "Corsair", detail: "850W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-evga-850gt", name: "EVGA SuperNOVA 850 GT", brand: "EVGA", detail: "850W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-huntkey-mvp850", name: "Huntkey MVP K850", brand: "Huntkey", detail: "850W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-msi-a850gl", name: "MSI MAG A850GL PCIE5", brand: "MSI", detail: "850W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-seasonic-gx850", name: "Seasonic Focus GX-850", brand: "Seasonic", detail: "850W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-corsair-rm1000e", name: "Corsair RM1000e", brand: "Corsair", detail: "1000W · 80+ Gold"),
        HardwareCatalogItem(id: "psu-seasonic-gx1000", name: "Seasonic Focus GX-1000", brand: "Seasonic", detail: "1000W · 80+ Gold")
    ]

    static let cpuOptions = unknownFirst(cpus.map(\.name))
    static let gpuOptions = unknownFirst(gpus.map(\.name))
    static let motherboardOptions = unknownFirst(motherboards.map(\.name))
    static let memoryOptions = unknownFirst(rams.map { "\($0.name) · \($0.detail)" })
    static let storageOptions = unknownFirst(storages.map { "\($0.name) · \($0.detail)" })
    static let powerSupplyOptions = unknownFirst(powerSupplies.map { "\($0.name) · \($0.detail)" })

    static let allOptionLabels = cpuOptions + gpuOptions + motherboardOptions + memoryOptions + storageOptions + powerSupplyOptions

    static func filters(for title: String) -> [HardwareCatalogFilter] {
        switch title {
        case "CPU", "处理器 (CPU)":
            return groupedFilters(items: cpus, filterKey: \.brand, groupKey: { generation(from: $0.detail) })
        case "显卡", "显卡 (GPU)":
            return groupedFilters(items: gpus, filterKey: \.brand, groupKey: { gpuSeries(from: $0.name) })
        case "主板":
            return groupedFilters(items: motherboards, filterKey: { motherboardPlatform(from: $0.detail) }, groupKey: { motherboardChipset(from: $0.detail) })
        case "内存", "内存 (RAM)":
            return groupedFilters(items: rams, filterKey: { ramType(from: $0.detail) }, groupKey: { ramSpeed(from: $0.detail) })
        case "硬盘":
            return groupedFilters(items: storages, filterKey: { storageType(from: $0.detail) }, groupKey: { storageCapacity(from: $0.detail) })
        case "电源", "电源 (PSU)":
            return groupedFilters(items: powerSupplies, filterKey: { powerWattage(from: $0.detail) }, groupKey: \.brand)
        default:
            return [
                HardwareCatalogFilter(
                    title: "全部",
                    groups: [HardwareCatalogGroup(title: title, items: items(for: title))]
                )
            ]
        }
    }

    static func motherboardFilters(compatibleWithCPU cpu: String) -> [HardwareCatalogFilter] {
        guard let socket = cpuSocket(for: cpu) else {
            return filters(for: "主板")
        }

        let compatibleMotherboards = motherboards.filter { motherboardSocket(for: $0.name) == socket }
        return groupedFilters(
            items: compatibleMotherboards,
            filterKey: { motherboardPlatform(from: $0.detail) },
            groupKey: { motherboardChipset(from: $0.detail) }
        )
    }

    static func areCompatible(cpu: String, motherboard: String) -> Bool {
        guard cpu != "不知道", motherboard != "不知道" else { return true }
        guard let cpuSocket = cpuSocket(for: cpu), let motherboardSocket = motherboardSocket(for: motherboard) else {
            return true
        }

        return cpuSocket == motherboardSocket
    }

    static func cpuSocket(for cpu: String) -> String? {
        guard let item = cpus.first(where: { $0.name == cpu }) else { return nil }
        return socket(from: item.detail)
    }

    static func motherboardSocket(for motherboard: String) -> String? {
        guard let item = motherboards.first(where: { $0.name == motherboard }) else { return nil }
        return socket(from: item.detail)
    }

    private static func unknownFirst(_ options: [String]) -> [String] {
        ["不知道"] + options
    }

    private static func items(for title: String) -> [HardwareCatalogItem] {
        switch title {
        case "CPU", "处理器 (CPU)":
            return cpus
        case "显卡", "显卡 (GPU)":
            return gpus
        case "主板":
            return motherboards
        case "内存", "内存 (RAM)":
            return rams
        case "硬盘":
            return storages
        case "电源", "电源 (PSU)":
            return powerSupplies
        default:
            return []
        }
    }

    private static func groupedFilters(
        items: [HardwareCatalogItem],
        filterKey: (HardwareCatalogItem) -> String,
        groupKey: (HardwareCatalogItem) -> String
    ) -> [HardwareCatalogFilter] {
        let filterTitles = unique(items.map(filterKey))

        return filterTitles.map { filterTitle in
            let filteredItems = items.filter { filterKey($0) == filterTitle }
            let groupTitles = unique(filteredItems.map(groupKey))
            let groups = groupTitles.map { groupTitle in
                HardwareCatalogGroup(
                    title: groupTitle,
                    items: filteredItems.filter { groupKey($0) == groupTitle }
                )
            }

            return HardwareCatalogFilter(title: filterTitle, groups: groups)
        }
    }

    private static func unique(_ values: [String]) -> [String] {
        values.reduce(into: []) { result, value in
            guard !result.contains(value) else { return }
            result.append(value)
        }
    }

    private static func generation(from detail: String) -> String {
        let value = detail.components(separatedBy: " · ").first ?? detail
        if value.contains("15代") || value.contains("Ultra") { return "酷睿 Ultra" }
        if value.contains("14代") { return "14代酷睿" }
        if value.contains("13代") { return "13代酷睿" }
        if value.contains("12代") { return "12代酷睿" }
        if value.contains("11代") { return "11代酷睿" }
        if value.contains("10代") { return "10代酷睿" }
        if value.contains("锐龙9000") { return "锐龙 9000" }
        if value.contains("锐龙7000") { return "锐龙 7000" }
        if value.contains("锐龙5000") { return "锐龙 5000" }
        return value
    }

    private static func gpuSeries(from name: String) -> String {
        if name.hasPrefix("RTX 50") { return "RTX 50 系列" }
        if name.hasPrefix("RTX 40") { return "RTX 40 系列" }
        if name.hasPrefix("RTX 30") { return "RTX 30 系列" }
        if name.hasPrefix("RTX 20") { return "RTX 20 系列" }
        if name.hasPrefix("GTX 16") { return "GTX 16 系列" }
        if name.hasPrefix("GTX 10") { return "GTX 10 系列" }
        if name.hasPrefix("RX 9") { return "RX 9000 系列" }
        if name.hasPrefix("RX 7") { return "RX 7000 系列" }
        if name.hasPrefix("RX 6") { return "RX 6000 系列" }
        if name.hasPrefix("RX 5") { return "RX 5000 系列" }
        return "其他显卡"
    }

    private static func motherboardPlatform(from detail: String) -> String {
        detail.components(separatedBy: " · ").first ?? "全部"
    }

    private static func motherboardChipset(from detail: String) -> String {
        detail.components(separatedBy: " · ").last ?? "其他芯片组"
    }

    private static func socket(from detail: String) -> String? {
        detail.components(separatedBy: " · ").first {
            $0.hasPrefix("LGA") || $0 == "AM4" || $0 == "AM5"
        }
    }

    private static func ramType(from detail: String) -> String {
        detail.components(separatedBy: " · ").first ?? "内存"
    }

    private static func ramSpeed(from detail: String) -> String {
        detail.components(separatedBy: " · ").dropFirst(2).first ?? "其他频率"
    }

    private static func storageType(from detail: String) -> String {
        detail.components(separatedBy: " · ").last ?? "硬盘"
    }

    private static func storageCapacity(from detail: String) -> String {
        detail.components(separatedBy: " · ").first ?? "容量"
    }

    private static func powerWattage(from detail: String) -> String {
        detail.components(separatedBy: " · ").first ?? "电源"
    }
}
