#include "ConfigurationWindow.h"
#include <imgui.h>
#include <SDL3/SDL.h>
#include <glad/glad.h>
#include <IL/il.h>
#include <windows.h>
#include <psapi.h>
#include "Application.h"
#include "ModuleCamera.h"
#include "ModuleEditor.h"
#include "EditorCamera.h"
#include "Log.h"
#include "AudioSystem.h"

ConfigurationWindow::ConfigurationWindow()
    : EditorWindow("Configuration")
{
    fpsHistory.reserve(maxFPSHistory);
}

void ConfigurationWindow::Draw()
{
    if (!isOpen) return;

    ImGui::Begin(name.c_str(), &isOpen);

    isHovered = (ImGui::IsWindowHovered(ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows));

    if (ImGui::CollapsingHeader("FPS"))
    {
        DrawFPSGraph();
    }

    ImGui::Separator();

    if (ImGui::CollapsingHeader("Window"))
    {
        DrawWindowSettings();
    }

    ImGui::Separator();

    if (ImGui::CollapsingHeader("Camera"))
    {
        DrawCameraSettings();
    }

    ImGui::Separator();

    if (ImGui::CollapsingHeader("Audio")) {

        DrawAudioVolumeSettings();
    }

    ImGui::Separator();

    if (ImGui::CollapsingHeader("Renderer"))
    {
        DrawRendererSettings();
    }

    ImGui::Separator();

    if (ImGui::CollapsingHeader("Hardware"))
    {
        DrawHardwareInfo();
    }

    ImGui::End();
}

void ConfigurationWindow::DrawFPSGraph()
{
    fpsTimer += ImGui::GetIO().DeltaTime;

    if (fpsTimer >= 0.1f)
    {
        float fps = ImGui::GetIO().Framerate;
        fpsHistory.push_back(fps);

        if (fpsHistory.size() > maxFPSHistory)
        {
            fpsHistory.erase(fpsHistory.begin());
        }

        fpsTimer = 0.0f;
    }

    ImGui::Text("FPS: %.0f", ImGui::GetIO().Framerate);
    ImGui::Text("Frame Time: %.3f ms", 1000.0f / ImGui::GetIO().Framerate);

    if (!fpsHistory.empty())
    {
        ImGui::PlotLines("##FPS", fpsHistory.data(), (int)fpsHistory.size(), 0, nullptr, 0.0f, 200.0f, ImVec2(0, 80));
    }
}

void ConfigurationWindow::DrawHardwareInfo()
{
    ImGui::Text("CPU Cores: %d", SDL_GetNumLogicalCPUCores());
    ImGui::Text("System RAM: %d MB", SDL_GetSystemRAM());

#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS_EX pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc)))
    {
        SIZE_T memoryUsedMB = pmc.WorkingSetSize / (1024 * 1024);
        ImGui::Text("Memory Usage: %llu MB", memoryUsedMB);
    }
#endif

    ImGui::Text("GPU: %s", glGetString(GL_RENDERER));

    ImGui::Separator();
    ImGui::Text("Software Versions:");

    int sdlVersion = SDL_GetVersion();
    int major = SDL_VERSIONNUM_MAJOR(sdlVersion);
    int minor = SDL_VERSIONNUM_MINOR(sdlVersion);
    int patch = SDL_VERSIONNUM_MICRO(sdlVersion);
    ImGui::BulletText("SDL3: %d.%d.%d", major, minor, patch);

    ImGui::BulletText("OpenGL: %s", glGetString(GL_VERSION));
    ImGui::BulletText("ImGui: %s", IMGUI_VERSION);

    ILint devilVersion = ilGetInteger(IL_VERSION_NUM);
    int devilMajor = devilVersion / 100;
    int devilMinor = (devilVersion / 10) % 10;
    int devilPatch = devilVersion % 10;
    ImGui::BulletText("DevIL: %d.%d.%d", devilMajor, devilMinor, devilPatch);
}

void ConfigurationWindow::DrawWindowSettings()
{
    int width, height;
    Application::GetInstance().window->GetWindowSize(width, height);

    ImGui::Text("Window Size: %dx%d", width, height);

    int tempWidth = width;
    if (ImGui::InputInt("Width", &tempWidth, 10, 100))
    {
        if (tempWidth > 0)
        {
            SDL_SetWindowSize(Application::GetInstance().window->GetWindow(), tempWidth, height);
        }
    }

    int tempHeight = height;
    if (ImGui::InputInt("Height", &tempHeight, 10, 100))
    {
        if (tempHeight > 0)
        {
            SDL_SetWindowSize(Application::GetInstance().window->GetWindow(), width, tempHeight);
        }
    }

    ImGui::Separator();

    if (ImGui::Checkbox("Fullscreen", &fullscreen))
    {
        SDL_SetWindowFullscreen(Application::GetInstance().window->GetWindow(), fullscreen);
    }

    static bool borderlessFullscreen = false;
    if (ImGui::Checkbox("Borderless Window", &borderlessFullscreen))
    {
        SDL_SetWindowBordered(Application::GetInstance().window->GetWindow(), !borderlessFullscreen);
    }

    ImGui::Separator();

    static bool resizable = true;
    if (ImGui::Checkbox("Resizable", &resizable))
    {
        SDL_SetWindowResizable(Application::GetInstance().window->GetWindow(), resizable);
    }

    ImGui::Separator();

    ImGui::Text("Resolutions:");

    if (ImGui::Button("Set 1920x1080"))
    {
        SDL_SetWindowSize(Application::GetInstance().window->GetWindow(), 1920, 1080);
    }
    ImGui::SameLine();
    if (ImGui::Button("Set 1280x720"))
    {
        SDL_SetWindowSize(Application::GetInstance().window->GetWindow(), 1280, 720);
    }
}

void ConfigurationWindow::DrawCameraSettings()
{
    EditorCamera* camera = Application::GetInstance().editor->GetEditorCamera();
    if (!camera) return;

    float speed = camera->GetSpeed();
    if (ImGui::SliderFloat("Speed", &speed, 0.1f, 50.0f))
        camera->SetSpeed(speed);
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("Editor Camera WASD movement speed");

    float multiplier = camera->GetSpeedMultiplier();
    if (ImGui::SliderFloat("Shift Multiplier", &multiplier, 1.0f, 20.0f))
        camera->SetSpeedMultiplier(multiplier);
    if (ImGui::IsItemHovered())
        ImGui::SetTooltip("Speed multiplier when holding Shift");
}

void ConfigurationWindow::DrawAudioVolumeSettings() {
    
    
    ImGui::Text("Audio Volume Settings");
    ImGui::Spacing();
    ImGui::Separator();

    globalVolume = Application::GetInstance().audio.get()->audioSystem->GetGlobalVolume();
    musicVolume = Application::GetInstance().audio.get()->audioSystem->GetMusicVolume();
    sfxVolume = Application::GetInstance().audio.get()->audioSystem->GetSFXVolume();

    

    ImGui::Text("Global Volume");
    if (ImGui::SliderFloat("##GlobalVolume", &globalVolume, 0.0f, 100.0f, "%.2f"))
    {
        
        if (Application::GetInstance().audio)
            Application::GetInstance().audio->SetGlobalVolume(globalVolume);
    }

    ImGui::Text("Music Volume");
    if (ImGui::SliderFloat("##MusicVolume", &musicVolume, 0.0f, 100.0f, "%.2f"))
    {
        
        if (Application::GetInstance().audio)
            Application::GetInstance().audio->SetMusicVolume(musicVolume);
    }

    ImGui::Text("SFX Volume");
    if (ImGui::SliderFloat("##SFXVolume", &sfxVolume, 0.0f, 100.0f, "%.2f"))
    {
        if (Application::GetInstance().audio)
            Application::GetInstance().audio->SetSFXVolume(sfxVolume);
    }

    ImGui::Spacing();


    if (ImGui::Button("Reload Soundbanks"))
    {
        if (Application::GetInstance().audio)
            Application::GetInstance().audio.get()->audioSystem->ReloadSoundBanks();
    }

    
}

void ConfigurationWindow::DrawRendererSettings()
{
    ImGui::Text("OpenGL Renderer Settings");
    ImGui::Separator();

    Renderer* renderer = Application::GetInstance().renderer.get();
    if (renderer == nullptr)
    {
        ImGui::TextColored(ImVec4(1.0f, 0.0f, 0.0f, 1.0f), "Error: Renderer not available");
        return;
    }

    if (ImGui::Checkbox("Show Z-Buffer", &showZBuffer))
    {
        Application::GetInstance().renderer->SetShowZBuffer(showZBuffer);
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::SetTooltip("Visualize depth buffer as grayscale\nWhite = Near, Black = Far");
    }
	ImGui::Spacing();

    bool faceCulling = renderer->IsFaceCullingEnabled();
    if (ImGui::Checkbox("Face Culling", &faceCulling))
    {
        renderer->SetFaceCulling(faceCulling);
    }
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Enable/disable back-face culling");

    if (faceCulling)
    {
        ImGui::Indent();
        int cullMode = renderer->GetCullFaceMode();
        const char* cullModes[] = { "Back", "Front", "Front and Back" };
        if (ImGui::Combo("Cull Face Mode", &cullMode, cullModes, 3))
        {
            renderer->SetCullFaceMode(cullMode);
        }
        if (ImGui::IsItemHovered()) ImGui::SetTooltip("Which faces to cull:\n- Back: Normal (hides back faces)\n- Front: Rare (hides front faces)\n- Both faces");
        ImGui::Unindent();
    }

    ImGui::Spacing();

    bool msaa = renderer->IsMSAAEnabled();
    if (ImGui::Checkbox("Multisample Antialiasing", &msaa))
    {
        renderer->SetMSAA(msaa);
    }
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Enable/disable Multisample Antialiasing");

    ImGui::Spacing();

    bool wireframe = renderer->IsWireframeMode();
    if (ImGui::Checkbox("Wireframe Mode", &wireframe))
    {
        renderer->SetWireframeMode(wireframe);
    }
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Render meshes as wireframes");

    ImGui::Spacing();
    ImGui::Separator();

    ImGui::Text("Background Color");

    float currentR, currentG, currentB;
    renderer->GetClearColor(currentR, currentG, currentB);

    static float editColor[3] = { currentR, currentG, currentB };

    ImGui::ColorEdit3("##ClearColor", editColor, ImGuiColorEditFlags_NoAlpha);

    bool colorChanged = (editColor[0] != currentR || editColor[1] != currentG || editColor[2] != currentB);

    ImGui::SameLine();

    if (!colorChanged)
    {
        ImGui::BeginDisabled();
    }

    if (ImGui::Button("Apply"))
    {
        renderer->SetClearColor(editColor[0], editColor[1], editColor[2]);
        LOG_CONSOLE("Background color updated");
        LOG_DEBUG("Background color set to (%.2f, %.2f, %.2f)", editColor[0], editColor[1], editColor[2]);
    }

    if (!colorChanged)
    {
        ImGui::EndDisabled();
    }

    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Apply the new background color");

    ImGui::SameLine();

    if (ImGui::Button("Reset Color"))
    {
        editColor[0] = 0.2f;
        editColor[1] = 0.25f;
        editColor[2] = 0.3f;
        renderer->SetClearColor(editColor[0], editColor[1], editColor[2]);
        LOG_CONSOLE("Background color reset to default");
        LOG_DEBUG("Background color reset to default");
    }
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Reset background color to default");

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Text("Global Light (Directional)");
    
    glm::vec3 lDir = renderer->GetLightDir();
    float lightDirArr[3] = { lDir.x, lDir.y, lDir.z };
    if (ImGui::SliderFloat3("Light Direction", lightDirArr, -1.0f, 1.0f))
    {
        renderer->SetLightDir(glm::vec3(lightDirArr[0], lightDirArr[1], lightDirArr[2]));
    }
    if (ImGui::Button("Reset Light"))
    {
        renderer->SetLightDir(glm::vec3(1.0f, -1.0f, -1.0f));
    }

    ImGui::Spacing();
    ImGui::Separator();

    if (ImGui::Button("Reset All Settings"))
    {
        renderer->SetFaceCulling(true);
        renderer->SetWireframeMode(false);
        renderer->SetCullFaceMode(0);
        renderer->SetClearColor(0.2f, 0.25f, 0.3f);
        renderer->SetMSAA(true);

        editColor[0] = 0.2f;
        editColor[1] = 0.25f;
        editColor[2] = 0.3f;

        LOG_CONSOLE("All renderer settings reset to defaults");
        LOG_DEBUG("All renderer settings reset to defaults");
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Text("Debug Visualization");

    if (ImGui::Checkbox("Show AABB", &showAABB))
    {
        LOG_DEBUG("AABB visualization: %s", showAABB ? "ON" : "OFF");
    }
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Show axis-aligned bounding boxes for all meshes");

    if (ImGui::Checkbox("Show Octree", &showOctree))
    {
        LOG_DEBUG("Octree visualization: %s", showOctree ? "ON" : "OFF");
    }
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Show octree spatial partitioning structure");

    if (ImGui::Checkbox("Show Raycast", &showRaycast))
    {
        LOG_DEBUG("Raycast visualization: %s", showRaycast ? "ON" : "OFF");
    }
    if (ImGui::IsItemHovered()) ImGui::SetTooltip("Show ray used for mouse picking");

    ImGui::Spacing();
}