package com.deskbtm.muasic.query

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class QueryRequest(
    val call: MethodCall,
    val result: MethodChannel.Result,
    val context: Context,
    val showDetailedLog: Boolean,
)
