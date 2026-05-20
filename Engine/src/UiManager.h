#pragma once

#include <string>
#include <unordered_set>
#include <unordered_map>
#include <vector>

class ComponentCanvas;

class UIManager {
public:
    static UIManager& GetInstance();

    // Botones
    void RegisterButton(const std::string& name);
    void RegisterClickedButton(const std::string& name);
    void RegisterFocusedButton(const std::string& name);
    
    bool WasButtonJustClicked(const std::string& name) const;
    bool WasButtonJustFocused(const std::string& name) const;

    void ClearFrameClicks();
    void ClearFrameFocused();
    void ClearCanvasButtons();

    std::unordered_set<std::string> GetCanvasButtons();

    // Sliders
    void RegisterSlider(const std::string& name);
    void RegisterSliderValue(const std::string& name, float value);
    float GetSliderValue(const std::string& name) const;
    bool SliderValueChanged(const std::string& name) const;
    void ClearSliderChanges();
    void SetSliderValue(const std::string& elementName, float value);
    std::unordered_set<std::string> GetCanvasSliders();

    // Canvas registry
    void RegisterCanvas(ComponentCanvas* canvas);
    void UnregisterCanvas(ComponentCanvas* canvas);

    void SetElementHeight(const std::string& elementName, float height);
    void SetElementWidth(const std::string& elementName, float width);
    void SetElementText(const std::string& elementName, const std::string& text);
    void SetCheckBox(const std::string& elementName, bool checked);
    void SetElementVisibility(const std::string& elementName, bool visible);
    void SetElementMargin(const std::string& elementName, float left, float top, float right, float bottom);
    void SetCanvasOpacity(ComponentCanvas* canvas, float opacity);
    void SetCanvasPosition(const std::string& elementName, float left, float top);

private:
    UIManager() = default;
    ~UIManager() = default;
    UIManager(const UIManager&) = delete;
    UIManager& operator=(const UIManager&) = delete;

    void* FindElement(const std::string& elementName);

    std::unordered_set<std::string>         m_justClickedButtons;
    std::unordered_set<std::string>         m_justFocusedButtons;
    std::vector<ComponentCanvas*>           m_canvases;
    std::unordered_set<std::string>         m_canvasButtons;

    // Sliders
    std::unordered_set<std::string>         m_canvasSliders;
    std::unordered_map<std::string, float>  m_sliderValues;
    std::unordered_set<std::string>         m_changedSliders;
};