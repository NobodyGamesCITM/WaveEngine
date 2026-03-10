cmake_minimum_required(VERSION 3.10)

project(Engine)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_definitions(-DNOMINMAX)

find_package(SDL3 CONFIG REQUIRED)
find_package(glad CONFIG REQUIRED)
find_package(glm CONFIG REQUIRED)
find_package(assimp CONFIG REQUIRED)
find_package(DevIL REQUIRED)
find_package(imgui REQUIRED)
find_package(imguizmo CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(Tracy CONFIG REQUIRED)
find_package(Lua REQUIRED)
find_package(unofficial-omniverse-physx-sdk CONFIG REQUIRED)
find_package(recastnavigation CONFIG REQUIRED)

set(CORE_SRC 
    src/Main.cpp 
    src/Application.cpp
    src/Application.h
    src/Input.cpp
    src/Input.h 
    src/Module.h 
    src/Window.cpp 
    src/Window.h
    src/ModuleGame.cpp 
    src/ModuleGame.h
)

set(EVENTS_SRC 
    src/ModuleEvents.h 
    src/ModuleEvents.cpp
	src/Event.h
	src/EventListener.h
)

set(RENDERING_SRC 
    src/EditorCamera.h 
    src/EditorCamera.cpp
    src/Primitives.cpp 
    src/Primitives.h 
    src/RenderContext.h 
    src/RenderContext.cpp 
    src/Renderer.h 
    src/Renderer.cpp 
    src/Frustum.h 
    src/AABB.h 
    src/ComponentMesh.h
    src/ComponentMesh.cpp
    src/ComponentSkinnedMesh.h
    src/ComponentSkinnedMesh.cpp
    src/CameraLens.h
    src/CameraLens.cpp
    src/UI.h
    src/UI.cpp  
) 
 
set(SHADERS_SRC 
    src/Shader.h
    src/Shader.cpp
    src/ShaderSimpleColor.h
    src/ShaderSimpleColor.cpp
    src/ShaderSingleColor.h
    src/ShaderSingleColor.cpp
    src/ShaderDepthVisualization.h
    src/ShaderDepthVisualization.cpp
    src/ShaderNoTexture.h
    src/ShaderNoTexture.cpp
    src/ShaderWater.h
    src/ShaderWater.cpp
    src/ShaderLines.h
    src/ShaderLines.cpp
    src/ShaderNormal.h
    src/ShaderNormal.cpp
    src/ShaderMesh.h
    src/ShaderMesh.cpp
    src/ShaderPicking.h
    src/ShaderPicking.cpp
    src/ShaderUiOverlay.h
    src/ShaderUiOverlay.cpp
    src/ShaderStandard.h
    src/ShaderStandard.cpp
    src/ShaderPostPorcessing.h
    src/ShaderPostPorcessing.cpp 
)  

set(VFX_SRC
    src/ParticleSystem.h
    src/ParticleSystem.cpp
)

set(PHYSICS_SRC
    src/ModulePhysics.h
    src/ModulePhysics.cpp
    src/Rigidbody.cpp
    src/Rigidbody.h
    src/Collider.cpp
    src/Collider.h
    src/BoxCollider.cpp
    src/BoxCollider.h
    src/SphereCollider.h
    src/SphereCollider.cpp
    src/CapsuleCollider.h
    src/CapsuleCollider.cpp
    src/ConvexCollider.h
    src/ConvexCollider.cpp
    src/InfinitePlaneCollider.h
    src/InfinitePlaneCollider.cpp
    src/PlaneCollider.cpp
    src/PlaneCollider.h
    src/MeshCollider.h
    src/MeshCollider.cpp
    src/Joint.cpp
    src/Joint.h
    src/SphericalJoint.cpp
    src/SphericalJoint.h
    src/PrismaticJoint.cpp
    src/PrismaticJoint.h
    src/HingeJoint.cpp
    src/HingeJoint.h
    src/FixedJoint.cpp
    src/FixedJoint.h
    src/DistanceJoint.cpp
    src/DistanceJoint.h
    src/D6Joint.cpp
    src/D6Joint.h
    src/PhysicsEventsListener.h
    src/PhysicsCooker.h
    src/PhysicsCooker.cpp
)

set(AUDIO_SRC
    src/ModuleAudio.h
    src/ModuleAudio.cpp
    src/AudioSystem.h
    src/AudioSystem.cpp
    src/AudioUtility.h
)

set(UTILS_SRC 
    src/Globals.h 
    src/Log.cpp 
    src/Log.h 
    src/Time.cpp 
    src/Time.h 
    src/Grid.cpp
    src/Grid.h
    src/ModuleCamera.cpp 
    src/ModuleCamera.h 
    src/SelectionManager.h
    src/SelectionManager.cpp
    src/Octree.h
    src/Octree.cpp
    src/FileUtils.h
    src/FileUtils.cpp
    src/Backup.h
    src/Backup.cpp
)

set(GAMEOBJECTS_SRC 
    src/GameObject.cpp 
    src/GameObject.h 
    src/ModuleScene.cpp 
    src/ModuleScene.h 
)

set(COMPONENTS_SRC
    src/Component.h
    src/Component.cpp
    src/ComponentMaterial.cpp
    src/ComponentMaterial.h
    src/Transform.cpp
    src/Transform.h
    src/ComponentCamera.cpp
    src/ComponentCamera.h
    src/ComponentRotate.cpp
    src/ComponentRotate.h
    src/ComponentParticleSystem.h
    src/ComponentParticleSystem.cpp
    src/ComponentCanvas.h
    src/ComponentCanvas.cpp
    src/AudioComponent.h
    src/AudioSource.h
    src/AudioSource.cpp
    src/AudioListener.h
    src/AudioListener.cpp
    src/ReverbZone.h
    src/ReverbZone.cpp
    src/ComponentAnimation.h
    src/ComponentAnimation.cpp
    src/ComponentPostProcessing.h
    src/ComponentPostProcessing.cpp
) 

set(LOADERS_SRC 
    src/Texture.h 
    src/Texture.cpp  
    src/ModuleLoader.h
    src/ModuleLoader.cpp 
)

set(EDITOR_SRC 
    src/ModuleEditor.h
    src/ModuleEditor.cpp 
    src/SceneWindow.h
    src/SceneWindow.cpp 
    src/EditorWindow.h 
    src/ConfigurationWindow.h
    src/ConfigurationWindow.cpp 
    src/ConsoleWindow.h
    src/ConsoleWindow.cpp 
    src/HierarchyWindow.h
    src/HierarchyWindow.cpp 
    src/InspectorWindow.h
    src/InspectorWindow.cpp 
    src/GameWindow.h
    src/GameWindow.cpp
    src/AssetsWindow.h
    src/AssetsWindow.cpp 
    src/ImportSettingsWindow.h
    src/ImportSettingsWindow.cpp 
    src/ShaderEditorWindow.h
    src/ShaderEditorWindow.cpp
    src/ScriptEditorWindow.h
    src/ScriptEditorWindow.cpp
    src/MaterialEditorWindow.h
    src/MaterialEditorWindow.cpp
    src/TextEditor.h
    src/TextEditor.cpp
    src/Editorcommand.h
    src/Commandhistory.h
    src/Transformcommand.cpp
    src/Transformcommand.h
    src/Deletecommand.h
    src/Createcommand.h
    src/Createcommand.cpp
    src/Deletecommand.cpp
    src/Compositecommand.h
    src/Transformcommand.h
    src/Reparentcommand.h
    src/Componentcommand.h
    src/Componentstatecommand.h
)  

set(IMPORTERS_SRC 
    src/MeshImporter.cpp 
    src/MeshImporter.h 
    src/AnimationImporter.cpp 
    src/AnimationImporter.h 
    src/SceneImporter.cpp 
    src/SceneImporter.h 
    src/PrefabImporter.cpp 
    src/PrefabImporter.h 
    src/LibraryManager.cpp 
    src/LibraryManager.h 
    src/MetaFile.cpp 
    src/MetaFile.h 
    src/TextureImporter.cpp 
    src/TextureImporter.h 
    src/ModelImporter.cpp 
    src/ModelImporter.h 
    src/MaterialImporter.cpp 
    src/MaterialImporter.h 
    src/ModuleResources.cpp 
    src/ModuleResources.h 
    src/ResourceMesh.cpp 
    src/ResourceMesh.h 
    src/ResourceModel.cpp 
    src/ResourceModel.h 
    src/ResourceScene.cpp 
    src/ResourceScene.h 
    src/ResourceTexture.cpp 
    src/ResourceTexture.h 
    src/ResourceAnimation.cpp 
    src/ResourceAnimation.h 
    src/ResourceShader.cpp
    src/ResourceShader.h
    src/ResourceAnimation.cpp
    src/ResourceAnimation.h
    src/ResourceMaterial.cpp
    src/ResourceMaterial.h
    src/ResourcePrefab.h
    src/ResourcePrefab.cpp
    src/Material.h
    src/MaterialStandard.cpp
    src/MaterialStandard.h
) 

set(SCRIPTING_SRC 
    src/ScriptManager.h
    src/ScriptManager.cpp
    src/ResourceScript.h
    src/ResourceScript.cpp
    src/ComponentScript.h
    src/ComponentScript.cpp
    src/EditorPreferences.h
    src/EditorPreferences.cpp
    src/Prefab.h
    src/Prefab.cpp
    src/PrefabManager.h
    src/PrefabManager.cpp
)

set(NAVIGATION_SRC
    src/NavMeshManager.cpp
    src/NavMeshManager.h
    src/ComponentNavigation.cpp
    src/ComponentNavigation.h
)

set(UI_SRC
    src/UI.h
    src/UI.cpp
    src/UiManager.h
    src/UiManager.cpp
)
source_group("Source\\Core" FILES ${CORE_SRC})
source_group("Source\\Events" FILES ${EVENTS_SRC})
source_group("Source\\Rendering" FILES ${RENDERING_SRC})
source_group("Source\\Rendering\\VFX" FILES ${VFX_SRC})
source_group("Source\\Rendering\\Shaders" FILES ${SHADERS_SRC})
source_group("Source\\Audio" FILES ${AUDIO_SRC})
source_group("Source\\Utils" FILES ${UTILS_SRC})
source_group("Source\\Utils\\Editor" FILES ${EDITOR_SRC})
source_group("Source\\Game Objects" FILES ${GAMEOBJECTS_SRC})
source_group("Source\\Game Objects\\Components" FILES ${COMPONENTS_SRC})
source_group("Source\\Loaders" FILES ${LOADERS_SRC})
source_group("Source\\Loaders\\Importers" FILES ${IMPORTERS_SRC})
source_group("Scripting" FILES ${SCRIPTING_SRC})
source_group("Source\\Physics" FILES ${PHYSICS_SRC})
source_group("Source\\Navigation" FILES ${NAVIGATION_SRC})
source_group("Source\\UI" FILES ${UI_SRC})

set(SRCS ${CORE_SRC} ${RENDERING_SRC} ${VFX_SRC} ${SHADERS_SRC} ${AUDIO_SRC} ${UTILS_SRC} ${EDITOR_SRC} ${GAMEOBJECTS_SRC} ${COMPONENTS_SRC} ${LOADERS_SRC} ${IMPORTERS_SRC} ${SCRIPTING_SRC} ${PHYSICS_SRC} ${EVENTS_SRC} ${NAVIGATION_SRC} ${UI_SRC})

add_executable(Engine ${SRCS})

target_link_libraries(Engine PRIVATE SDL3::SDL3)
target_link_libraries(Engine PRIVATE glad::glad)
target_link_libraries(Engine PRIVATE glm::glm)
target_link_libraries(Engine PRIVATE assimp::assimp)
target_link_libraries(Engine PRIVATE DevIL::IL)
target_link_libraries(Engine PRIVATE DevIL::ILU)
target_link_libraries(Engine PRIVATE imgui::imgui)
target_link_libraries(Engine PRIVATE imguizmo::imguizmo)
target_link_libraries(Engine PRIVATE nlohmann_json::nlohmann_json)
target_link_libraries(Engine PRIVATE Tracy::TracyClient)
target_link_libraries(Engine PRIVATE unofficial::omniverse-physx-sdk::sdk)
target_link_libraries(Engine PRIVATE RecastNavigation::Recast)
target_link_libraries(Engine PRIVATE RecastNavigation::Detour)
target_link_libraries(Engine PRIVATE RecastNavigation::DetourCrowd)
target_link_libraries(Engine PRIVATE ${LUA_LIBRARIES})
target_include_directories(Engine PRIVATE ${LUA_INCLUDE_DIR})

# ============= WWISE AUTO-DOWNLOAD =============
set(WWISE_SDK_DIR "${CMAKE_CURRENT_SOURCE_DIR}/External/Wwise/SDK")

# Check if Wwise libs exist (check soundengine file as indicator)
if(NOT EXISTS "${WWISE_SDK_DIR}/x64_vc170/Debug/lib/AkSoundEngine.lib")
    message(STATUS "Wwise SDK not found. Downloading...")
    
    file(DOWNLOAD 
        "https://dl.dropboxusercontent.com/scl/fi/92fdn4rhlc3eim2a5p0ox/wwise_sdk.zip?rlkey=nob090idq4yw0h6v2ehpa7j6t&dl=1"
        "${CMAKE_BINARY_DIR}/wwise_sdk.zip"
        SHOW_PROGRESS
        STATUS DOWNLOAD_STATUS
    )
    
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    if(NOT STATUS_CODE EQUAL 0)
        message(FATAL_ERROR "Failed to download Wwise SDK. Please download manually from: [https://dl.dropboxusercontent.com/scl/fi/92fdn4rhlc3eim2a5p0ox/wwise_sdk.zip?rlkey=nob090idq4yw0h6v2ehpa7j6t&dl=1]")
    endif()
    
    message(STATUS "Extracting Wwise SDK...")

    file(ARCHIVE_EXTRACT 
        INPUT "${CMAKE_BINARY_DIR}/wwise_sdk.zip"
        DESTINATION "${WWISE_SDK_DIR}"
    )
    
    message(STATUS "✓ Wwise SDK installed!")
endif()

# ============= END WWISE AUTO-DOWNLOAD =============


set(WWISE_CONFIG_DIR $<$<CONFIG:Debug>:Debug>$<$<CONFIG:Release>:Release>$<$<CONFIG:Profile>:Profile>)
set(WWISE_LIB_DIR "${WWISE_SDK_DIR}/x64_vc170/${WWISE_CONFIG_DIR}/lib")

target_compile_definitions(Engine PRIVATE 
    AK_WIN 
    WIN32 
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:AK_OPTIMIZED>
)

target_include_directories(Engine PRIVATE BEFORE
    "${WWISE_SDK_DIR}/include"
    "${WWISE_SDK_DIR}"
    "${WWISE_SDK_DIR}/include/Common"
    "${WWISE_SDK_DIR}/include/Win32"
)
set(WWISE_IO_SOURCES
    "${WWISE_SDK_DIR}/include/Common/AkFileLocationBase.cpp"
    "${WWISE_SDK_DIR}/include/Common/AkFilePackage.cpp"
    "${WWISE_SDK_DIR}/include/Common/AkFilePackageLUT.cpp"
    "${WWISE_SDK_DIR}/include/Common/AkMultipleFileLocation.cpp"
    "${WWISE_SDK_DIR}/include/Win32/AkDefaultIOHookDeferred.cpp"
)

set_source_files_properties(${WWISE_IO_SOURCES} PROPERTIES 
    COMPILE_DEFINITIONS "UNICODE;_UNICODE"
)

target_sources(Engine PRIVATE ${WWISE_IO_SOURCES})

target_link_libraries(Engine PRIVATE 
    "${WWISE_LIB_DIR}/AkSoundEngine.lib"
    "${WWISE_LIB_DIR}/AkMemoryMgr.lib"
    "${WWISE_LIB_DIR}/AkStreamMgr.lib"
    "${WWISE_LIB_DIR}/AkSpatialAudio.lib"
    $<$<CONFIG:Debug>:${WWISE_LIB_DIR}/CommunicationCentral.lib>
    $<$<NOT:$<CONFIG:Release>>:${WWISE_LIB_DIR}/CommunicationCentral.lib>
    "${WWISE_LIB_DIR}/AkRoomVerbFX.lib"
    ws2_32.lib 
    mswsock.lib 
    dinput8.lib 
    dsound.lib 
    dxguid.lib
)

target_include_directories(Engine PRIVATE ${LUA_INCLUDE_DIR})


# ============= NoesisGUI =============

# AUTO-DOWNLOAD

set(NOESIS_SDK_DIR "${CMAKE_SOURCE_DIR}/External/NoesisGUI")

if(NOT EXISTS "${NOESIS_SDK_DIR}/Lib/windows_x86/Noesis.lib")
    message(STATUS "NoesisGUI SDK not found. Downloading...")
    
    file(DOWNLOAD 
        "https://drive.usercontent.google.com/download?id=1KyGAq3gMaqE6nTexLKW_bBL8ZE7Qydbd&export=download&authuser=0&confirm=t&uuid=7d0cd1ad-694b-4b8d-831d-277f0019f001&at=APcXIO1GH_qglCnlDpFe4uf3p5hE%3A1771545574705"
        "${CMAKE_BINARY_DIR}/NoesisGUI.zip"
        SHOW_PROGRESS
        STATUS DOWNLOAD_STATUS
    )
    
    list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
    if(NOT STATUS_CODE EQUAL 0)
        message(FATAL_ERROR "Failed to download NoesisGUI SDK. Please download manually from: [https://drive.usercontent.google.com/download?id=1KyGAq3gMaqE6nTexLKW_bBL8ZE7Qydbd&export=download&authuser=0&confirm=t&uuid=7d0cd1ad-694b-4b8d-831d-277f0019f001&at=APcXIO1GH_qglCnlDpFe4uf3p5hE%3A1771545574705]")
    endif()
    
    message(STATUS "Extracting NoesisGUI SDK...")

    file(ARCHIVE_EXTRACT 
        INPUT "${CMAKE_BINARY_DIR}/NoesisGUI.zip"
        DESTINATION "${NOESIS_SDK_DIR}"
    )
    
    message(STATUS "NoesisGUI SDK installed!")
endif()


# INTEGRATION

file(GLOB NOESIS_APP_PROVIDERS_SOURCES
    "${NOESIS_SDK_DIR}/Src/Packages/App/Providers/Src/*.cpp"
)
file(GLOB NOESIS_RENDER_SOURCES
    "${NOESIS_SDK_DIR}/Src/Packages/Render/GLRenderDevice/Src/*.cpp"
)
file(GLOB NOESIS_INTERACTIVITY_SOURCES
    "${NOESIS_SDK_DIR}/Src/Packages/App/Interactivity/Src/*.cpp"
)
file(GLOB NOESIS_MEDIAELEMENT_SOURCES
    "${NOESIS_SDK_DIR}/Src/Packages/App/MediaElement/Src/*.cpp"
)

target_sources(Engine PRIVATE
    ${NOESIS_APP_PROVIDERS_SOURCES}
    ${NOESIS_RENDER_SOURCES}
    ${NOESIS_INTERACTIVITY_SOURCES}
    ${NOESIS_MEDIAELEMENT_SOURCES}
)

file(GLOB NOESIS_PACKAGE_INCLUDE_DIRS
    LIST_DIRECTORIES true
    "${NOESIS_SDK_DIR}/Src/Packages/*/Include"
    "${NOESIS_SDK_DIR}/Src/Packages/*/*/Include"
    "${NOESIS_SDK_DIR}/Src/Packages/*/Src"
    "${NOESIS_SDK_DIR}/Src/Packages/*/*/Src"
)
target_include_directories(Engine PRIVATE
    "${NOESIS_SDK_DIR}/Include"
    ${NOESIS_PACKAGE_INCLUDE_DIRS}
)

target_compile_definitions(Engine PRIVATE
    NS_APP_PROVIDERS_API=
    NS_APP_FRAMEWORK_API=
    NS_APP_INTERACTIVITY_API=
    NS_RENDER_GLRENDERDEVICE_API=
    NS_APP_MEDIAELEMENT_API=
)

if(MSVC)
    target_compile_options(Engine PRIVATE /FS)
endif()
if(WIN32)
    set(NOESIS_LIB "${NOESIS_SDK_DIR}/Lib/windows_x86_64/Noesis.lib")
    set(NOESIS_DLL "${NOESIS_SDK_DIR}/Bin/windows_x86_64/Noesis.dll")

    target_link_libraries(Engine PRIVATE ${NOESIS_LIB})

    add_custom_command(TARGET Engine POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${NOESIS_DLL}"
        $<TARGET_FILE_DIR:Engine>
    )
endif()

# =========== End NoesisGUI ===========
# Game (standalone)
set(SRCS ${CORE_SRC} ${RENDERING_SRC} ${VFX_SRC} ${SHADERS_SRC} ${AUDIO_SRC} ${UTILS_SRC} ${GAMEOBJECTS_SRC} ${COMPONENTS_SRC} ${LOADERS_SRC} ${IMPORTERS_SRC} ${SCRIPTING_SRC} ${PHYSICS_SRC} ${EVENTS_SRC} ${NAVIGATION_SRC} ${UI_SRC})

add_executable(Game ${SRCS})

target_compile_definitions(Game PRIVATE WAVE_GAME)

target_link_libraries(Game PRIVATE SDL3::SDL3)
target_link_libraries(Game PRIVATE glad::glad)
target_link_libraries(Game PRIVATE glm::glm)
target_link_libraries(Game PRIVATE assimp::assimp)
target_link_libraries(Game PRIVATE DevIL::IL)
target_link_libraries(Game PRIVATE DevIL::ILU)
target_link_libraries(Game PRIVATE nlohmann_json::nlohmann_json)
target_link_libraries(Game PRIVATE Tracy::TracyClient)
target_link_libraries(Game PRIVATE unofficial::omniverse-physx-sdk::sdk)
target_link_libraries(Game PRIVATE ${LUA_LIBRARIES})
target_link_libraries(Game PRIVATE RecastNavigation::Recast)
target_link_libraries(Game PRIVATE RecastNavigation::Detour)
target_link_libraries(Game PRIVATE RecastNavigation::DetourCrowd)
target_link_libraries(Game PRIVATE imgui::imgui)
target_link_libraries(Game PRIVATE imguizmo::imguizmo)


target_include_directories(Game PRIVATE ${LUA_INCLUDE_DIR})

target_sources(Game PRIVATE ${WWISE_IO_SOURCES})

target_link_libraries(Game PRIVATE 
    "${WWISE_LIB_DIR}/AkSoundEngine.lib"
    "${WWISE_LIB_DIR}/AkMemoryMgr.lib"
    "${WWISE_LIB_DIR}/AkStreamMgr.lib"
    "${WWISE_LIB_DIR}/AkSpatialAudio.lib"
    $<$<CONFIG:Debug>:${WWISE_LIB_DIR}/CommunicationCentral.lib>
    $<$<NOT:$<CONFIG:Release>>:${WWISE_LIB_DIR}/CommunicationCentral.lib>
    "${WWISE_LIB_DIR}/AkRoomVerbFX.lib"
    ws2_32.lib 
    mswsock.lib 
    dinput8.lib 
    dsound.lib 
    dxguid.lib
)

target_compile_definitions(Game PRIVATE 
    AK_WIN 
    WIN32 
    $<$<CONFIG:Debug>:_DEBUG>
    $<$<CONFIG:Release>:AK_OPTIMIZED>
)

target_include_directories(Game PRIVATE BEFORE
    "${WWISE_SDK_DIR}/include"
    "${WWISE_SDK_DIR}"
    "${WWISE_SDK_DIR}/include/Common"
    "${WWISE_SDK_DIR}/include/Win32"
)

target_sources(Game PRIVATE
    ${NOESIS_APP_PROVIDERS_SOURCES}
    ${NOESIS_RENDER_SOURCES}
    ${NOESIS_INTERACTIVITY_SOURCES}
    ${NOESIS_MEDIAELEMENT_SOURCES}
) 
target_include_directories(Game PRIVATE
    "${NOESIS_SDK_DIR}/Include"
    ${NOESIS_PACKAGE_INCLUDE_DIRS}
)

target_compile_definitions(Game PRIVATE
    NS_APP_PROVIDERS_API=
    NS_APP_FRAMEWORK_API=
    NS_APP_INTERACTIVITY_API=
    NS_RENDER_GLRENDERDEVICE_API=
    NS_APP_MEDIAELEMENT_API=
) 

if(MSVC)
    target_compile_options(Game PRIVATE /FS)
endif()
if(WIN32)
    set(NOESIS_LIB "${NOESIS_SDK_DIR}/Lib/windows_x86_64/Noesis.lib")
    set(NOESIS_DLL "${NOESIS_SDK_DIR}/Bin/windows_x86_64/Noesis.dll")

    target_link_libraries(Game PRIVATE ${NOESIS_LIB})

    add_custom_command(TARGET Game POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${NOESIS_DLL}"
        $<TARGET_FILE_DIR:Game>
    )
endif()

add_custom_command(TARGET Engine POST_BUILD
    COMMAND ${CMAKE_COMMAND} --build "${CMAKE_BINARY_DIR}" --target Game --config $<CONFIG>
    COMMENT "[WaveEngine] Building Game..."
    VERBATIM
)