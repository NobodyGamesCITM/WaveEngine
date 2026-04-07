#pragma once

#include "MaterialStandard.h"
#include "Application.h"
#include "ModuleResources.h"
#include "ResourceTexture.h"
#include "Shader.h"
#include "glad/glad.h"

#include <fstream>

MaterialStandard::MaterialStandard(MaterialType type) : Material(type)
{

}

MaterialStandard::~MaterialStandard()
{
    auto* resModule = Application::GetInstance().resources.get();

    if (albedoMapUID != 0) resModule->ReleaseResource(albedoMapUID);
    if (normalMapUID != 0) resModule->ReleaseResource(normalMapUID);
    if (heightMapUID != 0) resModule->ReleaseResource(heightMapUID);
    if (metallicMapUID != 0) resModule->ReleaseResource(metallicMapUID);
    if (occlusionMapUID != 0) resModule->ReleaseResource(occlusionMapUID);
    if (emissiveMapUID != 0) resModule->ReleaseResource(emissiveMapUID);

    albedoMapUID = 0;
    normalMapUID = 0;
    heightMapUID = 0;
    metallicMapUID = 0;
    occlusionMapUID = 0;
    emissiveMapUID = 0;
}

void MaterialStandard::Bind(Shader* shader)
{
    if (!shader) return;

    auto* resModule = Application::GetInstance().resources.get();
    if (albedoMap == nullptr && albedoMapUID != 0) albedoMap = (ResourceTexture*)resModule->RequestResource(albedoMapUID);
    if (normalMap == nullptr && normalMapUID != 0) normalMap = (ResourceTexture*)resModule->RequestResource(normalMapUID);
    if (metallicMap == nullptr && metallicMapUID != 0) metallicMap = (ResourceTexture*)resModule->RequestResource(metallicMapUID);
    if (occlusionMap == nullptr && occlusionMapUID != 0) occlusionMap = (ResourceTexture*)resModule->RequestResource(occlusionMapUID);
    if (heightMap == nullptr && heightMapUID != 0) heightMap = (ResourceTexture*)resModule->RequestResource(heightMapUID);
    if (emissiveMap == nullptr && emissiveMapUID != 0) emissiveMap = (ResourceTexture*)resModule->RequestResource(emissiveMapUID);

    shader->SetVec4("uColor", color);
    shader->SetFloat("uMetallic", metallic);
    shader->SetFloat("uRoughness", roughness);
    shader->SetFloat("uHeightScale", heightScale);
    shader->SetVec2("uTiling", tiling);
    shader->SetVec2("uOffset", offset);
    shader->SetVec3("uEmissiveColor", emissiveColor);

    // Albedo
    glActiveTexture(GL_TEXTURE0);
    if (albedoMap && albedoMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, albedoMap->GetGPU_ID());
    }
    else {
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    shader->SetInt("uAlbedoMap", 0);

    // Metallic
    glActiveTexture(GL_TEXTURE1);
    if (metallicMap && metallicMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, metallicMap->GetGPU_ID());
        shader->SetBool("uUseMetallicMap", true);
    }
    else {
        glBindTexture(GL_TEXTURE_2D, 0);
        shader->SetBool("uUseMetallicMap", false);
    }
    shader->SetInt("uMetallicMap", 1);

    // Normal
    glActiveTexture(GL_TEXTURE2);
    if (normalMap && normalMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, normalMap->GetGPU_ID());
        shader->SetBool("uUseNormalMap", true);
    }
    else {
        glBindTexture(GL_TEXTURE_2D, 0);
        shader->SetBool("uUseNormalMap", false);
    }
    shader->SetInt("uNormalMap", 2);

    // Occlusion
    glActiveTexture(GL_TEXTURE3);
    if (occlusionMap && occlusionMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, occlusionMap->GetGPU_ID());
        shader->SetBool("uUseOcclusionMap", true);
    }
    else {
        glBindTexture(GL_TEXTURE_2D, 0);
        shader->SetBool("uUseOcclusionMap", false);
    }
    shader->SetInt("uOcclusionMap", 3);

    // Height
    glActiveTexture(GL_TEXTURE4);
    if (heightMap && heightMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, heightMap->GetGPU_ID());
        shader->SetBool("uUseHeightMap", true);
    }
    else {
        glBindTexture(GL_TEXTURE_2D, 0);
        shader->SetBool("uUseHeightMap", false);
    }
    shader->SetInt("uHeightMap", 4);

    // Emissive
    glActiveTexture(GL_TEXTURE5);
    if (emissiveMap && emissiveMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, emissiveMap->GetGPU_ID());
        shader->SetBool("uUseEmissiveMap", true);
    }
    else {
        glBindTexture(GL_TEXTURE_2D, 0);
        shader->SetBool("uUseEmissiveMap", false);
    }
    shader->SetInt("uEmissiveMap", 5);

    glActiveTexture(GL_TEXTURE0);
}

void MaterialStandard::LoadCustomData(std::ifstream& file) {
    
    file.read((char*)&albedoMapUID, sizeof(UID));
    file.read((char*)&metallicMapUID, sizeof(UID));
    file.read((char*)&normalMapUID, sizeof(UID));
    file.read((char*)&heightMapUID, sizeof(UID));
    file.read((char*)&occlusionMapUID, sizeof(UID));
    file.read((char*)&emissiveMapUID, sizeof(UID));

    file.read((char*)&color, sizeof(glm::vec4));
    file.read((char*)&emissiveColor, sizeof(glm::vec3));
    file.read((char*)&metallic, sizeof(float));
    file.read((char*)&roughness, sizeof(float));
    file.read((char*)&heightScale, sizeof(float));

    file.read((char*)&tiling, sizeof(glm::vec2));
    file.read((char*)&offset, sizeof(glm::vec2));

    SetAlbedoMap(albedoMapUID);
    SetMetallicMap(metallicMapUID);
    SetNormalMap(normalMapUID);
    SetHeightMap(heightMapUID);
    SetOcclusionMap(occlusionMapUID);
    SetEmissiveMap(emissiveMapUID);
}

void MaterialStandard::SaveCustomData(std::ofstream& file) const {

    file.write((char*)&albedoMapUID, sizeof(UID));
    file.write((char*)&metallicMapUID, sizeof(UID));
    file.write((char*)&normalMapUID, sizeof(UID));
    file.write((char*)&heightMapUID, sizeof(UID));
    file.write((char*)&occlusionMapUID, sizeof(UID));
    file.write((char*)&emissiveMapUID, sizeof(UID));


    file.write((char*)&color, sizeof(glm::vec4));
    file.write((char*)&emissiveColor, sizeof(glm::vec3));
    file.write((char*)&metallic, sizeof(float));
    file.write((char*)&roughness, sizeof(float));
    file.write((char*)&heightScale, sizeof(float));
    
    file.write((char*)&tiling, sizeof(glm::vec2));
    file.write((char*)&offset, sizeof(glm::vec2));
}

void MaterialStandard::SaveToJson(nlohmann::json& j) const {
    j["AlbedoMapUID"] = albedoMapUID;
    j["NormalMapUID"] = normalMapUID;
    j["HeightMapUID"] = heightMapUID;
    j["MetallicMapUID"] = metallicMapUID;
    j["OcclusionMapUID"] = occlusionMapUID;
    j["EmissiveMapUID"] = emissiveMapUID;

    j["Color"] = { color.r, color.g, color.b, color.a };
    j["EmissiveColor"] = { emissiveColor.r, emissiveColor.g, emissiveColor.b };
    j["Metallic"] = metallic;
    j["Roughness"] = roughness;
    j["HeightScale"] = heightScale;
    
    j["Tiling"] = { tiling.x, tiling.y };
    j["Offset"] = { offset.x, offset.y };
}

void MaterialStandard::LoadFromJson(const nlohmann::json& j) {

    UID tempAlbedoMapUID = j.value("AlbedoMapUID", 0ull);
    UID tempNormalMapUID = j.value("NormalMapUID", 0ull);
    UID tempHeightMapUID = j.value("HeightMapUID", 0ull);
    UID tempMetallicMapUID = j.value("MetallicMapUID", 0ull);
    UID tempOcclusionMapUID = j.value("OcclusionMapUID", 0ull);
    UID tempEmissiveMapUID = j.value("EmissiveMapUID", 0ull);

    if (j.contains("Color")) {
        auto c = j["Color"];
        color = glm::vec4(c[0], c[1], c[2], c[3]);
    }
    if (j.contains("EmissiveColor")) {
        auto e = j["EmissiveColor"];
        emissiveColor = glm::vec3(e[0], e[1], e[2]);
    }
    metallic = j.value("Metallic", 0.0f);
    roughness = j.value("Roughness", 0.5f);
    heightScale = j.value("HeightScale", 0.05f);

    if (j.contains("Tiling")) {
        auto t = j["Tiling"];
        tiling = glm::vec2(t[0], t[1]);
    }
    if (j.contains("Offset")) {
        auto o = j["Offset"];
        offset = glm::vec2(o[0], o[1]);
    }

    SetAlbedoMap(tempAlbedoMapUID);
    SetNormalMap(tempNormalMapUID);
    SetHeightMap(tempHeightMapUID);
    SetMetallicMap(tempMetallicMapUID);
    SetOcclusionMap(tempOcclusionMapUID);
    SetEmissiveMap(tempEmissiveMapUID);
}

void MaterialStandard::SetAlbedoMap(UID uid) {
    if (albedoMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(albedoMapUID);
    }
    albedoMapUID = uid;
    albedoMap = (albedoMapUID != 0) ? (ResourceTexture*)Application::GetInstance().resources->RequestResource(albedoMapUID) : nullptr;
}

void MaterialStandard::SetHeightMap(UID uid) {
    if (heightMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(heightMapUID);
    }
    heightMapUID = uid;
    heightMap = (heightMapUID != 0) ? (ResourceTexture*)Application::GetInstance().resources->RequestResource(heightMapUID) : nullptr;
}

void MaterialStandard::SetNormalMap(UID uid) {
    if (normalMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(normalMapUID);
    }
    normalMapUID = uid;
    normalMap = (normalMapUID != 0) ? (ResourceTexture*)Application::GetInstance().resources->RequestResource(normalMapUID) : nullptr;
}

void MaterialStandard::SetMetallicMap(UID uid) {
    if (metallicMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(metallicMapUID);
    }
    metallicMapUID = uid;
    metallicMap = (metallicMapUID != 0) ? (ResourceTexture*)Application::GetInstance().resources->RequestResource(metallicMapUID) : nullptr;
}

void MaterialStandard::SetOcclusionMap(UID uid) {
    if (occlusionMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(occlusionMapUID);
    }
    occlusionMapUID = uid;
    occlusionMap = (occlusionMapUID != 0) ? (ResourceTexture*)Application::GetInstance().resources->RequestResource(occlusionMapUID) : nullptr;
}

void MaterialStandard::SetEmissiveMap(UID uid) {
    if (emissiveMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(emissiveMapUID);
    }
    emissiveMapUID = uid;
    emissiveMap = (emissiveMapUID != 0) ? (ResourceTexture*)Application::GetInstance().resources->RequestResource(emissiveMapUID) : nullptr;
}