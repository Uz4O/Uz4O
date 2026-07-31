package top.uzbox.app.ui.home

import androidx.annotation.DrawableRes
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.uzbox.app.R
import top.uzbox.app.ui.theme.UzBoxAccent
import top.uzbox.app.ui.theme.UzBoxBackground
import top.uzbox.app.ui.theme.UzBoxMuted
import top.uzbox.app.ui.theme.UzBoxSurface
import top.uzbox.app.ui.theme.UzBoxText
import top.uzbox.app.ui.theme.UzBoxTheme

private data class HomeFeature(
    val title: String,
    val selectorTitle: String,
    val subtitle: String,
    val buttonTitle: String,
    val glyph: String,
    val bullets: List<String>,
    @param:DrawableRes val image: Int,
    val tint: Color
)

private val homeFeatures = listOf(
    HomeFeature(
        title = "AI 一键装机",
        selectorTitle = "AI 装机",
        subtitle = "从预算到配置，一次讲清楚",
        buttonTitle = "开始装机",
        glyph = "AI",
        bullets = listOf("智能推荐配置", "自动检查兼容性", "优化预算分配"),
        image = R.drawable.home_style_black_knight,
        tint = Color(0xFFDDF7EE)
    ),
    HomeFeature(
        title = "游戏性能测试",
        selectorTitle = "性能测试",
        subtitle = "看懂帧率、瓶颈和体验差距",
        buttonTitle = "开始测试",
        glyph = "FPS",
        bullets = listOf("帧率表现估算", "硬件瓶颈分析", "游戏场景建议"),
        image = R.drawable.home_hero_performance_gpu,
        tint = Color(0xFFE8E8E8)
    ),
    HomeFeature(
        title = "配置排雷",
        selectorTitle = "配置排雷",
        subtitle = "快速判断这套配置能不能买",
        buttonTitle = "开始排雷",
        glyph = "✓",
        bullets = listOf("识别搭配风险", "检查兼容问题", "提示预算浪费"),
        image = R.drawable.home_hero_config_review_board,
        tint = Color(0xFFEAF0F4)
    ),
    HomeFeature(
        title = "升级建议",
        selectorTitle = "升级建议",
        subtitle = "把钱花在提升最明显的地方",
        buttonTitle = "查看建议",
        glyph = "↑",
        bullets = listOf("定位升级短板", "排序更换优先级", "匹配预算方案"),
        image = R.drawable.home_hero_upgrade_parts,
        tint = Color(0xFFF1ECE5)
    )
)

private data class BuildStyle(
    val title: String,
    val subtitle: String,
    @param:DrawableRes val image: Int
)

private val buildStyles = listOf(
    BuildStyle("黑武士", "沉稳·高性能", R.drawable.home_style_black_knight),
    BuildStyle("白色极简", "干净·高级感", R.drawable.home_style_white_minimal),
    BuildStyle("海景房", "通透·氛围感", R.drawable.home_style_panorama)
)

@Composable
fun HomeScreen(
    onFeatureClick: (Int) -> Unit = {},
    onStyleClick: (Int) -> Unit = {}
) {
    var selectedFeature by rememberSaveable { mutableIntStateOf(0) }

    Scaffold(
        containerColor = UzBoxBackground,
        bottomBar = { HomeBottomBar() }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(start = 20.dp, top = 12.dp, end = 20.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp)
        ) {
            item { HomeHeader() }
            item {
                AnimatedContent(
                    targetState = selectedFeature,
                    transitionSpec = {
                        (fadeIn(tween(220)) + scaleIn(tween(220), initialScale = 0.985f)) togetherWith
                            (fadeOut(tween(150)) + scaleOut(tween(150), targetScale = 0.99f))
                    },
                    label = "home-feature"
                ) { index ->
                    HomeHeroCard(homeFeatures[index]) { onFeatureClick(index) }
                }
            }
            item {
                FeatureSelector(
                    selectedIndex = selectedFeature,
                    onSelect = { selectedFeature = it }
                )
            }
            item { BuildStyleSection(onStyleClick) }
        }
    }
}

@Composable
private fun HomeHeader() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .statusBarsPadding(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(
                text = "UzBox",
                color = UzBoxText,
                fontSize = 30.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = (-1).sp
            )
            Text(
                text = "你的电脑配置助手",
                color = UzBoxMuted,
                fontSize = 12.sp
            )
        }
        Spacer(Modifier.weight(1f))
        Surface(
            modifier = Modifier
                .size(42.dp)
                .semantics { contentDescription = "消息" },
            shape = CircleShape,
            color = UzBoxSurface,
            shadowElevation = 5.dp
        ) {
            Box(contentAlignment = Alignment.Center) {
                Text("•", color = UzBoxText, fontSize = 27.sp, fontWeight = FontWeight.Black)
                Box(
                    Modifier
                        .padding(top = 9.dp, start = 9.dp)
                        .size(7.dp)
                        .background(UzBoxAccent, CircleShape)
                )
            }
        }
    }
}

@Composable
private fun HomeHeroCard(feature: HomeFeature, onClick: () -> Unit) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(14.dp, RoundedCornerShape(30.dp), ambientColor = Color.Black.copy(alpha = 0.08f)),
        shape = RoundedCornerShape(30.dp),
        color = UzBoxSurface
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(328.dp)
                .background(
                    Brush.linearGradient(
                        listOf(UzBoxSurface, feature.tint.copy(alpha = 0.84f))
                    )
                )
                .padding(24.dp)
        ) {
            Image(
                painter = painterResource(feature.image),
                contentDescription = null,
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .padding(top = 22.dp)
                    .size(width = 174.dp, height = 224.dp),
                contentScale = ContentScale.Fit
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth(0.64f)
                    .align(Alignment.TopStart)
            ) {
                Text("当前功能", color = UzBoxMuted, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                Spacer(Modifier.height(16.dp))
                Text(
                    text = feature.title,
                    color = UzBoxText,
                    fontSize = 30.sp,
                    lineHeight = 34.sp,
                    fontWeight = FontWeight.Black,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = feature.subtitle,
                    color = UzBoxMuted,
                    fontSize = 13.sp,
                    lineHeight = 20.sp,
                    maxLines = 2
                )
                Spacer(Modifier.height(22.dp))
                feature.bullets.forEach { bullet ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("✓", color = UzBoxText.copy(alpha = 0.55f), fontSize = 12.sp)
                        Spacer(Modifier.width(7.dp))
                        Text(bullet, color = UzBoxText.copy(alpha = 0.55f), fontSize = 12.sp)
                    }
                    Spacer(Modifier.height(6.dp))
                }
            }

            Button(
                onClick = onClick,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .height(46.dp),
                shape = RoundedCornerShape(23.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = UzBoxText,
                    contentColor = UzBoxSurface
                ),
                contentPadding = PaddingValues(horizontal = 22.dp)
            ) {
                Text(feature.buttonTitle, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                Spacer(Modifier.width(16.dp))
                Text("→", fontSize = 18.sp)
            }
        }
    }
}

@Composable
private fun FeatureSelector(selectedIndex: Int, onSelect: (Int) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        homeFeatures.forEachIndexed { index, feature ->
            val selected = index == selectedIndex
            Column(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(18.dp))
                    .clickable { onSelect(index) }
                    .padding(vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Surface(
                    modifier = Modifier.size(52.dp),
                    shape = RoundedCornerShape(17.dp),
                    color = if (selected) UzBoxText else UzBoxSurface,
                    shadowElevation = if (selected) 9.dp else 2.dp
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Text(
                            text = feature.glyph,
                            color = if (selected) UzBoxSurface else UzBoxText,
                            fontSize = if (feature.glyph.length > 2) 10.sp else 14.sp,
                            fontWeight = FontWeight.Black
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    text = feature.selectorTitle,
                    color = UzBoxText,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun BuildStyleSection(onStyleClick: (Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(15.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("精选装机风格", color = UzBoxText, fontSize = 20.sp, fontWeight = FontWeight.Black)
            Text("找到你喜欢的主机外观与氛围", color = UzBoxMuted, fontSize = 12.sp)
        }

        LazyRow(
            contentPadding = PaddingValues(end = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(buildStyles) { style ->
                val index = buildStyles.indexOf(style)
                Surface(
                    modifier = Modifier
                        .width(168.dp)
                        .clickable { onStyleClick(index) },
                    shape = RoundedCornerShape(24.dp),
                    color = UzBoxSurface,
                    shadowElevation = 3.dp
                ) {
                    Column {
                        Image(
                            painter = painterResource(style.image),
                            contentDescription = style.title,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(142.dp)
                                .padding(12.dp),
                            contentScale = ContentScale.Fit
                        )
                        Column(Modifier.padding(start = 15.dp, end = 15.dp, bottom = 15.dp)) {
                            Text(style.title, color = UzBoxText, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(3.dp))
                            Text(style.subtitle, color = UzBoxMuted, fontSize = 11.sp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeBottomBar() {
    val tabs = listOf("首页" to "●", "风格" to "◇", "DIY" to "+", "我的" to "○")
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = UzBoxSurface,
        shadowElevation = 18.dp
    ) {
        Row(
            modifier = Modifier
                .navigationBarsPadding()
                .height(66.dp)
                .padding(horizontal = 18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            tabs.forEachIndexed { index, (label, glyph) ->
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = label },
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = glyph,
                        color = if (index == 0) UzBoxText else UzBoxMuted.copy(alpha = 0.55f),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = label,
                        color = if (index == 0) UzBoxText else UzBoxMuted,
                        fontSize = 10.sp,
                        fontWeight = if (index == 0) FontWeight.Bold else FontWeight.Medium
                    )
                }
            }
        }
    }
}

@Preview(showBackground = true, widthDp = 393, heightDp = 852)
@Composable
private fun HomeScreenPreview() {
    UzBoxTheme {
        HomeScreen()
    }
}
