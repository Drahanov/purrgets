package com.drahanov.purrgets

import com.drahanov.purrgets.domain.model.Moment

/** `Moment.zone` is hidden in Swift by NSObject's own `zone` method, so Swift reads the id from here. */
val Moment.zoneId: String? get() = zone?.id
