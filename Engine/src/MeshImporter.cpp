#define _HAS_STD_BYTE 0 

#include "MeshImporter.h"
#include "LibraryManager.h"
#include <filesystem>
#include <assimp/mesh.h>
#include <fstream>
#include <sstream>
#include <chrono>
#include <algorithm>
#include <limits>

MeshImporter::MeshImporter() {}
MeshImporter::~MeshImporter() {}

// IMPORT: Assimp -> Our Mesh Structure
Mesh MeshImporter::ImportFromAssimp(const aiMesh* assimpMesh) {
    
    Mesh mesh;

    if (!assimpMesh) {
        LOG_DEBUG("ERROR: assimpMesh is nullptr");
        return mesh;
    }

    // Reserve space for efficiency
    mesh.vertices.reserve(assimpMesh->mNumVertices);
    mesh.indices.reserve(assimpMesh->mNumFaces * 3);

    // Import vertices
    for (unsigned int i = 0; i < assimpMesh->mNumVertices; i++) {
        Vertex vertex;

        // Position (always present)
        vertex.position = glm::vec3(
            assimpMesh->mVertices[i].x,
            assimpMesh->mVertices[i].y,
            assimpMesh->mVertices[i].z
        );

        // Normals
        if (assimpMesh->HasNormals()) {
            vertex.normal = glm::vec3(
                assimpMesh->mNormals[i].x,
                assimpMesh->mNormals[i].y,
                assimpMesh->mNormals[i].z
            );
        }
        else {
            vertex.normal = glm::vec3(0.0f, 1.0f, 0.0f);
        }

        // Texture coordinates
        if (assimpMesh->HasTextureCoords(0)) {
            vertex.texCoords = glm::vec2(
                assimpMesh->mTextureCoords[0][i].x,
                assimpMesh->mTextureCoords[0][i].y
            );
        }
        else {
            vertex.texCoords = glm::vec2(0.0f, 0.0f);
        }

        // Tangents
        if (assimpMesh->HasTangentsAndBitangents()) {
            vertex.tangent = glm::vec3(
                assimpMesh->mTangents[i].x,
                assimpMesh->mTangents[i].y,
                assimpMesh->mTangents[i].z
            );
        }
        else {
            vertex.tangent = glm::vec3(0.0f);
        }

        mesh.vertices.push_back(vertex);
    }

    // Import indices
    for (unsigned int i = 0; i < assimpMesh->mNumFaces; i++) {
        aiFace face = assimpMesh->mFaces[i];
        for (unsigned int j = 0; j < face.mNumIndices; j++) {
            mesh.indices.push_back(face.mIndices[j]);
        }
    }

    // Import Bones
    if (assimpMesh->HasBones()) {
        std::map<std::string, int> boneMapping;
        for (unsigned int i = 0; i < assimpMesh->mNumBones; i++) {
            aiBone* aiBone = assimpMesh->mBones[i];
            std::string boneName = aiBone->mName.C_Str();
            int boneID = -1;

            if (boneMapping.find(boneName) == boneMapping.end()) {
                boneID = (int)mesh.bones.size();
                Bone boneInfo;
                boneInfo.name = boneName;

                aiMatrix4x4 m = aiBone->mOffsetMatrix;
                boneInfo.offsetMatrix = glm::mat4(
                    m.a1, m.b1, m.c1, m.d1,
                    m.a2, m.b2, m.c2, m.d2,
                    m.a3, m.b3, m.c3, m.d3,
                    m.a4, m.b4, m.c4, m.d4
                );
                mesh.bones.push_back(boneInfo);
                boneMapping[boneName] = boneID;
            }
            else {
                boneID = boneMapping[boneName];
            }

            for (unsigned int j = 0; j < aiBone->mNumWeights; j++) {
                int vID = aiBone->mWeights[j].mVertexId;
                float weight = aiBone->mWeights[j].mWeight;
                if (vID < mesh.vertices.size()) {
                    mesh.vertices[vID].AddBoneData(boneID, weight);
                }
            }
        }
    }

    for (auto& vertex : mesh.vertices) {
        vertex.NormalizeWeights();
    }

    return mesh;
}

// SAVE: Our Mesh -> Custom Binary Format
bool MeshImporter::SaveToCustomFormat(const Mesh& mesh, const UID& uid) {
    std::string fullPath = LibraryManager::GetLibraryPath(uid);
    std::ofstream file(fullPath, std::ios::binary);

    if (!file.is_open()) return false;

    unsigned int numVertices = static_cast<unsigned int>(mesh.vertices.size());
    unsigned int numIndices = static_cast<unsigned int>(mesh.indices.size());
    unsigned int numBones = static_cast<unsigned int>(mesh.bones.size());

    file.write(reinterpret_cast<const char*>(&numVertices), sizeof(unsigned int));
    file.write(reinterpret_cast<const char*>(&numIndices), sizeof(unsigned int));
    file.write(reinterpret_cast<const char*>(&numBones), sizeof(unsigned int));

    file.write(reinterpret_cast<const char*>(mesh.vertices.data()), numVertices * sizeof(Vertex));

    file.write(reinterpret_cast<const char*>(mesh.indices.data()), numIndices * sizeof(unsigned int));

    for (const auto& bone : mesh.bones) {
        unsigned int nameSize = static_cast<unsigned int>(bone.name.size());
        file.write(reinterpret_cast<const char*>(&nameSize), sizeof(unsigned int));
        file.write(bone.name.c_str(), nameSize);
        file.write(reinterpret_cast<const char*>(&bone.offsetMatrix), sizeof(glm::mat4));
    }

    file.close();
    return true;
}

Mesh MeshImporter::LoadFromCustomFormat(const UID& uid) {
    std::string fullPath = LibraryManager::GetLibraryPath(uid);
    Mesh mesh;
    std::ifstream file(fullPath, std::ios::binary);

    if (!file.is_open()) return mesh;

    unsigned int numVertices = 0, numIndices = 0, numBones = 0;

    file.read(reinterpret_cast<char*>(&numVertices), sizeof(unsigned int));
    file.read(reinterpret_cast<char*>(&numIndices), sizeof(unsigned int));
    file.read(reinterpret_cast<char*>(&numBones), sizeof(unsigned int));

    if (numVertices > 0) {
        mesh.vertices.resize(numVertices);
        file.read(reinterpret_cast<char*>(mesh.vertices.data()), numVertices * sizeof(Vertex));
    }
    if (numIndices > 0) {
        mesh.indices.resize(numIndices);
        file.read(reinterpret_cast<char*>(mesh.indices.data()), numIndices * sizeof(unsigned int));
    }

    if (numBones > 0) {
        mesh.bones.resize(numBones);
        for (unsigned int i = 0; i < numBones; i++) {
            unsigned int nameSize = 0;
            file.read(reinterpret_cast<char*>(&nameSize), sizeof(unsigned int));

            mesh.bones[i].name.resize(nameSize);
            file.read(&mesh.bones[i].name[0], nameSize);

            file.read(reinterpret_cast<char*>(&mesh.bones[i].offsetMatrix), sizeof(glm::mat4));
        }
    }

    file.close();
    return mesh;
}

std::string MeshImporter::GenerateMeshFilename(const std::string& originalName) {
    std::string sanitized = originalName;
    if (sanitized.empty()) {
        sanitized = "unnamed_mesh";
    }

    std::replace(sanitized.begin(), sanitized.end(), ' ', '_');

    sanitized.erase(
        std::remove_if(sanitized.begin(), sanitized.end(),
            [](char c) { return !std::isalnum(c) && c != '_'; }),
        sanitized.end()
    );

    std::transform(sanitized.begin(), sanitized.end(), sanitized.begin(), ::tolower);

    std::hash<std::string> hasher;
    size_t hashValue = hasher(originalName);

    std::stringstream ss;
    ss << sanitized << "_" << std::hex << hashValue << ".mesh";

    return ss.str();
}