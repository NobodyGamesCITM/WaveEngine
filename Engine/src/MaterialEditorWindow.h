
#include "EditorWindow.h"
#include "Material.h"
#include "Globals.h"
#include <string>

class ResourceMaterial;
class MaterialStandard;

class MaterialEditorWindow : public EditorWindow
{
public:
    MaterialEditorWindow();
    ~MaterialEditorWindow();

    void SetMaterialToEdit(UID materialUID);

    void Draw() override;
    void Save();

private:
    void DrawStandardMaterialProperties(MaterialStandard* mat);
    bool DrawTextureSlot(const char* label, UID& currentUID, MaterialStandard* mat);
    void ChangeMaterialType(MaterialType newType);

    UID currentMatUID = 0;
    ResourceMaterial* resMat = nullptr;
    Material* editingMaterial = nullptr;
};
