package core.blocker.engine

sealed class BlockState {
    object IDLE : BlockState()
    object BLOCKED : BlockState()
    object BYPASS_ACTIVE : BlockState()
}

