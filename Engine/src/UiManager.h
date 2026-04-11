#pragma once

#include <string>
#include <unordered_set>
#include <vector>

class ComponentCanvas;

class UIManager {
public:
    static UIManager& GetInstance();

    //Botones
    void RegisterButton(const std::string& name);
    void RegisterClickedButton(const std::string& name);
    void RegisterFocusedButton(const std::string& name);
    
    bool WasButtonJustClicked(const std::string& name) const;
    bool WasButtonJustFocused(const std::string& name) const;

    void ClearFrameClicks();
    void ClearFrameFocused();
    void ClearCanvasButtons();

    //llamable des de Lua
    std::unordered_set<std::string> GetCanvasButtons();

    //Canvas registry
    void RegisterCanvas(ComponentCanvas* canvas);
    void UnregisterCanvas(ComponentCanvas* canvas);

    //Propiedades de elementos XAML (llamable desde Lua)
    void SetElementHeight(const std::string& elementName, float height);
    void SetElementWidth(const std::string& elementName, float width);
    void SetElementText(const std::string& elementName, const std::string& text);
    void SetElementVisibility(const std::string& elementName, bool visible);

private:
    UIManager() = default;
    ~UIManager() = default;
    UIManager(const UIManager&) = delete;
    UIManager& operator=(const UIManager&) = delete;

    void* FindElement(const std::string& elementName);

    std::unordered_set<std::string> m_justClickedButtons;
    std::unordered_set<std::string> m_justFocusedButtons;
    std::vector<ComponentCanvas*>   m_canvases;
    std::unordered_set<std::string> m_canvasButtons;
};