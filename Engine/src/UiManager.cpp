#include "UIManager.h"
#include "ComponentCanvas.h"
#include <NsGui/FrameworkElement.h>
#include <NsGui/VisualTreeHelper.h>
#include <NsGui/TextBlock.h>
#include <algorithm>
#include <functional>

UIManager& UIManager::GetInstance() {
    static UIManager instance;
    return instance;
}

void UIManager::RegisterClickedButton(const std::string& name) {
    if (!name.empty()) {
        m_justClickedButtons.insert(name);
    }
}

bool UIManager::WasButtonJustClicked(const std::string& name) const {
    return m_justClickedButtons.count(name) > 0;
}

void UIManager::ClearFrameClicks() {
    m_justClickedButtons.clear();
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

void UIManager::SetElementVisibility(const std::string& elementName, bool visible) {
    auto* fe = static_cast<Noesis::FrameworkElement*>(FindElement(elementName));
    if (!fe) return;

    fe->SetVisibility(visible ? Noesis::Visibility_Visible
        : Noesis::Visibility_Hidden);
}