#include "AssetsWindow.h"
#include <imgui.h>
#include "Application.h"
#include "LibraryManager.h"
#include "MetaFile.h"
#include "ModuleResources.h"
#include "ResourceTexture.h"
#include "ResourceMesh.h"
#include "Log.h"
#include <glad/glad.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>
#include "ImportSettingsWindow.h"
#include "TextureImporter.h" 
#include "ModuleLoader.h"       
#include "ModuleEvents.h"       
#include "GameObject.h"        
#include "Input.h"           
#include "ScriptEditorWindow.h"
#include "MaterialEditorWindow.h"
#include "EditorPreferences.h"
#include "MaterialImporter.h"
#include "ResourcePrefab.h"
#include "FileSystem.h"
#include "PrefabManager.h"
#include "Globals.h"

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

AssetsWindow::AssetsWindow()
    : EditorWindow("Assets"), selectedAsset(nullptr), iconSize(64.0f),
    showInMemoryOnly(false), show3DPreviews(true), showDeleteConfirmation(false)
{
    Application::GetInstance().events.get()->Subscribe(Event::Type::FileDropped, this);

    if (!LibraryManager::IsInitialized()) {
        LibraryManager::Initialize();
    }

    assetsRootPath = FileSystem::GetAssetsRoot();
    currentPath = assetsRootPath;

    importSettingsWindow = new ImportSettingsWindow();
}

AssetsWindow::~AssetsWindow()
{
    Application::GetInstance().events.get()->UnsubscribeAll(this);

    for (auto& asset : currentAssets)
    {
        UnloadPreviewForAsset(asset);
    }
    delete importSettingsWindow;
}

std::string AssetsWindow::TruncateFileName(const std::string& name, float maxWidth) const
{
    ImVec2 textSize = ImGui::CalcTextSize(name.c_str());

    if (textSize.x <= maxWidth)
        return name;

    std::string truncated = name;
    std::string suffix = "...";
    ImVec2 suffixSize = ImGui::CalcTextSize(suffix.c_str());

    while (truncated.length() > 3)
    {
        truncated = truncated.substr(0, truncated.length() - 1);
        ImVec2 currentSize = ImGui::CalcTextSize((truncated + suffix).c_str());

        if (currentSize.x <= maxWidth)
            return truncated + suffix;
    }

    return suffix;
}

void AssetsWindow::DrawIconShape(const AssetEntry& asset, const ImVec2& pos, const ImVec2& size)
{
    ImDrawList* drawList = ImGui::GetWindowDrawList();

    if (show3DPreviews && asset.previewTextureID != 0)
    {
        ImVec2 topLeft = pos;
        ImVec2 bottomRight = ImVec2(pos.x + size.x, pos.y + size.y);

        ImTextureID texID = (ImTextureID)(uintptr_t)asset.previewTextureID;
        drawList->AddImage(texID, topLeft, bottomRight, ImVec2(0, 1), ImVec2(1, 0));

        ImU32 borderColor = asset.inMemory ?
            ImGui::ColorConvertFloat4ToU32(ImVec4(0.3f, 0.8f, 0.3f, 1.0f)) :
            ImGui::ColorConvertFloat4ToU32(ImVec4(0.5f, 0.5f, 0.5f, 1.0f));

        drawList->AddRect(topLeft, bottomRight, borderColor, 3.0f, 0, 2.0f);
        return;
    }

    ImVec4 buttonColor;

    if (asset.isDirectory) {
        buttonColor = asset.inMemory ?
            ImVec4(0.3f, 0.8f, 0.3f, 1.0f) :
            ImVec4(0.8f, 0.7f, 0.3f, 1.0f);
    }
    else {
        buttonColor = asset.inMemory ?
            ImVec4(0.3f, 0.8f, 0.3f, 1.0f) :
            ImVec4(0.5f, 0.5f, 0.5f, 1.0f);
    }

    ImU32 color = ImGui::ColorConvertFloat4ToU32(buttonColor);
    ImU32 outlineColor = ImGui::ColorConvertFloat4ToU32(ImVec4(0.2f, 0.2f, 0.2f, 1.0f));

    ImVec2 center = ImVec2(pos.x + size.x * 0.5f, pos.y + size.y * 0.5f);
    float padding = size.x * 0.15f;

    if (asset.isDirectory)
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding + h * 0.2f);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        ImVec2 tabStart(topLeft.x, topLeft.y);
        ImVec2 tabEnd(topLeft.x + w * 0.4f, topLeft.y);
        ImVec2 tabTop(topLeft.x + w * 0.35f, pos.y + padding);

        drawList->AddQuadFilled(tabStart, tabEnd, tabTop, tabStart, color);
        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);
    }
    else if (asset.extension == ".fbx" || asset.extension == ".obj")
    {
        float cubeSize = (size.x - padding * 2) * 0.6f;
        ImVec2 p1(center.x - cubeSize * 0.5f, center.y);
        ImVec2 p2(center.x + cubeSize * 0.5f, center.y);
        ImVec2 p3(center.x, center.y - cubeSize * 0.7f);
        ImVec2 p4(center.x, center.y + cubeSize * 0.7f);

        drawList->AddTriangleFilled(p1, p2, p3, color);
        drawList->AddTriangleFilled(p1, p2, p4, ImGui::ColorConvertFloat4ToU32(ImVec4(buttonColor.x * 0.7f, buttonColor.y * 0.7f, buttonColor.z * 0.7f, 1.0f)));
        drawList->AddTriangle(p1, p2, p3, outlineColor, 2.0f);
        drawList->AddTriangle(p1, p2, p4, outlineColor, 2.0f);
    }
    else if (asset.extension == ".png" || asset.extension == ".jpg" || asset.extension == ".jpeg" || asset.extension == ".dds")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        ImVec2 m1(topLeft.x + w * 0.2f, topLeft.y + h * 0.7f);
        ImVec2 m2(topLeft.x + w * 0.4f, topLeft.y + h * 0.4f);
        ImVec2 m3(topLeft.x + w * 0.6f, topLeft.y + h * 0.7f);
        drawList->AddTriangleFilled(m1, m2, m3, ImGui::ColorConvertFloat4ToU32(ImVec4(0.3f, 0.3f, 0.3f, 0.8f)));

        drawList->AddCircleFilled(ImVec2(topLeft.x + w * 0.75f, topLeft.y + h * 0.25f), w * 0.1f, ImGui::ColorConvertFloat4ToU32(ImVec4(1.0f, 1.0f, 0.3f, 0.8f)));
    }
    else if (asset.extension == ".mesh")
    {
        float meshSize = (size.x - padding * 2) * 0.5f;
        ImVec2 p1(center.x, center.y - meshSize * 0.6f);
        ImVec2 p2(center.x - meshSize * 0.5f, center.y + meshSize * 0.4f);
        ImVec2 p3(center.x + meshSize * 0.5f, center.y + meshSize * 0.4f);

        drawList->AddTriangleFilled(p1, p2, p3, color);
        drawList->AddTriangle(p1, p2, p3, outlineColor, 2.0f);
    }
    else if (asset.extension == ".wav" || asset.extension == ".ogg" || asset.extension == ".mp3")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 start(pos.x + padding, center.y);

        int bars = 5;
        float barWidth = w / (bars * 2);
        for (int i = 0; i < bars; i++)
        {
            float barHeight = h * 0.3f * (1.0f + sin(i * 0.8f) * 0.7f);
            ImVec2 p1(start.x + i * barWidth * 2, center.y - barHeight * 0.5f);
            ImVec2 p2(start.x + i * barWidth * 2 + barWidth, center.y + barHeight * 0.5f);
            drawList->AddRectFilled(p1, p2, color, 2.0f);
        }
    }
    else if (asset.extension == ".lua")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        // Fondo del documento
        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        // Esquina doblada
        ImVec2 cornerSize(w * 0.2f, h * 0.2f);

        drawList->AddTriangleFilled(
            ImVec2(bottomRight.x - cornerSize.x, topLeft.y),
            ImVec2(bottomRight.x, topLeft.y),
            ImVec2(bottomRight.x, topLeft.y + cornerSize.y),
            ImGui::ColorConvertFloat4ToU32(ImVec4(buttonColor.x * 0.6f, buttonColor.y * 0.6f, buttonColor.z * 0.6f, 1.0f))
        );

        // Texto "Lua"
        ImVec2 textPos(center.x - w * 0.15f, center.y - h * 0.1f);
        drawList->AddText(textPos, ImGui::ColorConvertFloat4ToU32(ImVec4(0.2f, 0.2f, 0.8f, 1.0f)), "Lua");
    }
    else if (asset.extension == ".prefab")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        // Fondo del prefab (azul distintivo)
        ImU32 prefabColor = ImGui::ColorConvertFloat4ToU32(ImVec4(0.3f, 0.5f, 0.8f, 1.0f));
        drawList->AddRectFilled(topLeft, bottomRight, prefabColor, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        // Dibujar cubo pequeño (ícono de GameObject)
        float cubeSize = w * 0.3f;
        ImVec2 cubeCenter(center.x, center.y);

        ImU32 cubeColor = ImGui::ColorConvertFloat4ToU32(ImVec4(0.9f, 0.9f, 0.9f, 1.0f));

        // Frente del cubo
        ImVec2 c1(cubeCenter.x - cubeSize * 0.3f, cubeCenter.y);
        ImVec2 c2(cubeCenter.x + cubeSize * 0.3f, cubeCenter.y);
        ImVec2 c3(cubeCenter.x, cubeCenter.y - cubeSize * 0.5f);
        ImVec2 c4(cubeCenter.x, cubeCenter.y + cubeSize * 0.5f);

        drawList->AddTriangleFilled(c1, c2, c3, cubeColor);
        drawList->AddTriangleFilled(c1, c2, c4, ImGui::ColorConvertFloat4ToU32(ImVec4(0.6f, 0.6f, 0.6f, 1.0f)));
    }
    else
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        for (int i = 0; i < 3; i++)
        {
            float y = topLeft.y + h * 0.3f + i * h * 0.15f;
            drawList->AddLine(ImVec2(topLeft.x + w * 0.2f, y), ImVec2(bottomRight.x - w * 0.2f, y), outlineColor, 2.0f);
        }
    }
}

void AssetsWindow::Draw()
{
    if (!isOpen) return;

    static bool firstDraw = true;
    static bool previousShow3DPreviews = true;

    isHovered = ImGui::IsWindowHovered(ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows);

    if (firstDraw) {

        std::string libRoot = FileSystem::GetLibraryRoot();

        RefreshAssets();
        firstDraw = false;
        previousShow3DPreviews = show3DPreviews;
    }

    if (showDeleteConfirmation) {
        ImGui::OpenPopup("Delete Asset?");
        showDeleteConfirmation = false;
    }

    if (ImGui::BeginPopupModal("Delete Asset?", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
        ImGui::Text("Are you sure you want to delete:");
        ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.0f, 1.0f), "%s", assetToDelete.name.c_str());
        ImGui::Separator();

        if (assetToDelete.isDirectory) {
            ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "This will delete the entire folder and all its contents!");
        }
        else {
            ImGui::Text("This will also delete the corresponding Library file(s).");
        }

        ImGui::Separator();

        if (ImGui::Button("Delete", ImVec2(120, 0))) {
            if (DeleteAsset(assetToDelete)) {
                LOG_CONSOLE("Deleted: %s", assetToDelete.name.c_str());
                RefreshAssets();
            }
            ImGui::CloseCurrentPopup();
        }

        ImGui::SameLine();

        if (ImGui::Button("Cancel", ImVec2(120, 0))) {
            ImGui::CloseCurrentPopup();
        }

        ImGui::EndPopup();
    }

    if (ImGui::Begin(name.c_str(), &isOpen))
    {
        ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(4, 4));

        ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(4, 4));

        if (ImGui::Button("Refresh"))
        {
            RefreshAssets();
        }

        ImGui::SameLine();

        if (ImGui::Button("New Folder"))
        {
            ImGui::OpenPopup("CreateFolder");
        }

        ImGui::SameLine();

        if (ImGui::Button("New Script"))
        {
            ImGui::OpenPopup("CreateScript");
        }

        ImGui::SameLine();
        ImGui::Checkbox("In Memory Only", &showInMemoryOnly);

        ImGui::SameLine();
        ImGui::Checkbox("3D Previews", &show3DPreviews);
        if (ImGui::IsItemHovered())
        {
            ImGui::BeginTooltip();
            ImGui::Text("Show 3D preview for FBX models");
            ImGui::EndTooltip();
        }

        ImGui::SameLine();
        ImGui::SetNextItemWidth(100.0f);
        ImGui::SliderFloat("Icon Size", &iconSize, 32.0f, 128.0f, "%.0f");

        ImGui::PopStyleVar();
        ImGui::Separator();


        if (ImGui::BeginPopup("CreateFolder"))
        {
            static char folderName[256] = "NewFolder";

            ImGui::Text("Create New Folder");
            ImGui::Separator();

            ImGui::InputText("Name", folderName, sizeof(folderName));

            if (ImGui::Button("Create", ImVec2(120, 0)))
            {
                fs::path newFolderPath = fs::path(currentPath) / folderName;

                if (!fs::exists(newFolderPath))
                {
                    fs::create_directory(newFolderPath);
                    LOG_CONSOLE("[AssetsWindow] Created folder: %s", newFolderPath.string().c_str());
                    RefreshAssets();
                }
                else
                {
                    LOG_CONSOLE("[AssetsWindow] ERROR: Folder already exists");
                }

                ImGui::CloseCurrentPopup();
                strcpy(folderName, "NewFolder");
            }

            ImGui::SameLine();

            if (ImGui::Button("Cancel", ImVec2(120, 0)))
            {
                ImGui::CloseCurrentPopup();
                strcpy(folderName, "NewFolder");
            }

            ImGui::EndPopup();
        }

        if (ImGui::BeginPopup("CreateScript"))
        {
            static char scriptName[256] = "NewScript";

            ImGui::Text("Create New Lua Script");
            ImGui::Separator();

            ImGui::InputText("Name", scriptName, sizeof(scriptName));
            ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "Extension .lua will be added automatically");

            if (ImGui::Button("Create", ImVec2(120, 0)))
            {
                CreateNewScript(scriptName);
                ImGui::CloseCurrentPopup();
                strcpy(scriptName, "NewScript");
            }

            ImGui::SameLine();

            if (ImGui::Button("Cancel", ImVec2(120, 0)))
            {
                ImGui::CloseCurrentPopup();
                strcpy(scriptName, "NewScript");
            }

            ImGui::EndPopup();
        }

        if (ImGui::IsItemHovered())
        {
            ImGui::BeginTooltip();
            ImGui::Text("Show 3D preview for FBX models");
            ImGui::EndTooltip();
        }

        if (previousShow3DPreviews != show3DPreviews)
        {
            for (auto& asset : currentAssets)
            {
                if (asset.extension == ".fbx" || asset.extension == ".mesh")
                {
                    if (show3DPreviews)
                    {
                        asset.previewLoaded = false;
                        asset.previewTextureID = 0;
                    }
                    else
                    {
                        UnloadPreviewForAsset(asset);
                    }
                }

                if (asset.isFBX)
                {
                    for (auto& subMesh : asset.subResources)
                    {
                        if (show3DPreviews)
                        {
                            subMesh.previewLoaded = false;
                            subMesh.previewTextureID = 0;
                        }
                        else
                        {
                            UnloadPreviewForAsset(subMesh);
                        }
                    }
                }
            }

            previousShow3DPreviews = show3DPreviews;
        }

        ImGui::PopStyleVar();
        ImGui::Separator();

        ImGui::Text("Path: ");
        ImGui::SameLine();

        fs::path activeRoot;
        std::string rootName;

        activeRoot = assetsRootPath;
        rootName = "Assets";

        if (relativePathDirty)
        {
            cachedRelativePath = fs::relative(currentPath, activeRoot);
            relativePathDirty = false;
        }
        const fs::path& relativePath = cachedRelativePath;

        if (relativePath == ".")
        {
            ImGui::TextColored(ImVec4(0.5f, 0.8f, 1.0f, 1.0f), rootName.c_str());
        }
        else
        {
            if (ImGui::SmallButton((rootName + "##BreadcrumbRoot").c_str()))
            {
                currentPath = activeRoot.string();
                relativePathDirty = true;
                RefreshAssets();
            }

            std::string pathStr = relativePath.string();
            size_t pos = 0;
            std::string token;
            fs::path accumulatedPath = activeRoot;

            while ((pos = pathStr.find("\\")) != std::string::npos || (pos = pathStr.find("/")) != std::string::npos)
            {
                token = pathStr.substr(0, pos);
                ImGui::SameLine();
                ImGui::Text("/");
                ImGui::SameLine();

                accumulatedPath /= token;

                ImGui::PushID(accumulatedPath.string().c_str());
                if (ImGui::SmallButton(token.c_str()))
                {
                    currentPath = accumulatedPath.string();
                    relativePathDirty = true;
                    RefreshAssets();
                }
                ImGui::PopID();

                pathStr.erase(0, pos + 1);
            }

            if (!pathStr.empty())
            {
                ImGui::SameLine();
                ImGui::Text("/");
                ImGui::SameLine();
                ImGui::TextColored(ImVec4(0.5f, 0.8f, 1.0f, 1.0f), pathStr.c_str());
            }
        }

        ImGui::Separator();

        ImGui::BeginChild("FolderTree", ImVec2(200, 0), true);
        DrawFolderTree(assetsRootPath, "Assets");
        ImGui::EndChild();

        ImGui::SameLine();

        ImGui::BeginChild("AssetsList", ImVec2(0, 0), true);
        DrawAssetsList();
        ImGui::EndChild();

        HandleInternalDragDrop();

        ShowMaterialNamingModal();
        ShowPrefabNamingModal();
    }

    if (importSettingsWindow)
    {
        importSettingsWindow->Draw();
    }
   
    ImGui::End();
}

void AssetsWindow::DrawFolderTree(const fs::path& path, const std::string& label)
{
    if (!fs::exists(path) || !fs::is_directory(path))
        return;

    ImGuiTreeNodeFlags flags = ImGuiTreeNodeFlags_OpenOnArrow | ImGuiTreeNodeFlags_OpenOnDoubleClick;

    if (path == currentPath)
        flags |= ImGuiTreeNodeFlags_Selected;

    bool hasSubfolders = false;
    try {
        for (const auto& entry : fs::directory_iterator(path)) {
            if (entry.is_directory()) {
                hasSubfolders = true;
                break;
            }
        }
    }
    catch (...) {}

    if (!hasSubfolders)
    {
        flags |= ImGuiTreeNodeFlags_Leaf | ImGuiTreeNodeFlags_NoTreePushOnOpen;
    }

    ImGui::PushID(path.string().c_str());

    bool nodeOpen = ImGui::TreeNodeEx(label.c_str(), flags);

    if (ImGui::IsItemClicked())
    {
        currentPath = path.string();
        relativePathDirty = true;
        RefreshAssets();
    }

    if (nodeOpen)
    {
        if (hasSubfolders)
        {
            try {
                for (const auto& entry : fs::directory_iterator(path))
                {
                    if (entry.is_directory())
                    {
                        std::string folderName = entry.path().filename().string();
                        DrawFolderTree(entry.path(), folderName);
                    }
                }
            }
            catch (...) {}

            ImGui::TreePop();
        }
    }

    ImGui::PopID();
}

void AssetsWindow::DrawAssetsList()
{
    ImVec2 startPos = ImGui::GetCursorScreenPos();

    if (currentPath != assetsRootPath)
    {
        if (ImGui::Button("<- Back"))
        {
            currentPath = fs::path(currentPath).parent_path().string();
            RefreshAssets();
        }
        ImGui::Separator();
    }

    float windowWidth = ImGui::GetContentRegionAvail().x;
    int columns = (int)(windowWidth / (iconSize + 10.0f));
    if (columns < 1) columns = 1;

    int currentColumn = 0;
    std::string pathPendingToLoad = "";

    for (auto& asset : currentAssets)
    {
        if (showInMemoryOnly && !asset.inMemory)
            continue;

        if (!asset.isDirectory && !asset.previewLoaded && show3DPreviews)
        {
            LoadPreviewForAsset(asset);
        }

        if (asset.isFBX) {
            DrawExpandableAssetItem(asset, pathPendingToLoad);
        }
        else {
            DrawAssetItem(asset, pathPendingToLoad);
        }

        currentColumn++;
        if (currentColumn < columns)
        {
            ImGui::SameLine();
        }
        else
        {
            currentColumn = 0;
        }
    }

    if (!pathPendingToLoad.empty())
    {
        currentPath = pathPendingToLoad;
        RefreshAssets();
    }

    if (ImGui::BeginPopupContextWindow("AssetsContextMenu", ImGuiPopupFlags_MouseButtonRight | ImGuiPopupFlags_NoOpenOverItems))
    {
        if (ImGui::BeginMenu("Create"))
        {
            if (ImGui::MenuItem("Material"))
            {
                materialNamingOpened = true;
            }
            ImGui::EndMenu();
        }
        ImGui::EndPopup();
    }
}

void AssetsWindow::DrawExpandableAssetItem(AssetEntry& asset, std::string& pathPendingToLoad)
{
    ImGui::PushID(asset.path.c_str());
    ImGui::BeginGroup();

    // Arrow button to expand/collapse
    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
    const char* arrowIcon = asset.isExpanded ? "v " : "> ";

    if (ImGui::SmallButton(arrowIcon))
    {
        asset.isExpanded = !asset.isExpanded;

        if (asset.isExpanded && asset.subResources.empty()) {
            LoadFBXSubresources(asset);
        }
    }
    ImGui::PopStyleColor();

    ImGui::SameLine();

    // FBX icon
    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.3f, 0.3f, 0.3f, 0.3f));
    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.4f, 0.4f, 0.4f, 0.4f));

    bool clicked = ImGui::Button("##icon", ImVec2(iconSize, iconSize));

    ImGui::PopStyleColor(3);

    ImVec2 buttonPos = ImGui::GetItemRectMin();
    DrawIconShape(asset, buttonPos, ImVec2(iconSize, iconSize));

    bool isButtonHovered = ImGui::IsItemHovered();

    // Drag & Drop source for FBX
    if (ImGui::BeginDragDropSource(ImGuiDragDropFlags_None))
    {
        static DragDropPayload payload;
        payload.assetPath = asset.path;
        payload.assetUID = asset.uid;
        payload.assetType = DragDropAssetType::FBX_MODEL;

        ImGui::SetDragDropPayload("ASSET_ITEM", &payload, sizeof(DragDropPayload));
        ImGui::Text("FBX: %s", asset.name.c_str());
        ImGui::EndDragDropSource();
    }

    if (clicked)
    {
        selectedAsset = &asset;
    }

    const std::string& displayName = isButtonHovered ? asset.name : asset.cachedDisplayName;

    ImGui::PushTextWrapPos(ImGui::GetCursorPos().x + iconSize);
    ImGui::TextWrapped("%s", displayName.c_str());
    ImGui::PopTextWrapPos();

    if (asset.inMemory)
    {
        ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Loaded: %d", asset.references);
    }

    ImGui::EndGroup();

    // Context menu
    std::string popupID = "AssetContextMenu##" + asset.path;
    if (ImGui::BeginPopupContextItem(popupID.c_str()))
    {
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "%s", asset.name.c_str());
        ImGui::Separator();

        // Import Settings
        if (ImGui::MenuItem("Import Settings..."))
        {
            if (importSettingsWindow)
            {
                importSettingsWindow->OpenForAsset(asset.path);
            }
        }
        ImGui::Separator();

        if (ImGui::MenuItem("Delete"))
        {
            assetToDelete = asset;
            showDeleteConfirmation = true;
        }

        if (asset.uid != 0)
        {
            ImGui::Separator();
            ImGui::Text("UID: %llu", asset.uid);

            if (asset.inMemory)
            {
                ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Loaded in memory");
            }
        }

        ImGui::EndPopup();
    }

    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("%s", asset.name.c_str());
        if (asset.uid != 0) {
            ImGui::Text("UID: %llu", asset.uid);
        }
        ImGui::Text("Contains %zu subresources", asset.subResources.size());
        ImGui::EndTooltip();
    }

    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("%s", asset.name.c_str());
        if (asset.uid != 0) {
            ImGui::Text("UID: %llu", asset.uid);
        }
        ImGui::Text("Contains %zu subresources", asset.subResources.size());
        ImGui::EndTooltip();
    }

    // Draw submeshes horizontally with wrapping
    if (asset.isExpanded && !asset.subResources.empty())
    {
        float smallIconSize = iconSize * 0.7f;
        float itemWidth = smallIconSize + 15.0f;

        ImGui::Dummy(ImVec2(0, 0));

        // Calculate indentation for submeshes
        float indentSize = 30.0f;
        float startX = ImGui::GetCursorPosX() + indentSize;

        // Visual separator with indentation
        ImGui::SetCursorPosX(startX);
        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.5f, 0.5f, 0.5f, 1.0f));
        ImGui::Text(">");
        ImGui::PopStyleColor();

        // Obtain the available width considering the indentation
        float windowContentWidth = ImGui::GetContentRegionAvail().x;
        float currentX = startX;

        // Draw each submesh
        for (size_t i = 0; i < asset.subResources.size(); ++i)
        {
            auto& subMesh = asset.subResources[i];

            // Load preview if it has not yet been loaded
            // Solo cargar si show3DPreviews est activado
            if (!subMesh.previewLoaded && show3DPreviews)
            {
                LoadPreviewForAsset(subMesh);
            }

            // Check if we need a new line
            if (i > 0)
            {
                float remainingWidth = startX + windowContentWidth - currentX;

                if (remainingWidth < itemWidth)
                {
                    // New line with indentation
                    ImGui::NewLine();
                    ImGui::SetCursorPosX(startX);
                    currentX = startX;
                }
                else
                {
                    ImGui::SameLine();
                }
            }
            else
            {
                // First submesh - continue on the same line as the separator
                ImGui::SameLine();
            }

            // Update current position
            currentX = ImGui::GetCursorPosX();

            ImGui::PushID(subMesh.path.c_str());
            ImGui::BeginGroup();

            // Mesh icon (smaller)
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.3f, 0.3f, 0.3f, 0.3f));
            ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.4f, 0.4f, 0.4f, 0.4f));

            bool meshClicked = ImGui::Button("##meshicon", ImVec2(smallIconSize, smallIconSize));

            ImGui::PopStyleColor(3);

            ImVec2 meshButtonPos = ImGui::GetItemRectMin();
            DrawIconShape(subMesh, meshButtonPos, ImVec2(smallIconSize, smallIconSize));

            bool isMeshHovered = ImGui::IsItemHovered();

            // Drag & Drop source for individual mesh
            if (ImGui::BeginDragDropSource(ImGuiDragDropFlags_None))
            {
                static DragDropPayload payload;
                payload.assetPath = subMesh.path;
                payload.assetUID = subMesh.uid;
                payload.assetType = DragDropAssetType::MESH;

                ImGui::SetDragDropPayload("ASSET_ITEM", &payload, sizeof(DragDropPayload));
                ImGui::Text("Mesh: %s", subMesh.name.c_str());
                ImGui::EndDragDropSource();
            }

            if (meshClicked)
            {
                selectedAsset = &subMesh;
            }

            const std::string& meshDisplayName = isMeshHovered ? subMesh.name : subMesh.cachedDisplayName;

            ImGui::PushTextWrapPos(ImGui::GetCursorPos().x + smallIconSize);
            ImGui::TextWrapped("%s", meshDisplayName.c_str());
            ImGui::PopTextWrapPos();

            if (subMesh.inMemory)
            {
                ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "R:%d", subMesh.references);
            }

            ImGui::EndGroup();

            // Update currentX after the group (includes the width of the element)
            currentX += itemWidth;

            // Context menu for submesh
            std::string meshPopupID = "MeshContextMenu##" + subMesh.path;
            if (ImGui::BeginPopupContextItem(meshPopupID.c_str()))
            {
                ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "%s", subMesh.name.c_str());
                ImGui::Separator();

                if (subMesh.uid != 0)
                {
                    ImGui::Text("UID: %llu", subMesh.uid);

                    if (subMesh.inMemory)
                    {
                        ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Loaded in memory");
                    }
                }

                ImGui::EndPopup();
            }

            if (ImGui::IsItemHovered())
            {
                ImGui::BeginTooltip();
                ImGui::Text("Mesh: %s", subMesh.name.c_str());
                if (subMesh.uid != 0) {
                    ImGui::Text("UID: %llu", subMesh.uid);
                }
                if (subMesh.inMemory) {
                    ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Refs: %d", subMesh.references);
                }
                ImGui::EndTooltip();
            }

            ImGui::PopID();
        }
    }

    ImGui::PopID();
}

void AssetsWindow::DrawAssetItem(const AssetEntry& asset, std::string& pathPendingToLoad)
{
    ImGui::PushID(asset.path.c_str());
    ImGui::BeginGroup();

    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.3f, 0.3f, 0.3f, 0.3f));
    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.4f, 0.4f, 0.4f, 0.4f));

    bool clicked = ImGui::Button("##icon", ImVec2(iconSize, iconSize));

    ImGui::PopStyleColor(3);

    ImVec2 buttonPos = ImGui::GetItemRectMin();
    DrawIconShape(asset, buttonPos, ImVec2(iconSize, iconSize));

    bool isButtonHovered = ImGui::IsItemHovered();

    // Drag & Drop source 
    if (!asset.isDirectory && ImGui::BeginDragDropSource(ImGuiDragDropFlags_None))
    {
        static DragDropPayload payload;
        payload.assetPath = asset.path;
        payload.assetUID = asset.uid;

        if (asset.extension == ".png" || asset.extension == ".jpg" ||
            asset.extension == ".jpeg" || asset.extension == ".dds" || asset.extension == ".tga")
        {
            payload.assetType = DragDropAssetType::TEXTURE;
            ImGui::Text("Texture: %s", asset.name.c_str());
        }
        else if (asset.extension == ".mesh")
        {
            payload.assetType = DragDropAssetType::MESH;
            ImGui::Text("Mesh: %s", asset.name.c_str());
        }
        else if (asset.extension == ".lua")
        {
            payload.assetType = DragDropAssetType::SCRIPT;
            ImGui::Text("Script: %s", asset.name.c_str());
        }
        else if (asset.extension == ".prefab")  
        {
            payload.assetType = DragDropAssetType::PREFAB;
            ImGui::Text("Prefab: %s", asset.name.c_str());
        }
        else if (asset.extension == ".mat")  
        {
            payload.assetType = DragDropAssetType::MATERIAL;
            ImGui::Text("Material: %s", asset.name.c_str());
        }
        else if (asset.extension == ".scene")  
        {
            payload.assetType = DragDropAssetType::SCENE;
            ImGui::Text("Scene: %s", asset.name.c_str());
        }
        if (!asset.isDirectory && asset.extension == ".prefab")
        {
            if (ImGui::MenuItem("Update All Instances"))
            {
                Application::GetInstance().loader->UpdatePrefabInstances(asset.uid);
                LOG_CONSOLE("[Assets] Updated all instances of prefab: %s", asset.name.c_str());
            }
            ImGui::Separator();
        }
        else
        {
            payload.assetType = DragDropAssetType::UNKNOWN;
            ImGui::Text("Drag: %s", asset.name.c_str());
        }

        ImGui::SetDragDropPayload("ASSET_ITEM", &payload, sizeof(DragDropPayload));
        ImGui::EndDragDropSource();
    }

    if (clicked)
    {
        if (asset.isDirectory)
        {
            pathPendingToLoad = asset.path;
        }
        else
        {
            selectedAsset = const_cast<AssetEntry*>(&asset);
        }
    }

    // Doble click
    if (isButtonHovered && ImGui::IsMouseDoubleClicked(0))
    {
        if (asset.isDirectory)
        {
            pathPendingToLoad = asset.path;
        }
        else if (asset.extension == ".lua")
        {
            if (Application::GetInstance().editor.get()->GetScriptEditor())
            {
                Application::GetInstance().editor.get()->GetScriptEditor()->SetOpen(true);
                Application::GetInstance().editor.get()->GetScriptEditor()->OpenScript(asset.path);
            }
        }
        else if (asset.extension == ".mat")
        {
            if (Application::GetInstance().editor.get()->GetMaterialEditor())
            {
                Application::GetInstance().editor.get()->GetMaterialEditor()->SetOpen(true);
                Application::GetInstance().editor.get()->GetMaterialEditor()->SetMaterialToEdit(asset.uid);
            }
        }
        else if (asset.extension == ".scene")  
        {
            Application::GetInstance().loader->LoadScene(asset.path);
        }
    }

    const std::string& displayName = isButtonHovered ? asset.name : asset.cachedDisplayName;

    ImGui::PushTextWrapPos(ImGui::GetCursorPos().x + iconSize);
    ImGui::TextWrapped("%s", displayName.c_str());
    ImGui::PopTextWrapPos();

    if (asset.inMemory)
    {
        if (asset.isDirectory) {
            ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Loaded: %d", asset.references);
        }
        else {
            ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Refs: %d", asset.references);
        }
    }

    ImGui::EndGroup();

    // Context menu
    std::string popupID = "AssetContextMenu##" + asset.path;
    if (ImGui::BeginPopupContextItem(popupID.c_str()))
    {
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "%s", asset.name.c_str());
        ImGui::Separator();

        // Menú específico para SCRIPTS (.lua)
        if (!asset.isDirectory && asset.extension == ".lua")
        {
            ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Open With:");

            if (ImGui::MenuItem("Internal Editor"))
            {
                if (Application::GetInstance().editor.get()->GetMaterialEditor())
                {
                    Application::GetInstance().editor.get()->GetMaterialEditor()->SetMaterialToEdit(asset.uid);
                }
            }

            if (ImGui::MenuItem("Visual Studio 2022"))
            {
                EditorPreferences::SetPreferredEditor(ExternalEditor::VISUAL_STUDIO_2022);
                if (!EditorPreferences::OpenFileWithPreferredEditor(asset.path))
                {
                    LOG_CONSOLE("[AssetsWindow] Failed to open with VS2022. Is it installed?");
                }
            }

            if (ImGui::MenuItem("VS Code"))
            {
                EditorPreferences::SetPreferredEditor(ExternalEditor::VSCODE);
                if (!EditorPreferences::OpenFileWithPreferredEditor(asset.path))
                {
                    LOG_CONSOLE("[AssetsWindow] Failed to open with VS Code. Is it installed?");
                }
            }

            if (ImGui::MenuItem("Custom Editor..."))
            {
                ImGui::OpenPopup("SelectCustomEditor");
            }

            ImGui::Separator();

            ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "Default Editor:");

            ExternalEditor currentEditor = EditorPreferences::GetPreferredEditor();
            const char* editorNames[] = { "Internal", "VS 2022", "VS Code", "Custom" };
            int currentIdx = static_cast<int>(currentEditor);

            if (ImGui::Combo("##defaulteditor", &currentIdx, editorNames, 4))
            {
                EditorPreferences::SetPreferredEditor(static_cast<ExternalEditor>(currentIdx));
            }

            ImGui::Separator();
        }

        // Import Settings para FBX y texturas
        if (!asset.isDirectory &&
            (asset.extension == ".fbx" ||
                asset.extension == ".png" || asset.extension == ".jpg" ||
                asset.extension == ".jpeg" || asset.extension == ".dds" ||
                asset.extension == ".tga"))
        {
            if (ImGui::MenuItem("Import Settings..."))
            {
                if (importSettingsWindow)
                {
                    importSettingsWindow->OpenForAsset(asset.path);
                }
            }
            ImGui::Separator();
        }

        // Delete option (para todos los tipos)
        if (ImGui::MenuItem("Delete"))
        {
            assetToDelete = asset;
            showDeleteConfirmation = true;
        }

        // Info section
        if (!asset.isDirectory && asset.uid != 0)
        {
            ImGui::Separator();
            ImGui::Text("UID: %llu", asset.uid);

            if (asset.inMemory)
            {
                ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Loaded in memory");
            }
        }

        if (asset.isDirectory && asset.inMemory)
        {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Contains loaded assets");
            ImGui::Text("Total refs: %d", asset.references);
        }

        ImGui::EndPopup();
    }

    // Popup para seleccionar custom editor
    if (ImGui::BeginPopup("SelectCustomEditor"))
    {
        static char editorPath[512] = "";

        ImGui::Text("Select Custom Editor");
        ImGui::Separator();

        ImGui::InputText("Path", editorPath, sizeof(editorPath));
        ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "Example: C:\\MyEditor\\editor.exe");

        if (ImGui::Button("Browse..."))
        {
            LOG_CONSOLE("[AssetsWindow] File browser not implemented yet");
        }

        ImGui::SameLine();

        if (ImGui::Button("OK", ImVec2(120, 0)))
        {
            EditorPreferences::SetCustomEditorPath(editorPath);
            EditorPreferences::SetPreferredEditor(ExternalEditor::CUSTOM);
            ImGui::CloseCurrentPopup();
        }

        ImGui::SameLine();

        if (ImGui::Button("Cancel", ImVec2(120, 0)))
        {
            ImGui::CloseCurrentPopup();
        }

        ImGui::EndPopup();
    }

    // Tooltip
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::Text("%s", asset.name.c_str());

        if (!asset.isDirectory && asset.uid != 0) {
            ImGui::Text("UID: %llu", asset.uid);
        }

        if (asset.isDirectory && asset.inMemory) {
            ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Contains %d loaded refs", asset.references);
        }

        // Tooltip específico para prefabs
        if (asset.extension == ".prefab") {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(0.5f, 0.8f, 1.0f, 1.0f), "Double-click to instantiate");
            ImGui::Text("Drag to Hierarchy to place as child");
        }

        ImGui::EndTooltip();
    }

    ImGui::PopID();
}

void AssetsWindow::LoadFBXSubresources(AssetEntry& fbxAsset)
{
    // Limpiamos los subrecursos anteriores
    fbxAsset.subResources.clear();

    std::string metaPath = fbxAsset.path + ".meta";
    if (!fs::exists(metaPath)) {
        LOG_CONSOLE("[AssetsWindow] No .meta file found for FBX: %s", fbxAsset.path.c_str());
        return;
    }

    MetaFile meta = MetaFile::Load(metaPath);

    if (meta.uid == 0) {
        LOG_CONSOLE("[AssetsWindow] FBX has no UID in .meta");
        return;
    }

    ModuleResources* resources = Application::GetInstance().resources.get();
    if (!resources) {
        LOG_CONSOLE("[AssetsWindow] ModuleResources not available");
        return;
    }

    const auto& allResources = resources->GetAllResources();

    // --- 1. PROCESAR MINTAS (MESHES) ---
    for (const auto& [meshName, meshUID] : meta.meshes)
    {
        std::string libPath = LibraryManager::GetLibraryPath(meshUID);

        if (!LibraryManager::FileExists(libPath))
            continue;

        AssetEntry meshEntry;
        meshEntry.name = meshName;
        meshEntry.path = libPath;
        meshEntry.extension = ".mesh";
        meshEntry.isDirectory = false;
        meshEntry.isFBX = false;
        meshEntry.uid = meshUID;

        auto it = allResources.find(meshUID);
        if (it != allResources.end()) {
            meshEntry.inMemory = it->second->IsLoadedToMemory();
            meshEntry.references = it->second->GetReferenceCount();
        }

        meshEntry.cachedDisplayName = TruncateFileName(meshEntry.name, iconSize * 0.7f);
        fbxAsset.subResources.push_back(meshEntry);
    }

    for (const auto& [animName, animUID] : meta.animations)
    {
        std::string libPath = LibraryManager::GetLibraryPath(animUID);

        if (!LibraryManager::FileExists(libPath))
            continue;

        AssetEntry animEntry;
        animEntry.name = animName;
        animEntry.path = libPath;
        animEntry.extension = ".anim";
        animEntry.isDirectory = false;
        animEntry.isFBX = false;
        animEntry.uid = animUID;

        auto it = allResources.find(animUID);
        if (it != allResources.end()) {
            animEntry.inMemory = it->second->IsLoadedToMemory();
            animEntry.references = it->second->GetReferenceCount();
        }

        animEntry.cachedDisplayName = TruncateFileName(animEntry.name, iconSize * 0.7f);
        fbxAsset.subResources.push_back(animEntry);

    }

    LOG_DEBUG("[AssetsWindow] FBX Subresources loaded: %d items", (int)fbxAsset.subResources.size());
}

bool AssetsWindow::DeleteAsset(const AssetEntry& asset)
{
    try {
        if (asset.isDirectory)
        {
            return DeleteDirectory(fs::path(asset.path));
        }
        else
        {
            std::string metaPath = asset.path + ".meta";
            unsigned long long uid = 0;

            if (fs::exists(metaPath)) {
                MetaFile meta = MetaFile::Load(metaPath);
                uid = meta.uid;

                // For FBX files, delete all sequential mesh files
                if (meta.type == AssetType::MODEL_FBX) {
                    // Delete all mesh files with UIDs: base_uid, base_uid+1, base_uid+2, etc.
                    for (int i = 0; i < 100; i++) {
                        unsigned long long meshUID = uid + i;
                        std::string libPath = LibraryManager::GetLibraryPath(meshUID);

                        if (fs::exists(libPath)) {
                            fs::remove(libPath);
                        }
                        else {
                            break; // No more meshes
                        }
                    }
                }
                else {
                    // For textures and other single-file assets
                    std::string libPath;

                    if (meta.type == AssetType::TEXTURE_PNG ||
                        meta.type == AssetType::TEXTURE_JPG ||
                        meta.type == AssetType::TEXTURE_DDS ||
                        meta.type == AssetType::TEXTURE_TGA) {
                        libPath = LibraryManager::GetLibraryPath(uid);
                    }

                    if (!libPath.empty() && fs::exists(libPath)) {
                        fs::remove(libPath);
                    }
                }
            }

            // Delete .meta file
            if (fs::exists(metaPath)) {
                fs::remove(metaPath);
            }

            // Delete asset file
            if (fs::exists(asset.path)) {
                fs::remove(asset.path);
            }

            // Remove from ModuleResources
            if (uid != 0 && Application::GetInstance().resources) {
                Application::GetInstance().resources->RemoveResource(uid);
            }

            return true;
        }
    }
    catch (const fs::filesystem_error& e) {
        LOG_CONSOLE("[AssetsWindow] ERROR deleting asset: %s", e.what());
        return false;
    }
}

bool AssetsWindow::DeleteDirectory(const fs::path& dirPath)
{
    try {
        std::vector<unsigned long long> uidsToDelete;

        // Collect all UIDs from .meta files in directory
        for (const auto& entry : fs::recursive_directory_iterator(dirPath)) {
            if (entry.is_regular_file() && entry.path().extension() == ".meta") {
                MetaFile meta = MetaFile::Load(entry.path().string());
                if (meta.uid != 0) {
                    uidsToDelete.push_back(meta.uid);

                    // For FBX files, also delete all mesh UIDs
                    if (meta.type == AssetType::MODEL_FBX) {
                        for (int i = 0; i < 100; i++) {
                            unsigned long long meshUID = meta.uid + i;
                            std::string libPath = LibraryManager::GetLibraryPath(meshUID);

                            if (fs::exists(libPath)) {
                                fs::remove(libPath);
                            }
                            else {
                                break;
                            }
                        }
                    }
                    else {
                        // Delete single library file
                        std::string libPath;

                        if (meta.type == AssetType::TEXTURE_PNG ||
                            meta.type == AssetType::TEXTURE_JPG ||
                            meta.type == AssetType::TEXTURE_DDS ||
                            meta.type == AssetType::TEXTURE_TGA) {
                            libPath = LibraryManager::GetLibraryPath(meta.uid);
                        }

                        if (!libPath.empty() && fs::exists(libPath)) {
                            fs::remove(libPath);
                        }
                    }
                }
            }
        }

        // Remove from ModuleResources
        if (Application::GetInstance().resources) {
            for (unsigned long long uid : uidsToDelete) {
                Application::GetInstance().resources->RemoveResource(uid);
            }
        }

        // Delete entire directory
        fs::remove_all(dirPath);

        return true;
    }
    catch (const fs::filesystem_error& e) {
        LOG_CONSOLE("[AssetsWindow] ERROR deleting directory: %s", e.what());
        return false;
    }
}

void AssetsWindow::RefreshAssets()
{
    for (auto& asset : currentAssets)
    {
        UnloadPreviewForAsset(asset);
    }

    currentAssets.clear();

    if (!fs::exists(currentPath))
    {
        return;
    }

    ScanDirectory(currentPath, currentAssets);
}

void AssetsWindow::ScanDirectory(const fs::path& directory, std::vector<AssetEntry>& outAssets)
{
    if (!fs::exists(directory))
        return;

    for (const auto& entry : fs::directory_iterator(directory))
    {
        const auto& path = entry.path();
        std::string filename = path.filename().string();
        std::string extension = path.extension().string();

        std::transform(extension.begin(), extension.end(), extension.begin(),
            [](unsigned char c) { return std::tolower(c); });

        if (extension == ".meta")
        {
            continue;
        }

        bool isDirectory = entry.is_directory();

        if (!isDirectory && !IsAssetFile(extension))
        {
            continue;
        }

        AssetEntry asset;
        asset.name = filename;
        asset.path = path.string();
        asset.isDirectory = isDirectory;
        asset.extension = extension;
        asset.inMemory = false;
        asset.references = 0;
        asset.uid = 0;

        asset.isFBX = (extension == ".fbx");
        asset.isExpanded = false;
        asset.subResources.clear();

        if (isDirectory)
        {
            ModuleResources* resources = Application::GetInstance().resources.get();
            if (resources)
            {
                int totalRefs = 0;
                bool anyLoaded = false;

                try {
                    for (const auto& subEntry : fs::recursive_directory_iterator(path))
                    {
                        if (subEntry.is_regular_file())
                        {
                            std::string subExt = subEntry.path().extension().string();
                            std::transform(subExt.begin(), subExt.end(), subExt.begin(),
                                [](unsigned char c) { return std::tolower(c); });

                            if (subExt == ".meta")
                                continue;

                            if (!IsAssetFile(subExt))
                                continue;

                            std::string subMetaPath = subEntry.path().string() + ".meta";
                            if (fs::exists(subMetaPath))
                            {
                                MetaFile subMeta = MetaFile::Load(subMetaPath);
                                if (subMeta.uid != 0)
                                {
                                    if (subExt == ".fbx")
                                    {
                                        // For FBX, verify all meshes with sequential UIDs
                                        const auto& allResources = resources->GetAllResources();

                                        for (int i = 0; i < 100; i++) {
                                            unsigned long long meshUID = subMeta.uid + i;
                                            std::string meshLibPath = LibraryManager::GetLibraryPath(meshUID);

                                            if (!fs::exists(meshLibPath)) {
                                                break;
                                            }

                                            // Check if it is loaded in memory
                                            for (const auto& pair : allResources)
                                            {
                                                if (pair.second->GetLibraryFile() == meshLibPath)
                                                {
                                                    if (pair.second->IsLoadedToMemory())
                                                    {
                                                        anyLoaded = true;
                                                        totalRefs += pair.second->GetReferenceCount();
                                                    }
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                    else if (subExt == ".png" || subExt == ".jpg" || subExt == ".jpeg" ||
                                        subExt == ".dds" || subExt == ".tga")
                                    {
                                        if (resources->IsResourceLoaded(subMeta.uid))
                                        {
                                            anyLoaded = true;
                                            totalRefs += resources->GetResourceReferenceCount(subMeta.uid);
                                        }
                                    }
                                    else
                                    {
                                        // For other types of assets
                                        if (resources->IsResourceLoaded(subMeta.uid))
                                        {
                                            anyLoaded = true;
                                            totalRefs += resources->GetResourceReferenceCount(subMeta.uid);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                catch (...) {}

                asset.inMemory = anyLoaded;
                asset.references = totalRefs;
            }
        }
        else
        {
            std::string metaPath = asset.path + ".meta";
            if (fs::exists(metaPath))
            {
                MetaFile meta = MetaFile::Load(metaPath);
                asset.uid = meta.uid;

                if (asset.uid != 0 && Application::GetInstance().resources)
                {
                    ModuleResources* resources = Application::GetInstance().resources.get();

                    if (extension == ".fbx")
                    {
                        int totalRefs = 0;
                        bool anyLoaded = false;

                        const auto& allResources = resources->GetAllResources();

                        // Verify all meshes in the FBX (sequential UIDs)
                        for (int i = 0; i < 100; i++) {
                            unsigned long long meshUID = meta.uid + i;
                            std::string meshLibPath = LibraryManager::GetLibraryPath(meshUID);

                            if (!fs::exists(meshLibPath)) {
                                break;
                            }

                            // Check if it is loaded in memory
                            for (const auto& pair : allResources)
                            {
                                if (pair.second->GetLibraryFile() == meshLibPath)
                                {
                                    if (pair.second->IsLoadedToMemory())
                                    {
                                        anyLoaded = true;
                                        int refs = pair.second->GetReferenceCount();
                                        totalRefs += refs;
                                    }
                                    break;
                                }
                            }
                        }

                        asset.inMemory = anyLoaded;
                        asset.references = totalRefs;
                    }
                    else if (extension == ".png" || extension == ".jpg" || extension == ".jpeg" ||
                        extension == ".dds" || extension == ".tga")
                    {
                        asset.inMemory = resources->IsResourceLoaded(asset.uid);
                        asset.references = resources->GetResourceReferenceCount(asset.uid);
                    }
                    else
                    {
                        asset.inMemory = resources->IsResourceLoaded(asset.uid);
                        asset.references = resources->GetResourceReferenceCount(asset.uid);
                    }
                }
            }
        }

        asset.cachedDisplayName = TruncateFileName(asset.name, iconSize);

        outAssets.push_back(asset);
    }

    std::sort(outAssets.begin(), outAssets.end(), [](const AssetEntry& a, const AssetEntry& b)
        {
            if (a.isDirectory != b.isDirectory)
                return a.isDirectory > b.isDirectory;
            return a.name < b.name;
        });
}

const char* AssetsWindow::GetAssetIcon(const std::string& extension) const
{
    if (extension.empty()) return "[DIR]";
    if (extension == ".fbx" || extension == ".obj") return "[3D]";
    if (extension == ".png" || extension == ".jpg" || extension == ".jpeg" || extension == ".dds") return "[IMG]";
    if (extension == ".mesh") return "[MSH]";
    if (extension == ".texture") return "[TEX]";
    if (extension == ".wav" || extension == ".ogg" || extension == ".mp3") return "[SND]";
    if (extension == ".lua") return "[LUA]";  
    if (extension == ".prefab") return "[PREFAB]";
    return "[FILE]";
}

bool AssetsWindow::IsAssetFile(const std::string& extension) const
{
    return extension == ".fbx" ||
        extension == ".obj" ||
        extension == ".png" ||
        extension == ".jpg" ||
        extension == ".jpeg" ||
        extension == ".dds" ||
        extension == ".tga" ||
        extension == ".mesh" ||
        extension == ".texture" ||
        extension == ".wav" ||
        extension == ".ogg" ||
        extension == ".json" ||
        extension == ".lua"  ||
        extension == ".mat"  ||
        extension == ".prefab" ||
        extension == ".scene";
}

void AssetsWindow::LoadPreviewForAsset(AssetEntry& asset)
{
    // If loading has already been attempted, do not try again.
    if (asset.previewLoaded)
        return;

    asset.previewLoaded = true;

    // Textures (PNG, JPG, JPEG, TGA)
    if (asset.extension == ".png" || asset.extension == ".jpg" ||
        asset.extension == ".jpeg" || asset.extension == ".tga")
    {
        // Load image directly with stb_image
        int width, height, channels;
        stbi_set_flip_vertically_on_load(true);

        unsigned char* data = stbi_load(asset.path.c_str(), &width, &height, &channels, 0);

        if (data)
        {
            // Crear textura OpenGL
            GLuint textureID;
            glGenTextures(1, &textureID);
            glBindTexture(GL_TEXTURE_2D, textureID);

            // Configure parameters
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

            // Determine format
            GLenum format = GL_RGB;
            if (channels == 1)
                format = GL_RED;
            else if (channels == 3)
                format = GL_RGB;
            else if (channels == 4)
                format = GL_RGBA;

            // Upload data
            glTexImage2D(GL_TEXTURE_2D, 0, format, width, height, 0, format, GL_UNSIGNED_BYTE, data);

            glBindTexture(GL_TEXTURE_2D, 0);

            // unload dat
            stbi_image_free(data);

            // Guardar ID
            asset.previewTextureID = textureID;

            LOG_DEBUG("[AssetsWindow] Loaded preview for texture: %s", asset.name.c_str());
        }
        else
        {
            LOG_DEBUG("[AssetsWindow] Failed to load preview for: %s", asset.name.c_str());
        }
    }
    else if (asset.extension == ".dds")
    {
        if (asset.uid != 0)
        {
            ModuleResources* resources = Application::GetInstance().resources.get();
            if (resources)
            {
                const Resource* resource = resources->GetResource(asset.uid);
                if (resource && resource->IsLoadedToMemory())
                {
                    const ResourceTexture* texResource = dynamic_cast<const ResourceTexture*>(resource);
                    if (texResource)
                    {
                        asset.previewTextureID = texResource->GetGPU_ID();
                        LOG_DEBUG("[AssetsWindow] Using existing texture for preview: %s", asset.name.c_str());
                    }
                }
            }
        }
    }
    // Individual meshes
    else if (asset.extension == ".mesh")
    {
        if (!show3DPreviews)
        {
            return;
        }

        if (asset.uid != 0)
        {
            ModuleResources* resources = Application::GetInstance().resources.get();
            if (resources)
            {
                // Load the mesh temporarily
                ResourceMesh* meshResource = dynamic_cast<ResourceMesh*>(
                    resources->RequestResource(asset.uid)
                    );

                if (meshResource && meshResource->IsLoadedToMemory())
                {
                    const Mesh& mesh = meshResource->GetMesh();

                    // Render to texture
                    int previewSize = static_cast<int>(iconSize * 2);
                    asset.previewTextureID = RenderMeshToTexture(mesh, previewSize, previewSize);

                    LOG_DEBUG("[AssetsWindow] Rendered preview for mesh: %s", asset.name.c_str());

                    resources->ReleaseResource(asset.uid);
                }
            }
        }
    }
    // FBX (render ALL meshes together)
    else if (asset.extension == ".fbx")
    {
        if (!show3DPreviews)
        {
            return;
        }

        if (asset.uid != 0)
        {
            ModuleResources* resources = Application::GetInstance().resources.get();
            if (resources)
            {
                // Load all meshes from the FBX
                std::vector<const Mesh*> meshes;

                // Attempt to load up to 100 meshes (sequential UIDs)
                for (int i = 0; i < 100; i++)
                {
                    unsigned long long meshUID = asset.uid + i;
                    std::string meshLibPath = LibraryManager::GetLibraryPath(meshUID);

                    if (!LibraryManager::FileExists(meshLibPath))
                    {
                        break; 
                    }

                    ResourceMesh* meshResource = dynamic_cast<ResourceMesh*>(
                        resources->RequestResource(meshUID)
                        );

                    if (meshResource && meshResource->IsLoadedToMemory())
                    {
                        meshes.push_back(&meshResource->GetMesh());
                    }
                }

                if (!meshes.empty())
                {
                    // Render all meshes together
                    int previewSize = static_cast<int>(iconSize * 2);
                    asset.previewTextureID = RenderMultipleMeshesToTexture(meshes, previewSize, previewSize);

                    LOG_DEBUG("[AssetsWindow] Rendered preview for FBX: %s (%zu meshes)",
                        asset.name.c_str(), meshes.size());

                    // Free up resources
                    for (int i = 0; i < static_cast<int>(meshes.size()); i++)
                    {
                        resources->ReleaseResource(asset.uid + i);
                    }
                }
            }
        }
    }
}

void AssetsWindow::UnloadPreviewForAsset(AssetEntry& asset)
{
    // Release textures that we load ourselves (not those from the resource system)
    if (asset.previewTextureID != 0)
    {
        // We only release it if it is not a DDS texture from the resource system.
        if (asset.extension != ".dds")
        {
            glDeleteTextures(1, &asset.previewTextureID);
        }
        asset.previewTextureID = 0;
    }

    asset.previewLoaded = false;
}

unsigned int AssetsWindow::RenderMeshToTexture(const Mesh& mesh, int width, int height)
{
    // Save current OpenGL state
    GLint oldFBO, oldViewport[4];
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFBO);
    glGetIntegerv(GL_VIEWPORT, oldViewport);

    // Create framebuffer for off-screen rendering
    GLuint fbo, colorTexture, depthRBO;

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    // Create texture for colour
    glGenTextures(1, &colorTexture);
    glBindTexture(GL_TEXTURE_2D, colorTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTexture, 0);

    // Create render buffer for depth
    glGenRenderbuffers(1, &depthRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRBO);

    // Verify that the framebuffer is complete
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        LOG_DEBUG("[RenderMeshToTexture] ERROR: Framebuffer incomplete");
        glBindFramebuffer(GL_FRAMEBUFFER, oldFBO);
        glDeleteFramebuffers(1, &fbo);
        glDeleteRenderbuffers(1, &depthRBO);
        glDeleteTextures(1, &colorTexture);
        return 0;
    }

    glViewport(0, 0, width, height);

    glClearColor(0.2f, 0.2f, 0.25f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    glm::vec3 minBounds(FLT_MAX);
    glm::vec3 maxBounds(-FLT_MAX);

    for (const auto& vertex : mesh.vertices)
    {
        minBounds = glm::min(minBounds, vertex.position);
        maxBounds = glm::max(maxBounds, vertex.position);
    }

    glm::vec3 center = (minBounds + maxBounds) * 0.5f;
    glm::vec3 size = maxBounds - minBounds;
    float maxDim = glm::max(size.x, glm::max(size.y, size.z));

    // Configure camera arrays
    float distance = maxDim * 2.2f;
    glm::vec3 cameraPos = center + glm::vec3(distance * 0.6f, distance * 0.4f, distance * 0.6f);

    glm::mat4 view = glm::lookAt(cameraPos, center, glm::vec3(0, 1, 0));
    glm::mat4 projection = glm::perspective(glm::radians(45.0f), 1.0f, 0.1f, distance * 10.0f);
    glm::mat4 model = glm::mat4(1.0f);
    glm::mat4 mvp = projection * view * model;

    // Simple inline shader
    const char* vertexShaderSrc = R"(
        #version 330 core
        layout(location = 0) in vec3 aPos;
        layout(location = 1) in vec3 aNormal;
        
        uniform mat4 mvp;
        out vec3 Normal;
        
        void main() {
            gl_Position = mvp * vec4(aPos, 1.0);
            Normal = aNormal;
        }
    )";

    const char* fragmentShaderSrc = R"(
        #version 330 core
        in vec3 Normal;
        out vec4 FragColor;
        
        void main() {
            vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
            vec3 norm = normalize(Normal);
            float diff = max(dot(norm, lightDir), 0.0);
            
            vec3 baseColor = vec3(0.7, 0.7, 0.75);
            vec3 ambient = 0.3 * baseColor;
            vec3 diffuse = diff * baseColor;
            
            FragColor = vec4(ambient + diffuse, 1.0);
        }
    )";

    // Compile shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSrc, nullptr);
    glCompileShader(vertexShader);

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSrc, nullptr);
    glCompileShader(fragmentShader);

    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    glUseProgram(shaderProgram);

    GLint mvpLoc = glGetUniformLocation(shaderProgram, "mvp");
    if (mvpLoc != -1)
    {
        glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, glm::value_ptr(mvp));
    }

    if (mesh.VAO != 0 && !mesh.indices.empty())
    {
        glBindVertexArray(mesh.VAO);
        glDrawElements(GL_TRIANGLES, mesh.indices.size(), GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);
    }

    glDeleteProgram(shaderProgram);

    glBindFramebuffer(GL_FRAMEBUFFER, oldFBO);
    glViewport(oldViewport[0], oldViewport[1], oldViewport[2], oldViewport[3]);

    glDeleteFramebuffers(1, &fbo);
    glDeleteRenderbuffers(1, &depthRBO);

    return colorTexture;
}

unsigned int AssetsWindow::RenderMultipleMeshesToTexture(const std::vector<const Mesh*>& meshes, int width, int height)
{
    if (meshes.empty())
        return 0;

    // Save current OpenGL state
    GLint oldFBO, oldViewport[4];
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFBO);
    glGetIntegerv(GL_VIEWPORT, oldViewport);

    // Create framebuffer for off-screen rendering
    GLuint fbo, colorTexture, depthRBO;

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    // Create texture for colour
    glGenTextures(1, &colorTexture);
    glBindTexture(GL_TEXTURE_2D, colorTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTexture, 0);

    // Create render buffer for depth
    glGenRenderbuffers(1, &depthRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRBO);

    // Verify that the framebuffer is complete
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        LOG_DEBUG("[RenderMultipleMeshesToTexture] ERROR: Framebuffer incomplete");
        glBindFramebuffer(GL_FRAMEBUFFER, oldFBO);
        glDeleteFramebuffers(1, &fbo);
        glDeleteRenderbuffers(1, &depthRBO);
        glDeleteTextures(1, &colorTexture);
        return 0;
    }

    // Configure viewport
    glViewport(0, 0, width, height);

    // Clean with dark grey background
    glClearColor(0.2f, 0.2f, 0.25f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);

    // Calculate global AABB of all combined meshes
    glm::vec3 globalMinBounds(FLT_MAX);
    glm::vec3 globalMaxBounds(-FLT_MAX);

    for (const Mesh* mesh : meshes)
    {
        for (const auto& vertex : mesh->vertices)
        {
            globalMinBounds = glm::min(globalMinBounds, vertex.position);
            globalMaxBounds = glm::max(globalMaxBounds, vertex.position);
        }
    }

    glm::vec3 center = (globalMinBounds + globalMaxBounds) * 0.5f;
    glm::vec3 size = globalMaxBounds - globalMinBounds;
    float maxDim = glm::max(size.x, glm::max(size.y, size.z));

    // Configure camera arrays
    float distance = maxDim * 2.2f;
    glm::vec3 cameraPos = center + glm::vec3(distance * 0.6f, distance * 0.4f, distance * 0.6f);

    glm::mat4 view = glm::lookAt(cameraPos, center, glm::vec3(0, 1, 0));
    glm::mat4 projection = glm::perspective(glm::radians(45.0f), 1.0f, 0.1f, distance * 10.0f);
    glm::mat4 model = glm::mat4(1.0f);
    glm::mat4 mvp = projection * view * model;

    // Shader simple inline
    const char* vertexShaderSrc = R"(
        #version 330 core
        layout(location = 0) in vec3 aPos;
        layout(location = 1) in vec3 aNormal;
        
        uniform mat4 mvp;
        out vec3 Normal;
        
        void main() {
            gl_Position = mvp * vec4(aPos, 1.0);
            Normal = aNormal;
        }
    )";

    const char* fragmentShaderSrc = R"(
        #version 330 core
        in vec3 Normal;
        out vec4 FragColor;
        
        void main() {
            vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
            vec3 norm = normalize(Normal);
            float diff = max(dot(norm, lightDir), 0.0);
            
            vec3 baseColor = vec3(0.7, 0.7, 0.75);
            vec3 ambient = 0.3 * baseColor;
            vec3 diffuse = diff * baseColor;
            
            FragColor = vec4(ambient + diffuse, 1.0);
        }
    )";

    // Compilar shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSrc, nullptr);
    glCompileShader(vertexShader);

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSrc, nullptr);
    glCompileShader(fragmentShader);

    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    // Usar shader
    glUseProgram(shaderProgram);

    GLint mvpLoc = glGetUniformLocation(shaderProgram, "mvp");
    if (mvpLoc != -1)
    {
        glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, glm::value_ptr(mvp));
    }

    for (const Mesh* mesh : meshes)
    {
        if (mesh->VAO != 0 && !mesh->indices.empty())
        {
            glBindVertexArray(mesh->VAO);
            glDrawElements(GL_TRIANGLES, mesh->indices.size(), GL_UNSIGNED_INT, 0);
            glBindVertexArray(0);
        }
    }

    glDeleteProgram(shaderProgram);

    glBindFramebuffer(GL_FRAMEBUFFER, oldFBO);
    glViewport(oldViewport[0], oldViewport[1], oldViewport[2], oldViewport[3]);

    glDeleteFramebuffers(1, &fbo);
    glDeleteRenderbuffers(1, &depthRBO);

    return colorTexture;
}

void AssetsWindow::HandleExternalDragDrop(const std::string& filePath)
{
    std::string droppedPath = filePath;

    LOG_CONSOLE("[AssetsWindow] File dropped on Assets window: %s", droppedPath.c_str());

    if (ProcessDroppedFile(droppedPath))
    {
        RefreshAssets();
    }
    else
    {
        LOG_CONSOLE("[AssetsWindow] Failed to import: %s", droppedPath.c_str());
    }
}

void AssetsWindow::HandleInternalDragDrop()
{
    if (ImGui::BeginDragDropTarget())
    {
        if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("HIERARCHY_GAMEOBJECT"))
        {
            GameObject* droppedObject = *(GameObject**)payload->Data;

            if (droppedObject)
            {
                LOG_CONSOLE("[AssetsWindow] GameObject dropped: %s", droppedObject->GetName().c_str());

                prefabNamingOpened = true;
            }
        }

        ImGui::EndDragDropTarget();
    }
}

bool AssetsWindow::ProcessDroppedFile(const std::string& sourceFilePath)
{
    LOG_CONSOLE("[AssetsWindow] Processing dropped file: %s", sourceFilePath.c_str());

    if (!fs::exists(sourceFilePath))
    {
        LOG_CONSOLE("[AssetsWindow] ERROR: Source file does not exist");
        return false;
    }

    fs::path sourcePath(sourceFilePath);
    std::string extension = sourcePath.extension().string();
    std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);

    LOG_CONSOLE("[AssetsWindow] File extension: %s", extension.c_str());

    AssetType assetType = MetaFile::GetAssetType(extension);
    if (assetType == AssetType::UNKNOWN)
    {
        LOG_CONSOLE("[AssetsWindow] ERROR: Unsupported file type: %s", extension.c_str());
        return false;
    }

    std::string destPath;
    if (!CopyFileToAssets(sourceFilePath, destPath))
    {
        LOG_CONSOLE("[AssetsWindow] ERROR: Failed to copy file to Assets");
        return false;
    }

    LOG_CONSOLE("[AssetsWindow] File copied to: %s", destPath.c_str());

    Application::GetInstance().resources.get()->ImportFile(destPath.c_str(), true);

    return true;
}

bool AssetsWindow::CopyFileToAssets(const std::string& sourceFilePath, std::string& outDestPath)
{
    try
    {
        fs::path sourcePath(sourceFilePath);
        std::string filename = sourcePath.filename().string();

        LOG_CONSOLE("[AssetsWindow] Copying file: %s", filename.c_str());

        fs::path destDir(currentPath);

        LOG_CONSOLE("[AssetsWindow] Destination directory: %s", destDir.string().c_str());

        if (!fs::exists(destDir))
        {
            LOG_CONSOLE("[AssetsWindow] Creating directory: %s", destDir.string().c_str());
            fs::create_directories(destDir);
        }

        fs::path destPath = destDir / filename;

        if (fs::exists(destPath))
        {
            LOG_CONSOLE("[AssetsWindow] File already exists, generating unique name...");

            std::string baseName = sourcePath.stem().string();
            std::string extension = sourcePath.extension().string();
            int counter = 1;

            do
            {
                std::string newFilename = baseName + "_" + std::to_string(counter) + extension;
                destPath = destDir / newFilename;
                counter++;
            } while (fs::exists(destPath));

            LOG_CONSOLE("[AssetsWindow] Renamed to: %s", destPath.filename().string().c_str());
        }

        LOG_CONSOLE("[AssetsWindow] Copying from: %s", sourcePath.string().c_str());
        LOG_CONSOLE("[AssetsWindow] Copying to: %s", destPath.string().c_str());

        fs::copy_file(sourcePath, destPath, fs::copy_options::overwrite_existing);

        outDestPath = destPath.string();

        return true;
    }
    catch (const fs::filesystem_error& e)
    {
        LOG_CONSOLE("[AssetsWindow] ERROR copying file: %s", e.what());
        return false;
    }
}

// Modals
void AssetsWindow::ShowMaterialNamingModal()
{
    if (materialNamingOpened) ImGui::OpenPopup("Create New Material");
    
    if (ImGui::BeginPopupModal("Create New Material", NULL, ImGuiWindowFlags_AlwaysAutoResize))
    {
        static char matName[128] = "NewMaterial";
        
        if (ImGui::IsWindowAppearing())
        {
            materialNamingOpened = true;
        }

        if (materialNamingOpened)
        {
            ImGui::SetKeyboardFocusHere();
            materialNamingOpened = false;
        }

        ImGui::Text("Enter material name:");
        ImGui::InputText("##matname", matName, 128);

        ImGui::Spacing();
        if (ImGui::Button("Create", ImVec2(120, 0))) {
            UID newMatUID = MaterialImporter::CreateNewMaterial(currentPath, matName);
            if (newMatUID != 0) {
                RefreshAssets();
            }
            ImGui::CloseCurrentPopup();
            strcpy(matName, "NewMaterial");
        }

        ImGui::SameLine();
        if (ImGui::Button("Cancel", ImVec2(120, 0))) {
            ImGui::CloseCurrentPopup();
        }
        ImGui::EndPopup();
    }
}

void AssetsWindow::ShowPrefabNamingModal()
{
    if (prefabNamingOpened) ImGui::OpenPopup("Create Prefab");

    if (ImGui::BeginPopupModal("Create Prefab", nullptr, ImGuiWindowFlags_AlwaysAutoResize))
    {
        static char prefabName[256] = "";
        static GameObject* s_objectToConvertToPrefab = nullptr;
        
        if (ImGui::IsWindowAppearing())
        {
            SelectionManager* selection = Application::GetInstance().selectionManager;
            if (selection->HasSelection())
            {
                s_objectToConvertToPrefab = selection->GetSelectedObject();

                if (s_objectToConvertToPrefab)
                {
                    strncpy(prefabName, s_objectToConvertToPrefab->GetName().c_str(), sizeof(prefabName) - 1);
                    prefabName[sizeof(prefabName) - 1] = '\0';
                }
            }
        }

        ImGui::Text("Create Prefab from GameObject");
        ImGui::Separator();
        ImGui::Spacing();

        if (s_objectToConvertToPrefab)
        {
            ImGui::TextColored(ImVec4(0.5f, 0.8f, 1.0f, 1.0f), "GameObject: %s",
                s_objectToConvertToPrefab->GetName().c_str());
        }
        else
        {
            ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.5f, 1.0f), "ERROR: No GameObject selected");
        }

        ImGui::Spacing();
        ImGui::Separator();
        ImGui::Spacing();

        ImGui::Text("Prefab Name:");
        ImGui::SetNextItemWidth(300.0f);

        if (prefabNamingOpened)
        {
            ImGui::SetKeyboardFocusHere();
            prefabNamingOpened = false;
        }

        ImGui::InputText("##prefabname", prefabName, sizeof(prefabName));
        ImGui::TextColored(ImVec4(0.7f, 0.7f, 0.7f, 1.0f), "Extension .prefab will be added automatically");

        ImGui::Spacing();

        fs::path destinationPath = fs::path(currentPath) / (std::string(prefabName) + ".prefab");
        std::string relativePath = destinationPath.string();
        std::string assetsRoot = FileSystem::GetAssetsRoot();

        if (relativePath.find(assetsRoot) == 0)
        {
            relativePath = relativePath.substr(assetsRoot.length());
            if (!relativePath.empty() && (relativePath[0] == '\\' || relativePath[0] == '/'))
            {
                relativePath = relativePath.substr(1);
            }
        }

        ImGui::TextColored(ImVec4(0.6f, 0.6f, 0.6f, 1.0f), "Will be saved to:");
        ImGui::SameLine();
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.5f, 1.0f), "Assets/%s", relativePath.c_str());

        ImGui::Spacing();
        ImGui::Separator();
        ImGui::Spacing();

        bool canCreate = (strlen(prefabName) > 0 && s_objectToConvertToPrefab != nullptr);

        if (!canCreate)
        {
            ImGui::PushStyleVar(ImGuiStyleVar_Alpha, 0.5f);
        }

        if (ImGui::Button("Create", ImVec2(120, 0)) && canCreate)
        {
            Application::GetInstance().loader.get()->SavePrefab(s_objectToConvertToPrefab, destinationPath.generic_string());
            Application::GetInstance().resources.get()->ImportFile(destinationPath.generic_string().c_str());
            RefreshAssets();

            s_objectToConvertToPrefab = nullptr;
            strcpy(prefabName, "");
            prefabNamingOpened = false;
            ImGui::CloseCurrentPopup();
        }

        if (!canCreate)
        {
            ImGui::PopStyleVar();
        }

        ImGui::SameLine();

        if (ImGui::Button("Cancel", ImVec2(120, 0)))
        {
            s_objectToConvertToPrefab = nullptr;
            strcpy(prefabName, "");
            prefabNamingOpened = false;
            ImGui::CloseCurrentPopup();
        }

        ImGui::EndPopup();
    }
}

// scripts
void AssetsWindow::CreateNewScript(const std::string& scriptName)
{
    std::string filename = scriptName;

    // Añadir extensión .lua si no está presente
    if (filename.find(".lua") == std::string::npos)
    {
        filename += ".lua";
    }

    fs::path scriptPath = fs::path(currentPath) / filename;

    // Verificar si el archivo ya existe
    if (fs::exists(scriptPath))
    {
        LOG_CONSOLE("[AssetsWindow] ERROR: Script already exists: %s", filename.c_str());

        // Generar nombre único
        int counter = 1;
        std::string baseName = scriptName;

        do
        {
            filename = baseName + "_" + std::to_string(counter) + ".lua";
            scriptPath = fs::path(currentPath) / filename;
            counter++;
        } while (fs::exists(scriptPath));

        LOG_CONSOLE("[AssetsWindow] Using unique name: %s", filename.c_str());
    }

    // Crear archivo de script con template
    std::ofstream scriptFile(scriptPath);

    if (!scriptFile.is_open())
    {
        LOG_CONSOLE("[AssetsWindow] ERROR: Cannot create script file");
        return;
    }

    scriptFile << GetDefaultScriptTemplate();
    scriptFile.close();

    LOG_CONSOLE("[AssetsWindow] Created script: %s", scriptPath.string().c_str());

    // Crear archivo .meta
    MetaFile meta;
    meta.uid = GenerateUID();
    meta.type = AssetType::SCRIPT_LUA;
    meta.originalPath = scriptPath.string();

    std::string metaPath = scriptPath.string() + ".meta";
    meta.Save(metaPath);

    // Importar al sistema de recursos
    ModuleResources* resources = Application::GetInstance().resources.get();
    if (resources)
    {
        Resource* scriptResource = resources->CreateNewResourceWithUID(
            scriptPath.string().c_str(),
            Resource::SCRIPT,
            meta.uid
        );

        if (scriptResource)
        {
            scriptResource->SetAssetFile(scriptPath.string());
            scriptResource->SetLibraryFile(scriptPath.string());
            LOG_CONSOLE("[AssetsWindow] Script registered with UID: %llu", meta.uid);
        }
    }

    RefreshAssets();

    // Abrir en el editor interno por defecto
    if (Application::GetInstance().editor.get()->GetScriptEditor())
    {
        Application::GetInstance().editor.get()->GetScriptEditor()->SetOpen(true);
        Application::GetInstance().editor.get()->GetScriptEditor()->OpenScript(scriptPath.string());
    }
}

std::string AssetsWindow::GetDefaultScriptTemplate()
{
    return R"(-- Script Template
-- This script is attached to a GameObject
-- Access the GameObject through: self.gameObject
-- Access the Transform through: self.transform

function Start()
    -- Called once when the script is initialized
    Engine.Log("Script Started!")
    
    -- Example: Get initial position
    local pos = self.transform.position
    Engine.Log("Initial Position: " .. pos.x .. ", " .. pos.y .. ", " .. pos.z)
end

function Update(deltaTime)
    -- Called every frame
    -- deltaTime = time since last frame in seconds
    
    -- Example: Rotate object
    -- local rot = self.transform.rotation
    -- self.transform:SetRotation(rot.x, rot.y + 90 * deltaTime, rot.z)
    
    -- Example: Move with WASD
    -- local pos = self.transform.position
    -- local speed = 5.0
    -- 
    -- if Input.GetKey("W") then
    --     self.transform:SetPosition(pos.x, pos.y, pos.z - speed * deltaTime)
    -- end
    -- if Input.GetKey("S") then
    --     self.transform:SetPosition(pos.x, pos.y, pos.z + speed * deltaTime)
    -- end
    -- if Input.GetKey("A") then
    --     self.transform:SetPosition(pos.x - speed * deltaTime, pos.y, pos.z)
    -- end
    -- if Input.GetKey("D") then
    --     self.transform:SetPosition(pos.x + speed * deltaTime, pos.y, pos.z)
    -- end
end
)";
}

void AssetsWindow::OnEvent(const Event& event)
{
    switch (event.type)
    {
    case Event::Type::FileDropped:
    {
        std::string filePath = event.data.string.string;
        HandleExternalDragDrop(filePath);
        break;
    }

    default:
        break;
    }
}