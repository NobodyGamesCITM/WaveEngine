#pragma once
#include "GameObject.h"
#include "Transform.h"
#include "AudioUtility.h"

class AudioComponent {
public:
    virtual ~AudioComponent() {}

    // Pure virtual (for Listener and Source)
    virtual void SetTransform() = 0; 

    // get the type (source or listener)
    virtual ComponentType GetType() const = 0;

    // Get the associated game object
    std::shared_ptr<GameObject> GetGameObject() { return GO; }

public:
    AkGameObjectID goID;
    std::shared_ptr<GameObject> GO;
    bool enabled = true;
};