#include "ImportSettingsWindow.h"
#include "ModuleResources.h"
#include "MetaFile.h"
#include "LibraryManager.h"
#include "Application.h"
#include "ModuleLoader.h"
#include "TextureImporter.h"
#include "Log.h"
#include <imgui.h>
#include <filesystem>
#include "ComponentMaterial.h"
#include "GameObject.h"           
#include "ModuleScene.h"

ImportSettingsWindow::ImportSettingsWindow()
    : EditorWindow("Import Settings"),
    hasUnsavedChanges(false),
    showApplyButton(false)
{
}

ImportSettingsWindow::~ImportSettingsWindow()
{
}

void ImportSettingsWindow::OpenForAsset(const std::string& assetPath)
{
    if (!std::filesystem::exists(assetPath))
    {
        LOG_CONSOLE("[ImportSettings] Asset not found: %s", assetPath.c_str());
        return;
    }

    currentAssetPath = assetPath;

    std::string metaPath = assetPath + ".meta";
    if (std::filesystem::exists(metaPath))
    {
        currentMeta = MetaFile::Load(metaPath);
    }
    else
    {
        currentMeta = MetaFileManager::GetOrCreateMeta(assetPath);
    }

    workingSettings = currentMeta.importSettings;

    hasUnsavedChanges = false;
    showApplyButton = false;
    isOpen = true;

    LOG_CONSOLE("[ImportSettings] Opened settings for: %s", assetPath.c_str());
}

void ImportSettingsWindow::Draw()
{
    if (!isOpen || currentAssetPath.empty())
        return;

    ImGui::SetNextWindowSize(ImVec2(500, 600), ImGuiCond_FirstUseEver);

    if (ImGui::Begin("Import Settings", &isOpen))
    {
        isHovered = ImGui::IsWindowHovered();

        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Asset:");
        ImGui::SameLine();

        std::string filename = std::filesystem::path(currentAssetPath).filename().string();
        ImGui::TextWrapped("%s", filename.c_str());

        ImGui::TextColored(ImVec4(0.6f, 0.6f, 0.6f, 1.0f), "UID: %llu", currentMeta.uid);

        ImGui::Separator();

        if (currentMeta.type == AssetType::MODEL_FBX)
        {
            DrawModelSettings();
        }
        else if (currentMeta.type == AssetType::TEXTURE_PNG ||
            currentMeta.type == AssetType::TEXTURE_JPG ||
            currentMeta.type == AssetType::TEXTURE_DDS ||
            currentMeta.type == AssetType::TEXTURE_TGA)
        {
            DrawTextureSettings();
        }
        else
        {
            ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.5f, 1.0f),
                "No import settings available for this asset type.");
        }

        ImGui::Separator();

        ImGui::Spacing();

        if (hasUnsavedChanges)
        {
            ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.0f, 1.0f), "* Unsaved changes");
        }

        ImGui::Spacing();

        bool canApply = hasUnsavedChanges;

        if (!canApply)
        {
            ImGui::PushStyleVar(ImGuiStyleVar_Alpha, 0.5f);
        }

        if (ImGui::Button("Apply", ImVec2(100, 0)))
        {
            if (canApply)
            {
                ApplyChanges();
            }
        }

        if (!canApply)
        {
            ImGui::PopStyleVar();
        }

        if (ImGui::IsItemHovered() && canApply)
        {
            ImGui::BeginTooltip();
            ImGui::Text("Save settings and reimport asset");
            ImGui::EndTooltip();
        }

        ImGui::SameLine();

        if (ImGui::Button("Reset to Defaults", ImVec2(150, 0)))
        {
            ResetToDefaults();
        }

        ImGui::SameLine();

        if (ImGui::Button("Cancel", ImVec2(80, 0)))
        {
            CancelChanges();
        }
    }
    ImGui::End();
}

void ImportSettingsWindow::DrawModelSettings()
{
    ImGui::TextColored(ImVec4(0.5f, 0.8f, 1.0f, 1.0f), "Model Import Settings");
    ImGui::Spacing();

    bool changed = false;

    ImGui::Text("Import Scale");
    ImGui::SetNextItemWidth(200.0f);
    if (ImGui::DragFloat("##importScale", &workingSettings.importScale, 0.01f, 0.001f, 100.0f, "%.3f"))
    {
        changed = true;
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("Scale factor applied on import");
        ImGui::EndTooltip();
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Spacing();

    ImGui::Text("Axis Configuration");
    ImGui::Spacing();

    const char* upAxisOptions[] = { "Y-Up", "Z-Up" };
    if (ImGui::Combo("Up Axis", &workingSettings.upAxis, upAxisOptions, IM_ARRAYSIZE(upAxisOptions)))
    {
        changed = true;
    }

    const char* frontAxisOptions[] = { "Z-Forward", "Y-Forward", "X-Forward" };
    if (ImGui::Combo("Front Axis", &workingSettings.frontAxis, frontAxisOptions, IM_ARRAYSIZE(frontAxisOptions)))
    {
        changed = true;
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Spacing();

    ImGui::Text("Post-Processing");
    ImGui::Spacing();

    if (ImGui::Checkbox("Generate Normals", &workingSettings.generateNormals))
    {
        changed = true;
    }

    if (ImGui::Checkbox("Flip UVs", &workingSettings.flipUVs))
    {
        changed = true;
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("Flip texture coordinates vertically (for models)");
        ImGui::EndTooltip();
    }

    if (ImGui::Checkbox("Optimize Meshes", &workingSettings.optimizeMeshes))
    {
        changed = true;
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Spacing();

    ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "Note:");
    ImGui::TextWrapped("Changes will be saved to .meta file and applied on next import.");

    if (changed && !hasUnsavedChanges)
    {
        hasUnsavedChanges = true;
    }
}

void ImportSettingsWindow::DrawTextureSettings()
{
    ImGui::TextColored(ImVec4(0.5f, 0.8f, 1.0f, 1.0f), "Texture Import Settings");
    ImGui::Spacing();

    bool changed = false;

    // Filtering
    ImGui::Text("Filtering");
    ImGui::Spacing();

    const char* filterModes[] = { "Point (Nearest)", "Bilinear", "Trilinear" };
    if (ImGui::Combo("Filter Mode", &workingSettings.filterMode, filterModes, IM_ARRAYSIZE(filterModes)))
    {
        changed = true;
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("Point: Sharp, pixelated\nBilinear: Smooth\nTrilinear: Smooth with mipmaps");
        ImGui::EndTooltip();
    }

    ImGui::Spacing();

    if (ImGui::Checkbox("Generate Mipmaps", &workingSettings.generateMipmaps))
    {
        changed = true;
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("Generate mipmap levels for better quality at distance\nRequired for Trilinear filtering");
        ImGui::EndTooltip();
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Spacing();

    // Flip options
    ImGui::Text("Flip Options");
    ImGui::Spacing();

    if (ImGui::Checkbox("Flip Vertically (Y)", &workingSettings.flipUVs))
    {
        changed = true;
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("Flip texture image data vertically");
        ImGui::EndTooltip();
    }

    if (ImGui::Checkbox("Flip Horizontally (X)", &workingSettings.flipHorizontal))
    {
        changed = true;
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("Flip texture image data horizontally");
        ImGui::EndTooltip();
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Spacing();

    // Max Size
    ImGui::Text("Max Texture Size");
    ImGui::Spacing();

    const char* textureSizes[] = { "32", "64", "128", "256", "512", "1024", "2048", "4096", "8192" };
    if (ImGui::Combo("Max Size", &workingSettings.maxTextureSize, textureSizes, IM_ARRAYSIZE(textureSizes)))
    {
        changed = true;
    }
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("Maximum texture dimension\nTextures larger than this will be downscaled");
        ImGui::EndTooltip();
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Spacing();

    // Info box
    ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "Note:");
    ImGui::TextWrapped("Changes will be applied immediately after clicking Apply.");

    if (changed && !hasUnsavedChanges)
    {
        hasUnsavedChanges = true;
    }
}

void ImportSettingsWindow::ApplyChanges()
{
    if (!hasUnsavedChanges)
        return;

    LOG_CONSOLE("[ImportSettings] Applying changes to: %s", currentAssetPath.c_str());

    // Save settings to meta
    currentMeta.importSettings = workingSettings;

    std::string metaPath = currentAssetPath + ".meta";
    if (!currentMeta.Save(metaPath)) {
        LOG_CONSOLE("[ImportSettings] ERROR: Failed to save .meta file");
        return;
    }

    LOG_CONSOLE("[ImportSettings] Settings saved to .meta");

    ModuleResources* resources = Application::GetInstance().resources.get();
    if (!resources || currentMeta.uid == 0) {
        LOG_CONSOLE("[ImportSettings] ERROR: ModuleResources unavailable or invalid UID");
        return;
    }

    // TEXTURES
    if (currentMeta.type == AssetType::TEXTURE_PNG ||
        currentMeta.type == AssetType::TEXTURE_JPG ||
        currentMeta.type == AssetType::TEXTURE_DDS ||
        currentMeta.type == AssetType::TEXTURE_TGA)
    {
        Resource* resource = const_cast<Resource*>(resources->GetResource(currentMeta.uid));

        // Reimport with new settings
        if (Application::GetInstance().resources.get()->ImportFile(currentAssetPath.c_str(), true)) {
            LOG_CONSOLE("[ImportSettings] Texture reimported successfully!");

            // Reload texture in all materials that use it
            ReloadTextureInScene(currentMeta.uid);

            hasUnsavedChanges = false;
        }
        else {
            LOG_CONSOLE("[ImportSettings] ERROR: Failed to reimport texture");
        }
    }
    // FBX MODELS
    else if (currentMeta.type == AssetType::MODEL_FBX)
    {
        int unloadedCount = 0;
        for (int i = 0; i < 100; i++) {
            unsigned long long meshUID = currentMeta.uid + i;
            Resource* resource = const_cast<Resource*>(resources->GetResource(meshUID));

            if (!resource) break;
        }
        LOG_CONSOLE("[ImportSettings] Unloaded %d meshes", unloadedCount);

        // Reimport
        if (Application::GetInstance().resources.get()->ImportFile(currentAssetPath.c_str(), true)) {
            LOG_CONSOLE("[ImportSettings] FBX reimported successfully!");
            hasUnsavedChanges = false;
        }
        else {
            LOG_CONSOLE("[ImportSettings] ERROR: Failed to reimport FBX");
        }
    }
}
void ImportSettingsWindow::ResetToDefaults()
{
    workingSettings.importScale = 1.0f;
    workingSettings.generateNormals = true;
    workingSettings.flipUVs = true;
    workingSettings.optimizeMeshes = true;
    workingSettings.generateMipmaps = true;
    workingSettings.upAxis = 0;
    workingSettings.frontAxis = 0;
    workingSettings.filterMode = 2;
    workingSettings.flipHorizontal = false;
    workingSettings.maxTextureSize = 6;  // 2048

    hasUnsavedChanges = true;

    LOG_CONSOLE("[ImportSettings] Reset to defaults");
}

void ImportSettingsWindow::CancelChanges()
{
    if (hasUnsavedChanges)
    {
        workingSettings = currentMeta.importSettings;
        hasUnsavedChanges = false;
    }

    isOpen = false;
    currentAssetPath.clear();

    LOG_CONSOLE("[ImportSettings] Cancelled changes");
}

void ImportSettingsWindow::ReloadTextureInScene(UID textureUID)
{
    LOG_CONSOLE("[ImportSettings] Reloading texture in all scene materials...");

    GameObject* root = Application::GetInstance().scene->GetRoot();
    if (!root) {
        LOG_CONSOLE("[ImportSettings] ERROR: No scene root");
        return;
    }

    int reloadedCount = 0;
    ReloadTextureRecursive(root, textureUID, reloadedCount);

    LOG_CONSOLE("[ImportSettings] Reloaded texture in %d materials", reloadedCount);
}

void ImportSettingsWindow::ReloadTextureRecursive(GameObject* obj, UID textureUID, int& count)
{
    if (!obj) return;

    // Check if this object has a material component with this texture
    ComponentMaterial* material = static_cast<ComponentMaterial*>(
        obj->GetComponent(ComponentType::MATERIAL)
        );

    //FIXMAT
    //if (material && material->GetTextureUID() == textureUID) {
    //    LOG_DEBUG("[ImportSettings] Reloading texture for: %s", obj->GetName().c_str());
    //    material->ReloadTexture();
    //    count++;
    //}

    // Process children recursively
    for (GameObject* child : obj->GetChildren()) {
        ReloadTextureRecursive(child, textureUID, count);
    }
}