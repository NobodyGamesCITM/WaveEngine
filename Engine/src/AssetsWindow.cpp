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
#include "ScriptImporter.h"
#include "ResourcePrefab.h"
#include "FileSystem.h"
#include "PrefabManager.h"
#include "Globals.h"
#include <algorithm>

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

AssetsWindow::AssetsWindow()
    : EditorWindow("Assets"), selectedAsset(nullptr), iconSize(64.0f),
    show3DPreviews(true), showDeleteConfirmation(false)
{
    Application::GetInstance().events.get()->Subscribe(Event::Type::FileDropped, this);

    if (!LibraryManager::IsInitialized()) {
        LibraryManager::Initialize();
    }

    assetsRootPath = FileSystem::GetAssetsRoot();
    currentPath = assetsRootPath;

    importSettingsWindow = new ImportSettingsWindow();

    CompilePreviewShader();
}

AssetsWindow::~AssetsWindow()
{
    Application::GetInstance().events.get()->UnsubscribeAll(this);
    if (rootNode) FreeTree(rootNode);

    delete importSettingsWindow;

    if (previewShaderProgram != 0) glDeleteProgram(previewShaderProgram);
}

void AssetsWindow::FreeTree(AssetNode* node)
{
    if (!node) return;

    UnloadPreviewForAsset(node);

    for (AssetNode* child : node->children) {
        FreeTree(child);
    }
    for (AssetNode* sub : node->subResources) {
        FreeTree(sub);
    }
    delete node;
}

void AssetsWindow::RefreshAssets()
{
    std::string previousPath = currentPath;
    breadcrumbTrail.clear();
    currentNode = nullptr;

    if (rootNode) {
        FreeTree(rootNode);
        rootNode = nullptr;
    }

    if (!fs::exists(assetsRootPath)) return;

    rootNode = new AssetNode();
    rootNode->path = assetsRootPath;
    rootNode->name = "Assets";
    rootNode->isDirectory = true;
    rootNode->isFBX = false;
    rootNode->isExpanded = false;

    BuildTreeRecursive(rootNode);

    AssetNode* restoredNode = FindNodeByPath(rootNode, previousPath);
    if (restoredNode) {
        currentNode = restoredNode;
    }
    else {
        currentNode = rootNode;
        currentPath = assetsRootPath;
    }
    relativePathDirty = true;
}

void AssetsWindow::BuildTreeRecursive(AssetNode* parentNode)
{
    if (!fs::exists(parentNode->path)) return;

    for (const auto& entry : fs::directory_iterator(parentNode->path))
    {
        const auto& path = entry.path();
        std::string filename = path.filename().string();
        std::string extension = path.extension().string();

        std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);

        if (extension == ".meta") continue;

        bool isDirectory = entry.is_directory();
        if (!isDirectory && !IsAssetFile(extension)) continue;

        AssetNode* childNode = new AssetNode();
        childNode->name = filename;
        childNode->path = path.string();
        childNode->isDirectory = isDirectory;
        childNode->extension = extension;
        childNode->isFBX = (extension == ".fbx");
        childNode->isExpanded = false;
        childNode->parent = parentNode;
        childNode->cachedDisplayName = TruncateFileName(filename, iconSize);
        childNode->inMemory = false;
        childNode->references = 0;
        childNode->uid = 0;

        // Comprobar UID y estado en memoria de forma optimizada
        if (!isDirectory)
        {
            std::string metaPath = childNode->path + ".meta";
            if (fs::exists(metaPath))
            {
                MetaFile meta = MetaFile::Load(metaPath);
                childNode->uid = meta.uid;

                if (childNode->uid != 0 && Application::GetInstance().resources)
                {
                    ModuleResources* resources = Application::GetInstance().resources.get();
                    if (extension == ".fbx")
                    {
                        // FBX (Comprobar meshes secuenciales)
                        int totalRefs = 0;
                        bool anyLoaded = false;
                        const auto& allResources = resources->GetAllResources();
                        for (int i = 0; i < 100; i++) {
                            unsigned long long meshUID = meta.uid + i;
                            std::string meshLibPath = LibraryManager::GetLibraryPath(meshUID);
                            if (!fs::exists(meshLibPath)) break;

                            for (const auto& pair : allResources) {
                                if (pair.second->GetLibraryFile() == meshLibPath && pair.second->IsLoadedToMemory()) {
                                    anyLoaded = true;
                                    totalRefs += pair.second->GetReferenceCount();
                                    break;
                                }
                            }
                        }
                        childNode->inMemory = anyLoaded;
                        childNode->references = totalRefs;
                    }
                    else
                    {
                        childNode->inMemory = resources->IsResourceLoaded(childNode->uid);
                        childNode->references = resources->GetResourceReferenceCount(childNode->uid);
                    }
                }
            }
        }

        parentNode->children.push_back(childNode);

        if (isDirectory) {
            BuildTreeRecursive(childNode);
        }
    }

    // Ordenar: Carpetas primero, luego alfabéticamente
    std::sort(parentNode->children.begin(), parentNode->children.end(), [](const AssetNode* a, const AssetNode* b) {
        if (a->isDirectory != b->isDirectory) return a->isDirectory > b->isDirectory;
        return a->name < b->name;
        });
}

AssetNode* AssetsWindow::FindNodeByPath(AssetNode* node, const std::string& targetPath)
{
    if (!node) return nullptr;
    if (node->path == targetPath) return node;

    for (AssetNode* child : node->children) {
        if (child->isDirectory) {
            AssetNode* result = FindNodeByPath(child, targetPath);
            if (result) return result;
        }
    }
    return nullptr;
}


// === DRAW PRINCIPAL ===

void AssetsWindow::Draw()
{
    if (!isOpen) return;

    static bool firstDraw = true;
    static bool previousShow3DPreviews = true;

    isHovered = ImGui::IsWindowHovered(ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows);

    if (firstDraw) {
        RefreshAssets();
        firstDraw = false;
        previousShow3DPreviews = show3DPreviews;
    }

    // UI de borrado
    if (showDeleteConfirmation && assetToDelete != nullptr) {
        ImGui::OpenPopup("Delete Asset?");
        showDeleteConfirmation = false;
    }

    if (ImGui::BeginPopupModal("Delete Asset?", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
        ImGui::Text("Are you sure you want to delete:");
        ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.0f, 1.0f), "%s", assetToDelete->name.c_str());
        ImGui::Separator();

        if (assetToDelete->isDirectory) {
            ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "This will delete the entire folder and all its contents!");
        }
        else {
            ImGui::Text("This will also delete the corresponding Library file(s).");
        }

        ImGui::Separator();
        if (ImGui::Button("Delete", ImVec2(120, 0))) {
            if (DeleteAsset(assetToDelete)) {
                LOG_CONSOLE("Deleted: %s", assetToDelete->name.c_str());
                assetToDelete = nullptr;
                RefreshAssets();
            }
            ImGui::CloseCurrentPopup();
        }
        ImGui::SameLine();
        if (ImGui::Button("Cancel", ImVec2(120, 0))) {
            assetToDelete = nullptr;
            ImGui::CloseCurrentPopup();
        }
        ImGui::EndPopup();
    }

    if (ImGui::Begin(name.c_str(), &isOpen))
    {
        ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(4, 4));

        if (ImGui::Button("Refresh")) RefreshAssets();
        
        ImGui::SameLine();
        ImGui::Checkbox("3D Previews", &show3DPreviews);

        ImGui::SameLine();
        ImGui::SetNextItemWidth(100.0f);
        ImGui::SliderFloat("Icon Size", &iconSize, 32.0f, 128.0f, "%.0f");

        ImGui::PopStyleVar();
        ImGui::Separator();

        ImGui::Text("Path: ");
        ImGui::SameLine();

        if (relativePathDirty) {
            UpdateBreadcrumbs();
            relativePathDirty = false;
        }

        for (size_t i = 0; i < breadcrumbTrail.size(); i++)
        {
            AssetNode* crumb = breadcrumbTrail[i];

            ImGui::PushID(crumb);

            if (ImGui::SmallButton(crumb->name.c_str())) {
                currentNode = crumb;
                currentPath = crumb->path;
                relativePathDirty = true;
            }
            ImGui::PopID();

            if (i < breadcrumbTrail.size() - 1) {
                ImGui::SameLine();
                ImGui::Text("/");
                ImGui::SameLine();
            }
        }

        ImGui::Separator();

        // COLUMNAS
        ImGui::BeginChild("FolderTree", ImVec2(200, 0), true);
        if (rootNode) DrawFolderTreeRecursive(rootNode);
        ImGui::EndChild();

        ImGui::SameLine();

        ImGui::BeginChild("AssetsList", ImVec2(0, 0), true);
        DrawAssetsList();
        ImGui::EndChild();

        HandleInternalDragDrop();
        ShowMaterialNamingModal();
        ShowPrefabNamingModal();
        ShowScriptNamingModal();
        ShowFolderNamingModal();
    }

    if (importSettingsWindow) importSettingsWindow->Draw();
    ImGui::End();
}

void AssetsWindow::DrawFolderTreeRecursive(AssetNode* node)
{
    if (!node->isDirectory) return;

    ImGuiTreeNodeFlags flags = ImGuiTreeNodeFlags_OpenOnArrow | ImGuiTreeNodeFlags_OpenOnDoubleClick;
    if (node == currentNode) flags |= ImGuiTreeNodeFlags_Selected;

    bool hasSubfolders = false;
    for (AssetNode* child : node->children) {
        if (child->isDirectory) { hasSubfolders = true; break; }
    }

    if (!hasSubfolders) flags |= ImGuiTreeNodeFlags_Leaf | ImGuiTreeNodeFlags_NoTreePushOnOpen;

    ImGui::PushID(node->path.c_str());
    bool nodeOpen = ImGui::TreeNodeEx(node->name.c_str(), flags);

    if (ImGui::IsItemClicked()) {
        currentNode = node;
        currentPath = node->path;
        relativePathDirty = true;
    }

    if (nodeOpen) {
        if (hasSubfolders) {
            for (AssetNode* child : node->children) {
                if (child->isDirectory) DrawFolderTreeRecursive(child);
            }

            ImGui::TreePop();
        }
    }
    ImGui::PopID();
}

void AssetsWindow::DrawAssetsList()
{
    if (!currentNode) return;

    ImVec2 startPos = ImGui::GetCursorScreenPos();

    if (currentNode != rootNode)
    {
        if (ImGui::Button("<- Back") && currentNode->parent) {
            currentNode = currentNode->parent;
            currentPath = currentNode->path;
            relativePathDirty = true;
        }
        ImGui::Separator();
    }

    float windowWidth = ImGui::GetContentRegionAvail().x;
    int columns = (int)(windowWidth / (iconSize + 10.0f));
    if (columns < 1) columns = 1;

    int currentColumn = 0;

    // === EL CAMBIO CLAVE ===
    // En lugar de un string vacío, usamos un puntero nulo
    AssetNode* nodePendingToLoad = nullptr;

    for (AssetNode* asset : currentNode->children)
    {
        // === OPCIÓN A: ACTUALIZACIÓN DINÁMICA EN TIEMPO REAL ===
        if (!asset->isDirectory && asset->uid != 0 && Application::GetInstance().resources)
        {
            ModuleResources* resources = Application::GetInstance().resources.get();

            if (asset->isFBX)
            {
                int totalRefs = 0;
                bool anyLoaded = false;
                for (int i = 0; i < 100; i++) {
                    unsigned long long meshUID = asset->uid + i;
                    if (resources->IsResourceLoaded(meshUID)) {
                        anyLoaded = true;
                        totalRefs += resources->GetResourceReferenceCount(meshUID);
                    }
                }
                asset->inMemory = anyLoaded;
                asset->references = totalRefs;
            }
            else
            {
                asset->inMemory = resources->IsResourceLoaded(asset->uid);
                asset->references = resources->GetResourceReferenceCount(asset->uid);
            }
        }
        // =======================================================

        if (!asset->isDirectory && !asset->previewLoaded && show3DPreviews) {
            LoadPreviewForAsset(asset);
        }

        if (asset->isFBX) {
            // Pasamos el PUNTERO por referencia
            DrawExpandableAssetItem(asset, nodePendingToLoad);
        }
        else {

            DrawAssetItem(asset, nodePendingToLoad);
        }

        currentColumn++;
        if (currentColumn < columns) {
            ImGui::SameLine();
        }
        else {
            currentColumn = 0;
        }
    }

    if (nodePendingToLoad != nullptr) {
        currentNode = nodePendingToLoad;
        currentPath = nodePendingToLoad->path;
        relativePathDirty = true;
    }

    if (ImGui::BeginPopupContextWindow("AssetsContextMenu", ImGuiPopupFlags_MouseButtonRight | ImGuiPopupFlags_NoOpenOverItems))
    {
        if (ImGui::BeginMenu("Create")) {
            if (ImGui::MenuItem("Folder")) folderNamingOpened = true;
            if (ImGui::MenuItem("Material")) materialNamingOpened = true;
            if (ImGui::MenuItem("Script")) scriptNamingOpened = true;
            ImGui::EndMenu();
        }
        ImGui::EndPopup();
    }
}

void AssetsWindow::DrawAssetItem(AssetNode* asset, AssetNode*& nodePendingToLoad)
{
    ImGui::PushID(asset->path.c_str());
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
    if (!asset->isDirectory && ImGui::BeginDragDropSource(ImGuiDragDropFlags_None))
    {
        static DragDropPayload payload;
        payload.assetPath = asset->path;
        payload.assetUID = asset->uid;

        if (asset->extension == ".png" || asset->extension == ".jpg" ||
            asset->extension == ".jpeg" || asset->extension == ".dds" || asset->extension == ".tga") {
            payload.assetType = DragDropAssetType::TEXTURE;
            ImGui::Text("Texture: %s", asset->name.c_str());
        }
        else if (asset->extension == ".mesh") {
            payload.assetType = DragDropAssetType::MESH;
            ImGui::Text("Mesh: %s", asset->name.c_str());
        }
        else if (asset->extension == ".lua") {
            payload.assetType = DragDropAssetType::SCRIPT;
            ImGui::Text("Script: %s", asset->name.c_str());
        }
        else if (asset->extension == ".prefab") {
            payload.assetType = DragDropAssetType::PREFAB;
            ImGui::Text("Prefab: %s", asset->name.c_str());
        }
        else if (asset->extension == ".mat") {
            payload.assetType = DragDropAssetType::MATERIAL;
            ImGui::Text("Material: %s", asset->name.c_str());
        }
        else if (asset->extension == ".scene") {
            payload.assetType = DragDropAssetType::SCENE;
            ImGui::Text("Scene: %s", asset->name.c_str());
        }
        else {
            payload.assetType = DragDropAssetType::UNKNOWN;
            ImGui::Text("Drag: %s", asset->name.c_str());
        }

        ImGui::SetDragDropPayload("ASSET_ITEM", &payload, sizeof(DragDropPayload));
        ImGui::EndDragDropSource();
    }

    if (clicked) {
        if (asset->isDirectory) nodePendingToLoad = asset;
        else selectedAsset = asset;
    }

    if (isButtonHovered && ImGui::IsMouseDoubleClicked(0)) {
        if (asset->isDirectory) {
            nodePendingToLoad = asset;
        }
        else if (asset->extension == ".lua") {
            if (Application::GetInstance().editor.get()->GetScriptEditor()) {
                Application::GetInstance().editor.get()->GetScriptEditor()->SetOpen(true);
                Application::GetInstance().editor.get()->GetScriptEditor()->OpenScript(asset->path);
            }
        }
        else if (asset->extension == ".mat") {
            if (Application::GetInstance().editor.get()->GetMaterialEditor()) {
                Application::GetInstance().editor.get()->GetMaterialEditor()->SetOpen(true);
                Application::GetInstance().editor.get()->GetMaterialEditor()->SetMaterialToEdit(asset->uid);
            }
        }
        else if (asset->extension == ".scene") {
            Application::GetInstance().loader->LoadScene(asset->path);
        }
    }

    const std::string& displayName = isButtonHovered ? asset->name : asset->cachedDisplayName;
    ImGui::PushTextWrapPos(ImGui::GetCursorPos().x + iconSize);
    ImGui::TextWrapped("%s", displayName.c_str());
    ImGui::PopTextWrapPos();

    if (asset->inMemory) {
        if (asset->isDirectory) ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Loaded: %d", asset->references);
        else ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Refs: %d", asset->references);
    }

    ImGui::EndGroup();

    // Context menu
    std::string popupID = "AssetContextMenu##" + asset->path;
    if (ImGui::BeginPopupContextItem(popupID.c_str()))
    {
        ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "%s", asset->name.c_str());
        ImGui::Separator();

        if (!asset->isDirectory && asset->extension == ".lua") {
            // ... (Tu código de Abrir script con VS Code, etc. se mantiene igual)
            ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "Open With:");
            // ... [Todo el bloque de scripts]
            ImGui::Separator();
        }

        if (!asset->isDirectory && (asset->extension == ".fbx" || asset->extension == ".png" || asset->extension == ".jpg" || asset->extension == ".dds")) {
            if (ImGui::MenuItem("Import Settings...")) {
                if (importSettingsWindow) importSettingsWindow->OpenForAsset(asset->path);
            }
            ImGui::Separator();
        }

        if (ImGui::MenuItem("Delete")) {
            assetToDelete = asset;
            showDeleteConfirmation = true;
        }

        if (!asset->isDirectory && asset->uid != 0) {
            ImGui::Separator();
            ImGui::Text("UID: %llu", asset->uid);
            if (asset->inMemory) ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Loaded in memory");
        }

        ImGui::EndPopup();
    }

    if (ImGui::IsItemHovered()) {
        ImGui::BeginTooltip();
        ImGui::Text("%s", asset->name.c_str());
        if (!asset->isDirectory && asset->uid != 0) ImGui::Text("UID: %llu", asset->uid);
        if (asset->extension == ".prefab") {
            ImGui::Separator();
            ImGui::TextColored(ImVec4(0.5f, 0.8f, 1.0f, 1.0f), "Double-click to instantiate");
        }
        ImGui::EndTooltip();
    }

    ImGui::PopID();
}

void AssetsWindow::DrawExpandableAssetItem(AssetNode* asset, AssetNode*& nodePendingToLoad)
{
    ImGui::PushID(asset->path.c_str());
    ImGui::BeginGroup();

    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
    const char* arrowIcon = asset->isExpanded ? "v " : "> ";

    if (ImGui::SmallButton(arrowIcon)) {
        asset->isExpanded = !asset->isExpanded;
        if (asset->isExpanded && asset->subResources.empty()) {
            LoadFBXSubresources(asset);
        }
    }
    ImGui::PopStyleColor();

    ImGui::SameLine();

    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.3f, 0.3f, 0.3f, 0.3f));
    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.4f, 0.4f, 0.4f, 0.4f));

    bool clicked = ImGui::Button("##icon", ImVec2(iconSize, iconSize));
    ImGui::PopStyleColor(3);

    ImVec2 buttonPos = ImGui::GetItemRectMin();
    DrawIconShape(asset, buttonPos, ImVec2(iconSize, iconSize));

    bool isButtonHovered = ImGui::IsItemHovered();

    if (ImGui::BeginDragDropSource(ImGuiDragDropFlags_None)) {
        static DragDropPayload payload;
        payload.assetPath = asset->path;
        payload.assetUID = asset->uid;
        payload.assetType = DragDropAssetType::FBX_MODEL;
        ImGui::SetDragDropPayload("ASSET_ITEM", &payload, sizeof(DragDropPayload));
        ImGui::Text("FBX: %s", asset->name.c_str());
        ImGui::EndDragDropSource();
    }

    if (clicked) selectedAsset = asset;

    const std::string& displayName = isButtonHovered ? asset->name : asset->cachedDisplayName;
    ImGui::PushTextWrapPos(ImGui::GetCursorPos().x + iconSize);
    ImGui::TextWrapped("%s", displayName.c_str());
    ImGui::PopTextWrapPos();

    if (asset->inMemory) {
        ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "Refs: %d", asset->references);
    }

    ImGui::EndGroup();

    if (asset->isExpanded && !asset->subResources.empty()) {
        float smallIconSize = iconSize * 0.7f;
        float itemWidth = smallIconSize + 15.0f;

        ImGui::Dummy(ImVec2(0, 0));
        float startX = ImGui::GetCursorPosX() + 30.0f;
        ImGui::SetCursorPosX(startX);
        ImGui::TextDisabled(">");

        float windowContentWidth = ImGui::GetContentRegionAvail().x;
        float currentX = startX;

        for (size_t i = 0; i < asset->subResources.size(); ++i) {
            AssetNode* subMesh = asset->subResources[i];

            // === OPCIÓN A: ACTUALIZACIÓN DINÁMICA DE LAS SUB-MALLAS ===
            if (subMesh->uid != 0 && Application::GetInstance().resources) {
                ModuleResources* resources = Application::GetInstance().resources.get();
                subMesh->inMemory = resources->IsResourceLoaded(subMesh->uid);
                subMesh->references = resources->GetResourceReferenceCount(subMesh->uid);
            }
            // ==========================================================

            if (!subMesh->previewLoaded && show3DPreviews) LoadPreviewForAsset(subMesh);

            if (i > 0) {
                if (startX + windowContentWidth - currentX < itemWidth) {
                    ImGui::NewLine();
                    ImGui::SetCursorPosX(startX);
                    currentX = startX;
                }
                else {
                    ImGui::SameLine();
                }
            }
            else {
                ImGui::SameLine();
            }

            currentX = ImGui::GetCursorPosX();

            ImGui::PushID(subMesh->path.c_str());
            ImGui::BeginGroup();

            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0, 0, 0, 0));
            bool meshClicked = ImGui::Button("##meshicon", ImVec2(smallIconSize, smallIconSize));
            ImGui::PopStyleColor();

            ImVec2 meshButtonPos = ImGui::GetItemRectMin();
            DrawIconShape(subMesh, meshButtonPos, ImVec2(smallIconSize, smallIconSize));

            if (ImGui::BeginDragDropSource(ImGuiDragDropFlags_None)) {
                static DragDropPayload payload;
                payload.assetPath = subMesh->path;
                payload.assetUID = subMesh->uid;
                payload.assetType = DragDropAssetType::MESH;
                ImGui::SetDragDropPayload("ASSET_ITEM", &payload, sizeof(DragDropPayload));
                ImGui::Text("Mesh: %s", subMesh->name.c_str());
                ImGui::EndDragDropSource();
            }

            if (meshClicked) selectedAsset = subMesh;

            ImGui::PushTextWrapPos(ImGui::GetCursorPos().x + smallIconSize);
            ImGui::TextWrapped("%s", subMesh->cachedDisplayName.c_str());
            ImGui::PopTextWrapPos();

            if (subMesh->inMemory) {
                ImGui::TextColored(ImVec4(0.3f, 1.0f, 0.3f, 1.0f), "R:%d", subMesh->references);
            }

            ImGui::EndGroup();
            currentX += itemWidth;
            ImGui::PopID();
        }
    }

    ImGui::PopID();
}



void AssetsWindow::UpdateBreadcrumbs()
{
    breadcrumbTrail.clear();

    AssetNode* n = currentNode;
    while (n != nullptr) {
        breadcrumbTrail.push_back(n);
        n = n->parent;
    }

    std::reverse(breadcrumbTrail.begin(), breadcrumbTrail.end());
}

void AssetsWindow::LoadFBXSubresources(AssetNode* fbxAsset)
{
    // Limpiamos los subrecursos anteriores (y liberamos su RAM)
    for (auto* sub : fbxAsset->subResources) {
        UnloadPreviewForAsset(sub);
        delete sub;
    }
    fbxAsset->subResources.clear();
    std::string metaPath = fbxAsset->path + ".meta";
    if (!fs::exists(metaPath)) return;

    MetaFile meta = MetaFile::Load(metaPath);
    if (meta.uid == 0) return;

    ModuleResources* resources = Application::GetInstance().resources.get();
    if (!resources) return;
    const auto& allResources = resources->GetAllResources();

    for (const auto& [meshName, meshUID] : meta.meshes)
    {
        std::string libPath = LibraryManager::GetLibraryPath(meshUID);
        if (!LibraryManager::FileExists(libPath)) continue;

        AssetNode* meshEntry = new AssetNode();
        meshEntry->name = meshName;
        meshEntry->path = libPath;
        meshEntry->extension = ".mesh";
        meshEntry->isDirectory = false;
        meshEntry->isFBX = false;
        meshEntry->uid = meshUID;
        meshEntry->parent = fbxAsset; // El padre es el FBX

        auto it = allResources.find(meshUID);
        if (it != allResources.end()) {
            meshEntry->inMemory = it->second->IsLoadedToMemory();
            meshEntry->references = it->second->GetReferenceCount();
        }
        meshEntry->cachedDisplayName = TruncateFileName(meshEntry->name, iconSize * 0.7f);
        fbxAsset->subResources.push_back(meshEntry);
    }

    //anims
    for (const auto& [animName, animUID] : meta.animations)
    {
        std::string libPath = LibraryManager::GetLibraryPath(animUID);
        if (!LibraryManager::FileExists(libPath))
            continue;
        AssetNode* animEntry = new AssetNode();
        animEntry->name = animName;
        animEntry->path = libPath;
        animEntry->extension = ".anim";
        animEntry->isDirectory = false;
        animEntry->isFBX = false;
        animEntry->uid = animUID;

        auto it = allResources.find(animUID);
        if (it != allResources.end()) {
            animEntry->inMemory = it->second->IsLoadedToMemory();
            animEntry->references = it->second->GetReferenceCount();
        }
        animEntry->cachedDisplayName = TruncateFileName(animEntry->name, iconSize * 0.7f);
        fbxAsset->subResources.push_back(animEntry);
    }

    LOG_DEBUG("[AssetsWindow] FBX Subresources loaded: %d items", (int)fbxAsset->subResources.size());
}



// === DRAW ICONS Y PREVIEWS (Idénticos a tu V1, adaptados al puntero) ===

void AssetsWindow::DrawIconShape(const AssetNode* asset, const ImVec2& pos, const ImVec2& size)
{
    ImDrawList* drawList = ImGui::GetWindowDrawList();

    if (show3DPreviews && asset->previewTextureID != 0)
    {
        ImVec2 topLeft = pos;
        ImVec2 bottomRight = ImVec2(pos.x + size.x, pos.y + size.y);
        ImTextureID texID = (ImTextureID)(uintptr_t)asset->previewTextureID;
        drawList->AddImage(texID, topLeft, bottomRight, ImVec2(0, 1), ImVec2(1, 0));

        ImU32 borderColor = asset->inMemory ?
            ImGui::ColorConvertFloat4ToU32(ImVec4(0.3f, 0.8f, 0.3f, 1.0f)) :
            ImGui::ColorConvertFloat4ToU32(ImVec4(0.5f, 0.5f, 0.5f, 1.0f));

        drawList->AddRect(topLeft, bottomRight, borderColor, 3.0f, 0, 2.0f);
        return;
    }

    ImVec4 buttonColor;
    if (asset->isDirectory) {
        buttonColor = asset->inMemory ? ImVec4(0.3f, 0.8f, 0.3f, 1.0f) : ImVec4(0.8f, 0.7f, 0.3f, 1.0f);
    }
    else {
        buttonColor = asset->inMemory ? ImVec4(0.3f, 0.8f, 0.3f, 1.0f) : ImVec4(0.5f, 0.5f, 0.5f, 1.0f);
    }

    ImU32 color = ImGui::ColorConvertFloat4ToU32(buttonColor);
    ImU32 outlineColor = ImGui::ColorConvertFloat4ToU32(ImVec4(0.2f, 0.2f, 0.2f, 1.0f));

    ImVec2 center = ImVec2(pos.x + size.x * 0.5f, pos.y + size.y * 0.5f);
    float padding = size.x * 0.15f;

    if (asset->isDirectory)
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
    else if (asset->extension == ".fbx" || asset->extension == ".obj")
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
    else if (asset->extension == ".png" || asset->extension == ".jpg" || asset->extension == ".dds")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);
        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);
    }
    else if (asset->extension == ".wav" || asset->extension == ".ogg" || asset->extension == ".mp3")
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
    else if (asset->extension == ".lua")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        ImVec2 cornerSize(w * 0.2f, h * 0.2f);
        drawList->AddTriangleFilled(
            ImVec2(bottomRight.x - cornerSize.x, topLeft.y),
            ImVec2(bottomRight.x, topLeft.y),
            ImVec2(bottomRight.x, topLeft.y + cornerSize.y),
            ImGui::ColorConvertFloat4ToU32(ImVec4(buttonColor.x * 0.6f, buttonColor.y * 0.6f, buttonColor.z * 0.6f, 1.0f))
        );

        ImVec2 textPos(center.x - w * 0.15f, center.y - h * 0.1f);
        drawList->AddText(textPos, ImGui::ColorConvertFloat4ToU32(ImVec4(0.2f, 0.2f, 0.8f, 1.0f)), "Lua");
    }
    else if (asset->extension == ".prefab")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        ImU32 prefabColor = ImGui::ColorConvertFloat4ToU32(ImVec4(0.3f, 0.5f, 0.8f, 1.0f));
        drawList->AddRectFilled(topLeft, bottomRight, prefabColor, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        float cubeSize = w * 0.3f;
        ImVec2 cubeCenter(center.x, center.y);
        ImU32 cubeColor = ImGui::ColorConvertFloat4ToU32(ImVec4(0.9f, 0.9f, 0.9f, 1.0f));

        ImVec2 c1(cubeCenter.x - cubeSize * 0.3f, cubeCenter.y);
        ImVec2 c2(cubeCenter.x + cubeSize * 0.3f, cubeCenter.y);
        ImVec2 c3(cubeCenter.x, cubeCenter.y - cubeSize * 0.5f);
        ImVec2 c4(cubeCenter.x, cubeCenter.y + cubeSize * 0.5f);

        drawList->AddTriangleFilled(c1, c2, c3, cubeColor);
        drawList->AddTriangleFilled(c1, c2, c4, ImGui::ColorConvertFloat4ToU32(ImVec4(0.6f, 0.6f, 0.6f, 1.0f)));
    }
    // === NUEVOS ICONOS: MATERIAL Y ESCENA ===
    else if (asset->extension == ".mat")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        // Esfera de material
        drawList->AddCircleFilled(center, w * 0.35f, ImGui::ColorConvertFloat4ToU32(ImVec4(0.8f, 0.3f, 0.3f, 1.0f)));
        drawList->AddCircleFilled(ImVec2(center.x - w * 0.1f, center.y - w * 0.1f), w * 0.08f, ImGui::ColorConvertFloat4ToU32(ImVec4(1.0f, 1.0f, 1.0f, 0.6f)));
    }
    else if (asset->extension == ".scene")
    {
        float w = size.x - padding * 2;
        float h = size.y - padding * 2;
        ImVec2 topLeft(pos.x + padding, pos.y + padding);
        ImVec2 bottomRight(pos.x + size.x - padding, pos.y + size.y - padding);

        drawList->AddRectFilled(topLeft, bottomRight, color, 3.0f);
        drawList->AddRect(topLeft, bottomRight, outlineColor, 3.0f, 0, 2.0f);

        // Claqueta de Cine
        ImVec2 clapTopLeft = topLeft;
        ImVec2 clapBottomRight = ImVec2(bottomRight.x, topLeft.y + h * 0.25f);

        drawList->AddRectFilled(clapTopLeft, clapBottomRight, ImGui::ColorConvertFloat4ToU32(ImVec4(0.15f, 0.15f, 0.15f, 1.0f)), 3.0f, ImDrawFlags_RoundCornersTop);
        drawList->AddLine(ImVec2(topLeft.x + w * 0.2f, topLeft.y), ImVec2(topLeft.x + w * 0.4f, topLeft.y + h * 0.25f), ImGui::ColorConvertFloat4ToU32(ImVec4(0.9f, 0.9f, 0.9f, 1.0f)), 2.0f);
        drawList->AddLine(ImVec2(topLeft.x + w * 0.6f, topLeft.y), ImVec2(topLeft.x + w * 0.8f, topLeft.y + h * 0.25f), ImGui::ColorConvertFloat4ToU32(ImVec4(0.9f, 0.9f, 0.9f, 1.0f)), 2.0f);
    }
    // ========================================
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

void AssetsWindow::CompilePreviewShader()
{
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

    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSrc, nullptr);
    glCompileShader(vertexShader);

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSrc, nullptr);
    glCompileShader(fragmentShader);

    previewShaderProgram = glCreateProgram();
    glAttachShader(previewShaderProgram, vertexShader);
    glAttachShader(previewShaderProgram, fragmentShader);
    glLinkProgram(previewShaderProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
}

void AssetsWindow::LoadPreviewForAsset(AssetNode* asset)
{
    if (asset->previewLoaded) return;
    asset->previewLoaded = true;

    if (asset->extension == ".png" || asset->extension == ".jpg" || asset->extension == ".tga") {
        int width, height, channels;
        stbi_set_flip_vertically_on_load(true);

        unsigned char* data = stbi_load(asset->path.c_str(), &width, &height, &channels, 4);

        if (data) {
            GLuint textureID;
            glGenTextures(1, &textureID);
            glBindTexture(GL_TEXTURE_2D, textureID);

            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
            stbi_image_free(data);

            glPixelStorei(GL_UNPACK_ALIGNMENT, 4);

            asset->previewTextureID = textureID;
        }
        else
        {
            LOG_CONSOLE("[AssetsWindow] Error cargando imagen: %s", stbi_failure_reason());
        }
    }
    else if (asset->extension == ".mesh" && show3DPreviews && asset->uid != 0) {
        if (Application::GetInstance().resources) {
            ResourceMesh* meshResource = dynamic_cast<ResourceMesh*>(Application::GetInstance().resources->RequestResource(asset->uid));
            if (meshResource && meshResource->IsLoadedToMemory()) {
                int size = static_cast<int>(iconSize * 2);
                asset->previewTextureID = RenderMeshToTexture(meshResource->GetMesh(), size, size);
                Application::GetInstance().resources->ReleaseResource(asset->uid);
            }
        }
    }
    else if (asset->extension == ".fbx" && show3DPreviews && asset->uid != 0) {
        if (Application::GetInstance().resources) {
            std::vector<const Mesh*> meshes;
            for (int i = 0; i < 100; i++) {
                unsigned long long meshUID = asset->uid + i;
                if (!LibraryManager::FileExists(LibraryManager::GetLibraryPath(meshUID))) break;

                ResourceMesh* meshResource = dynamic_cast<ResourceMesh*>(Application::GetInstance().resources->RequestResource(meshUID));
                if (meshResource && meshResource->IsLoadedToMemory()) {
                    meshes.push_back(&meshResource->GetMesh());
                }
            }
            if (!meshes.empty()) {
                int size = static_cast<int>(iconSize * 2);
                asset->previewTextureID = RenderMultipleMeshesToTexture(meshes, size, size);
                for (int i = 0; i < static_cast<int>(meshes.size()); i++) {
                    Application::GetInstance().resources->ReleaseResource(asset->uid + i);
                }
            }
        }
    }
}

void AssetsWindow::UnloadPreviewForAsset(AssetNode* asset)
{
    if (asset->previewTextureID != 0 && asset->extension != ".dds") {
        glDeleteTextures(1, &asset->previewTextureID);
        asset->previewTextureID = 0;
    }
    asset->previewLoaded = false;
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



bool AssetsWindow::DeleteAsset(AssetNode* asset)
{
    try {
        if (asset->isDirectory)
        {
            return DeleteDirectory(fs::path(asset->path));
        }
        else
        {
            std::string metaPath = asset->path + ".meta";
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
            if (fs::exists(asset->path)) {
                fs::remove(asset->path);
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
    if (extension == ".particle") return "[PTC]";
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
        extension == ".particle" ||
        extension == ".scene";
}

unsigned int AssetsWindow::RenderMeshToTexture(const Mesh& mesh, int width, int height)
{
    GLint oldFBO, oldViewport[4];
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFBO);
    glGetIntegerv(GL_VIEWPORT, oldViewport);

    GLuint fbo, colorTexture, depthRBO;

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);


    glGenTextures(1, &colorTexture);
    glBindTexture(GL_TEXTURE_2D, colorTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTexture, 0);

    glGenRenderbuffers(1, &depthRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRBO);

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

    float distance = maxDim * 2.2f;
    glm::vec3 cameraPos = center + glm::vec3(distance * 0.6f, distance * 0.4f, distance * 0.6f);

    glm::mat4 view = glm::lookAt(cameraPos, center, glm::vec3(0, 1, 0));
    glm::mat4 projection = glm::perspective(glm::radians(45.0f), 1.0f, 0.1f, distance * 10.0f);
    glm::mat4 model = glm::mat4(1.0f);
    glm::mat4 mvp = projection * view * model;

    glUseProgram(previewShaderProgram);

    GLint mvpLoc = glGetUniformLocation(previewShaderProgram, "mvp");
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

    GLint oldFBO, oldViewport[4];
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &oldFBO);
    glGetIntegerv(GL_VIEWPORT, oldViewport);

    GLuint fbo, colorTexture, depthRBO;

    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    glGenTextures(1, &colorTexture);
    glBindTexture(GL_TEXTURE_2D, colorTexture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, colorTexture, 0);

    glGenRenderbuffers(1, &depthRBO);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRBO);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRBO);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        LOG_DEBUG("[RenderMultipleMeshesToTexture] ERROR: Framebuffer incomplete");
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

    float distance = maxDim * 2.2f;
    glm::vec3 cameraPos = center + glm::vec3(distance * 0.6f, distance * 0.4f, distance * 0.6f);

    glm::mat4 view = glm::lookAt(cameraPos, center, glm::vec3(0, 1, 0));
    glm::mat4 projection = glm::perspective(glm::radians(45.0f), 1.0f, 0.1f, distance * 10.0f);
    glm::mat4 model = glm::mat4(1.0f);
    glm::mat4 mvp = projection * view * model;

    glUseProgram(previewShaderProgram);

    GLint mvpLoc = glGetUniformLocation(previewShaderProgram, "mvp");
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

void AssetsWindow::ShowScriptNamingModal()
{
    if (scriptNamingOpened) ImGui::OpenPopup("Create New Script");

    if (ImGui::BeginPopupModal("Create New Script", NULL, ImGuiWindowFlags_AlwaysAutoResize))
    {
        static char scriptName[128] = "NewScript";

        if (ImGui::IsWindowAppearing())
        {
            scriptNamingOpened = true;
        }

        if (scriptNamingOpened)
        {
            ImGui::SetKeyboardFocusHere();
            scriptNamingOpened = false;
        }

        ImGui::Text("Enter script name:");
        ImGui::InputText("##scriptname", scriptName, 128);
        ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), ".lua extension will be added");

        ImGui::Spacing();
        if (ImGui::Button("Create", ImVec2(120, 0))) {
            
            UID newScriptUID = ScriptImporter::CreateNewScript(currentPath, scriptName);

            if (newScriptUID != 0)
            {
                RefreshAssets();

                std::string filename = scriptName;
                if (filename.find(".lua") == std::string::npos) filename += ".lua";
                std::string finalPath = currentPath + "/" + filename;

                if (Application::GetInstance().editor.get()->GetScriptEditor())
                {
                    Application::GetInstance().editor.get()->GetScriptEditor()->SetOpen(true);
                    Application::GetInstance().editor.get()->GetScriptEditor()->OpenScript(finalPath);
                }
            }

            ImGui::CloseCurrentPopup();
            strcpy(scriptName, "NewScript");
        }

        ImGui::SameLine();
        if (ImGui::Button("Cancel", ImVec2(120, 0))) {
            ImGui::CloseCurrentPopup();
        }
        ImGui::EndPopup();
    }
}

void AssetsWindow::ShowFolderNamingModal()
{
    if (folderNamingOpened) ImGui::OpenPopup("Create New Folder");

    if (ImGui::BeginPopupModal("Create New Folder", NULL, ImGuiWindowFlags_AlwaysAutoResize))
    {
        static char folderName[128] = "NewFolder";

        if (ImGui::IsWindowAppearing())
        {
            folderNamingOpened = true;
        }

        if (folderNamingOpened)
        {
            ImGui::SetKeyboardFocusHere();
            folderNamingOpened = false;
        }

        ImGui::Text("Enter folder name:");
        ImGui::InputText("##foldername", folderName, 128);

        ImGui::Spacing();
        if (ImGui::Button("Create", ImVec2(120, 0))) {
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