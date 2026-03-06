#pragma once

#include <string>
#include <unordered_set>

class UIManager {
public:
    static UIManager& GetInstance();

    // Llamado por los manejadores de eventos de Noesis cuando se pulsa un botón
    void RegisterClickedButton(const std::string& name);

    // Llamado desde Lua para comprobar si un botón fue pulsado en este fotograma
    bool WasButtonJustClicked(const std::string& name) const;

    // Llamado al final del fotograma para limpiar el estado
    void ClearFrameClicks();

private:
    UIManager() = default;
    ~UIManager() = default;
    UIManager(const UIManager&) = delete;
    UIManager& operator=(const UIManager&) = delete;

    std::unordered_set<std::string> m_justClickedButtons;
};
