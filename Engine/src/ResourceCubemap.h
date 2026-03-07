#pragma once

#include "ModuleResources.h"

class ResourceCubemap : public Resource {
public:
	ResourceCubemap(UID uid);
	virtual ~ResourceCubemap();

	// Virtual method implementation
	bool LoadInMemory() override;
	void UnloadFromMemory() override;

	Cubemap* GetCubemap() { return cubemap; }

private:
	Cubemap* cubemap;
};