plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// El plugin de Google Services aborta la build entera si no encuentra
// google-services.json, y ese archivo sale del proyecto de Firebase de cada
// entorno. Se aplica solo si está presente, así nadie queda sin poder compilar
// por no tenerlo: es el mismo criterio que usa el backend, que saltea el canal
// de push cuando no están configuradas sus credenciales (config/push.php).
//
// Sin el archivo la app funciona igual — Firebase no arranca, PushService se
// marca como no disponible y los chats siguen llegando por el polleo. Lo único
// que se pierde son los avisos con la app cerrada.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn(
        "AVISO: falta android/app/google-services.json. " +
            "La app se compila SIN notificaciones push.",
    )
}

android {
    namespace = "com.cloudapicc.cloud_api_cc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cloudapicc.cloud_api_cc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
