#include "MaterialEditorWindow.h"
#include "Application.h"
#include "ModuleResources.h"
#include "AssetsWindow.h"
#include "Material.h"
#include "MaterialStandard.h"
#include "ResourceMaterial.h"
#include "MaterialImporter.h"
#include "glm/glm.hpp"
#include <glm/gtc/type_ptr.hpp>

MaterialEditorWindow::MaterialEditorWindow()
    : EditorWindow("Material Editor")
{
    isOpen = false;
}

MaterialEditorWindow::~MaterialEditorWindow()
{
    if (editingMaterial) {
        MaterialStandard* sMat = (MaterialStandard*)editingMaterial;
        sMat->SetAlbedoMap(0);
        sMat->SetNormalMap(0);
        sMat->SetHeightMap(0);
        sMat->SetMetallicMap(0);
        sMat->SetOcclusionMap(0);
        sMat->SetEmissiveMap(0);

        delete editingMaterial;
        editingMaterial = nullptr;
    }

    if (resMat) {
        Application::GetInstance().resources->ReleaseResource(currentMatUID);
        resMat = nullptr;
    }
}


void MaterialEditorWindow::Draw() {
    if (!isOpen) return;
    if (ImGui::Begin(name.c_str(), &isOpen)) {
        if (currentMatUID == 0 || !resMat || !editingMaterial) {
            ImGui::Text("Select a material from Assets to edit.");
            ImGui::End();
            return;
        }

        // --- TIPO DE MATERIAL ---
        int currentType = (int)editingMaterial->GetType();
        const char* types[] = { "Standard", "Unlit", "Water" };
        if (ImGui::Combo("Material Type", &currentType, types, IM_ARRAYSIZE(types))) {
            ChangeMaterialType((MaterialType)currentType);
        }
        ImGui::Separator();

        // --- PROPIEDADES STANDARD ---
        if (editingMaterial->GetType() == MaterialType::STANDARD) {
            MaterialStandard* sMat = (MaterialStandard*)editingMaterial;

            // Albedo y Opacidad
            glm::vec4 color = sMat->GetColor();
            if (ImGui::ColorEdit4("Albedo Tint", glm::value_ptr(color))) {
                sMat->SetColor(color);
            }

            // --- EMISIVO (NUEVO) ---
            glm::vec3 emissiveColor = sMat->GetEmissiveColor();
            if (ImGui::ColorEdit3("Emissive Color/Intensity", glm::value_ptr(emissiveColor), ImGuiColorEditFlags_HDR | ImGuiColorEditFlags_Float)) {
                sMat->SetEmissiveColor(emissiveColor);
            }
            // -----------------------

            // --- PARÁMETROS PBR ---
            float metallic = sMat->GetMetallic();
            if (ImGui::SliderFloat("Metallic", &metallic, 0.0f, 1.0f)) {
                sMat->SetMetallic(metallic);
            }

            float roughness = sMat->GetRoughness();
            if (ImGui::SliderFloat("Roughness", &roughness, 0.0f, 1.0f)) {
                sMat->SetRoughness(roughness);
            }

            float hScale = sMat->GetHeightScale();
            if (ImGui::DragFloat("Height Scale (Relieve)", &hScale, 0.005f, 0.0f, 1.0f)) {
                sMat->SetHeightScale(hScale);
            }

            ImGui::Separator();

            // --- UV TRANSFORM ---
            glm::vec2 tiling = sMat->GetTiling();
            if (ImGui::DragFloat2("Tiling", glm::value_ptr(tiling), 0.1f)) {
                sMat->SetTiling(tiling);
            }

            glm::vec2 offset = sMat->GetOffset();
            if (ImGui::DragFloat2("Offset", glm::value_ptr(offset), 0.01f)) {
                sMat->SetOffset(offset);
            }

            ImGui::Separator();

            // --- TEXTURE SLOTS ---
            UID albedoUID = sMat->GetAlbedoMapUID();
            if (DrawTextureSlot("Albedo Map", albedoUID, sMat))
                sMat->SetAlbedoMap(albedoUID);

            UID normalUID = sMat->GetNormalMapUID();
            if (DrawTextureSlot("Normal Map", normalUID, sMat))
                sMat->SetNormalMap(normalUID);

            UID heightUID = sMat->GetHeightMapUID();
            if (DrawTextureSlot("Height Map", heightUID, sMat))
                sMat->SetHeightMap(heightUID);

            UID metallicUID = sMat->GetMetallicMapUID();
            if (DrawTextureSlot("Metallic Map", metallicUID, sMat))
                sMat->SetMetallicMap(metallicUID);

            UID occlusionUID = sMat->GetOcclusioMapUID();
            if (DrawTextureSlot("Occlusion Map", occlusionUID, sMat))
                sMat->SetOcclusionMap(occlusionUID);

            UID emissiveUID = sMat->GetEmissiveMapUID();
            if (DrawTextureSlot("Emissive Map", emissiveUID, sMat))
                sMat->SetEmissiveMap(emissiveUID);
        }

        ImGui::Spacing();
        ImGui::Separator();
        ImGui::Spacing();

        if (ImGui::Button("Save Changes", ImVec2(120, 30))) {
            Save();
        }
        ImGui::SameLine();
        if (ImGui::Button("Discard", ImVec2(120, 30))) {
            SetMaterialToEdit(currentMatUID);
        }
    }
    ImGui::End();
}

void MaterialEditorWindow::ChangeMaterialType(MaterialType newType) {
    if (editingMaterial->GetType() == newType) return;

    Material* nextMat = nullptr;
    switch (newType) {
    case MaterialType::STANDARD: nextMat = new MaterialStandard(newType); break;
        
    }

    if (nextMat) {

        nextMat->SetOpacity(editingMaterial->GetOpacity());

        delete editingMaterial;
        editingMaterial = nextMat;
    }
}

void MaterialEditorWindow::SetMaterialToEdit(UID materialUID) {
    if (editingMaterial) {
        
        delete editingMaterial;
        editingMaterial = nullptr;
    }

    currentMatUID = materialUID;
    resMat = (ResourceMaterial*)Application::GetInstance().resources->RequestResource(currentMatUID);

    if (resMat && resMat->GetMaterial()) {

        editingMaterial = MaterialImporter::CloneMaterial(resMat->GetMaterial());
    }
}

bool MaterialEditorWindow::DrawTextureSlot(const char* label, UID& currentUID, MaterialStandard* mat) {
    bool changed = false;
    ImGui::Text(label);

    std::string buttonText = "None (Drop Texture)";
    if (currentUID != 0) {
        auto* res = Application::GetInstance().resources->PeekResource(currentUID);
        if (res) buttonText = std::to_string(res->GetUID());
    }

    ImGui::PushID(label);
    ImGui::Button(buttonText.c_str(), ImVec2(ImGui::GetContentRegionAvail().x - 30, 20));

    if (ImGui::BeginDragDropTarget()) {
        if (const ImGuiPayload* payload = ImGui::AcceptDragDropPayload("ASSET_ITEM")) {
            const DragDropPayload* data = (const DragDropPayload*)payload->Data;

            if (data->assetType == DragDropAssetType::TEXTURE) {
                currentUID = data->assetUID;
                changed = true;
            }
        }
        ImGui::EndDragDropTarget();
    }

    ImGui::SameLine();
    if (ImGui::Button("X")) {
        currentUID = 0;
        changed = true;
    }
    ImGui::PopID();

    return changed;
}

void MaterialEditorWindow::Save() {
    if (!resMat || !editingMaterial) return;

    nlohmann::json j;

    j["Type"] = (int)editingMaterial->GetType();
    j["Opacity"] = editingMaterial->GetOpacity();

    editingMaterial->SaveToJson(j);

    std::string path = resMat->GetAssetFile();
    std::ofstream file(path);
    if (file.is_open()) {
        file << j.dump(4);
        file.close();

        Application::GetInstance().resources->ImportFile(path.c_str(), true);
        LOG_CONSOLE("[MaterialEditor] Saved and Re-imported: %s", path.c_str());
    }
}