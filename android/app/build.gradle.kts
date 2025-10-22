plugins {
	id("com.android.application")
	id("kotlin-android")
	// The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
	id("dev.flutter.flutter-gradle-plugin")
}

android {
	namespace = "com.itsng.label_printer"
	compileSdk = flutter.compileSdkVersion
	ndkVersion = flutter.ndkVersion

	compileOptions {
			sourceCompatibility = JavaVersion.VERSION_11
			targetCompatibility = JavaVersion.VERSION_11
	}

	kotlinOptions {
			jvmTarget = JavaVersion.VERSION_11.toString()
	}

	defaultConfig {
		// TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
		applicationId = "com.itsng.label_printer"
		// You can update the following values to match your application needs.
		// For more information, see: https://flutter.dev/to/review-gradle-config.
		minSdk = flutter.minSdkVersion
		targetSdk = flutter.targetSdkVersion
		versionCode = flutter.versionCode
		versionName = flutter.versionName
		resConfigs("en", "ko")

		ndk {
			abiFilters += setOf("arm64-v8a") // arm64만 포함
		}
	}

	buildTypes {
		getByName("debug") {
			// 디버그 빌드에서는 코드/리소스 축소 비활성화(개발 속도 우선)
			isMinifyEnabled = false
			isShrinkResources = false
		}

		getByName("release") {
			// TODO: 실제 배포용 서명 설정을 구성하세요.
			// 현재는 `flutter run --release` 편의를 위해 debug 서명을 사용합니다.
			signingConfig = signingConfigs.getByName("debug")

			// 사용하지 않는 리소스 제거는 코드 축소가 켜져 있어야 동작합니다.
			isMinifyEnabled = true
			isShrinkResources = true
		}
	}
}

dependencies {
	implementation("androidx.documentfile:documentfile:1.0.1")
}

flutter {
    source = "../.."
}
