package com.murattarslan.tayfam

import com.murattarslan.tayfam.e2e.SignalKoprusu
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var signalKoprusu: SignalKoprusu? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        signalKoprusu = SignalKoprusu.kur(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        signalKoprusu?.birak()
        signalKoprusu = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
