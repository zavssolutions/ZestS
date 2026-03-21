package com.zests

import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.withClassName
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.hamcrest.Matchers.endsWith
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Espresso test to verify the Registration Flow functionality.
 * Since ZestS is a Flutter application, this test verifies that the 
 * Flutter engine initializes and displays the main FlutterView on an AVD.
 * 
 * For deep interaction with Flutter widgets, consider using the 
 * Flutter integration_test package instead, or adding semantics labels
 * to the Flutter widgets so Espresso can locate them via withContentDescription().
 */
@RunWith(AndroidJUnit4::class)
class RegistrationFlowTest {

    @Test
    fun testAppLaunchesToRegistrationScreen() {
        // Launch the MainActivity which hosts the Flutter engine
        val scenario = ActivityScenario.launch(MainActivity::class.java)

        // Verify that the Flutter surface is displayed
        onView(withClassName(endsWith("FlutterView"))).check(matches(isDisplayed()))
        
        // Note: To test the actual text fields (e.g. First Name, DOB, Role Dropdown),
        // we would need Semantics injected from Flutter or use Flutter Integration Tests.
        
        scenario.close()
    }
}
