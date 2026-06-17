#pragma once
#if (defined(__linux__) || defined(__APPLE__)) && !defined(ANDROID)
#include <_types.h>
#include <sound/SoundSystem.hpp>
#ifdef __APPLE__
// On Apple, ALCdevice/ALCcontext are typedefs (typedef struct ALCdevice_struct
// ALCdevice), so `struct ALCdevice*` would create a conflicting tag. Pull in
// the real OpenAL headers and use the typedef names directly.
#include <OpenAL/alc.h>
#endif

struct SoundSystemAL: public SoundSystem
{
	static const int MAX_PLAYED = 4;

#ifdef __APPLE__
	ALCdevice* device = 0;
	ALCcontext* context = 0;
#else
	struct ALCdevice* device = 0;
	struct ALCcontext* context = 0;
#endif
	int playedCnt = 0;
	uint32_t buffers[MAX_PLAYED] = {0};
	uint32_t sources[MAX_PLAYED] = {0};

	SoundSystemAL(void);
	virtual ~SoundSystemAL();
	bool_t checkErr(uint32_t);
	void destroy(void);
	void init(void);
	void removeStoppedSounds(void);
	virtual void setListenerPos(float, float, float);
	virtual void setListenerAngle(float);
	virtual void load(const std::string&);
	virtual void play(const std::string&);
	virtual void pause(const std::string&);
	virtual void stop(const std::string&);
	virtual void playAt(const struct SoundDesc&, float, float, float, float, float);
};
#endif
