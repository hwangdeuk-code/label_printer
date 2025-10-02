# Flutter 프로젝트 자동 분석 결과

## 디렉터리 트리 (상위 6레벨)

```
flutter_project_analysis
├── android
│   ├── app
│   │   └── src
│   │       ├── debug
│   │       │   └── AndroidManifest.xml
│   │       ├── main
│   │       │   ├── java
│   │       │   │   └── io
│   │       │   │       └── flutter
│   │       │   ├── kotlin
│   │       │   │   └── com
│   │       │   │       └── example
│   │       │   ├── res
│   │       │   │   ├── drawable
│   │       │   │   │   └── launch_background.xml
│   │       │   │   ├── drawable-v21
│   │       │   │   │   └── launch_background.xml
│   │       │   │   ├── mipmap-hdpi
│   │       │   │   │   └── ic_launcher.png
│   │       │   │   ├── mipmap-mdpi
│   │       │   │   │   └── ic_launcher.png
│   │       │   │   ├── mipmap-xhdpi
│   │       │   │   │   └── ic_launcher.png
│   │       │   │   ├── mipmap-xxhdpi
│   │       │   │   │   └── ic_launcher.png
│   │       │   │   ├── mipmap-xxxhdpi
│   │       │   │   │   └── ic_launcher.png
│   │       │   │   ├── values
│   │       │   │   │   └── styles.xml
│   │       │   │   └── values-night
│   │       │   │       └── styles.xml
│   │       │   └── AndroidManifest.xml
│   │       └── profile
│   │           └── AndroidManifest.xml
│   ├── gradle
│   │   └── wrapper
│   │       ├── gradle-wrapper.jar
│   │       └── gradle-wrapper.properties
│   ├── gradle.properties
│   ├── gradlew
│   ├── gradlew.bat
│   ├── local.properties
│   └── settings.gradle.kts
├── ios
│   ├── Flutter
│   │   ├── ephemeral
│   │   │   ├── flutter_lldb_helper.py
│   │   │   └── flutter_lldbinit
│   │   ├── AppFrameworkInfo.plist
│   │   ├── Debug.xcconfig
│   │   ├── flutter_export_environment.sh
│   │   ├── Generated.xcconfig
│   │   └── Release.xcconfig
│   ├── Runner
│   │   ├── Assets.xcassets
│   │   │   ├── AppIcon.appiconset
│   │   │   │   ├── Contents.json
│   │   │   │   ├── Icon-App-1024x1024@1x.png
│   │   │   │   ├── Icon-App-20x20@1x.png
│   │   │   │   ├── Icon-App-20x20@2x.png
│   │   │   │   ├── Icon-App-20x20@3x.png
│   │   │   │   ├── Icon-App-29x29@1x.png
│   │   │   │   ├── Icon-App-29x29@2x.png
│   │   │   │   ├── Icon-App-29x29@3x.png
│   │   │   │   ├── Icon-App-40x40@1x.png
│   │   │   │   ├── Icon-App-40x40@2x.png
│   │   │   │   ├── Icon-App-40x40@3x.png
│   │   │   │   ├── Icon-App-60x60@2x.png
│   │   │   │   ├── Icon-App-60x60@3x.png
│   │   │   │   ├── Icon-App-76x76@1x.png
│   │   │   │   ├── Icon-App-76x76@2x.png
│   │   │   │   └── Icon-App-83.5x83.5@2x.png
│   │   │   └── LaunchImage.imageset
│   │   │       ├── Contents.json
│   │   │       ├── LaunchImage.png
│   │   │       ├── LaunchImage@2x.png
│   │   │       ├── LaunchImage@3x.png
│   │   │       └── README.md
│   │   ├── Base.lproj
│   │   │   ├── LaunchScreen.storyboard
│   │   │   └── Main.storyboard
│   │   ├── AppDelegate.swift
│   │   ├── GeneratedPluginRegistrant.h
│   │   ├── GeneratedPluginRegistrant.m
│   │   ├── Info.plist
│   │   └── Runner-Bridging-Header.h
│   ├── Runner.xcodeproj
│   │   ├── project.xcworkspace
│   │   │   ├── xcshareddata
│   │   │   │   ├── IDEWorkspaceChecks.plist
│   │   │   │   └── WorkspaceSettings.xcsettings
│   │   │   └── contents.xcworkspacedata
│   │   ├── xcshareddata
│   │   │   └── xcschemes
│   │   │       └── Runner.xcscheme
│   │   └── project.pbxproj
│   ├── Runner.xcworkspace
│   │   ├── xcshareddata
│   │   │   ├── IDEWorkspaceChecks.plist
│   │   │   └── WorkspaceSettings.xcsettings
│   │   └── contents.xcworkspacedata
│   ├── RunnerTests
│   │   └── RunnerTests.swift
│   └── Podfile
├── lib
│   ├── core
│   │   ├── bootstrap.dart
│   │   └── constants.dart
│   ├── drawables
│   │   ├── barcode_drawable.dart
│   │   ├── constrained_text_drawable.dart
│   │   ├── image_box_drawable.dart
│   │   └── table_drawable.dart
│   ├── flutter_painter_v2
│   │   ├── controllers
│   │   │   ├── actions
│   │   │   │   ├── action.dart
│   │   │   │   ├── actions.dart
│   │   │   │   ├── add_drawables_action.dart
│   │   │   │   ├── clear_drawables_action.dart
│   │   │   │   ├── grouped_action.dart
│   │   │   │   ├── insert_drawables_action.dart
│   │   │   │   ├── merge_drawables_action.dart
│   │   │   │   ├── remove_drawable_action.dart
│   │   │   │   └── replace_drawable_action.dart
│   │   │   ├── drawables
│   │   │   │   ├── background
│   │   │   │   │   ├── background_drawable.dart
│   │   │   │   │   ├── background_drawables.dart
│   │   │   │   │   ├── color_background_drawable.dart
│   │   │   │   │   └── image_background_drawable.dart
│   │   │   │   ├── path
│   │   │   │   │   ├── erase_drawable.dart
│   │   │   │   │   ├── free_style_drawable.dart
│   │   │   │   │   ├── path_drawable.dart
│   │   │   │   │   └── path_drawables.dart
│   │   │   │   ├── shape
│   │   │   │   │   ├── arrow_drawable.dart
│   │   │   │   │   ├── double_arrow_drawable.dart
│   │   │   │   │   ├── line_drawable.dart
│   │   │   │   │   ├── oval_drawable.dart
│   │   │   │   │   ├── rectangle_drawable.dart
│   │   │   │   │   ├── shape_drawable.dart
│   │   │   │   │   └── shape_drawables.dart
│   │   │   │   ├── drawable.dart
│   │   │   │   ├── drawables.dart
│   │   │   │   ├── grouped_drawable.dart
│   │   │   │   ├── image_drawable.dart
│   │   │   │   ├── object_drawable.dart
│   │   │   │   ├── sized1ddrawable.dart
│   │   │   │   ├── sized2ddrawable.dart
│   │   │   │   └── text_drawable.dart
│   │   │   ├── events
│   │   │   │   ├── add_text_painter_event.dart
│   │   │   │   ├── events.dart
│   │   │   │   ├── painter_event.dart
│   │   │   │   └── selected_object_drawable_removed_event.dart
│   │   │   ├── factories
│   │   │   │   ├── arrow_factory.dart
│   │   │   │   ├── double_arrow_factory.dart
│   │   │   │   ├── factories.dart
│   │   │   │   ├── line_factory.dart
│   │   │   │   ├── oval_factory.dart
│   │   │   │   ├── rectangle_factory.dart
│   │   │   │   └── shape_factory.dart
│   │   │   ├── helpers
│   │   │   │   ├── renderer_check
│   │   │   │   │   ├── renderer_check.dart
│   │   │   │   │   ├── renderer_check_native.dart
│   │   │   │   │   └── renderer_check_web.dart
│   │   │   │   ├── border_box_shadow.dart
│   │   │   │   └── helpers.dart
│   │   │   ├── notifications
│   │   │   │   ├── drawable_created_notification.dart
│   │   │   │   ├── drawable_deleted_notification.dart
│   │   │   │   ├── drawable_notification.dart
│   │   │   │   ├── notification.dart
│   │   │   │   ├── notifications.dart
│   │   │   │   ├── object_reselected_notification.dart
│   │   │   │   ├── selected_object_updated_notification.dart
│   │   │   │   └── settings_updated_notification.dart
│   │   │   ├── settings
│   │   │   │   ├── free_style_settings.dart
│   │   │   │   ├── haptic_feedback_settings.dart
│   │   │   │   ├── object_settings.dart
│   │   │   │   ├── painter_settings.dart
│   │   │   │   ├── scale_settings.dart
│   │   │   │   ├── settings.dart
│   │   │   │   ├── shape_settings.dart
│   │   │   │   └── text_settings.dart
│   │   │   ├── controllers.dart
│   │   │   └── painter_controller.dart
│   │   ├── extensions
│   │   │   ├── extensions.dart
│   │   │   ├── image_provider_ui_image_getter_extension.dart
│   │   │   ├── paint_copy_extension.dart
│   │   │   ├── painter_controller_helper_extension.dart
│   │   │   └── ui_image_png_uint8list_getter_extension.dart
│   │   ├── views
│   │   │   ├── painters
│   │   │   │   └── painter.dart
│   │   │   ├── widgets
│   │   │   │   ├── flutter_painter.dart
│   │   │   │   ├── free_style_widget.dart
│   │   │   │   ├── object_widget.dart
│   │   │   │   ├── painter_controller_widget.dart
│   │   │   │   ├── shape_widget.dart
│   │   │   │   ├── text_widget.dart
│   │   │   │   └── widgets.dart
│   │   │   └── views.dart
│   │   ├── flutter_painter.dart
│   │   ├── flutter_painter_extensions.dart
│   │   └── flutter_painter_pure.dart
│   ├── models
│   │   ├── drag_action.dart
│   │   └── tool.dart
│   ├── pages
│   │   └── painter_page.dart
│   ├── widgets
│   │   ├── canvas_area.dart
│   │   ├── color_dot.dart
│   │   ├── inspector_panel.dart
│   │   └── tool_panel.dart
│   ├── app.dart
│   └── main.dart
├── macos
│   ├── Flutter
│   │   ├── ephemeral
│   │   │   ├── Flutter-Generated.xcconfig
│   │   │   └── flutter_export_environment.sh
│   │   ├── Flutter-Debug.xcconfig
│   │   ├── Flutter-Release.xcconfig
│   │   └── GeneratedPluginRegistrant.swift
│   ├── Runner
│   │   ├── Assets.xcassets
│   │   │   └── AppIcon.appiconset
│   │   │       ├── app_icon_1024.png
│   │   │       ├── app_icon_128.png
│   │   │       ├── app_icon_16.png
│   │   │       ├── app_icon_256.png
│   │   │       ├── app_icon_32.png
│   │   │       ├── app_icon_512.png
│   │   │       ├── app_icon_64.png
│   │   │       └── Contents.json
│   │   ├── Base.lproj
│   │   │   └── MainMenu.xib
│   │   ├── Configs
│   │   │   ├── AppInfo.xcconfig
│   │   │   ├── Debug.xcconfig
│   │   │   ├── Release.xcconfig
│   │   │   └── Warnings.xcconfig
│   │   ├── AppDelegate.swift
│   │   ├── DebugProfile.entitlements
│   │   ├── Info.plist
│   │   ├── MainFlutterWindow.swift
│   │   └── Release.entitlements
│   ├── Runner.xcodeproj
│   │   ├── project.xcworkspace
│   │   │   └── xcshareddata
│   │   │       └── IDEWorkspaceChecks.plist
│   │   ├── xcshareddata
│   │   │   └── xcschemes
│   │   │       └── Runner.xcscheme
│   │   └── project.pbxproj
│   ├── Runner.xcworkspace
│   │   ├── xcshareddata
│   │   │   └── IDEWorkspaceChecks.plist
│   │   └── contents.xcworkspacedata
│   ├── RunnerTests
│   │   └── RunnerTests.swift
│   ├── Podfile
│   └── Podfile.lock
├── test
│   └── widget_test.dart
├── windows
│   ├── flutter
│   │   ├── ephemeral
│   │   │   ├── .plugin_symlinks
│   │   │   │   ├── file_selector_windows
│   │   │   │   │   ├── example
│   │   │   │   │   │   ├── lib
│   │   │   │   │   │   ├── windows
│   │   │   │   │   │   ├── pubspec.yaml
│   │   │   │   │   │   └── README.md
│   │   │   │   │   ├── lib
│   │   │   │   │   │   ├── src
│   │   │   │   │   │   └── file_selector_windows.dart
│   │   │   │   │   ├── pigeons
│   │   │   │   │   │   ├── copyright.txt
│   │   │   │   │   │   └── messages.dart
│   │   │   │   │   ├── test
│   │   │   │   │   │   ├── file_selector_windows_test.dart
│   │   │   │   │   │   ├── file_selector_windows_test.mocks.dart
│   │   │   │   │   │   └── test_api.g.dart
│   │   │   │   │   ├── windows
│   │   │   │   │   │   ├── include
│   │   │   │   │   │   ├── test
│   │   │   │   │   │   ├── CMakeLists.txt
│   │   │   │   │   │   ├── file_dialog_controller.cpp
│   │   │   │   │   │   ├── file_dialog_controller.h
│   │   │   │   │   │   ├── file_selector_plugin.cpp
│   │   │   │   │   │   ├── file_selector_plugin.h
│   │   │   │   │   │   ├── file_selector_windows.cpp
│   │   │   │   │   │   ├── messages.g.cpp
│   │   │   │   │   │   ├── messages.g.h
│   │   │   │   │   │   ├── string_utils.cpp
│   │   │   │   │   │   └── string_utils.h
│   │   │   │   │   ├── AUTHORS
│   │   │   │   │   ├── CHANGELOG.md
│   │   │   │   │   ├── LICENSE
│   │   │   │   │   ├── pubspec.yaml
│   │   │   │   │   └── README.md
│   │   │   │   ├── package_info_plus
│   │   │   │   │   ├── android
│   │   │   │   │   │   ├── src
│   │   │   │   │   │   ├── gradle.properties
│   │   │   │   │   │   └── settings.gradle
│   │   │   │   │   ├── example
│   │   │   │   │   │   ├── android
│   │   │   │   │   │   ├── integration_test
│   │   │   │   │   │   ├── ios
│   │   │   │   │   │   ├── lib
│   │   │   │   │   │   ├── linux
│   │   │   │   │   │   ├── macos
│   │   │   │   │   │   ├── web
│   │   │   │   │   │   ├── windows
│   │   │   │   │   │   ├── analysis_options.yaml
│   │   │   │   │   │   ├── pubspec.yaml
│   │   │   │   │   │   └── README.md
│   │   │   │   │   ├── ios
│   │   │   │   │   │   ├── package_info_plus
│   │   │   │   │   │   └── package_info_plus.podspec
│   │   │   │   │   ├── lib
│   │   │   │   │   │   ├── src
│   │   │   │   │   │   └── package_info_plus.dart
│   │   │   │   │   ├── macos
│   │   │   │   │   │   ├── package_info_plus
│   │   │   │   │   │   └── package_info_plus.podspec
│   │   │   │   │   ├── test
│   │   │   │   │   │   ├── package_info_plus_linux_test.dart
│   │   │   │   │   │   ├── package_info_plus_windows_test.dart
│   │   │   │   │   │   └── package_info_test.dart
│   │   │   │   │   ├── CHANGELOG.md
│   │   │   │   │   ├── LICENSE
│   │   │   │   │   ├── pubspec.yaml
│   │   │   │   │   └── README.md
│   │   │   │   ├── screen_retriever_windows
│   │   │   │   │   ├── windows
│   │   │   │   │   │   ├── include
│   │   │   │   │   │   ├── test
│   │   │   │   │   │   ├── CMakeLists.txt
│   │   │   │   │   │   ├── screen_retriever_windows_plugin.cpp
│   │   │   │   │   │   ├── screen_retriever_windows_plugin.h
│   │   │   │   │   │   └── screen_retriever_windows_plugin_c_api.cpp
│   │   │   │   │   ├── analysis_options.yaml
│   │   │   │   │   ├── CHANGELOG.md
│   │   │   │   │   ├── LICENSE
│   │   │   │   │   ├── pubspec.yaml
│   │   │   │   │   └── README.md
│   │   │   │   └── window_manager
│   │   │   │       ├── example
│   │   │   │       │   ├── images
│   │   │   │       │   ├── integration_test
│   │   │   │       │   ├── lib
│   │   │   │       │   ├── linux
│   │   │   │       │   ├── macos
│   │   │   │       │   ├── test
│   │   │   │       │   ├── windows
│   │   │   │       │   ├── analysis_options.yaml
│   │   │   │       │   ├── pubspec.yaml
│   │   │   │       │   └── README.md
│   │   │   │       ├── lib
│   │   │   │       │   ├── src
│   │   │   │       │   └── window_manager.dart
│   │   │   │       ├── linux
│   │   │   │       │   ├── include
│   │   │   │       │   ├── CMakeLists.txt
│   │   │   │       │   └── window_manager_plugin.cc
│   │   │   │       ├── macos
│   │   │   │       │   ├── window_manager
│   │   │   │       │   └── window_manager.podspec
│   │   │   │       ├── test
│   │   │   │       │   └── window_manager_test.dart
│   │   │   │       ├── windows
│   │   │   │       │   ├── include
│   │   │   │       │   ├── CMakeLists.txt
│   │   │   │       │   ├── window_manager.cpp
│   │   │   │       │   └── window_manager_plugin.cpp
│   │   │   │       ├── analysis_options.yaml
│   │   │   │       ├── CHANGELOG.md
│   │   │   │       ├── dart_dependency_validator.yaml
│   │   │   │       ├── LICENSE
│   │   │   │       ├── pubspec.yaml
│   │   │   │       ├── README-ZH.md
│   │   │   │       └── README.md
│   │   │   ├── cpp_client_wrapper
│   │   │   │   ├── include
│   │   │   │   │   └── flutter
│   │   │   │   │       ├── basic_message_channel.h
│   │   │   │   │       ├── binary_messenger.h
│   │   │   │   │       ├── byte_streams.h
│   │   │   │   │       ├── dart_project.h
│   │   │   │   │       ├── encodable_value.h
│   │   │   │   │       ├── engine_method_result.h
│   │   │   │   │       ├── event_channel.h
│   │   │   │   │       ├── event_sink.h
│   │   │   │   │       ├── event_stream_handler.h
│   │   │   │   │       ├── event_stream_handler_functions.h
│   │   │   │   │       ├── flutter_engine.h
│   │   │   │   │       ├── flutter_view.h
│   │   │   │   │       ├── flutter_view_controller.h
│   │   │   │   │       ├── message_codec.h
│   │   │   │   │       ├── method_call.h
│   │   │   │   │       ├── method_channel.h
│   │   │   │   │       ├── method_codec.h
│   │   │   │   │       ├── method_result.h
│   │   │   │   │       ├── method_result_functions.h
│   │   │   │   │       ├── plugin_registrar.h
│   │   │   │   │       ├── plugin_registrar_windows.h
│   │   │   │   │       ├── plugin_registry.h
│   │   │   │   │       ├── standard_codec_serializer.h
│   │   │   │   │       ├── standard_message_codec.h
│   │   │   │   │       ├── standard_method_codec.h
│   │   │   │   │       └── texture_registrar.h
│   │   │   │   ├── binary_messenger_impl.h
│   │   │   │   ├── byte_buffer_streams.h
│   │   │   │   ├── core_implementations.cc
│   │   │   │   ├── engine_method_result.cc
│   │   │   │   ├── flutter_engine.cc
│   │   │   │   ├── flutter_view_controller.cc
│   │   │   │   ├── plugin_registrar.cc
│   │   │   │   ├── readme
│   │   │   │   ├── standard_codec.cc
│   │   │   │   └── texture_registrar_impl.h
│   │   │   ├── flutter_export.h
│   │   │   ├── flutter_messenger.h
│   │   │   ├── flutter_plugin_registrar.h
│   │   │   ├── flutter_texture_registrar.h
│   │   │   ├── flutter_windows.dll
│   │   │   ├── flutter_windows.dll.exp
│   │   │   ├── flutter_windows.dll.lib
│   │   │   ├── flutter_windows.dll.pdb
│   │   │   ├── flutter_windows.h
│   │   │   ├── generated_config.cmake
│   │   │   └── icudtl.dat
│   │   ├── CMakeLists.txt
│   │   ├── generated_plugin_registrant.cc
│   │   ├── generated_plugin_registrant.h
│   │   └── generated_plugins.cmake
│   ├── runner
│   │   ├── resources
│   │   │   └── app_icon.ico
│   │   ├── CMakeLists.txt
│   │   ├── flutter_window.cpp
│   │   ├── flutter_window.h
│   │   ├── main.cpp
│   │   ├── resource.h
│   │   ├── runner.exe.manifest
│   │   ├── Runner.rc
│   │   ├── utils.cpp
│   │   ├── utils.h
│   │   ├── win32_window.cpp
│   │   └── win32_window.h
│   └── CMakeLists.txt
├── .flutter-plugins-dependencies
├── .metadata
├── analysis_options.yaml
├── Inno_Setup_Installer.iss
├── Inno_Setup_Installer.ps1
├── pubspec.lock
├── pubspec.yaml
└── README.md
```

## Dart 파일 요약

| 파일 | 라인수 | 클래스수 | 위젯/페이지명 수 | import 수 | main() | build() 메서드 수 |
|---|---:|---:|---:|---:|:---:|---:|
| lib/app.dart | 22 | 1 | 0 | 3 |  | 1 |
| lib/core/bootstrap.dart | 52 | 0 | 0 | 6 |  | 0 |
| lib/core/constants.dart | 4 | 0 | 0 | 0 |  | 0 |
| lib/drawables/barcode_drawable.dart | 197 | 1 | 0 | 5 |  | 0 |
| lib/drawables/constrained_text_drawable.dart | 94 | 1 | 0 | 3 |  | 0 |
| lib/drawables/image_box_drawable.dart | 126 | 1 | 0 | 4 |  | 0 |
| lib/drawables/table_drawable.dart | 116 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/action.dart | 115 | 2 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/actions.dart | 8 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/add_drawables_action.dart | 44 | 1 | 0 | 4 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/clear_drawables_action.dart | 60 | 1 | 0 | 4 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/grouped_action.dart | 127 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/insert_drawables_action.dart | 44 | 1 | 0 | 4 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/merge_drawables_action.dart | 51 | 1 | 0 | 5 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/remove_drawable_action.dart | 86 | 1 | 0 | 6 |  | 0 |
| lib/flutter_painter_v2/controllers/actions/replace_drawable_action.dart | 120 | 1 | 0 | 7 |  | 0 |
| lib/flutter_painter_v2/controllers/controllers.dart | 5 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/background/background_drawable.dart | 6 | 0 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/background/background_drawables.dart | 3 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/background/color_background_drawable.dart | 37 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/background/image_background_drawable.dart | 43 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/drawable.dart | 28 | 0 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/drawables.dart | 9 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/grouped_drawable.dart | 34 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/image_drawable.dart | 137 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/object_drawable.dart | 227 | 0 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/path/erase_drawable.dart | 50 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/path/free_style_drawable.dart | 65 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/path/path_drawable.dart | 58 | 0 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/path/path_drawables.dart | 3 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/shape/arrow_drawable.dart | 139 | 1 | 0 | 6 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/shape/double_arrow_drawable.dart | 121 | 1 | 0 | 6 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/shape/line_drawable.dart | 96 | 1 | 0 | 5 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/shape/oval_drawable.dart | 108 | 1 | 0 | 5 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/shape/rectangle_drawable.dart | 121 | 1 | 0 | 5 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/shape/shape_drawable.dart | 49 | 0 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/shape/shape_drawables.dart | 6 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/sized1ddrawable.dart | 62 | 0 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/sized2ddrawable.dart | 59 | 0 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/drawables/text_drawable.dart | 88 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/events/add_text_painter_event.dart | 7 | 1 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/events/events.dart | 2 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/events/painter_event.dart | 8 | 0 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/events/selected_object_drawable_removed_event.dart | 7 | 1 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/factories/arrow_factory.dart | 23 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/factories/double_arrow_factory.dart | 23 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/factories/factories.dart | 6 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/factories/line_factory.dart | 16 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/factories/oval_factory.dart | 16 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/factories/rectangle_factory.dart | 28 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/factories/shape_factory.dart | 13 | 0 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/helpers/border_box_shadow.dart | 38 | 1 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/helpers/helpers.dart | 1 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/helpers/renderer_check/renderer_check.dart | 2 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/helpers/renderer_check/renderer_check_native.dart | 2 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/helpers/renderer_check/renderer_check_web.dart | 5 | 0 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/drawable_created_notification.dart | 8 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/drawable_deleted_notification.dart | 8 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/drawable_notification.dart | 12 | 0 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/notification.dart | 9 | 0 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/notifications.dart | 6 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/object_reselected_notification.dart | 12 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/selected_object_updated_notification.dart | 16 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/notifications/settings_updated_notification.dart | 12 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/painter_controller.dart | 499 | 4 | 0 | 15 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/free_style_settings.dart | 44 | 1 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/haptic_feedback_settings.dart | 36 | 0 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/object_settings.dart | 158 | 2 | 0 | 4 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/painter_settings.dart | 50 | 1 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/scale_settings.dart | 40 | 1 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/settings.dart | 7 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/shape_settings.dart | 55 | 2 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/controllers/settings/text_settings.dart | 31 | 1 | 0 | 1 |  | 0 |
| lib/flutter_painter_v2/extensions/extensions.dart | 4 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/extensions/image_provider_ui_image_getter_extension.dart | 24 | 0 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/extensions/paint_copy_extension.dart | 46 | 0 | 0 | 2 |  | 0 |
| lib/flutter_painter_v2/extensions/painter_controller_helper_extension.dart | 321 | 0 | 0 | 5 |  | 0 |
| lib/flutter_painter_v2/extensions/ui_image_png_uint8list_getter_extension.dart | 17 | 0 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/flutter_painter.dart | 7 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/flutter_painter_extensions.dart | 7 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/flutter_painter_pure.dart | 7 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/views/painters/painter.dart | 72 | 1 | 0 | 3 |  | 0 |
| lib/flutter_painter_v2/views/views.dart | 1 | 0 | 0 | 0 |  | 0 |
| lib/flutter_painter_v2/views/widgets/flutter_painter.dart | 201 | 2 | 1 | 22 |  | 2 |
| lib/flutter_painter_v2/views/widgets/free_style_widget.dart | 163 | 3 | 1 | 0 |  | 1 |
| lib/flutter_painter_v2/views/widgets/object_widget.dart | 1106 | 3 | 1 | 0 |  | 2 |
| lib/flutter_painter_v2/views/widgets/painter_controller_widget.dart | 24 | 1 | 1 | 2 |  | 0 |
| lib/flutter_painter_v2/views/widgets/shape_widget.dart | 126 | 2 | 1 | 0 |  | 1 |
| lib/flutter_painter_v2/views/widgets/text_widget.dart | 341 | 4 | 2 | 0 |  | 2 |
| lib/flutter_painter_v2/views/widgets/widgets.dart | 1 | 0 | 0 | 0 |  | 0 |
| lib/main.dart | 14 | 0 | 0 | 3 |  | 0 |
| lib/models/drag_action.dart | 14 | 0 | 0 | 0 |  | 0 |
| lib/models/tool.dart | 14 | 0 | 0 | 0 |  | 0 |
| lib/pages/painter_page.dart | 1353 | 2 | 1 | 23 |  | 1 |
| lib/widgets/canvas_area.dart | 380 | 5 | 0 | 4 |  | 2 |
| lib/widgets/color_dot.dart | 63 | 3 | 1 | 1 |  | 2 |
| lib/widgets/inspector_panel.dart | 742 | 4 | 0 | 10 |  | 2 |
| lib/widgets/tool_panel.dart | 765 | 6 | 0 | 6 |  | 4 |
| test/widget_test.dart | 30 | 0 | 0 | 3 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/get_directory_page.dart | 82 | 2 | 1 | 2 |  | 2 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/get_multiple_directories_page.dart | 84 | 2 | 1 | 2 |  | 2 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/home_page.dart | 67 | 1 | 1 | 1 |  | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/main.dart | 45 | 1 | 0 | 8 | ✅ | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/open_image_page.dart | 92 | 2 | 1 | 4 |  | 2 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/open_multiple_images_page.dart | 104 | 2 | 1 | 4 |  | 2 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/open_text_page.dart | 89 | 2 | 1 | 2 |  | 2 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/example/lib/save_text_page.dart | 102 | 1 | 1 | 4 |  | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/lib/file_selector_windows.dart | 129 | 1 | 0 | 2 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/lib/src/messages.g.dart | 242 | 5 | 0 | 4 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/pigeons/messages.dart | 62 | 3 | 0 | 1 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/test/file_selector_windows_test.dart | 466 | 0 | 0 | 9 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/test/file_selector_windows_test.mocks.dart | 102 | 2 | 0 | 3 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/file_selector_windows/test/test_api.g.dart | 145 | 1 | 0 | 6 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/example/integration_test/driver.dart | 3 | 0 | 0 | 1 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/example/integration_test/package_info_plus_test.dart | 235 | 0 | 0 | 7 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/example/integration_test/package_info_plus_web_test.dart | 326 | 0 | 0 | 11 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/example/integration_test/package_info_plus_web_test.mocks.dart | 350 | 5 | 0 | 7 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/example/lib/main.dart | 101 | 3 | 1 | 3 | ✅ | 2 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/lib/package_info_plus.dart | 248 | 1 | 0 | 3 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/lib/src/file_attribute.dart | 83 | 1 | 0 | 4 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/lib/src/file_version_info.dart | 113 | 2 | 0 | 4 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/lib/src/package_info_plus_linux.dart | 107 | 1 | 0 | 5 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/lib/src/package_info_plus_macos.dart | 3 | 0 | 0 | 0 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/lib/src/package_info_plus_web.dart | 131 | 1 | 0 | 8 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/lib/src/package_info_plus_windows.dart | 51 | 1 | 0 | 5 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/test/package_info_plus_linux_test.dart | 13 | 0 | 0 | 3 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/test/package_info_plus_windows_test.dart | 72 | 0 | 0 | 6 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/package_info_plus/test/package_info_test.dart | 250 | 0 | 0 | 4 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/example/integration_test/window_manager_test.dart | 128 | 0 | 0 | 5 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/example/lib/main.dart | 71 | 2 | 0 | 5 | ✅ | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/example/lib/pages/home.dart | 1089 | 2 | 1 | 8 |  | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/example/lib/utils/config.dart | 80 | 3 | 0 | 2 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/example/test/widget_test.dart | 27 | 0 | 0 | 3 | ✅ | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/resize_edge.dart | 10 | 0 | 0 | 0 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/title_bar_style.dart | 4 | 0 | 0 | 0 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/utils/calc_window_position.dart | 93 | 0 | 0 | 2 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/widgets/drag_to_move_area.dart | 48 | 1 | 0 | 2 |  | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/widgets/drag_to_resize_area.dart | 158 | 1 | 0 | 4 |  | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/widgets/virtual_window_frame.dart | 146 | 2 | 0 | 7 |  | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/widgets/window_caption.dart | 139 | 2 | 0 | 5 |  | 1 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/widgets/window_caption_button.dart | 465 | 9 | 0 | 1 |  | 2 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/window_listener.dart | 57 | 0 | 0 | 0 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/window_manager.dart | 763 | 1 | 0 | 12 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/src/window_options.dart | 32 | 1 | 0 | 2 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/lib/window_manager.dart | 11 | 0 | 0 | 0 |  | 0 |
| windows/flutter/ephemeral/.plugin_symlinks/window_manager/test/window_manager_test.dart | 27 | 0 | 0 | 2 | ✅ | 0 |

## pubspec.yaml dependencies 섹션 (원본)

```
flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  barcode: ^2.2.9
  cupertino_icons: ^1.0.8
  file_selector: ^1.0.4
  package_info_plus: ^9.0.0
  screen_retriever: ^0.2.0
  window_manager: ^0.5.1
```
