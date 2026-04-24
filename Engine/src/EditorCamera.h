#pragma once
#include "Module.h"
#include <glm/gtc/matrix_transform.hpp>
#include <array>

class AABB;
class CameraLens;
struct Ray;


class EditorCamera
{
public:

	EditorCamera();

	virtual ~EditorCamera();

	bool Update();

	bool CleanUp();

	void LockCamera(bool _lockCamera) { lockCamera = _lockCamera; }

	CameraLens* GetCameraLens() { return cameraLens; }

	bool GetCameraLocked() { return lockCamera; }

	float GetSpeed() const { return speed; }
	void  SetSpeed(float s) { speed = s; }
	float GetSpeedMultiplier() const { return speedMultiplier; }
	void  SetSpeedMultiplier(float m) { speedMultiplier = m; }

	bool IsMouseCaptured() const { return mouseCaptured; }

	////EVENTS
	//void OnEvent(const Event& event) override;

private:
	void CalcMouseVectors();
	void MoveCamera();

public:
	bool windowChanged;
	bool viewChanged;

	glm::vec3 forward;
private:

	CameraLens* cameraLens;

	glm::vec3 position;
	glm::vec3 up;
	glm::vec3 right;

	float speed;
	float speedMultiplier;

	float mouseSensibility;
	float yaw;
	float pitch;

	float fieldOfView;
	float maxFieldOfView;
	float minFieldOfView;
	float zoomSpeed;

	float focusDistance;
	float orbitDistance;

	bool orbit;
	bool move;
	bool zoom;
	bool focus;
	bool pan;

	float panSpeed = 0.003f;

	glm::vec3 orbitPivot;
	bool orbitActive = false;

	bool shouldBeRelative;
	bool mouseCaptured;
	bool lockCamera;


	glm::vec2 startMovementPos;
};