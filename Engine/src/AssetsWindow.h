#pragma once

#include "EventListener.h"
#include "EditorWindow.h"
#include <string>
#include <vector>
#include <filesystem>
#include <unordered_set>
#include <imgui.h>
#include "MetaFile.h"
#include "GameObject.h"

class MetaFile;
namespace fs = std::filesystem;

struct Mesh;
class ImportSettingsWindow;

// EL NUEVO NODO DEL ÁRBOL EN MEMORIA
struct AssetNode
{
    std::string name;
    std::string path;
    std::string extension;
    bool isDirectory;
    bool inMemory;
    unsigned int references;
    unsigned long long uid;

    // Jerarquía
    AssetNode* parent = nullptr;
    std::vector<AssetNode*> children;

    // Para FBX expandibles
    bool isFBX;
    bool isExpanded;
    std::vector<AssetNode*> subResources;

    // Preview/thumbnail
    unsigned int previewTextureID = 0;
    bool previewLoaded = false;
    std::string cachedDisplayName;
};

// Tipos de assets para drag & drop
enum class DragDropAssetType
{
    UNKNOWN = 0,
    FBX_MODEL,
    MESH,
    TEXTURE,
    SCRIPT,
    PREFAB,
    ANIMATION,
    MATERIAL,
    SCENE
};

struct DragDropPayload
{
    std::string assetPath;
    UID assetUID;
    DragDropAssetType assetType;
};

class AssetsWindow : public EditorWindow, public EventListener
{
public:
    AssetsWindow();
    ~AssetsWindow();

    void Draw() override;

private:
    void RefreshAssets();
    void BuildTreeRecursive(AssetNode* parentNode);
    void FreeTree(AssetNode* node);
    AssetNode* FindNodeByPath(AssetNode* node, const std::string& path);

    void DrawFolderTreeRecursive(AssetNode* node);
    void DrawAssetsList();
    void DrawAssetItem(AssetNode* asset, AssetNode*& nodePendingToLoad);
    void DrawExpandableAssetItem(AssetNode* asset, AssetNode*& nodePendingToLoad);
    void DrawIconShape(const AssetNode* entry, const ImVec2& pos, const ImVec2& size);

    const char* GetAssetIcon(const std::string& extension) const;
    bool IsAssetFile(const std::string& extension) const;
    std::string TruncateFileName(const std::string& name, float maxWidth) const;

    bool DeleteAsset(AssetNode* asset);
    bool DeleteDirectory(const fs::path& dirPath);

    // Modals
    void ShowFolderNamingModal();
    void ShowPrefabNamingModal();
    void ShowMaterialNamingModal();
    void ShowScriptNamingModal();

    // Funciones para expandir FBX
    void LoadFBXSubresources(AssetNode* fbxAsset);

    // Preview/Thumbnail system
    void CompilePreviewShader();
    void LoadPreviewForAsset(AssetNode* asset);
    void UnloadPreviewForAsset(AssetNode* asset);
    unsigned int RenderMeshToTexture(const Mesh& mesh, int width, int height);
    unsigned int RenderMultipleMeshesToTexture(const std::vector<const Mesh*>& meshes, int width, int height);

    // Drag & Drop
    void HandleInternalDragDrop();
    void HandleExternalDragDrop(const std::string& filePath);
    bool ProcessDroppedFile(const std::string& sourceFilePath);
    bool CopyFileToAssets(const std::string& sourceFilePath, std::string& outDestPath);

    void OnEvent(const Event& event) override;

    // Variables de estado
    std::string assetsRootPath;
    std::string currentPath;

    // NAVEGACIÓN EN MEMORIA
    AssetNode* rootNode = nullptr;
    AssetNode* currentNode = nullptr;

    AssetNode* selectedAsset = nullptr;
    float iconSize;
    bool show3DPreviews;
    bool showDeleteConfirmation;
    AssetNode* assetToDelete = nullptr;

    ImportSettingsWindow* importSettingsWindow;

    bool materialNamingOpened = false;
    bool prefabNamingOpened = false;
    bool scriptNamingOpened = false;
    bool folderNamingOpened = false;

    fs::path cachedRelativePath;
    bool relativePathDirty = true;

    unsigned int previewShaderProgram;

    std::vector<AssetNode*> breadcrumbTrail;
    void UpdateBreadcrumbs();
};