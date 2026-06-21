package com.sukoon.launcher

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen overlay that blocks access to a blocked app.
 * Launched by AppBlockerService when it detects a blocked app in the foreground.
 * 
 * This Activity sits on top of the blocked app and pressing back
 * goes to the home screen (our launcher), not back to the blocked app.
 */
class BlockedAppActivity : Activity() {

    companion object {
        const val TAG = "BlockedAppActivity"
    }

    private var blockedPackage: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ── SENIOR LOGIC: Launcher Guard ──
        if (!isSukoonDefaultLauncher()) {
            Log.d(TAG, "Not default launcher — closing blocking overlay")
            finish()
            return
        }

        blockedPackage = intent?.getStringExtra("blocked_package")
        Log.d(TAG, "Blocking overlay shown for: $blockedPackage")

        // Make it full screen, cover everything
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)

        // Get app name
        val appName = try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(blockedPackage ?: "", 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            blockedPackage?.split(".")?.lastOrNull() ?: "App"
        }

        // Motivational messages — matches Flutter BlockedAppScreen
        val motivations = arrayOf(
            "This urge will pass.\nYour discipline won't.",
            "Every second of resistance\nrewires your brain.",
            "You chose to block this.\nTrust your better self.",
            "The discomfort is temporary.\nThe growth is permanent.",
            "Stay the course.\nYour future self thanks you.",
            "Distraction steals time\nyou can never get back."
        )
        val motivation = motivations[(System.currentTimeMillis() % motivations.size).toInt()]

        // Build the blocking UI — minimalist red theme
        val blockRed = 0xFFD93025.toInt()

        val root = FrameLayout(this).apply {
            setBackgroundColor(0xFF0A0A0A.toInt()) // Near-black background
            isClickable = true  // Consume all touches
            isFocusable = true
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(100, 0, 100, 0)
        }

        // Block icon (⛔ style using text)
        val icon = TextView(this).apply {
            text = "⊘"
            textSize = 52f
            setTextColor(0x99D93025.toInt()) // Red 60%
            gravity = Gravity.CENTER
        }
        content.addView(icon)

        // Spacing
        content.addView(spacer(32))

        // App name — subtle
        val subtitle = TextView(this).apply {
            text = appName
            textSize = 13f
            setTextColor(0x59FFFFFF.toInt()) // White 35%
            gravity = Gravity.CENTER
            letterSpacing = 0.1f
        }
        content.addView(subtitle)

        // Spacing
        content.addView(spacer(8))

        // "BLOCKED" label — red accent
        val blockedLabel = TextView(this).apply {
            text = "BLOCKED"
            textSize = 11f
            setTextColor(0xB3D93025.toInt()) // Red 70%
            gravity = Gravity.CENTER
            letterSpacing = 0.2f
            paint.isFakeBoldText = true
        }
        content.addView(blockedLabel)

        // Spacing
        content.addView(spacer(36))

        // Motivational message
        val message = TextView(this).apply {
            text = motivation
            textSize = 15f
            setTextColor(0x8CFFFFFF.toInt()) // White 55%
            gravity = Gravity.CENTER
            setLineSpacing(10f, 1f)
        }
        content.addView(message)

        // Spacing
        content.addView(spacer(56))

        // "Go Back" button — subtle white
        val goHomeBtn = TextView(this).apply {
            text = "Go Back"
            textSize = 14f
            setTextColor(0x80FFFFFF.toInt()) // White 50%
            gravity = Gravity.CENTER
            letterSpacing = 0.03f
            setPadding(80, 40, 80, 40)
            setBackgroundColor(0x0AFFFFFF.toInt()) // White 4%
            setOnClickListener { goHome() }
        }
        content.addView(goHomeBtn)

        // Center content in root
        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }
        root.addView(content, params)

        setContentView(root)
    }

    private fun spacer(heightDp: Int): android.view.View {
        return android.view.View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (heightDp * resources.displayMetrics.density).toInt()
            )
        }
    }

    /**
     * Back button → go to home screen (our launcher), NOT back to blocked app
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goHome()
    }

    /**
     * If user switches away and comes back (via recents), 
     * and the blocked app is still blocked, keep showing this.
     */
    override fun onResume() {
        super.onResume()
        // Re-check if still blocked (rule might have been deactivated)
        val pkg = blockedPackage
        if (pkg != null) {
            val blocked = AppBlockerService.getBlockedPackages(this)
            if (!blocked.contains(pkg)) {
                // No longer blocked — dismiss this overlay
                finish()
            }
        }
    }

    private fun goHome() {
        // Correct behavior for a premium launcher: 
        // Always go to the current default home screen (whichever it is).
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(intent)
        finish()
    }

    private fun isSukoonDefaultLauncher(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
            val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            resolveInfo?.activityInfo?.packageName == packageName
        } catch (e: Exception) {
            false
        }
    }
}
