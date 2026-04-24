#include "SceneWindow.h"
#include <imgui.h>
#include <ImGuizmo.h>
#include <glm/gtc/type_ptr.hpp>

#define GLM_ENABLE_EXPERIMENTAL
#include <glm/gtx/matrix_decompose.hpp>

#include "Application.h"
#include "GameObject.h"
#include "Transform.h"
#include "SelectionManager.h"
#include "InspectorWindow.h"
#include "Input.h"
#include "AssetsWindow.h"
#include "ComponentMesh.h"
#include "ComponentMaterial.h"
#include "ModuleEditor.h"
#include "EditorCamera.h"
#include "CameraLens.h"
#include "Log.h"
#include "MetaFile.h"
#include "LibraryManager.h"
#include <glm/glm.hpp>
#include <filesystem>
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>
#include "TransformCommand.h"
#include "ModuleEditor.h"
#include "CreateCommand.h"
#include "FileSystem.h"

namespace fs = std::filesystem;

// Helper function (outside the class)
static aiNode* FindNodeWithMeshIndex(aiNode* node, int meshIndex)
{
    if (!node) return nullptr;
    // Check if this node has the mesh we're looking for
    for (unsigned int i = 0; i < node->mNumMeshes; i++) {
        if (static_cast<int>(node->mMeshes[i]) == meshIndex) {
            return node;
        }
    }
    // Search recursively in children
    for (unsigned int i = 0; i < node->mNumChildren; i++) {
        aiNode* found = FindNodeWithMeshIndex(node->mChildren[i], meshIndex);
        if (found) {
            return found;
        }
    }
    return nullptr;
}

SceneWindow::SceneWindow(InspectorWindow* inspector)
    : EditorWindow("Scene"), inspectorWindow(inspector)
{
}

void SceneWindow::Draw()
{
    isHovered = false;
    isFocused = false;
    
    if (!isOpen) return;

    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0, 0));
    ImGui::Begin(name.c_str(), &isOpen);

    isHovered = (ImGui::IsWindowHovered(ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows));
    isFocused = (ImGui::IsWindowFocused(ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows));

    sceneViewportPos = ImGui::GetCursorScreenPos();
    sceneViewportSize = ImGui::GetContentRegionAvail();
    
    CameraLens* camera = Application::GetInstance().editor->GetEditorCamera()->GetCameraLens();
    if (sceneViewportSize.x != camera->textureWidth || sceneViewportSize.y != camera->textureHeight)
    {
        camera->SetRenderTarget((int)sceneViewportSize.x, (int)sceneViewportSize.y);
        camera->SetPerspective(camera->GetFov(), sceneViewportSize.x / sceneViewportSize.y, camera->GetNearPlane(), camera->GetFarPlane());
    }
    
    unsigned int textureID = camera->textureID;

    if (textureID != 0 && sceneViewportSize.x > 0 && sceneViewportSize.y > 0)
    {
        ImTextureID texID = (ImTextureID)(uintptr_t)textureID;
        ImGui::Image(texID, sceneViewportSize, ImVec2(0, 1), ImVec2(1, 0));

        HandleAssetDropTarget();
    }
    else
    {
        ImGui::InvisibleButton("SceneView", sceneViewportSize);
    }

    if (Application::GetInstance().input->GetMouseButtonDown(1) == KEY_DOWN && Application::GetInstance().input->GetKey(SDL_SCANCODE_LALT) != KEY_REPEAT)
        SelectObject();


    ImGuizmo::BeginFrame();

    HandleGizmoInput();
    DrawGizmo();

    ImGui::End();
    ImGui::PopStyleVar();
}

void SceneWindow::SelectObject()
{
    bool hasSelection = Application::GetInstance().selectionManager->GetSelectedObject() != nullptr;

    if (hasSelection)
    {
        if (ImGuizmo::IsOver() || ImGuizmo::IsUsing()) return;
    }

    if (!isHovered) return;

    GameObject* objToSelect = GetGameObjectUnderMouse();

    bool shiftPressed = Application::GetInstance().input.get()->GetKey(SDL_SCANCODE_LSHIFT) || Application::GetInstance().input.get()->GetKey(SDL_SCANCODE_RSHIFT);

    if (objToSelect) {

        if (shiftPressed)
        {
            Application::GetInstance().selectionManager->ToggleSelection(objToSelect);
        }
        else
        {
            Application::GetInstance().selectionManager->SetSelectedObject(objToSelect);
        }

        LOG_CONSOLE("Selected: %s", objToSelect ? objToSelect->GetName().c_str() : "None");
    }
    else Application::GetInstance().selectionManager->ClearSelection();

}

void SceneWindow::HandleAssetDropTarget()
{
    if (ImGui::BeginDragDropTarget())
    {
        if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("ASSET_ITEM"))
        {
            DragDropPayload* dropData = (DragDropPayload*)payload->Data;

            LOG_CONSOLE("[DROP RECEIVED] Asset: %s, Type: %d, UID: %llu",
                dropData->assetPath.c_str(),
                (int)dropData->assetType,
                dropData->assetUID);

            switch (dropData->assetType)
            {
            case DragDropAssetType::FBX_MODEL:
            {
                GameObject* loadedModel = Application::GetInstance().loader->LoadModel(dropData->assetUID);
                if (loadedModel)
                {
                    Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                        std::make_unique<CreateCommand>(loadedModel)
                    );
                    LOG_CONSOLE("FBX model loaded successfully");
                }
                else
                {
                    LOG_CONSOLE("ERROR: Failed to load FBX model");
                }
                break;
            }

            case DragDropAssetType::MESH:
            {
                LOG_CONSOLE("Loading mesh...");
                GameObject* meshObject = new GameObject("Mesh");

                ComponentMesh* meshComp = static_cast<ComponentMesh*>(
                    meshObject->CreateComponent(ComponentType::MESH)
                    );

                if (meshComp && meshComp->LoadMeshByUID(dropData->assetUID))
                {
                    ApplyMeshTransformFromFBX(meshObject, dropData->assetUID);

                    GameObject* root = Application::GetInstance().scene->GetRoot();
                    root->AddChild(meshObject);
                    Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                        std::make_unique<CreateCommand>(meshObject)
                    );
                    LOG_CONSOLE("Mesh loaded successfully (UID: %llu)", dropData->assetUID);
                }
                else
                {
                    delete meshObject;
                    LOG_CONSOLE("ERROR: Failed to load mesh");
                }
                break;
            }
            case DragDropAssetType::TEXTURE:
            {
                LOG_CONSOLE("Applying texture...");

                std::vector<GameObject*> targetObjects;

                GameObject* objectUnderMouse = GetGameObjectUnderMouse();

                if (objectUnderMouse)
                {
                    targetObjects.push_back(objectUnderMouse);
                }
                else
                {
                    targetObjects = Application::GetInstance().selectionManager->GetSelectedObjects();
                }


                if (targetObjects.empty())
                {
                    LOG_CONSOLE("No object under mouse and no selection");
                    break;
                }

                int successCount = 0;
                for (GameObject* obj : targetObjects)
                {
                    if (Application::GetInstance().loader->LoadTextureToGameObject(obj, dropData->assetUID));
                        successCount++;
                }


                if (successCount > 0)
                {
                    LOG_CONSOLE("Texture applied to %d selected object(s)", successCount);
                }
                else
                {
                    LOG_CONSOLE("ERROR: Failed to apply texture");
                }
                break;
            }
            case DragDropAssetType::MATERIAL:
            {
                LOG_CONSOLE("Applying Material...");

                std::vector<GameObject*> targetObjects;

                GameObject* objectUnderMouse = GetGameObjectUnderMouse();

                if (objectUnderMouse)
                {
                    targetObjects.push_back(objectUnderMouse);
                }
                else
                {
                    targetObjects = Application::GetInstance().selectionManager->GetSelectedObjects();
                }


                if (targetObjects.empty())
                {
                    LOG_CONSOLE("No object under mouse and no selection");
                    break;
                }

                int successCount = 0;
                for (GameObject* obj : targetObjects)
                {
                    if (Application::GetInstance().loader->LoadMaterialToGameObject(obj, dropData->assetUID));
                        successCount++;
                }


                if (successCount > 0)
                {
                    LOG_CONSOLE("Material applied to %d selected object(s)", successCount);
                }
                else
                {
                    LOG_CONSOLE("ERROR: Failed to apply material");
                }
                break;
            }
            case DragDropAssetType::PREFAB:
            {
                GameObject* loadedModel = Application::GetInstance().loader->LoadPrefab(dropData->assetUID);
                if (loadedModel)
                {
                    Application::GetInstance().editor->GetCommandHistory()->ExecuteCommand(
                        std::make_unique<CreateCommand>(loadedModel)
                    );
                    LOG_CONSOLE("FBX model loaded successfully");
                }
                else
                {
                    LOG_CONSOLE("ERROR: Failed to load FBX model");
                }
                break;
            }

            default:
                LOG_CONSOLE("Unknown asset type dropped");
                break;
            }
        }
        ImGui::EndDragDropTarget();
    }
}
void SceneWindow::HandleGizmoInput()
{
    Input* input = Application::GetInstance().input.get();

    if (ImGui::GetIO().WantTextInput) return;

    if (input->GetKey(SDL_SCANCODE_W) == KEY_DOWN)
    {
        inspectorWindow->SetGizmoOperation(ImGuizmo::TRANSLATE);
    }

    if (!pivotEditMode)
    {
        if (input->GetKey(SDL_SCANCODE_E) == KEY_DOWN)
        {
            inspectorWindow->SetGizmoOperation(ImGuizmo::ROTATE);
        }

        if (input->GetKey(SDL_SCANCODE_R) == KEY_DOWN)
        {
            inspectorWindow->SetGizmoOperation(ImGuizmo::SCALE);
        }

        if (input->GetKey(SDL_SCANCODE_Q) == KEY_DOWN)
        {
            inspectorWindow->SetGizmoOperation(ImGuizmo::BOUNDS);
        }
    }

    if (input->GetKey(SDL_SCANCODE_T) == KEY_DOWN)
    {
        ImGuizmo::MODE currentMode = inspectorWindow->GetCurrentGizmoMode();
        inspectorWindow->SetGizmoMode(
            (currentMode == ImGuizmo::WORLD) ? ImGuizmo::LOCAL : ImGuizmo::WORLD
        );
    }
}

void SceneWindow::DrawGizmo()
{
    // 1. Verificaci�n de objeto seleccionado
    GameObject* selectedObject = Application::GetInstance().selectionManager->GetSelectedObject();

    // First check if the gizmo was being used in the previous frame
    bool wasUsingGizmo = isGizmoActive;

    if (pivotEditMode) inspectorWindow->SetGizmoOperation(ImGuizmo::TRANSLATE);

    std::vector<GameObject*> selectedObjects = Application::GetInstance().selectionManager->GetFilteredObjects();

    //GameObject* selectedObject = Application::GetInstance().selectionManager->GetSelectedObject();
    if (selectedObjects.empty())
    {
        isGizmoActive = false;
        return;
    }

    // 2. Obtenci�n de componentes necesarios
    EditorCamera* camera = Application::GetInstance().editor->GetEditorCamera();
    Transform* transform = static_cast<Transform*>(selectedObject->GetComponent(ComponentType::TRANSFORM));

    if (!camera || !transform || sceneViewportSize.y <= 0.0f || sceneViewportSize.x <= 0.0f) return;
    std::vector<Transform*> transforms;
    for (auto& selectedObject : selectedObjects)
    {
        Transform* transform = static_cast<Transform*>(selectedObject->GetComponent(ComponentType::TRANSFORM));
        if (!transform)
        {
            isGizmoActive = false;
            return;
        }
        transforms.push_back(transform);
    }
    if (sceneViewportSize.y <= 0.0f)
    {
        isGizmoActive = false;
        return;
    }

    // 3. Configuraci�n obligatoria para ImGuizmo
    ImGuizmo::SetOrthographic(false);
    ImGuizmo::SetDrawlist();

    // Rect�ngulo exacto del viewport dentro de la ventana de ImGui
    ImGuizmo::SetRect(sceneViewportPos.x, sceneViewportPos.y, sceneViewportSize.x, sceneViewportSize.y);

    // 4. Preparaci�n de matrices
    glm::mat4 viewMatrix = camera->GetCameraLens()->GetViewMatrix();
    glm::mat4 projectionMatrix = camera->GetCameraLens()->GetProjectionMatrix();

    // Obtenemos la matriz global inicial del objeto
    glm::mat4 matrix = transform->GetGlobalMatrix();
    const float TOLERANCE = 0.001f;
    //if (std::abs(currentAspect - sceneAspect) > TOLERANCE)
    //{
    //    camera->SetAspectRatio(sceneAspect);
    //}

    //glm::mat4 viewMatrix = camera->GetViewMatrix();
    //glm::mat4 projectionMatrix = camera->GetProjectionMatrix();

    // 5. Manipulacion
    ImGuizmo::OPERATION currentOp = inspectorWindow->GetCurrentGizmoOperation();
    ImGuizmo::MODE currentMode = inspectorWindow->GetCurrentGizmoMode();

    glm::vec3 pivot(0.0f);
    for (auto* t : transforms)
        pivot += t->GetGlobalPosition();
    pivot /= transforms.size();

    glm::mat4 originalPivotMatrix;
    if (currentMode == ImGuizmo::LOCAL && transforms.size() == 1)
    {
        glm::mat4 globalMat = transforms[0]->GetGlobalMatrix();
        glm::vec3 pos, scale, skew;
        glm::vec4 persp;
        glm::quat rot;
        glm::decompose(globalMat, scale, rot, pos, skew, persp);
        originalPivotMatrix = glm::translate(glm::mat4(1.0f), pos) * glm::mat4_cast(rot);
    }
    else
    {
        originalPivotMatrix = glm::translate(glm::mat4(1.0f), pivot);
    }
    glm::mat4 gizmoMatrix = originalPivotMatrix;

    float snapValues[3];

    if (snapEnabled)
    {
        if (currentOp == ImGuizmo::TRANSLATE)
        {
            snapValues[0] = positionSnap;
            snapValues[1] = positionSnap;
            snapValues[2] = positionSnap;
        }
        else if (currentOp == ImGuizmo::ROTATE)
        {
            snapValues[0] = rotationSnap;
            snapValues[1] = rotationSnap;
            snapValues[2] = rotationSnap;
        }
        else if (currentOp == ImGuizmo::SCALE)
        {
            snapValues[0] = scaleSnap;
            snapValues[1] = scaleSnap;
            snapValues[2] = scaleSnap;
        }
    }

    ImGuizmo::Manipulate(
        glm::value_ptr(viewMatrix),
        glm::value_ptr(projectionMatrix),
        currentOp,
        currentMode,
        glm::value_ptr(gizmoMatrix),
        nullptr,
        snapEnabled ? snapValues : nullptr
    );
 
    // Update the flag indicating whether the gizmo is being used
    isGizmoActive = ImGuizmo::IsUsing();

    if (!wasUsingGizmo && isGizmoActive)
    {
        originalScales.clear();
        for (auto* t : transforms)
            originalScales.push_back(t->GetScale());
    }

    if (!wasUsingGizmo && isGizmoActive)
    {
        gizmoSnapshotPos = transforms[0]->GetPosition();
        gizmoSnapshotRot = transforms[0]->GetRotation();
        gizmoSnapshotScale = transforms[0]->GetScale();
        gizmoSnapshotTaken = true;
    }

    glm::mat4 deltaMatrix = glm::inverse(originalPivotMatrix) * gizmoMatrix;

    //save transform
    for (int cnt = 0; selectedObjects.size() > cnt;cnt++)
    {
        if (ImGuizmo::IsUsing())
        {
            if (currentOp == ImGuizmo::SCALE)
            {
                glm::vec3 deltaScale;
                deltaScale.x = glm::length(glm::vec3(deltaMatrix[0]));
                deltaScale.y = glm::length(glm::vec3(deltaMatrix[1]));
                deltaScale.z = glm::length(glm::vec3(deltaMatrix[2]));
                
                glm::vec3 newScale = originalScales[cnt] * deltaScale;

                transforms[cnt]->SetScale(newScale);
            }
            else
            {
                glm::mat4 originalGlobal = transforms[cnt]->GetGlobalMatrix();
                glm::vec3 oldWorldPos = glm::vec3(originalGlobal[3]);

                glm::mat4 newGlobal = originalPivotMatrix * deltaMatrix * glm::inverse(originalPivotMatrix) * originalGlobal;
                glm::vec3 newWorldPos = glm::vec3(newGlobal[3]);

                // pivot edit
                ComponentMesh* meshComp = nullptr;
                glm::vec3 meshWorldPos(0.0f);
                std::vector<glm::vec3> childWorldPositions;

                if (pivotEditMode)
                {
                    meshComp = static_cast<ComponentMesh*>(
                        selectedObjects[cnt]->GetComponent(ComponentType::MESH));
                    if (meshComp)
                    {
                        glm::mat3 RS = glm::mat3(originalGlobal);
                        meshWorldPos = oldWorldPos + RS * meshComp->GetPivotLocalOffset();
                    }
                    for (GameObject* child : selectedObjects[cnt]->GetChildren())
                    {
                        Transform* ct = static_cast<Transform*>(child->GetComponent(ComponentType::TRANSFORM));
                        childWorldPositions.push_back(ct ? ct->GetGlobalPosition() : glm::vec3(0.0f));
                    }
                }

                GameObject* parent = selectedObjects[cnt]->GetParent();

                if (parent)
                {
                    Transform* parentTransform = static_cast<Transform*>(parent->GetComponent(ComponentType::TRANSFORM));
                    if (parentTransform)
                        newGlobal = glm::inverse(parentTransform->GetGlobalMatrix()) * newGlobal;
                }

                glm::vec3 position, scale, skew;
                glm::vec4 perspective;
                glm::quat rotation;

                glm::decompose(newGlobal, scale, rotation, position, skew, perspective);

                transforms[cnt]->SetPosition(position);
                transforms[cnt]->SetRotationQuat(rotation);

                if (pivotEditMode)
                {
                    if (meshComp)
                    {
                        glm::mat3 newRS = glm::mat3(transforms[cnt]->GetGlobalMatrix());
                        glm::vec3 newPivOff = glm::inverse(newRS) * (meshWorldPos - newWorldPos);
                        meshComp->SetPivotLocalOffset(newPivOff);
                    }

                    const auto& children = selectedObjects[cnt]->GetChildren();
                    for (size_t i = 0; i < children.size() && i < childWorldPositions.size(); i++)
                    {
                        Transform* ct = static_cast<Transform*>(children[i]->GetComponent(ComponentType::TRANSFORM));
                        if (ct) ct->SetGlobalPosition(childWorldPositions[i]);
                    }
                }
            }
        }
        else if (wasUsingGizmo)
        {
            // We just released the gizmo, mark for octree rebuild
            if (gizmoSnapshotTaken)
            {
                CommandHistory* history = Application::GetInstance().editor->GetCommandHistory();
                history->ExecuteCommand(std::make_unique<TransformCommand>(
                    selectedObjects[cnt],
                    gizmoSnapshotPos, gizmoSnapshotRot, gizmoSnapshotScale,
                    transforms[cnt]->GetPosition(), transforms[cnt]->GetRotation(), transforms[cnt]->GetScale()
                ));
                gizmoSnapshotTaken = false;
            }
        }
    }
}

unsigned long long SceneWindow::FindTextureForDroppedMesh(unsigned long long meshUID)
{
    std::string assetsPath = FileSystem::GetAssetsRoot();
    // 1. Search for the FBX that contains this mesh
    for (const auto& entry : fs::recursive_directory_iterator(assetsPath)) {
        if (!entry.is_regular_file()) continue;
        std::string path = entry.path().string();
        if (entry.path().extension() != ".meta") continue;
        MetaFile meta = MetaFile::Load(path);
        if (meta.type != AssetType::MODEL_FBX) continue;
        unsigned long long fbxUID = meta.uid;
        // Check if this FBX contains the mesh (sequential UIDs)
        if (meshUID >= fbxUID && meshUID < fbxUID + 100) {
            std::string fbxPath = path.substr(0, path.length() - 5); // Remove ".meta"
            if (!fs::exists(fbxPath)) continue;
            // 2. Calculate mesh index within the FBX
            int meshIndex = static_cast<int>(meshUID - fbxUID);
            LOG_CONSOLE("[FindTexture] Found parent FBX: %s (mesh index: %d)", fbxPath.c_str(), meshIndex);
            // 3. Load FBX with Assimp to extract material info
            Assimp::Importer importer;
            const aiScene* scene = importer.ReadFile(
                fbxPath,
                aiProcess_Triangulate | aiProcess_FlipUVs
            );
            if (!scene || scene->mFlags & AI_SCENE_FLAGS_INCOMPLETE) {
                LOG_CONSOLE("[FindTexture] Failed to load FBX with Assimp");
                continue;
            }
            if (meshIndex >= static_cast<int>(scene->mNumMeshes)) {
                LOG_CONSOLE("[FindTexture] Mesh index out of range");
                continue;
            }
            // 4. Get the specific mesh
            aiMesh* mesh = scene->mMeshes[meshIndex];
            // 5. Get the material for this mesh
            if (mesh->mMaterialIndex >= scene->mNumMaterials) {
                LOG_CONSOLE("[FindTexture] Invalid material index");
                continue;
            }
            aiMaterial* material = scene->mMaterials[mesh->mMaterialIndex];
            // 6. Extract the diffuse texture
            if (material->GetTextureCount(aiTextureType_DIFFUSE) > 0) {
                aiString texPath;
                material->GetTexture(aiTextureType_DIFFUSE, 0, &texPath);
                std::string textureName = texPath.C_Str();
                LOG_CONSOLE("[FindTexture] Texture name from FBX: %s", textureName.c_str());
                // 7. Search for the texture in Assets/
                for (const auto& texEntry : fs::recursive_directory_iterator(assetsPath)) {
                    if (!texEntry.is_regular_file()) continue;
                    std::string filename = texEntry.path().filename().string();
                    std::string filenameNoExt = texEntry.path().stem().string();
                    std::string textureNoExt = fs::path(textureName).stem().string();
                    // Compare name with and without extension
                    if (filename == textureName || filenameNoExt == textureNoExt) {
                        // 8. Get the texture UID from its .meta
                        std::string texMetaPath = texEntry.path().string() + ".meta";
                        if (fs::exists(texMetaPath)) {
                            MetaFile texMeta = MetaFile::Load(texMetaPath);
                            LOG_CONSOLE("[FindTexture] Found texture UID: %llu", texMeta.uid);
                            return texMeta.uid;
                        }
                    }
                }
                LOG_CONSOLE("[FindTexture] Texture not found in Assets: %s", textureName.c_str());
            }
            else {
                LOG_CONSOLE("[FindTexture] No diffuse texture in material");
            }
            break; // FBX found, exit loop
        }
    }
    LOG_CONSOLE("[FindTexture] Could not find parent FBX or texture");
    return 0;
}

void SceneWindow::ApplyMeshTransformFromFBX(GameObject* meshObject, unsigned long long meshUID)
{
    std::string assetsPath = FileSystem::GetAssetsRoot();
    // 1. Search for the FBX that contains this mesh
    for (const auto& entry : fs::recursive_directory_iterator(assetsPath)) {
        if (!entry.is_regular_file()) continue;
        std::string path = entry.path().string();
        if (entry.path().extension() != ".meta") continue;
        MetaFile meta = MetaFile::Load(path);
        if (meta.type != AssetType::MODEL_FBX) continue;
        unsigned long long fbxUID = meta.uid;
        // Check if this FBX contains the mesh
        if (meshUID >= fbxUID && meshUID < fbxUID + 100) {
            std::string fbxPath = path.substr(0, path.length() - 5);
            if (!fs::exists(fbxPath)) continue;
            // 2. Calculate mesh index
            int meshIndex = static_cast<int>(meshUID - fbxUID);
            // 3. Load FBX with Assimp
            Assimp::Importer importer;
            const aiScene* scene = importer.ReadFile(
                fbxPath,
                aiProcess_Triangulate | aiProcess_FlipUVs
            );
            if (!scene || meshIndex >= static_cast<int>(scene->mNumMeshes)) {
                continue;
            }
            // 4. Search for the node that contains this mesh in the hierarchy
            aiNode* meshNode = FindNodeWithMeshIndex(scene->mRootNode, meshIndex);
            if (!meshNode) {
                LOG_CONSOLE("[ApplyTransform] Could not find node for mesh index %d", meshIndex);
                continue;
            }
            // 5. Accumulate ONLY rotations and scales, NOT positions
            // To do this, we extract only the rotation/scale part of each transformation
            aiMatrix4x4 accumulatedTransform;
            aiNode* currentNode = meshNode;
            while (currentNode) {
                // Extract node transformation
                aiMatrix4x4 nodeTransform = currentNode->mTransformation;
                // Remove translation (keep only rotation and scale)
                nodeTransform.a4 = 0.0f;
                nodeTransform.b4 = 0.0f;
                nodeTransform.c4 = 0.0f;
                // Accumulate
                accumulatedTransform = nodeTransform * accumulatedTransform;
                currentNode = currentNode->mParent;
            }
            // 6. Convert aiMatrix4x4 to glm::mat4
            glm::mat4 glmTransform;
            for (int i = 0; i < 4; i++) {
                for (int j = 0; j < 4; j++) {
                    glmTransform[j][i] = accumulatedTransform[i][j];
                }
            }
            // 7. Decompose matrix into rotation and scale (without position)
            glm::vec3 scale, skew;
            glm::vec4 perspective;
            glm::quat rotation;
            glm::vec3 translation; // We ignore this
            glm::decompose(glmTransform, scale, rotation, translation, skew, perspective);
            // 8. Apply ONLY rotation and scale to GameObject's Transform
            // Position is left at (0, 0, 0)
            Transform* transform = static_cast<Transform*>(
                meshObject->GetComponent(ComponentType::TRANSFORM)
                );
            if (transform) {
                transform->SetPosition(glm::vec3(0.0f, 0.0f, 0.0f)); // Force to origin
                transform->SetRotationQuat(rotation);
                transform->SetScale(scale);
                LOG_CONSOLE("[ApplyTransform] Applied transform - Pos: (0, 0, 0), Rot: (%.2f, %.2f, %.2f, %.2f), Scale: (%.2f, %.2f, %.2f)",
                    rotation.x, rotation.y, rotation.z, rotation.w,
                    scale.x, scale.y, scale.z);
            }
            break;
        }
    }
}

GameObject* SceneWindow::GetGameObjectUnderMouse()
{

    ImVec2 mousePos = ImGui::GetMousePos();

    int mouseX = (int)(mousePos.x - sceneViewportPos.x);
    int mouseY = (int)(mousePos.y - sceneViewportPos.y);

    UID objectToSelectUID = Application::GetInstance().renderer->GetObjectInPixel(
        Application::GetInstance().editor->GetEditorCamera()->GetCameraLens(),
        mouseX,
        mouseY
    );

    if (objectToSelectUID != 0) {
        GameObject* objectToSelect = Application::GetInstance().scene->FindObject(objectToSelectUID);
        return objectToSelect;
    }
    return nullptr;
}