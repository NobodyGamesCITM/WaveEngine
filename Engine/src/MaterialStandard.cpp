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

    albedoMapUID = 0;
    normalMapUID = 0;
    heightMapUID = 0;
    metallicMapUID = 0;
    occlusionMapUID = 0;
}

void MaterialStandard::Bind(Shader* shader)
{
    if (!shader) return;

    shader->SetVec4("uColor", color);
    shader->SetFloat("uMetallic", metallic);
    shader->SetFloat("uRoughness", roughness);
    shader->SetFloat("uHeightScale", heightScale);
    shader->SetVec2("uTiling", tiling);
    shader->SetVec2("uOffset", offset);

    glActiveTexture(GL_TEXTURE0);
    if (albedoMap && albedoMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, albedoMap->GetGPU_ID());
        shader->SetInt("uAlbedoMap", 0);
    }
    
    glActiveTexture(GL_TEXTURE1);
    if (metallicMap && metallicMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, metallicMap->GetGPU_ID());
        shader->SetInt("uMetallicMap", 1);
    }

    glActiveTexture(GL_TEXTURE2);
    if (normalMap && normalMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, normalMap->GetGPU_ID());
        shader->SetInt("uNormalMap", 2);
    }

    glActiveTexture(GL_TEXTURE3);
    if (occlusionMap && occlusionMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, occlusionMap->GetGPU_ID());
        shader->SetInt("uOcclusionMap", 3);
    }

    glActiveTexture(GL_TEXTURE4);
    if (heightMap && heightMap->IsLoadedToMemory()) {
        glBindTexture(GL_TEXTURE_2D, heightMap->GetGPU_ID());
        shader->SetInt("uHeightMap", 4);
    }

    glActiveTexture(GL_TEXTURE0);
}

void MaterialStandard::LoadCustomData(std::ifstream& file) {
    
    file.read((char*)&albedoMapUID, sizeof(UID));
    file.read((char*)&metallicMapUID, sizeof(UID));
    file.read((char*)&normalMapUID, sizeof(UID));
    file.read((char*)&heightMapUID, sizeof(UID));
    file.read((char*)&occlusionMapUID, sizeof(UID));

    file.read((char*)&color, sizeof(glm::vec4));
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
}

void MaterialStandard::SaveCustomData(std::ofstream& file) const {

    file.write((char*)&albedoMapUID, sizeof(UID));
    file.write((char*)&metallicMapUID, sizeof(UID));
    file.write((char*)&normalMapUID, sizeof(UID));
    file.write((char*)&heightMapUID, sizeof(UID));
    file.write((char*)&occlusionMapUID, sizeof(UID));

    file.write((char*)&color, sizeof(glm::vec4));
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
    
    j["Color"] = { color.r, color.g, color.b, color.a };
    j["Metallic"] = metallic;
    j["Roughness"] = roughness;
    j["HeightScale"] = heightScale;
    
    j["Tiling"] = { tiling.x, tiling.y };
    j["Offset"] = { offset.x, offset.y };
}

void MaterialStandard::LoadFromJson(const nlohmann::json& j) {

    albedoMapUID = j.value("AlbedoMapUID", 0ull);
    normalMapUID = j.value("NormalMapUID", 0ull);
    heightMapUID = j.value("HeightMapUID", 0ull);
    metallicMapUID = j.value("MetallicMapUID", 0ull);
    occlusionMapUID = j.value("OcclusionMapUID", 0ull);

    if (j.contains("Color")) {
        auto c = j["Color"];
        color = glm::vec4(c[0], c[1], c[2], c[3]);
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

    SetAlbedoMap(albedoMapUID);
    SetNormalMap(normalMapUID);
    SetHeightMap(heightMapUID);
    SetMetallicMap(metallicMapUID);
    SetOcclusionMap(occlusionMapUID);
}

void MaterialStandard::SetAlbedoMap(UID uid) {

    if (albedoMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(albedoMapUID);
        albedoMapUID = 0;
    }

    albedoMap = (ResourceTexture*)Application::GetInstance().resources.get()->RequestResource(uid);

    if (albedoMap) albedoMapUID = uid;
}

void MaterialStandard::SetHeightMap(UID uid) {

    if (heightMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(heightMapUID);
        heightMapUID = 0;
    }

    heightMap = (ResourceTexture*) Application::GetInstance().resources.get()->RequestResource(uid);

    if (heightMap) heightMapUID = uid;
}

void MaterialStandard::SetNormalMap(UID uid) {

    if (normalMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(normalMapUID);
        normalMapUID = 0;
    }

    normalMap = (ResourceTexture*) Application::GetInstance().resources.get()->RequestResource(uid);

    if (normalMap) normalMapUID = uid;
}

void MaterialStandard::SetMetallicMap(UID uid) {

    if (metallicMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(metallicMapUID);
        metallicMapUID = 0;
    }

    metallicMap = (ResourceTexture*) Application::GetInstance().resources.get()->RequestResource(uid);

    if (metallicMap) metallicMapUID = uid;
}

void MaterialStandard::SetOcclusionMap(UID uid) {

    if (occlusionMapUID != 0) {
        Application::GetInstance().resources->ReleaseResource(occlusionMapUID);
        occlusionMapUID = 0;
    }

    occlusionMap = (ResourceTexture*) Application::GetInstance().resources.get()->RequestResource(uid);

    if (occlusionMap) occlusionMapUID = uid;
}

