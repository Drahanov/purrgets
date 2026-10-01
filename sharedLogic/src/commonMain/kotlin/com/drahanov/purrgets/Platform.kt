package com.drahanov.purrgets

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform