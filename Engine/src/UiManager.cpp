#include "UIManager.h"

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
