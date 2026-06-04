#include "UIManager.h"
#include "ComponentCanvas.h"
#include <NsGui/FrameworkElement.h>
#include <NsGui/VisualTreeHelper.h>
#include <NsGui/TextBlock.h>
#include <NsGui/CheckBox.h>
#include <NsGui/Slider.h>
#include <NsCore/Nullable.h>
#include <NsGui/Canvas.h>
#include <NsGui/Shape.h>
#include <NsGui/Brush.h>
#include <NsGui/GradientBrush.h>
#include <NsGui/GradientStop.h>
#include <algorithm>
#include <functional>
#include <NsDrawing/Thickness.h>
#include <NsGui/RadialGradientBrush.h>

UIManager& UIManager::GetInstance() {
    static UIManager instance;
    return instance;
}

void UIManager::RegisterButton(const std::string& name) {
    if (!name.empty())
        m_canvasButtons.insert(name);
}

void UIManager::RegisterClickedButton(const std::string& name) {
    if (!name.empty())
        m_justClickedButtons.insert(name);
}

void UIManager::RegisterFocusedButton(const std::string& name) {
    if (!name.empty())
        m_justFocusedButtons.insert(name);
}

bool UIManager::WasButtonJustClicked(const std::string& name) const {
    return m_justClickedButtons.count(name) > 0;
}

bool UIManager::WasButtonJustFocused(const std::string& name) const {
    return m_justFocusedButtons.count(name) > 0;
}

void UIManager::ClearFrameClicks() { m_justClickedButtons.clear(); }
void UIManager::ClearFrameFocused() { m_justFocusedButtons.clear(); }
void UIManager::ClearCanvasButtons() { m_canvasButtons.clear(); }

// ---- Sliders ----

void UIManager::RegisterSlider(const std::string& name) {
    if (!name.empty()) {
        m_canvasSliders.insert(name);
        if (m_sliderValues.find(name) == m_sliderValues.end())
            m_sliderValues[name] = 0.0f;
    }
}

void UIManager::RegisterSliderValue(const std::string& name, float value) {
    if (!name.empty()) {
        m_sliderValues[name] = value;
        m_changedSliders.insert(name);
    }
}

float UIManager::GetSliderValue(const std::string& name) const {
    auto it = m_sliderValues.find(name);
    return (it != m_sliderValues.end()) ? it->second : 0.0f;
}

bool UIManager::SliderValueChanged(const std::string& name) const {
    return m_changedSliders.count(name) > 0;
}

void UIManager::ClearSliderChanges() { m_changedSliders.clear(); }

std::unordered_set<std::string> UIManager::GetCanvasSliders() {
    return m_canvasSliders;
}

void UIManager::SetSliderValue(const std::string& elementName, float value) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName));
    if (!fe) return;
    if (auto* slider = Noesis::DynamicCast<Noesis::Slider*>(fe)) {
        float clamped = std::clamp(value,
            (float)slider->GetMinimum(),
            (float)slider->GetMaximum());
        slider->SetValue(clamped);
        m_sliderValues[elementName] = clamped;
    }
}

// ---- Slider con foco (para mando) ----

void UIManager::SetFocusedSlider(const std::string& name) {
    m_focusedSlider = name;
}

void UIManager::ClearFocusedSlider() {
    m_focusedSlider.clear();
}

const std::string& UIManager::GetFocusedSlider() const {
    return m_focusedSlider;
}

bool UIManager::HasFocusedSlider() const {
    return !m_focusedSlider.empty();
}

void UIManager::StepFocusedSlider(float delta) {
    if (m_focusedSlider.empty()) return;

    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(m_focusedSlider));
    if (!fe) return;

    if (auto* slider = Noesis::DynamicCast<Noesis::Slider*>(fe)) {
        float current = (float)slider->GetValue();
        float minVal = (float)slider->GetMinimum();
        float maxVal = (float)slider->GetMaximum();
        float newVal = std::clamp(current + delta, minVal, maxVal);
        slider->SetValue(newVal);
        m_sliderValues[m_focusedSlider] = newVal;
        m_changedSliders.insert(m_focusedSlider);
    }
}

void UIManager::RegisterCanvas(ComponentCanvas* canvas) {
    m_canvases.push_back(canvas);
}

void UIManager::UnregisterCanvas(ComponentCanvas* canvas) {
    m_canvases.erase(
        std::remove(m_canvases.begin(), m_canvases.end(), canvas),
        m_canvases.end());
}

void* UIManager::FindElement(const std::string& elementName) {
    for (auto* canvas : m_canvases) {
        auto* view = canvas->GetView();
        if (!view) continue;
        Noesis::FrameworkElement* root = view->GetContent();
        if (!root) continue;
        Noesis::FrameworkElement* found = nullptr;
        std::function<void(Noesis::Visual*)> search = [&](Noesis::Visual* el) {
            if (!el || found) return;
            if (auto* fe = Noesis::DynamicCast<Noesis::FrameworkElement*>(el)) {
                const char* n = fe->GetName();
                if (n && elementName == n) { found = fe; return; }
            }
            uint32_t count = Noesis::VisualTreeHelper::GetChildrenCount(el);
            for (uint32_t i = 0; i < count; ++i)
                search(Noesis::VisualTreeHelper::GetChild(el, i));
            };
        search(root);
        if (found) return found;
    }
    return nullptr;
}

void UIManager::SetElementHeight(const std::string& elementName, float height) {
    if (auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName)))
        fe->SetHeight(height);
}

void UIManager::SetElementWidth(const std::string& elementName, float width) {
    if (auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName)))
        fe->SetWidth(width);
}

void UIManager::SetElementText(const std::string& elementName, const std::string& text) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName));
    if (!fe) return;
    if (auto* tb = Noesis::DynamicCast<Noesis::TextBlock*>(fe))
        tb->SetText(text.c_str());
}

void UIManager::SetCheckBox(const std::string& elementName, bool checked) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName));
    if (!fe) return;
    if (auto* cb = Noesis::DynamicCast<Noesis::CheckBox*>(fe))
        cb->SetIsChecked(checked);
}

void UIManager::SetElementVisibility(const std::string& elementName, bool visible) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName));
    if (!fe) return;
    fe->SetVisibility(visible ? Noesis::Visibility_Visible : Noesis::Visibility_Hidden);
}

std::unordered_set<std::string> UIManager::GetCanvasButtons() {
    return m_canvasButtons;
}

void UIManager::SetElementMargin(const std::string& elementName, float left, float top, float right, float bottom) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName));
    if (!fe) return;
    fe->SetMargin(Noesis::Thickness(left, top, right, bottom));
}

void UIManager::SetCanvasOpacity(ComponentCanvas* canvas, float opacity) {
    if (!canvas) return;
    canvas->SetOpacity(std::clamp(opacity, 0.0f, 1.0f));
}

void UIManager::SetCanvasPosition(const std::string& elementName, float left, float top) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName));
    if (!fe) return;
    Noesis::Canvas::SetLeft(fe, left);
    Noesis::Canvas::SetTop(fe, top);
}

void UIManager::SetRadialGradientCenter(const std::string& name, float x, float y) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(name));
    if (!fe) return;

    Noesis::Shape* shape = Noesis::DynamicCast<Noesis::Shape*>(fe);
    if (!shape) return;

    Noesis::Brush* brush = shape->GetFill();
    if (!brush) return;

    Noesis::RadialGradientBrush* rgb = Noesis::DynamicCast<Noesis::RadialGradientBrush*>(brush);
    if (!rgb) return;

    rgb->SetCenter(Noesis::Point(x, y));
    rgb->SetGradientOrigin(Noesis::Point(x, y));
}

void UIManager::SetRadialGradientCenterAndRadius(const std::string& name, float x, float y, float radiusX, float radiusY) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(name));
    if (!fe) return;

    Noesis::Shape* shape = Noesis::DynamicCast<Noesis::Shape*>(fe);
    if (!shape) return;

    Noesis::Brush* brush = shape->GetFill();
    if (!brush) return;

    Noesis::RadialGradientBrush* rgb = Noesis::DynamicCast<Noesis::RadialGradientBrush*>(brush);
    if (!rgb) return;

    rgb->SetMappingMode(Noesis::BrushMappingMode_Absolute);
    rgb->SetCenter(Noesis::Point(x, y));
    rgb->SetGradientOrigin(Noesis::Point(x, y));
    rgb->SetRadiusX(radiusX);
    rgb->SetRadiusY(radiusY);
}