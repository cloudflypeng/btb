package com.cloudflypeng.btb.ui.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.cloudflypeng.btb.ui.interaction.rememberAnimationsEnabled

@Composable
fun SkeletonBlock(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(6.dp),
) {
    Box(modifier.background(MaterialTheme.colorScheme.surfaceVariant, shape))
}

@Composable
fun SkeletonCircle(size: Dp) {
    SkeletonBlock(Modifier.size(size), CircleShape)
}

@Composable
fun Modifier.skeletonPulse(): Modifier {
    val animationsEnabled = rememberAnimationsEnabled()
    return if (animationsEnabled) {
        val transition = rememberInfiniteTransition(label = "btb-skeleton")
        val alpha by transition.animateFloat(
            initialValue = 0.48f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 950, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse,
            ),
            label = "btb-skeleton-alpha",
        )
        this.alpha(alpha)
    } else {
        this.alpha(0.72f)
    }
}

@Composable
fun VideoCardSkeleton(modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().skeletonPulse()) {
        SkeletonBlock(
            Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f),
            RoundedCornerShape(12.dp),
        )
        Spacer(Modifier.height(10.dp))
        SkeletonBlock(Modifier.fillMaxWidth().height(16.dp))
        Spacer(Modifier.height(7.dp))
        SkeletonBlock(Modifier.fillMaxWidth(0.72f).height(16.dp))
        Spacer(Modifier.height(10.dp))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            SkeletonCircle(22.dp)
            SkeletonBlock(Modifier.width(120.dp).height(12.dp))
        }
    }
}

@Composable
fun DynamicCardSkeleton(modifier: Modifier = Modifier) {
    Column(modifier.fillMaxWidth().padding(14.dp).skeletonPulse()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            SkeletonCircle(34.dp)
            Column(
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.weight(1f),
            ) {
                SkeletonBlock(Modifier.width(100.dp).height(12.dp))
                SkeletonBlock(Modifier.width(70.dp).height(10.dp))
            }
        }
        Spacer(Modifier.height(12.dp))
        SkeletonBlock(Modifier.fillMaxWidth().height(12.dp))
        Spacer(Modifier.height(6.dp))
        SkeletonBlock(Modifier.fillMaxWidth(0.85f).height(12.dp))
        Spacer(Modifier.height(12.dp))
        SkeletonBlock(
            Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f),
            RoundedCornerShape(10.dp),
        )
    }
}

@Composable
fun MessageRowSkeleton(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .skeletonPulse(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SkeletonCircle(38.dp)
        Column(
            verticalArrangement = Arrangement.spacedBy(7.dp),
            modifier = Modifier.weight(1f),
        ) {
            SkeletonBlock(Modifier.width(120.dp).height(12.dp))
            SkeletonBlock(Modifier.fillMaxWidth().height(12.dp))
            SkeletonBlock(Modifier.fillMaxWidth(0.7f).height(12.dp))
        }
    }
}

@Composable
fun CommentRowSkeleton(modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 10.dp)
            .skeletonPulse(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SkeletonCircle(32.dp)
        Column(
            verticalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.weight(1f),
        ) {
            SkeletonBlock(Modifier.width(110.dp).height(11.dp))
            SkeletonBlock(Modifier.fillMaxWidth().height(12.dp))
            SkeletonBlock(Modifier.fillMaxWidth(0.75f).height(12.dp))
        }
    }
}
