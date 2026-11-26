package com.cloudflypeng.btb.ui.account

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.cloudflypeng.btb.data.StoredAccount
import com.cloudflypeng.btb.ui.components.AppMark
import com.cloudflypeng.btb.ui.components.Avatar
import com.cloudflypeng.btb.ui.components.LoadingState
import com.cloudflypeng.btb.ui.components.MessageState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    viewModel: AccountViewModel,
    modifier: Modifier = Modifier,
    footer: @Composable () -> Unit = {},
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    var showLogin by remember { mutableStateOf(false) }
    var showAccounts by remember { mutableStateOf(false) }
    var removing by remember { mutableStateOf<StoredAccount?>(null) }

    Scaffold(
        modifier = modifier,
        topBar = {
            TopAppBar(title = { Text("我的", fontWeight = FontWeight.Bold) })
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            when {
                state.isLoading && state.accounts.isEmpty() -> LoadingState()

                state.error != null && state.accounts.isEmpty() -> MessageState(
                    icon = Icons.Default.Warning,
                    title = "账号加载失败",
                    message = state.error ?: "",
                    actionLabel = "重试",
                    onAction = viewModel::refresh,
                )

                else -> Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Column(
                        modifier = Modifier
                            .widthIn(max = 720.dp)
                            .fillMaxWidth()
                            .padding(20.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        val active = state.active
                        if (active == null) {
                            LoginCard(onLogin = {
                                viewModel.prepareLogin()
                                showLogin = true
                            })
                        } else {
                            ProfileCard(
                                account = active,
                                profileName = state.profile?.uname,
                                avatarUrl = state.profile?.avatarUrl ?: active.avatarUrl,
                                level = state.profile?.level,
                                coins = state.profile?.coins,
                                vip = state.profile?.vipStatus == 1,
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                OutlinedButton(
                                    onClick = { showAccounts = true },
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("切换账号")
                                }
                                OutlinedButton(
                                    onClick = viewModel::logout,
                                    modifier = Modifier.weight(1f),
                                ) {
                                    Text("退出登录")
                                }
                            }
                        }

                        if (state.error != null) {
                            Text(
                                text = state.error ?: "",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }

                        footer()
                    }
                }
            }
        }
    }

    if (showLogin) {
        LoginSheet(viewModel = viewModel, onDismiss = { showLogin = false })
    }

    if (showAccounts) {
        AccountsSheet(
            accounts = state.accounts,
            onDismiss = { showAccounts = false },
            onSelect = { account ->
                showAccounts = false
                if (account.active != true) viewModel.useAccount(account.mid)
            },
            onRemove = { account -> removing = account },
            onAdd = {
                showAccounts = false
                viewModel.prepareLogin()
                showLogin = true
            },
        )
    }

    removing?.let { account ->
        AlertDialog(
            onDismissRequest = { removing = null },
            title = { Text("移除账号") },
            text = { Text("从本机移除 ${account.displayName}？") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.removeAccount(account.mid)
                        removing = null
                    },
                ) {
                    Text("移除")
                }
            },
            dismissButton = {
                TextButton(onClick = { removing = null }) {
                    Text("取消")
                }
            },
        )
    }
}

@Composable
private fun LoginCard(onLogin: () -> Unit) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(20.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 28.dp),
        ) {
            AppMark(size = 58.dp)
            Text(
                text = "登录 BTB",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "同步观看进度、收藏与稍后再看",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(4.dp))
            Button(
                onClick = onLogin,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("登录")
            }
        }
    }
}

@Composable
private fun ProfileCard(
    account: StoredAccount,
    profileName: String?,
    avatarUrl: String?,
    level: Int?,
    coins: Int?,
    vip: Boolean,
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = RoundedCornerShape(20.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(20.dp),
        ) {
            Avatar(url = avatarUrl, size = 64.dp)
            Column(Modifier.weight(1f)) {
                Text(
                    text = profileName?.takeIf { it.isNotBlank() } ?: account.displayName,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = buildString {
                        append("UID ${account.mid}")
                        if (level != null && level > 0) append(" · LV$level")
                        if (coins != null) append(" · 硬币 $coins")
                    },
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (vip) {
                Surface(
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(50),
                ) {
                    Text(
                        text = "大会员",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AccountsSheet(
    accounts: List<StoredAccount>,
    onDismiss: () -> Unit,
    onSelect: (StoredAccount) -> Unit,
    onRemove: (StoredAccount) -> Unit,
    onAdd: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp),
        ) {
            Text(
                text = "切换账号",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(8.dp))
            accounts.forEach { account ->
                AccountRow(
                    account = account,
                    onClick = { onSelect(account) },
                    onRemove = { onRemove(account) },
                )
            }
            Spacer(Modifier.height(8.dp))
            TextButton(onClick = onAdd) {
                Text("添加账号")
            }
        }
    }
}

@Composable
private fun AccountRow(
    account: StoredAccount,
    onClick: () -> Unit,
    onRemove: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 10.dp),
    ) {
        Avatar(url = account.avatarUrl, size = 40.dp)
        Column(Modifier.weight(1f)) {
            Text(
                text = account.displayName,
                style = MaterialTheme.typography.titleSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = "UID ${account.mid}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (account.active == true) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "当前账号",
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(20.dp),
            )
        }
        IconButton(onClick = onRemove) {
            Icon(
                imageVector = Icons.Default.Delete,
                contentDescription = "移除账号",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
