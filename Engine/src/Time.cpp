#include "Time.h"
#include "Log.h"
#include "Application.h"
#include <SDL3/SDL.h>

Time* Time::instance = nullptr;

Time::Time() : Module(), deltaTime(0.0f), gameDeltaTime(0.0f), totalTime(0.0f), gameTime(0.0f), lastFrame(0.0f), isPaused(true), timeScale(1.0f), shouldStepFrame(false)
{
	instance = this;  
}

Time::~Time()
{
	instance = nullptr;  
}

bool Time::Start()
{
	lastFrame = SDL_GetTicks() / 1000.0f;
	accumulator = 0.0f;
	fixedDeltaTime = 0.02f;

	return true;
}

bool Time::PreUpdate()
{
	ZoneScopedNC("Time::PreUpdate", 0x95A5A6);
	float currentFrame = SDL_GetTicks() / 1000.0f;
	deltaTime = currentFrame - lastFrame;
	totalTime = currentFrame;
	lastFrame = currentFrame;

	//GAME TIMERS
	if (!isPaused || shouldStepFrame)
	{
		//DELTA TIME
		if (shouldStepFrame)
		{
			gameDeltaTime = fixedDeltaTime;
			shouldStepFrame = false;
		}
		else
		{
			gameDeltaTime = deltaTime * timeScale;
		}

		//FIXED DELTA TIME
		accumulator += gameDeltaTime;

		while (accumulator >= fixedDeltaTime)
		{
			Application::GetInstance().FixedUpdate();

			accumulator -= fixedDeltaTime;
		}

		fixedAlpha = accumulator /fixedDeltaTime;
	}
	else
	{
		gameDeltaTime = 0.0f;
		fixedAlpha = 1.0f;
	}

	gameTime += gameDeltaTime;

	return true;
}

bool Time::PostUpdate()
{
	ZoneScopedNC("Time::PostUpdate", 0x7F8C8D);
	return true;
}

void Time::Reset()
{
	lastFrame = SDL_GetTicks() / 1000.0f;
	totalTime = 0.0f;
	gameTime = 0.0f;
	gameDeltaTime = 0.0f;
	deltaTime = 0.0f;
	accumulator = 0.0f;
	isPaused = false;
}

float Time::GetDeltaTimeStatic()
{
	if (!instance) return 0.016f;
	return instance->gameDeltaTime;
}

float Time::GetRealDeltaTimeStatic()
{
	if (!instance) return 0.016f;
	return instance->deltaTime;
}

float Time::GetTotalTimeStatic()
{
	if (!instance) return 0.0f;
	return instance->totalTime;
}