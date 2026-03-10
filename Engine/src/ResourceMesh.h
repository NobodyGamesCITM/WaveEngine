#pragma once

#include "ModuleResources.h"
#include "glm/glm.hpp"

// Vertex data structure
struct Vertex {
    glm::vec3 position;
    glm::vec3 normal;
    glm::vec2 texCoords;
    glm::vec3 tangent;

    int boneIDs[4] = { -1, -1, -1, -1 };

    float weights[4] = { 0.0f, 0.0f, 0.0f, 0.0f };

    void Vertex::AddBoneData(int boneID, float weight)
    {
        for (int i = 0; i < 4; i++)
        {
            if (boneIDs[i] == -1)
            {
                boneIDs[i] = boneID;
                weights[i] = weight;
                return;
            }
        }

        int smallestIndex = -1;
        float smallestWeight = weight;

        for (int i = 0; i < 4; i++)
        {
            if (weights[i] < smallestWeight)
            {
                smallestWeight = weights[i];
                smallestIndex = i;
            }
        }

        if (smallestIndex != -1)
        {
            boneIDs[smallestIndex] = boneID;
            weights[smallestIndex] = weight;
        }
    }

    void Vertex::NormalizeWeights() {
        float totalWeight = 0.0f;
        for (int i = 0; i < 4; i++) {
            if (boneIDs[i] != -1) totalWeight += weights[i];
        }

        if (totalWeight > 0.0f) {
            for (int i = 0; i < 4; i++) {
                weights[i] /= totalWeight;
            }
        }
        else {
            
            weights[0] = 1.0f;
        }
    }
};

// Texture information
struct TextureInfo {
    unsigned int id = 0;
    std::string type;  // e.g., "diffuse", "specular", "normal"
    std::string path;
};

struct Bone {
    std::string name;
    glm::mat4 offsetMatrix;
};

// Mesh container with vertex data and OpenGL buffer IDs
struct Mesh {
    
    std::vector<Vertex> vertices = {};
    std::vector<unsigned int> indices = {};
    std::vector<Bone> bones = {};
    std::vector<TextureInfo> textures = {};

    // OpenGL buffer IDs 
    unsigned int VAO = 0;
    unsigned int VBO = 0;
    unsigned int EBO = 0;

    bool IsValid() const { return VAO != 0; }
    bool IsSkinned() { return bones.size() != 0; }
};

class ResourceMesh : public Resource {
public:
    ResourceMesh(UID uid);
    virtual ~ResourceMesh();

    bool LoadInMemory() override;
    void UnloadFromMemory() override;

    // getters
    const Mesh& GetMesh() const { return mesh; }
    unsigned int GetNumVertices() const { return mesh.vertices.size(); }
    unsigned int GetNumIndices() const { return mesh.indices.size(); }
    unsigned int GetNumTriangles() const { return mesh.indices.size() / 3; }

private:
    Mesh mesh;  
};