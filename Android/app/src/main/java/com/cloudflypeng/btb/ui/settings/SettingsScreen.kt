package com.cloudflypeng.btb.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cloudflypeng.btb.BtbApplication
import com.cloudflypeng.btb.data.ThemeMode
import com.cloudflypeng.btb.ui.discover.DiscoverSubScreen

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    version: String = "1.0",
) {
    val context = LocalContext.current
    val settings = remember(context) {
        (context.applicationContext as BtbApplication).container.settings
    }
    val state by settings.state.collectAsStateWithLifecycle()
    var blockWords by remember(state.danmakuBlockWords) { mutableStateOf(state.danmakuBlockWords) }

    DiscoverSubScreen(title = "设置", onBack = onBack) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            SettingsGroup(title = "外观") {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                ) {
                    ThemeMode.entries.forEach { mode ->
                        FilterChip(
                            selected = state.themeMode == mode,
                            onClick = { settings.setThemeMode(mode) },
                            label = { Text(mode.label) },
                        )
                    }
                }
            }

            SettingsGroup(title = "播放") {
                SettingsSwitchRow(
                    title = "自动连播",
                    subtitle = "播放结束后自动播放下一个视频",
                    checked = state.autoplayNext,
                    onCheckedChange = settings::setAutoplayNext,
                )
                SettingsChoiceRow(
                    title = "默认清晰度",
                    options = QUALITY_OPTIONS,
                    selected = state.defaultQuality,
                    onSelect = settings::setDefaultQuality,
                )
            }

            SettingsGroup(title = "弹幕") {
                SettingsSwitchRow(
                    title = "默认开启弹幕",
                    subtitle = "打开新视频时显示弹幕",
                    checked = state.danmakuEnabled,
                    onCheckedChange = settings::setDanmakuEnabled,
                )
                SettingsSliderRow(
                    title = "不透明度",
                    value = state.danmakuOpacity,
                    range = 0.2f..1f,
                    format = { "${(it * 100).toInt()}%" },
                    onChange = settings::setDanmakuOpacity,
                )
                SettingsSliderRow(
                    title = "速度",
                    value = state.danmakuSpeed,
                    range = 0.5f..2f,
                    format = { String.format(java.util.Locale.CHINA, "%.1fx", it) },
                    onChange = settings::setDanmakuSpeed,
                )
                SettingsSliderRow(
                    title = "字号",
                    value = state.danmakuFontScale,
                    range = 0.7f..1.6f,
                    format = { String.format(java.util.Locale.CHINA, "%.1fx", it) },
                    onChange = settings::setDanmakuFontScale,
                )
                Column(Modifier.padding(horizontal = 14.dp, vertical = 8.dp)) {
                    OutlinedTextField(
                        value = blockWords,
                        onValueChange = { blockWords = it },
                        label = { Text("屏蔽词（逗号分隔）") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            "命中的弹幕将不会显示",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            "保存",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier
                                .padding(horizontal = 6.dp)
                                .clickable { settings.setDanmakuBlockWords(blockWords) },
                        )
                    }
                }
            }

            SettingsGroup(title = "关于") {
                Column(Modifier.padding(horizontal = 14.dp, vertical = 10.dp)) {
                    Text("BTB Android $version", style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "由 bbcore 提供数据与播放能力，仅用于个人学习与观看。",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

private val QUALITY_OPTIONS = listOf(
    127L to "超高清 8K",
    126L to "杜比视界",
    125L to "HDR 真彩",
    120L to "超清 4K",
    116L to "高清 1080P60",
    80L to "高清 1080P",
    64L to "高清 720P",
    32L to "清晰 480P",
)

@Composable
private fun SettingsGroup(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            title,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 4.dp),
        )
        Surface(
            color = MaterialTheme.colorScheme.surfaceVariant,
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column { content() }
        }
    }
}

@Composable
private fun SettingsSwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyMedium)
            Text(
                subtitle,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun SettingsChoiceRow(
    title: String,
    options: List<Pair<Long, String>>,
    selected: Long,
    onSelect: (Long) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(Modifier.padding(horizontal = 14.dp, vertical = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            Text(
                options.firstOrNull { it.first == selected }?.second ?: "默认",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f), RoundedCornerShape(8.dp))
                    .padding(horizontal = 10.dp, vertical = 4.dp)
                    .clickable { expanded = true },
            )
        }
        androidx.compose.material3.DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (qn, label) ->
                androidx.compose.material3.DropdownMenuItem(
                    text = { Text(label) },
                    onClick = {
                        expanded = false
                        onSelect(qn)
                    },
                )
            }
        }
    }
}

@Composable
private fun SettingsSliderRow(
    title: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    format: (Float) -> String,
    onChange: (Float) -> Unit,
) {
    Column(Modifier.padding(horizontal = 14.dp, vertical = 4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            Text(
                format(value),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Slider(
            value = value.coerceIn(range.start, range.endInclusive),
            onValueChange = onChange,
            valueRange = range,
        )
    }
}
