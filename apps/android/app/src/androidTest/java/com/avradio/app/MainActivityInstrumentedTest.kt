package com.avradio.app

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class MainActivityInstrumentedTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun appShowsHomeAfterContinuingAsGuest() {
        dismissOnboardingIfNeeded()

        composeRule.onNodeWithText("Discover live radio").assertIsDisplayed()
        composeRule.onNodeWithText("Home").assertIsDisplayed()
    }

    @Test
    fun appNavigatesToSearchTab() {
        dismissOnboardingIfNeeded()

        composeRule.onNodeWithText("Search").performClick()
        composeRule.onNodeWithText("Search stations").assertIsDisplayed()
    }

    @Test
    fun appNavigatesToLibraryTab() {
        dismissOnboardingIfNeeded()

        composeRule.onNodeWithText("Library").performClick()
        composeRule.onNodeWithText("Your library").assertIsDisplayed()
        composeRule.onNodeWithText("No favorites yet").assertIsDisplayed()
    }

    @Test
    fun appNavigatesToProfileTab() {
        dismissOnboardingIfNeeded()

        composeRule.onNodeWithText("Profile").performClick()
        composeRule.onNodeWithText("Profile").assertIsDisplayed()
        composeRule.onNodeWithText("Local data").assertIsDisplayed()
    }

    @Test
    fun profileSleepTimerCanBeChangedLocally() {
        dismissOnboardingIfNeeded()

        composeRule.onNodeWithText("Profile").performClick()
        composeRule.onNodeWithText("Sleep timer: Off").assertIsDisplayed()
        composeRule.onNodeWithText("15m").performClick()
        composeRule.onNodeWithText("Sleep timer: 15 minutes").assertIsDisplayed()
        composeRule.onNodeWithText("Off").performClick()
        composeRule.onNodeWithText("Sleep timer: Off").assertIsDisplayed()
    }

    private fun dismissOnboardingIfNeeded() {
        val continueNodes = composeRule.onAllNodesWithText("Continue in local mode")
        if (continueNodes.fetchSemanticsNodes().isNotEmpty()) {
            composeRule.onNodeWithText("Continue in local mode").performClick()
        }
    }
}
