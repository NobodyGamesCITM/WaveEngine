#include "EditorCamera.h"
#include "Application.h"
#include <SDL3/sdl.h>
#include "glm/glm.hpp"
#include <glm/gtc/matrix_transform.hpp>
#include "CameraLens.h"
#include "ModuleEditor.h"
#include "SceneWindow.h"
#include "Renderer.h"
#include "ModuleScene.h"
#include "Window.h"
#include "GameObject.h"
#include "Component.h"
#include "Transform.h"
#include "Frustum.h"
#include "Time.h"
#include "ImGuizmo.h"
#ifndef WAVE_GAME
#include "ModuleEditor.h"
#endif // !WAVE_GAME



EditorCamera::EditorCamera()
{
	bool ret = true;

	cameraLens = new CameraLens();
	cameraLens->SetDebugCamera(true);

	int w, h;
	Application::GetInstance().window->GetWindowSize(w, h);
	cameraLens->SetRenderTarget(w, h);
	cameraLens->depth = -1;

	position = glm::vec3(0.0f, 0.0f, 10.0f);
	forward = glm::vec3(0.0f, 0.0f, -1.0f);
	up = glm::vec3(0.0f, 1.0f, 0.0f);
	right = glm::cross(forward, up);

	speed = 1;
	speedMultiplier = 5;
	yaw = -90.0f;
	pitch = 0.0f;
	mouseSensibility = 0.1f;
	fieldOfView = 45.0f;
	maxFieldOfView = 45.0f;
	minFieldOfView = 10.0f;
	fieldOfView = 45.0f;
	zoomSpeed = 3.0f;
	focusDistance = 5.0f;

	focus = false;
	move = false;
	zoom = false;
	orbit = false;
	pan = false;

	shouldBeRelative = false;
	mouseCaptured = false;
	lockCamera = true;

	viewChanged = true;
	windowChanged = true;
}

EditorCamera::~EditorCamera()
{

}


bool EditorCamera::Update()
{
	bool ret = true;
#ifndef WAVE_GAME
	lockCamera = ImGuizmo::IsUsing() || !Application::GetInstance().editor->GetSceneWindow()->IsHovered();

	if (!lockCamera)
	{
		MoveCamera();
	}

	//UPDATE MATRIX
	if (viewChanged)
	{
		cameraLens->LookAt(position, position + forward, up);
		viewChanged = false;
	}

	if (windowChanged)
	{
		float aspectRatio = 1.77f;

		if (cameraLens->textureHeight > 0)
		{
			aspectRatio = (float)cameraLens->textureWidth / (float)cameraLens->textureHeight;
		}

		cameraLens->SetPerspective(fieldOfView, aspectRatio, 0.1f, 1000.0f);
		windowChanged = false;
	}
#endif // !WAVE_ENGINE
	return ret;

}

void EditorCamera::MoveCamera()
{
	std::vector<GameObject*> gameObjects = Application::GetInstance().selectionManager->GetSelectedObjects();

	bool shouldBeRelative = (
		(Application::GetInstance().input->GetMouseButtonDown(3) == KEY_REPEAT) ||
		(Application::GetInstance().input->GetMouseButtonDown(2) == KEY_REPEAT) ||
		(Application::GetInstance().input->GetKey(SDL_SCANCODE_LALT) == KEY_REPEAT && Application::GetInstance().input->GetMouseButtonDown(1) == KEY_REPEAT));

	if (shouldBeRelative && !mouseCaptured)
	{
		float tempX, tempY;
		SDL_GetRelativeMouseState(&tempX, &tempY);
		SDL_SetWindowRelativeMouseMode(Application::GetInstance().window->GetWindow(), true);
		mouseCaptured = true;
		SDL_GetMouseState(&startMovementPos.x, &startMovementPos.y);
	}
	else if (mouseCaptured && !shouldBeRelative)
	{
		SDL_SetWindowRelativeMouseMode(Application::GetInstance().window->GetWindow(), false);
		mouseCaptured = false;
	}
	else if (mouseCaptured && shouldBeRelative)
	{
		SDL_WarpMouseInWindow(Application::GetInstance().window->GetWindow(), startMovementPos.x, startMovementPos.y);
	}


	orbit = Application::GetInstance().input->GetMouseButtonDown(1) == KEY_REPEAT && Application::GetInstance().input->GetKey(SDL_SCANCODE_LALT) == KEY_REPEAT;
	pan = Application::GetInstance().input->GetMouseButtonDown(2) == KEY_REPEAT;
	move = Application::GetInstance().input->GetMouseButtonDown(3) == KEY_REPEAT;

	if (!orbit) orbitActive = false;
	focus = Application::GetInstance().input->GetKey(SDL_SCANCODE_F) == KEY_DOWN && !gameObjects.empty();
	zoom = Application::GetInstance().input->GetMouseWheelY() != 0;

	//FOCUS
	if (focus)
	{
		glm::vec3 centerPosition(0.0f);
		int validTransforms = 0;

		for (GameObject* go : gameObjects)
		{
			Transform* transform = (Transform*)go->transform;
			if (transform)
			{
				centerPosition += transform->GetGlobalPosition();
				validTransforms++;
			}
		}

		if (validTransforms > 0)
		{
			centerPosition /= (float)validTransforms;

			forward = glm::normalize(centerPosition - position);
			position = centerPosition - (forward * focusDistance);

			yaw = glm::degrees(atan2(forward.z, forward.x));
			pitch = glm::degrees(asin(forward.y));

			right = glm::normalize(glm::cross(forward, glm::vec3(0.0f, 1.0f, 0.0f)));
			up = glm::normalize(glm::cross(right, forward));

			viewChanged = true;
		}
		focus = false;
	}
	//ORBIT
	else if (orbit)
	{
		if (!orbitActive)
		{
			if (!gameObjects.empty())
			{
				glm::vec3 centerPosition(0.0f);
				int validTransforms = 0;
				for (GameObject* go : gameObjects)
				{
					Transform* transform = (Transform*)go->transform;
					if (transform)
					{
						centerPosition += transform->GetGlobalPosition();
						validTransforms++;
					}
				}
				if (validTransforms > 0)
					orbitPivot = centerPosition / (float)validTransforms;
			}
			else
			{
				orbitPivot = position + forward * orbitDistance;
			}
			orbitActive = true;
		}

		orbitDistance = glm::length(orbitPivot - position);
		CalcMouseVectors();
		position = orbitPivot - (forward * orbitDistance);
		viewChanged = true;
	}
	//PAN
	else if (pan)
	{
		float mouseX, mouseY;
		SDL_GetRelativeMouseState(&mouseX, &mouseY);

		float panScale = panSpeed * orbitDistance;
		position -= right * (mouseX * panScale);
		position += up * (mouseY * panScale);
		viewChanged = true;
	}
	//WASD AND MOUSE MOVEMENT
	else if (move)
	{
		CalcMouseVectors();

		bool wPressed = Application::GetInstance().input->GetKey(SDL_SCANCODE_W) == KEY_REPEAT;
		bool sPressed = Application::GetInstance().input->GetKey(SDL_SCANCODE_S) == KEY_REPEAT;
		bool aPressed = Application::GetInstance().input->GetKey(SDL_SCANCODE_A) == KEY_REPEAT;
		bool dPressed = Application::GetInstance().input->GetKey(SDL_SCANCODE_D) == KEY_REPEAT;
		bool qPressed = Application::GetInstance().input->GetKey(SDL_SCANCODE_Q) == KEY_REPEAT;
		bool ePressed = Application::GetInstance().input->GetKey(SDL_SCANCODE_E) == KEY_REPEAT;
		bool shift = (Application::GetInstance().input->GetKey(SDL_SCANCODE_LSHIFT) == KEY_REPEAT ||
			Application::GetInstance().input->GetKey(SDL_SCANCODE_RSHIFT) == KEY_REPEAT);


		int xMovement = 0;
		if (aPressed && !dPressed) xMovement = -1;
		if (dPressed && !aPressed) xMovement = 1;

		int zMovement = 0;
		if (wPressed && !sPressed) zMovement = 1;
		if (sPressed && !wPressed) zMovement = -1;

		float dt = Application::GetInstance().time->GetRealDeltaTime();
		float finalSpeed = speed * dt * (shift ? speedMultiplier : 1.0f);

		if (wPressed)
			position += forward * finalSpeed;
		if (sPressed)
			position -= forward * finalSpeed;
		if (aPressed)
			position -= right * finalSpeed;
		if (dPressed)
			position += right * finalSpeed;
		if (qPressed)
			position -= up * finalSpeed;
		if (ePressed)
			position += up * finalSpeed;
		viewChanged = true;
	}

	//ZOOM and SPEED CHANGE
	if (zoom)
	{
		float mouseWheel = Application::GetInstance().input->GetMouseWheelY();

		bool cameraMoving = move && (
			Application::GetInstance().input->GetKey(SDL_SCANCODE_W) == KEY_REPEAT ||
			Application::GetInstance().input->GetKey(SDL_SCANCODE_S) == KEY_REPEAT ||
			Application::GetInstance().input->GetKey(SDL_SCANCODE_A) == KEY_REPEAT ||
			Application::GetInstance().input->GetKey(SDL_SCANCODE_D) == KEY_REPEAT ||
			Application::GetInstance().input->GetKey(SDL_SCANCODE_Q) == KEY_REPEAT ||
			Application::GetInstance().input->GetKey(SDL_SCANCODE_E) == KEY_REPEAT
			);

		if (cameraMoving)
		{
			speed = glm::clamp(speed + mouseWheel * 0.5f, 0.1f, 50.0f);
		}
		else
		{
			if (mouseWheel < 0)
			{
				position -= forward * 2.0f;
			}
			else if (mouseWheel > 0)
			{
				position += forward * 2.0f;
			}
			viewChanged = true;
		}
	}
}

void EditorCamera::CalcMouseVectors()
{
	//MOUSE
	float mouseX, mouseY;
	SDL_GetRelativeMouseState(&mouseX, &mouseY);

	float xOffset = mouseX * mouseSensibility;
	float yOffset = mouseY * mouseSensibility;

	yaw += xOffset;
	pitch -= yOffset;

	if (pitch > 89.0f)
		pitch = 89.0f;
	if (pitch < -89.0f)
		pitch = -89.0f;

	glm::vec3 newForward;
	newForward.x = cos(glm::radians(yaw)) * cos(glm::radians(pitch));
	newForward.y = sin(glm::radians(pitch));
	newForward.z = sin(glm::radians(yaw)) * cos(glm::radians(pitch));

	forward = glm::normalize(newForward);

	right = glm::normalize(glm::cross(forward, glm::vec3(0.0f, 1.0f, 0.0f)));
	up = glm::normalize(glm::cross(right, forward));
}

bool EditorCamera::CleanUp()
{
	bool ret = true;

	cameraLens->CleanUp();
	delete cameraLens;

	return ret;
}