package core.blocker.engine

data class BypassRule(
    val id: String,
    val resourceId: String,
    val grantedAtMillis: Long,
    val durationMillis: Long = DEFAULT_DURATION_MILLIS
) {
    init {
        require(id.isNotBlank()) { "Bypass ID must not be blank" }
        require(resourceId.isNotBlank()) { "Resource ID must not be blank" }
        require(grantedAtMillis >= 0) { "Granted timestamp must be non-negative" }
        require(durationMillis > 0) { "Duration must be positive" }
        require(durationMillis <= MAX_DURATION_MILLIS) { "Duration must not exceed maximum" }
    }

    val expiresAtMillis: Long
        get() = grantedAtMillis + durationMillis

    fun isActive(currentTimeMillis: Long): Boolean {
        return currentTimeMillis in grantedAtMillis until expiresAtMillis
    }

    fun isExpired(currentTimeMillis: Long): Boolean {
        return currentTimeMillis >= expiresAtMillis
    }

    companion object {
        const val DEFAULT_DURATION_MILLIS = 2L * 60 * 1000
        const val MAX_DURATION_MILLIS = 24L * 60 * 60 * 1000
    }
}

