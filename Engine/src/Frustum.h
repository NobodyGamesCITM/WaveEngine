#pragma once
#include "glm/glm.hpp"
#include <array>
#include "AABB.h"

struct Plane
{
    glm::vec3 normal;
    float distance;

    Plane::Plane()
    {
        normal = glm::vec3(0.0f, 1.0f, 0.0f);
        distance = 0.0f;
    }

    Plane::Plane(const glm::vec3& n, float d)
    {
        normal = n;
        distance = d;
    }

    void Plane::Normalize()
    {
        float length = glm::length(normal);
        normal /= length;
        distance /= length;
    }

    float Plane::DistanceToPoint(const glm::vec3& point) const
    {
        return glm::dot(normal, point) + distance;
    }
    
    bool Plane::IsOnPositiveSide(const glm::vec3& point) const
    {
        return DistanceToPoint(point) >= 0.0f;
    }
};

class Frustum
{
public:

    Frustum() = default;
    ~Frustum() = default;

    void Frustum::Update(const glm::mat4& viewProjMatrix)
    {
        const auto& mat = viewProjMatrix;

        planes[0].normal.x = mat[0][3] + mat[0][0];
        planes[0].normal.y = mat[1][3] + mat[1][0];
        planes[0].normal.z = mat[2][3] + mat[2][0];
        planes[0].distance = mat[3][3] + mat[3][0];

        planes[1].normal.x = mat[0][3] - mat[0][0];
        planes[1].normal.y = mat[1][3] - mat[1][0];
        planes[1].normal.z = mat[2][3] - mat[2][0];
        planes[1].distance = mat[3][3] - mat[3][0];

        planes[2].normal.x = mat[0][3] + mat[0][1];
        planes[2].normal.y = mat[1][3] + mat[1][1];
        planes[2].normal.z = mat[2][3] + mat[2][1];
        planes[2].distance = mat[3][3] + mat[3][1];

        planes[3].normal.x = mat[0][3] - mat[0][1];
        planes[3].normal.y = mat[1][3] - mat[1][1];
        planes[3].normal.z = mat[2][3] - mat[2][1];
        planes[3].distance = mat[3][3] - mat[3][1];

        planes[4].normal.x = mat[0][3] + mat[0][2];
        planes[4].normal.y = mat[1][3] + mat[1][2];
        planes[4].normal.z = mat[2][3] + mat[2][2];
        planes[4].distance = mat[3][3] + mat[3][2];

        planes[5].normal.x = mat[0][3] - mat[0][2];
        planes[5].normal.y = mat[1][3] - mat[1][2];
        planes[5].normal.z = mat[2][3] - mat[2][2];
        planes[5].distance = mat[3][3] - mat[3][2];

        for (int i = 0; i < 6; ++i)
        {
            planes[i].Normalize();
        }
    };

    bool Frustum::InFrustum(const AABB& aabb) const
    {
        for (int i = 0; i < 6; ++i)
        {
            const Plane& plane = planes[i];

            glm::vec3 pVertex;

            if (plane.normal.x > 0) pVertex.x = aabb.max.x;
            else                    pVertex.x = aabb.min.x;

            if (plane.normal.y > 0) pVertex.y = aabb.max.y;
            else                    pVertex.y = aabb.min.y;

            if (plane.normal.z > 0) pVertex.z = aabb.max.z;
            else                    pVertex.z = aabb.min.z;

            if (plane.DistanceToPoint(pVertex) < 0)
            {
                return false;
            }
        }

        return true;
    };
    
private:
    std::array<Plane, 6> planes = {};
};