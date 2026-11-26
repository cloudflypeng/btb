package com.cloudflypeng.btb.data

import com.cloudflypeng.btb.core.CoreException
import com.cloudflypeng.btb.core.CoreTransport
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.put

@Serializable
data class UserSpaceInfo(
    val mid: Long = 0,
    val name: String = "",
    val face: String? = null,
    val sign: String? = null,
    val level: Int? = null,
    @SerialName("top_photo") val topPhoto: String? = null,
    val attention: Long? = null,
    val fans: Long? = null,
) {
    val faceUrl: String? get() = normalizeMediaUrl(face)
    val bannerUrl: String? get() = normalizeMediaUrl(topPhoto)
}

@Serializable
data class UserRelation(
    val mid: Long = 0,
    val attribute: Int? = null,
    @SerialName("is_followed") val isFollowed: Boolean? = null,
) {
    val isFollowing: Boolean get() = attribute == 2 || attribute == 6 || isFollowed == true
}

@Serializable
data class SocialUser(
    val mid: Long = 0,
    val uname: String = "",
    val face: String? = null,
    val sign: String? = null,
    val attribute: Int? = null,
    val special: Int? = null,
    @SerialName("official_verify") val official: SearchUserOfficial? = null,
) {
    val faceUrl: String? get() = normalizeMediaUrl(face)
    val isFollowing: Boolean get() = (attribute ?: 0) == 2 || attribute == 6
    val detailText: String
        get() = official?.desc?.takeIf { it.isNotBlank() } ?: sign.orEmpty()
}

@Serializable
data class FollowingsData(
    val list: List<SocialUser>? = null,
    val total: Int? = null,
)

@Serializable
data class FollowersData(
    val list: List<SocialUser>? = null,
    val total: Int? = null,
)

@Serializable
private data class VideoOwnerRaw(val mid: Long? = null)

@Serializable
private data class VideoInfoData(val owner: VideoOwnerRaw? = null)

class SocialRepository(private val core: CoreTransport) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    suspend fun videoOwnerMid(bvid: String): Long? {
        val result = core.call("video.info", buildJsonObject { put("bvid", bvid) })
        val response = json.decodeFromJsonElement<UpstreamResponse<VideoInfoData>>(result)
        if (response.code != 0) return null
        return response.data?.owner?.mid?.takeIf { it > 0 }
    }

    suspend fun info(mid: Long): UserSpaceInfo {
        val result = core.call("user.info", buildJsonObject { put("mid", mid) })
        val response = json.decodeFromJsonElement<UpstreamResponse<UserSpaceInfo>>(result)
        requireSuccess(response, "用户信息加载失败")
        return response.data ?: throw CoreException(response.code, "用户不存在")
    }

    suspend fun relation(mid: Long): UserRelation? {
        val result = core.call("user.relation", buildJsonObject { put("mid", mid) })
        val response = json.decodeFromJsonElement<UpstreamResponse<UserRelation>>(result)
        return response.data
    }

    suspend fun videos(mid: Long, page: Int = 1, pageSize: Int = 20): List<VideoItem> {
        val result = core.call(
            "user.videos",
            buildJsonObject {
                put("mid", mid)
                put("pn", page)
                put("ps", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<UserVideosData>>(result)
        requireSuccess(response, "投稿加载失败")
        return response.data?.list?.vlist.orEmpty().mapNotNull { it.toVideoItemOrNull() }
    }

    suspend fun followings(vmid: Long, page: Int = 1, pageSize: Int = 30): List<SocialUser> {
        val result = core.call(
            "user.followings",
            buildJsonObject {
                put("vmid", vmid)
                put("pn", page)
                put("ps", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<FollowingsData>>(result)
        requireSuccess(response, "关注列表加载失败")
        return response.data?.list.orEmpty()
    }

    suspend fun followers(vmid: Long, page: Int = 1, pageSize: Int = 30): List<SocialUser> {
        val result = core.call(
            "user.followers",
            buildJsonObject {
                put("vmid", vmid)
                put("pn", page)
                put("ps", pageSize)
            },
        )
        val response = json.decodeFromJsonElement<UpstreamResponse<FollowersData>>(result)
        requireSuccess(response, "粉丝列表加载失败")
        return response.data?.list.orEmpty()
    }

    suspend fun follow(uid: Long, follow: Boolean) {
        val result = core.call(
            "user.follow",
            buildJsonObject {
                put("fid", uid)
                put("follow", follow)
            },
        )
        val response = json.decodeFromJsonElement<LiveBasicResponse>(result)
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: "操作失败")
        }
    }

    private fun requireSuccess(response: UpstreamResponse<*>, failure: String) {
        if (response.code != 0) {
            throw CoreException(response.code, response.message ?: failure)
        }
    }
}
