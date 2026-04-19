#include "Component.h"
#include "GameObject.h"
#include <imgui.h>  
#include <ImGuizmo.h>

Component::Component(GameObject* owner, ComponentType type) : owner(owner), type(type), active(true) {
    switch (type) {
    case ComponentType::TRANSFORM:               name = "Transform";                break;
    case ComponentType::MESH:                    name = "Mesh";                     break;
    case ComponentType::MATERIAL:                name = "Material";                 break;
    case ComponentType::CAMERA:                  name = "Camera";                   break;
    case ComponentType::ROTATE:                  name = "Auto Rotate";              break;
    case ComponentType::SCRIPT:                  name = "Script";                   break;
    case ComponentType::PARTICLE:                name = "Particle System";          break;
    case ComponentType::RIGIDBODY:               name = "Rigidbody";                break;
    case ComponentType::COLLIDER:                name = "Collider";                 break;
    case ComponentType::BOX_COLLIDER:            name = "Box Collider";             break;
    case ComponentType::SPHERE_COLLIDER:         name = "Sphere Collider";          break;
    case ComponentType::CAPSULE_COLLIDER:        name = "Capsule Collider";         break;
    case ComponentType::PLANE_COLLIDER:          name = "Plane Collider";           break;
    case ComponentType::INFINITE_PLANE_COLLIDER: name = "Infinite Plane Collider";  break;
    case ComponentType::MESH_COLLIDER:           name = "Mesh Collider";            break;
    case ComponentType::CONVEX_COLLIDER:         name = "Convex Collider";          break;
    case ComponentType::JOINT:                   name = "Joint";                    break;
    case ComponentType::HINGE_JOINT:             name = "Hinge Joint";              break;
    case ComponentType::DISTANCE_JOINT:          name = "Distance Joint";           break;
    case ComponentType::FIXED_JOINT:             name = "Fixed Joint";              break;
    case ComponentType::D6_JOINT:                name = "D6 Joint";                 break;
    case ComponentType::PRISMATIC_JOINT:         name = "Prismatic Joint";          break;
    case ComponentType::SPHERICAL_JOINT:         name = "Spherical Joint";          break;
    case ComponentType::CANVAS:                  name = "Canvas";                   break;
    case ComponentType::LISTENER:                name = "Audio Listener";           break;
    case ComponentType::AUDIOSOURCE:             name = "Audio Source";             break;
    case ComponentType::REVERBZONE:              name = "Reverb Zone";              break;
    case ComponentType::NAVIGATION:              name = "Navigation";               break;
    case ComponentType::LIGHT:                   name = "Light";                    break;
    case ComponentType::CAMERA_ZONE:             name = "Camera Zone";              break;
    case ComponentType::CINEMATIC_CAMERA:        name = "Cinematic Camera";         break;
    default:                                     name = "Unknown Component";        break;
    }
}