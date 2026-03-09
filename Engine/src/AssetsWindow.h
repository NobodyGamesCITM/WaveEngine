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
class ScriptEditorWindow;  // Forward declaration
namespace fs = std::filesystem;

// Forward declarations
//Test
struct Mesh;
class ImportSettingsWindow;

struct AssetEntry
{
    std::string name;
    std::string path;
    std::string extension;
    bool isDirectory;
    bool inMemory;
    unsigned int references;
    unsigned long long uid;

    // Para FBX expandibles
    bool isFBX;
    bool isExpanded;
    std::vector<AssetEntry> subResources;

    // Preview/thumbnail
    unsigned int previewTextureID = 0;
    bool previewLoaded = false;
};

// Tipos de assets para drag & drop
enum class DragDropAssetType
{
    UNKNOWN = 0,
    FBX_MODEL,      // FBX completo (todas las meshes)
    MESH,           // Mesh individual
    TEXTURE,        // Texture (PNG, JPG, DDS, etc)
    SCRIPT,         // Lua script
    PREFAB,
    ANIMATION,
    MATERIAL
};

// Payload para drag & drop interno
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
    void ScanDirectory(const fs::path& directory, std::vector<AssetEntry>& outAssets);

    void DrawFolderTree(const fs::path& path, const std::string& label);
    void DrawAssetsList();
    void DrawAssetItem(const AssetEntry& asset, std::string& pathPendingToLoad);
    void DrawIconShape(const AssetEntry& entry, const ImVec2& pos, const ImVec2& size);

    const char* GetAssetIcon(const std::string& extension) const;
    bool IsAssetFile(const std::string& extension) const;
    std::string TruncateFileName(const std::string& name, float maxWidth) const;

    bool DeleteAsset(const AssetEntry& asset);
    bool DeleteDirectory(const fs::path& dirPath);

    // Funciones para expandir FBX
    void LoadFBXSubresources(AssetEntry& fbxAsset);
    void DrawExpandableAssetItem(AssetEntry& asset, std::string& pathPendingToLoad);

    // Preview/Thumbnail system
    void LoadPreviewForAsset(AssetEntry& asset);
    void UnloadPreviewForAsset(AssetEntry& asset);
    unsigned int RenderMeshToTexture(const Mesh& mesh, int width, int height);
    unsigned int RenderMultipleMeshesToTexture(const std::vector<const Mesh*>& meshes, int width, int height);

    // Drag & Drop from external files
    void HandleExternalDragDrop(const std::string& filePath);
    bool ProcessDroppedFile(const std::string& sourceFilePath);
    bool CopyFileToAssets(const std::string& sourceFilePath, std::string& outDestPath);

    // Script management
    void CreateNewScript(const std::string& scriptName);
    std::string GetDefaultScriptTemplate();

    void HandlePrefabCreationDrop(const std::string& prefabName);
    bool CreatePrefabFromGameObject(GameObject* obj, const std::string& prefabPath);
    
    void OnEvent(const Event& event) override;

    std::string assetsRootPath;
    std::string currentPath;
    std::string sceneRootPath;
    std::vector<AssetEntry> currentAssets;

    AssetEntry* selectedAsset;
    float iconSize;
    bool showInMemoryOnly;
    bool show3DPreviews;

    bool showDeleteConfirmation;
    AssetEntry assetToDelete;

    std::unordered_set<std::string> expandedFBXPaths;

    ImportSettingsWindow* importSettingsWindow;

};