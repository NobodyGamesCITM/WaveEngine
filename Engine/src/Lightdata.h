#pragma once
#include <glm/glm.hpp>

struct DirectionalLightData
{
    glm::vec3 direction = glm::vec3(0.0f, -1.0f, 0.0f);
    glm::vec3 ambient = glm::vec3(0.05f);
    glm::vec3 diffuse = glm::vec3(0.8f);
    glm::vec3 specular = glm::vec3(0.5f);
};

struct PointLightData
{
    glm::vec3 position = glm::vec3(0.0f);
    glm::vec3 ambient = glm::vec3(0.05f);
    glm::vec3 diffuse = glm::vec3(0.8f);
    glm::vec3 specular = glm::vec3(1.0f);
    float     constant = 1.0f;
    float     linear = 0.09f;
    float     quadratic = 0.032f;
};

struct SpotLightData
{
    glm::vec3 position = glm::vec3(0.0f);
    glm::vec3 direction = glm::vec3(0.0f, -1.0f, 0.0f);
    glm::vec3 ambient = glm::vec3(0.0f);
    glm::vec3 diffuse = glm::vec3(1.0f);
    glm::vec3 specular = glm::vec3(1.0f);
    float     cutOff = 12.5f;   // degrees
    float     outerCutOff = 17.5f;   
    float     constant = 1.0f;
    float     linear = 0.09f;
    float     quadratic = 0.032f;
};




struct GPUDirLight
{
    glm::vec3 direction; float _pad0;
    glm::vec3 ambient;   float _pad1;
    glm::vec3 diffuse;   float _pad2;
    glm::vec3 specular;  float _pad3;
};

struct GPUPointLight
{
    glm::vec3 position;  float _pad0;
    glm::vec3 ambient;   float _pad1;
    glm::vec3 diffuse;   float _pad2;
    glm::vec3 specular;  float _pad3;
    float constant;
    float linear;
    float quadratic;
    float _pad4;         
};

struct GPUSpotLight
{
    glm::vec3 position;    float _pad0;
    glm::vec3 direction;   float _pad1;
    glm::vec3 ambient;     float _pad2;
    glm::vec3 diffuse;     float _pad3;
    glm::vec3 specular;    float _pad4;
    float cutOff;         
    float outerCutOff;    
    float constant;
    float linear;
    float quadratic;
    float _pad5; float _pad6; float _pad7; 
};







//Directional Light
//
//Represents a light that comes from a fixed direction but without a position.
//That is, all light rays are parallel.

//This is normally used to simulate very distant light such as the sun and things like that, that is, light sources that do not have a specific position in space but illuminate the whole scene from a given direction.
//


// Point Light
// 
// Represents a light that has a position in space and emits
// light in all directions.
//
// It is the typical model for bulbs, torches, small lights and such, that is, light sources that are not directional but illuminate in all directions from a specific point.
// The intensity of the light decreases with distance.
//

// Spot Light
//
// Represents a light with position and direction that illuminates
// only inside a cone.
//
// It is the typical model for flashlights, spotlights and such, that is, directional light sources but with a range limited to a cone.
//
// Only objects inside the cone receive illumination.
//