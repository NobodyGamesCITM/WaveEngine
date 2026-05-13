#include "Grid.h"
#include "Application.h"
#include "Renderer.h"
#include "Log.h"

Grid::Grid() : Module(), enabled(true), gridSize(200.0f), gridDivisions(20)
{
}

Grid::~Grid()
{
}

bool Grid::Start()
{
    // Ya no necesitamos CreateGrid() porque no creamos buffers fijos
    return true;
}

bool Grid::Update()
{
    ZoneScopedNC("Grid::Update", 0x16A085);
    if (enabled)
    {
        Draw();
    }
    return true;
}

void Grid::Draw()
{
    // Acceso al renderer
    auto* renderer = Application::GetInstance().renderer.get();
    if (!renderer) return;

    float halfSize = gridSize / 2.0f;
    float step = gridSize / (float)gridDivisions;

    glm::vec4 normalColor = glm::vec4(0.5f, 0.5f, 0.5f, 1.0f);
    glm::vec4 axisColor = glm::vec4(1.0f, 1.0f, 1.0f, 1.0f);

    for (int i = 0; i <= gridDivisions; ++i)
    {
        float x = -halfSize + (float)i * step;
        glm::vec4 color = (abs(x) < 0.001f) ? axisColor : normalColor;

        renderer->DrawLine(
            glm::vec3(x, 0.0f, -halfSize),
            glm::vec3(x, 0.0f, halfSize),
            color
        );
    }

    for (int i = 0; i <= gridDivisions; ++i)
    {
        float z = -halfSize + (float)i * step;
        glm::vec4 color = (abs(z) < 0.001f) ? axisColor : normalColor;

        renderer->DrawLine(
            glm::vec3(-halfSize, 0.0f, z),
            glm::vec3(halfSize, 0.0f, z),
            color
        );
    }
}

bool Grid::CleanUp()
{
    LOG_DEBUG("Cleaning up Grid");
    
    return true;
}